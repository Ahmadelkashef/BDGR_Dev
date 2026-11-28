import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../fantasy.dart' show openProfileRoundSquad;
import '../media_cache.dart';
import '../profile/profile_trophies.dart';
import '../profile/visitor_profile_sheet.dart';
import 'feed_api.dart' show FeedApi;

// ═════════════════════════════════════════════════════════════════════════
// BDGR moments (owner, 28 Nov): achievement cards made by the app from real results.
// Users upload nothing and write nothing (preset captions only) → no comments, no moderation, ~zero egress
// (the card is drawn on the phone from numbers). Server: feed_moments + moments_feed / moments_stories / moment_react.
// The owner controls everything (remove, story hours) from the DB (mgmt_moment_set).
// ═════════════════════════════════════════════════════════════════════════

const _reactions = <(String, String)>[('fire', '🔥'), ('clap', '👏'), ('laugh', '😂'), ('clown', '🤡')];

class MomentUser {
  MomentUser(Map<String, dynamic> j)
      : userId = (j['user_id'] as num?)?.toInt() ?? 0,
        uid = j['uid']?.toString(),
        name = '${j['name'] ?? 'New Badger'}',
        username = j['username']?.toString(),
        avatar = j['avatar']?.toString();
  final int userId;
  final String? uid, username, avatar;
  final String name;
}

class Moment {
  Moment(Map<String, dynamic> j)
      : id = '${j['id']}',
        kind = '${j['kind']}',
        arena = j['arena']?.toString(),
        eventId = j['event_id']?.toString(),
        payload = j['payload'] is Map ? Map<String, dynamic>.from(j['payload'] as Map) : {},
        caption = j['caption']?.toString(),
        at = DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
        user = MomentUser(Map<String, dynamic>.from(j['user'] as Map? ?? {})),
        counts = {for (final e in (j['counts'] as Map? ?? {}).entries) '${e.key}': (e.value as num).toInt()},
        mine = j['mine']?.toString(),
        isMe = j['is_me'] == true,
        iFollow = j['i_follow'] == true;
  final String id, kind;
  final String? arena, eventId, caption;
  final Map<String, dynamic> payload;
  final DateTime at;
  final MomentUser user;
  final Map<String, int> counts;
  String? mine;
  final bool isMe;
  bool iFollow;
  int get total => counts.values.fold(0, (a, b) => a + b);
}

class MomentsApi {
  MomentsApi._();
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<List<Moment>> feed({DateTime? before}) async {
    final r = await _sb.rpc('moments_feed', params: {'p_before': before?.toUtc().toIso8601String(), 'p_limit': 10});
    return [for (final x in (r as List? ?? const [])) Moment(Map<String, dynamic>.from(x as Map))];
  }

  /// one entry per user: [user's moments oldest → newest]
  static Future<List<List<Moment>>> stories() async {
    final r = await _sb.rpc('moments_stories');
    return [
      for (final u in (r as List? ?? const []))
        [for (final x in ((u as Map)['items'] as List? ?? const [])) Moment(Map<String, dynamic>.from(x as Map))]
    ].where((l) => l.isNotEmpty).toList();
  }

  static Future<void> react(Moment m, String? emoji) =>
      _sb.rpc('moment_react', params: {'p_id': m.id, 'p_emoji': emoji});

  static Future<void> follow(int userId) => _sb.rpc('follow_user', params: {'p_target_user_id': userId});
}

/// preset captions (no free text)
String momentCaption(String? key) => switch (key) {
      'break' => AppLang.t('Who can beat this? 😏', 'مين يقدر يكسرها؟ 😏'),
      'first' => AppLang.t('First time up here 🔥', 'أول مرة أوصل هنا 🔥'),
      'streak' => AppLang.t("Haven't missed a gameweek 🔥", 'ولا جولة فاتتني 🔥'),
      'proud' => AppLang.t('My best one yet 💪', 'أحسن جولة ليا لحد دلوقتي 💪'),
      _ => '',
    };

String _flag(String? arena) => arena == 'WORLD' ? '🌍' : '🇪🇬';
String _n(int v) => v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
String _pts(dynamic p) => p is num ? (p == p.roundToDouble() ? '${p.toInt()}' : '$p') : '$p';

/// colours per kind
(Color, Color, Color) _tone(Moment m) {
  final rank = (m.payload['rank'] as num?)?.toInt() ?? 0;
  if (m.kind == 'gov1' || rank == 1) return (const Color(0xFF5A1010), const Color(0xFF7A2020), const Color(0xFFFF5A5A));
  if (m.kind == 'streak') return (const Color(0xFF5A2A0A), const Color(0xFF6B4520), const Color(0xFFFF8A3D));
  if (rank > 0 && rank <= 3) return (const Color(0xFF4A3A10), const Color(0xFF7A6420), const Color(0xFFFFD27A));
  return (const Color(0xFF14304A), const Color(0xFF2A5070), const Color(0xFF8FD0FF));
}

/// The big middle of the card (drawn from numbers).
Widget momentBody(Moment m, {double scale = 1}) {
  final p = m.payload;
  final tone = _tone(m).$3;
  final round = AppLang.t('${p['name_en'] ?? ''}', '${p['name_ar'] ?? p['name_en'] ?? ''}');
  late final String icon, label, big, sub;
  switch (m.kind) {
    case 'streak':
      icon = '🔥';
      big = '${p['current'] ?? p['best'] ?? 0}';
      label = 'GAMEWEEKS IN A ROW';
      sub = AppLang.t('Streak · best ${p['best'] ?? big}', 'ستريك · الأحسن ${p['best'] ?? big}');
    case 'gov1':
      icon = '🥇';
      big = '${_pts(p['points'])} pts';
      label = '#1 ${'${p['gov'] ?? ''}'.toUpperCase()}';
      sub = AppLang.t('First in the governorate · $round ${_flag(m.arena)}', 'الأول في محافظته · $round ${_flag(m.arena)}');
    case 'best':
      icon = '💪';
      big = '${_pts(p['points'])} pts';
      label = 'PERSONAL BEST';
      sub = AppLang.t('Best round so far · $round ${_flag(m.arena)}', 'أحسن جولة ليه · $round ${_flag(m.arena)}');
    default: // round
      final rank = (p['rank'] as num?)?.toInt() ?? 0;
      final n = (p['n'] as num?)?.toInt() ?? 0;
      final pct = (p['pct'] as num?)?.toDouble() ?? 1;
      icon = rank == 1 ? '🏆' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '⭐';
      big = rank > 0 && rank <= 3 ? '#$rank' : 'TOP ${pct <= 0.01 ? '1' : pct <= 0.05 ? '5' : pct <= 0.10 ? '10' : pct <= 0.25 ? '25' : '50'}%';
      label = '${_pts(p['points'])} PTS';
      sub = AppLang.t('#${_n(rank)} of ${_n(n)} · $round ${_flag(m.arena)}',
          '#${_n(rank)} من ${_n(n)} · $round ${_flag(m.arena)}');
  }
  return Padding(
    padding: EdgeInsets.fromLTRB(14, 6 * scale, 14, 16 * scale),
    child: Column(children: [
      Text(icon, style: TextStyle(fontSize: 44 * scale, height: 1.1)),
      FittedBox(fit: BoxFit.scaleDown, child: Text(big, style: TextStyle(color: Colors.white, fontSize: 50 * scale, fontWeight: FontWeight.w900, height: 1.05))),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: TextStyle(color: tone, fontSize: 12.5 * scale, letterSpacing: 2.5, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(sub, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12.5 * scale)),
    ]),
  );
}

Widget _stamp() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/badger_white.png', width: 13, height: 8),
        const SizedBox(width: 4),
        const Text('✓ BDGR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );

class MomentAvatar extends StatelessWidget {
  const MomentAvatar({super.key, required this.user, this.size = 40});
  final MomentUser user;
  final double size;
  @override
  Widget build(BuildContext context) {
    final a = user.avatar;
    final letter = Text(user.name.isEmpty ? 'B' : user.name.characters.first.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.4));
    return ClipOval(
      child: Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFC97B45), Color(0xFF8A4A20), Color(0xFF6B3514)])),
        child: a == null || a.isEmpty ? letter
            : Image(image: ResizeImage(MediaCache.image(a), width: (size * 3).round()), width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => letter),
      ),
    );
  }
}

void _openProfile(BuildContext context, MomentUser u) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => VisitorProfileSheet(userId: u.userId)));

void _openSquad(BuildContext context, Moment m, {MomentUser? who, Map<String, dynamic>? row}) {
  final u = who ?? m.user;
  if (m.eventId == null || u.uid == null) return;
  openProfileRoundSquad(context, userId: u.uid!, userName: u.name, username: u.username, avatarUrl: u.avatar,
      round: row ?? {'event_id': m.eventId, 'name_en': m.payload['name_en'], 'name_ar': m.payload['name_ar'],
        'rank': m.payload['rank'], 'points': m.payload['points'], 'mode': m.payload['mode']});
}

/// "⚔️ Challenge": my result in the same round vs his
Future<void> showMomentChallenge(BuildContext context, Moment m) async {
  final sb = Supabase.instance.client;
  Map<String, dynamic>? mine;
  MomentUser? me;
  try {
    final id = await sb.rpc('get_my_iplay_user_id');
    final uid = id is num ? id.toInt() : int.tryParse('$id');
    if (uid != null) {
      final t = await ProfileTrophies.load(uid);
      mine = t?.roundsList.where((r) => '${r['event_id']}' == m.eventId).cast<Map<String, dynamic>?>().firstWhere((_) => true, orElse: () => null);
      final p = await sb.from('user_profile').select('display_name, username, avatar_url').eq('user_id', uid).maybeSingle();
      me = MomentUser({'user_id': uid, 'uid': sb.auth.currentUser?.id, 'name': p?['display_name'] ?? 'Me',
        'username': p?['username'], 'avatar': p?['avatar_url']});
    }
  } catch (_) {}
  if (!context.mounted) return;
  final his = m.payload;
  Widget side(MomentUser u, dynamic pts, dynamic rank, bool win) => Expanded(child: Column(children: [
        MomentAvatar(user: u, size: 54),
        const SizedBox(height: 6),
        Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(pts == null ? '—' : '${_pts(pts)}', style: TextStyle(color: win ? const Color(0xFFFFD27A) : Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
        Text(rank == null ? AppLang.t("didn't play", 'ما لعبش') : '#${_n((rank as num).toInt())}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]));
  final hp = (his['points'] as num?)?.toDouble();
  final mp = (mine?['points'] as num?)?.toDouble();
  await showModalBottomSheet<void>(
    context: context, useRootNavigator: true, useSafeArea: true, backgroundColor: const Color(0xFF16171B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 22), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Text('⚔️ ${AppLang.t('${his['name_en'] ?? ''}', '${his['name_ar'] ?? his['name_en'] ?? ''}')} ${_flag(m.arena)}',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (me != null) side(me, mine?['points'], mine?['rank'], mp != null && (hp == null || mp > hp)),
          const Padding(padding: EdgeInsets.only(top: 30), child: Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900))),
          side(m.user, his['points'], his['rank'], hp != null && (mp == null || hp > mp)),
        ]),
        const SizedBox(height: 16),
        Text(mp == null ? AppLang.t("You didn't play this round. Next one is yours 💪", 'إنت مالعبتش الجولة دي. الجاية بتاعتك 💪')
            : hp != null && mp > hp ? AppLang.t('You beat him this round 😎', 'إنت كسبته الجولة دي 😎')
            : hp != null && mp == hp ? AppLang.t('Dead even 🤝', 'متعادلين 🤝')
            : AppLang.t('He beat you this round. Get him next time 🔥', 'هو كسبك الجولة دي. خد حقك الجاية 🔥'),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 14),
        Row(children: [
          if (mine != null && me != null) Expanded(child: OutlinedButton(
            onPressed: () { Navigator.pop(ctx); _openSquad(context, m, who: me, row: mine); },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
            child: Text(AppLang.t('My team', 'تشكيلتي')))),
          if (mine != null) const SizedBox(width: 10),
          Expanded(child: FilledButton(
            onPressed: () { Navigator.pop(ctx); _openSquad(context, m); },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1A1A)),
            child: Text(AppLang.t('His team', 'تشكيلته')))),
        ]),
      ])),
    ),
  );
}

/// One moment in the feed.
class MomentCard extends StatefulWidget {
  const MomentCard({super.key, required this.m});
  final Moment m;
  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  bool _following = false;

  Future<void> _react(String e) async {
    final m = widget.m;
    HapticFeedback.lightImpact();
    final old = m.mine;
    final next = old == e ? null : e;
    setState(() {
      if (old != null) m.counts[old] = (m.counts[old] ?? 1) - 1;
      if (next != null) m.counts[next] = (m.counts[next] ?? 0) + 1;
      m.mine = next;
    });
    try {
      await MomentsApi.react(m, next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (next != null) m.counts[next] = (m.counts[next] ?? 1) - 1;
        if (old != null) m.counts[old] = (m.counts[old] ?? 0) + 1;
        m.mine = old;
      });
    }
  }

  Future<void> _follow() async {
    setState(() => _following = true);
    try {
      await MomentsApi.follow(widget.m.user.userId);
      if (mounted) setState(() => widget.m.iFollow = true);
    } catch (_) {}
    if (mounted) setState(() => _following = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final tone = _tone(m);
    final cap = momentCaption(m.caption);
    // owner 28 Nov: post layout = avatar circle + name OUTSIDE, caption above the achievement box, reactions under it
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          GestureDetector(
            onTap: () => _openProfile(context, m.user),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tone.$3.withValues(alpha: 0.7), width: 1.5)),
              child: MomentAvatar(user: m.user, size: 40),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openProfile(context, m.user),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 1),
              Text('${m.user.username == null ? '' : '@${m.user.username} · '}${FeedApi.ago(m.at)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
            ]),
          )),
          // owner 28 Nov: "Follow" only when I don't follow him yet (and it's not me)
          if (!m.isMe && !m.iFollow)
            GestureDetector(
              onTap: _following ? null : _follow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFF1A1A), borderRadius: BorderRadius.circular(20)),
                child: Text(AppLang.t('Follow', 'تابع'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
        if (cap.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
              child: Text(cap, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35))),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tone.$2),
            gradient: RadialGradient(center: const Alignment(0, -1.1), radius: 1.3,
                colors: [tone.$1, const Color(0xFF17111A), const Color(0xFF0E0E10)]),
            boxShadow: [BoxShadow(color: tone.$1.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Align(alignment: AlignmentDirectional.centerEnd, child: _stamp()),
            ),
            momentBody(m),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          for (final (k, e) in _reactions) Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: GestureDetector(
              onTap: () => _react(k),
              child: AnimatedScale(
                scale: m.mine == k ? 1.08 : 1, duration: const Duration(milliseconds: 160),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: m.mine == k ? const Color(0x33FF1A1A) : const Color(0xFF17181C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: m.mine == k ? const Color(0xFFFF1A1A) : Colors.white10),
                  ),
                  child: Text((m.counts[k] ?? 0) > 0 ? '$e ${FeedApi.count(m.counts[k]!)}' : e,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (m.eventId != null) ...[
            _action('👀', AppLang.t('Team', 'تشكيلته'), () => _openSquad(context, m)),
            if (!m.isMe) _action('⚔️', AppLang.t('Challenge', 'تحدّاه'), () => showMomentChallenge(context, m)),
          ],
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
        const SizedBox(height: 14),
      ]),
    );
  }

  Widget _action(String e, String t, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: Text('$e $t', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      );
}

/// Story rings (users with an active moment story).
class MomentStoriesRow extends StatelessWidget {
  const MomentStoriesRow({super.key, required this.groups});
  final List<List<Moment>> groups;
  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < groups.length; i++)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: GestureDetector(
            onTap: () => openMomentStories(context, groups, i),
            child: SizedBox(width: 62, child: Column(children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFFF3B3B), Color(0xFFFF1A1A)])),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0E0E10)),
                  child: ClipOval(child: MomentAvatar(user: groups[i].first.user, size: 50)),
                ),
              ),
              const SizedBox(height: 4),
              Text(groups[i].first.user.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ])),
          ),
        ),
    ]);
  }
}

Future<void> openMomentStories(BuildContext context, List<List<Moment>> groups, int start) =>
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, __, ___) => _StoryViewer(groups: groups, start: start),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({required this.groups, required this.start});
  final List<List<Moment>> groups;
  final int start;
  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> with SingleTickerProviderStateMixin {
  late int _g = widget.start;
  int _i = 0;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..addStatusListener((s) { if (s == AnimationStatus.completed) _next(); })
    ..forward();

  void _next() {
    final list = widget.groups[_g];
    if (_i < list.length - 1) {
      setState(() => _i++);
    } else if (_g < widget.groups.length - 1) {
      setState(() { _g++; _i = 0; });
    } else {
      Navigator.of(context).maybePop();
      return;
    }
    _c.forward(from: 0);
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
    } else if (_g > 0) {
      setState(() { _g--; _i = 0; });
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.groups[_g];
    final m = list[_i];
    final tone = _tone(m);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: GestureDetector(
          onTapUp: (d) {
            final w = MediaQuery.of(context).size.width;
            final left = d.globalPosition.dx < w / 3;
            (AppLang.isArabic ? !left : left) ? _prev() : _next();
          },
          onLongPressStart: (_) => _c.stop(),
          onLongPressEnd: (_) => _c.forward(),
          onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).maybePop(); },
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [tone.$1, const Color(0xFF120D0E), const Color(0xFF0B0B0D)])),
            child: SafeArea(child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Row(children: [
                  for (var k = 0; k < list.length; k++) Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedBuilder(animation: _c, builder: (_, __) => LinearProgressIndicator(
                      value: k < _i ? 1 : k == _i ? _c.value : 0, minHeight: 2.5,
                      backgroundColor: Colors.white24, color: Colors.white)),
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  GestureDetector(onTap: () { _c.stop(); _openProfile(context, m.user); }, child: MomentAvatar(user: m.user, size: 34)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${m.user.name}  ·  ${FeedApi.ago(m.at)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700))),
                  _stamp(),
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white70)),
                ]),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: tone.$2),
                      gradient: RadialGradient(center: const Alignment(0, -1.2), radius: 1.4,
                          colors: [tone.$1, const Color(0xFF1A0E10), const Color(0xFF0E0E10)])),
                  child: Padding(padding: const EdgeInsets.only(top: 18), child: momentBody(m, scale: 1.15)),
                ),
              ),
              if (momentCaption(m.caption).isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 14),
                    child: Text(momentCaption(m.caption), style: const TextStyle(color: Colors.white, fontSize: 15))),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final (k, e) in _reactions) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final next = m.mine == k ? null : k;
                        setState(() => m.mine = next);
                        try { await MomentsApi.react(m, next); } catch (_) {}
                      },
                      child: AnimatedScale(
                        scale: m.mine == k ? 1.25 : 1, duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: 50, height: 50, alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: m.mine == k ? const Color(0x44FF1A1A) : Colors.white10,
                              border: Border.all(color: m.mine == k ? const Color(0xFFFF1A1A) : Colors.white24)),
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ])),
          ),
        ),
      ),
    );
  }
}
