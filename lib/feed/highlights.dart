import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../fantasy.dart' show openProfileRoundSquad;
import '../local_store.dart';
import '../media_cache.dart';
import '../profile/visitor_profile_sheet.dart';
import 'moments.dart' show MomentAvatar, MomentUser, kMascotFull, kMascotHoodie;

// ═════════════════════════════════════════════════════════════════════════
// Feed highlight stories (owner, 28 Nov): the stories row shows only the big things:
// 🏆 round champion · 🗺️ top governorates · 👑 month champion · 🎁 prize winners.
// Server `feed_highlights()` = numbers only (~6 KB, cached 10 min on the phone).
// Winner picture: dashboard photo → profile photo + prize → BDGR mascot + prize (mascot is bundled = zero egress).
// Prize art: the prize image from the dashboard, else drawn per category.
// ═════════════════════════════════════════════════════════════════════════

class FeedHighlights {
  static Map<String, dynamic>? _cache;
  static DateTime? _at;

  static Future<Map<String, dynamic>> load({bool force = false}) async {
    if (!force && _cache != null && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 10)) return _cache!;
    final r = await Supabase.instance.client.rpc('feed_highlights');
    _cache = Map<String, dynamic>.from(r as Map);
    _at = DateTime.now();
    return _cache!;
  }
}

List<Map<String, dynamic>> _list(dynamic v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
String _n(num v) => v.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
String _pts(dynamic p) => p is num ? (p == p.roundToDouble() ? _n(p) : '$p') : '${p ?? 0}';
String _flag(String? a) => a == 'WORLD' ? '🌍' : '🇪🇬';
String _arena(String? a) => a == 'WORLD' ? AppLang.t('World', 'العالم') : AppLang.t('Egypt', 'مصر');
String _round(Map<String, dynamic> m) => AppLang.t('${m['name_en'] ?? ''}', '${m['name_ar'] ?? m['name_en'] ?? ''}');

const _gold = (Color(0xFFFFE9A8), Color(0xFFE0A93A), Color(0xFF9A6A12));
const _silver = (Color(0xFFFFFFFF), Color(0xFFAEB4BF), Color(0xFF6B7280));
const _bronze = (Color(0xFFF3C29A), Color(0xFFC07A3E), Color(0xFF7A4520));
const _redR = (Color(0xFFFF8A3D), Color(0xFFFF3B3B), Color(0xFFC80000));
(Color, Color, Color) _medal(int rank) => rank == 1 ? _gold : rank == 2 ? _silver : _bronze;
Color _bgOf(int rank) => rank == 1 ? const Color(0xFF4A3A10) : rank == 2 ? const Color(0xFF2E3340) : const Color(0xFF4A2A14);

/// One slide in a highlight story.
class _Slide {
  _Slide(this.bg, this.build);
  final Color bg;
  final Widget Function(BuildContext) build;
}

class _Kind {
  _Kind(this.key, this.icon, this.en, this.ar, this.ring, this.slides, this.seenKey, {this.user, this.badge, this.subEn, this.subAr, this.badgeColor});
  final String key, icon, en, ar, seenKey;
  final (Color, Color, Color) ring;
  final List<_Slide> slides;
  // person circle (owner 28 Nov): one story per winner after the big highlights
  final MomentUser? user;
  final String? badge, subEn, subAr;
  final Color? badgeColor;
  bool get isPerson => user != null;
}

/// One achievement of one person, used to build the per-winner circles.
class _Ach {
  _Ach(this.weight, this.slide, {this.prize = 0, this.badge, this.subEn, this.subAr, this.ring = _gold, this.badgeColor});
  final int weight; // bigger = shown first (inside the person's story too)
  final int prize; // EGP value, the first sort key between people
  final _Slide slide;
  final String? badge, subEn, subAr;
  final (Color, Color, Color) ring;
  final Color? badgeColor;
}

String _ord(int r) => r == 1 ? '1st' : r == 2 ? '2nd' : '3rd';
String _ordAr(int r) => r == 1 ? 'الأول' : r == 2 ? 'التاني' : 'التالت';
const _medalEmoji = ['🥇', '🥈', '🥉'];

/// Every winner once, biggest prize / achievement first (owner 28 Nov).
List<_Kind> _people(Map<String, dynamic> d) {
  final by = <int, List<_Ach>>{};
  final users = <int, MomentUser>{};
  final events = <int, Set<String>>{};
  final covered = <String>{}; // event:user that already has a prize slide
  void add(MomentUser u, String ev, _Ach a) {
    if (u.userId == 0) return;
    users[u.userId] ??= u;
    (by[u.userId] ??= []).add(a);
    (events[u.userId] ??= {}).add(ev);
  }
  for (final p in _list(d['prizes'])) {
    for (final it in _list(p['items'])) {
      final rank = (it['rank'] as num?)?.toInt() ?? 3;
      final u = MomentUser(Map<String, dynamic>.from(it['user'] as Map? ?? {}));
      final x = Map<String, dynamic>.from(it['x'] as Map? ?? {});
      final v = (x['value_egp'] as num?)?.toInt() ?? 0;
      covered.add('${p['event_id']}:${u.userId}');
      add(u, '${p['event_id']}', _Ach(900 - rank * 100, _prizeSlide(p, it), prize: v,
          badge: '${_medalEmoji[(rank - 1).clamp(0, 2)]} ${v > 0 ? _n(v) : '#$rank'}',
          subEn: '${_ord(rank)} · ${_arena('${p['arena']}')} ${_flag('${p['arena']}')}',
          subAr: '${_ordAr(rank)} · ${_arena('${p['arena']}')} ${_flag('${p['arena']}')}',
          ring: _medal(rank), badgeColor: _medal(rank).$1));
    }
  }
  for (final r in _list(d['round'])) {
    for (final t in _list(r['top'])) {
      final rank = (t['rank'] as num?)?.toInt() ?? 3;
      final u = MomentUser(Map<String, dynamic>.from(t['user'] as Map? ?? {}));
      if (covered.contains('${r['event_id']}:${u.userId}')) continue;
      add(u, '${r['event_id']}', _Ach(890 - rank * 100, _championSlide(r, t),
          badge: '${_medalEmoji[(rank - 1).clamp(0, 2)]} #$rank',
          subEn: '${_ord(rank)} · ${_arena('${r['arena']}')} ${_flag('${r['arena']}')}',
          subAr: '${_ordAr(rank)} · ${_arena('${r['arena']}')} ${_flag('${r['arena']}')}',
          ring: _medal(rank), badgeColor: _medal(rank).$1));
    }
  }
  for (final m in _list(d['month'])) {
    for (final w in _list(m['winners'])) {
      final u = MomentUser(Map<String, dynamic>.from(w['user'] as Map? ?? {}));
      add(u, '${m['arena']}${m['key']}', _Ach(950, _monthSlide(m, w), badge: '👑',
          subEn: 'Month · ${_arena('${m['arena']}')} ${_flag('${m['arena']}')}',
          subAr: 'بطل الشهر · ${_arena('${m['arena']}')}', ring: _gold, badgeColor: _gold.$1));
    }
  }
  for (final g in _list(d['govs'])) {
    for (final c in _list(g['list'])) {
      if (c['champ'] == null) continue;
      final ch = Map<String, dynamic>.from(c['champ'] as Map);
      final u = MomentUser(Map<String, dynamic>.from(ch['user'] as Map? ?? {}));
      final gr = (c['rank'] as num?)?.toInt() ?? 9;
      add(u, '${g['event_id']}g', _Ach(300 - gr * 10, _govChampSlide(g, c), badge: '🗺️ #1',
          subEn: '#1 ${c['gov']}', subAr: 'بطل ${c['gov']}', ring: _redR, badgeColor: const Color(0xFFFF9A8A)));
    }
  }
  final ids = by.keys.toList();
  int prizeOf(int id) => by[id]!.fold(0, (a, b) => a > b.prize ? a : b.prize);
  int weightOf(int id) => by[id]!.fold(0, (a, b) => a > b.weight ? a : b.weight);
  ids.sort((a, b) {
    final p = prizeOf(b).compareTo(prizeOf(a));
    return p != 0 ? p : weightOf(b).compareTo(weightOf(a));
  }); // stable: WORLD before LOCAL as the server sends them
  return [
    for (final id in ids) () {
      final list = [...by[id]!]..sort((a, b) => b.weight.compareTo(a.weight));
      final top = list.first;
      final u = users[id]!;
      final first = u.name.trim().split(RegExp(r'\s+')).first;
      return _Kind('p$id', '', first, first, top.ring, [for (final a in list) a.slide],
          'hl_seen_p_${id}_${events[id]!.join('_').hashCode}',
          user: u, badge: top.badge, subEn: top.subEn, subAr: top.subAr, badgeColor: top.badgeColor);
    }(),
  ];
}

/// The circles at the top of the feed.
class HighlightStoriesRow extends StatefulWidget {
  const HighlightStoriesRow({super.key, required this.data});
  final Map<String, dynamic>? data;
  @override
  State<HighlightStoriesRow> createState() => _HighlightStoriesRowState();
}

class _HighlightStoriesRowState extends State<HighlightStoriesRow> {
  final Set<String> _seen = {};

  @override
  void didUpdateWidget(HighlightStoriesRow old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _loadSeen();
  }

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    for (final k in _kinds()) {
      if (await LocalStore.getFlag(k.seenKey)) _seen.add(k.seenKey);
    }
    if (mounted) setState(() {});
  }

  List<_Kind> _kinds() {
    final d = widget.data;
    if (d == null) return const [];
    final out = <_Kind>[];
    final rounds = _list(d['round']).where((r) => _list(r['top']).isNotEmpty).toList();
    if (rounds.isNotEmpty) {
      out.add(_Kind('round', '🏆', 'Round\nchampion', 'بطل\nالجولة', _gold, [
        for (final r in rounds) for (final t in _list(r['top'])) _championSlide(r, t),
      ], 'hl_seen_round_${rounds.map((r) => r['event_id']).join('_')}'));
    }
    final govs = _list(d['govs']).where((g) => _list(g['list']).isNotEmpty).toList();
    if (govs.isNotEmpty) {
      out.add(_Kind('govs', '🗺️', 'Top\ngovernorates', 'أحسن\nالمحافظات', _redR, [
        for (final g in govs) ...[_govSlide(g), for (final c in _list(g['list'])) if (c['champ'] != null) _govChampSlide(g, c)],
      ], 'hl_seen_govs_${govs.map((r) => r['event_id']).join('_')}'));
    }
    final months = _list(d['month']).where((m) => _list(m['winners']).isNotEmpty).toList();
    if (months.isNotEmpty) {
      out.add(_Kind('month', '👑', 'Month\nchampion', 'بطل\nالشهر', _gold, [
        for (final m in months) for (final w in _list(m['winners'])) _monthSlide(m, w),
      ], 'hl_seen_month_${months.map((m) => '${m['arena']}${m['key']}').join('_')}'));
    }
    final prizes = _list(d['prizes']).where((p) => _list(p['items']).isNotEmpty).toList();
    if (prizes.isNotEmpty) {
      out.add(_Kind('prizes', '🎁', 'Prize\nwinners', 'الفايزين\nبالجوايز', _redR, [
        for (final p in prizes) for (final it in _list(p['items'])) _prizeSlide(p, it),
      ], 'hl_seen_prizes_${prizes.map((p) => '${p['event_id']}${_list(p['items']).map((i) => i['photo'] ?? '').join()}').join('_').hashCode}'));
    }
    if (AppLang.feedPeopleStories) out.addAll(_people(d));
    return out;
  }

  static const double _size = 74;

  @override
  Widget build(BuildContext context) {
    final kinds = _kinds();
    if (kinds.isEmpty) return const SizedBox.shrink();
    final firstPerson = kinds.indexWhere((k) => k.isPerson);
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < kinds.length; i++) ...[
        if (i == firstPerson && i > 0)
          Container(width: 1, height: 60, margin: const EdgeInsetsDirectional.only(end: 12, top: 8), color: const Color(0xFF2C2C33)),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              LocalStore.setFlag(kinds[i].seenKey);
              setState(() => _seen.add(kinds[i].seenKey));
              await _openViewer(context, kinds, i);
            },
            child: SizedBox(width: _size + 4, child: Column(children: [
              Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
              Container(
                width: _size, height: _size, padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: _seen.contains(kinds[i].seenKey) ? null
                        : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [kinds[i].ring.$1, kinds[i].ring.$2, kinds[i].ring.$3]),
                    color: _seen.contains(kinds[i].seenKey) ? const Color(0xFF3A3B40) : null),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0B0B0D), width: 2.5),
                      color: const Color(0xFF17120A)),
                  clipBehavior: Clip.antiAlias,
                  child: kinds[i].isPerson
                      ? MomentAvatar(user: kinds[i].user!, size: _size - 11)
                      : Text(kinds[i].icon, style: const TextStyle(fontSize: 30)),
                ),
              ),
              if (kinds[i].badge != null) Positioned(bottom: -7, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(color: const Color(0xFF0B0B0D), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (kinds[i].badgeColor ?? Colors.white).withValues(alpha: 0.35))),
                child: Text(kinds[i].badge!, style: TextStyle(color: kinds[i].badgeColor ?? Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
              )),
              ]),
              SizedBox(height: kinds[i].badge != null ? 10 : 5),
              Text(AppLang.t(kinds[i].en, kinds[i].ar), maxLines: kinds[i].isPerson ? 1 : 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.15)),
              if (kinds[i].isPerson && kinds[i].subEn != null)
                Text(AppLang.t(kinds[i].subEn!, kinds[i].subAr ?? kinds[i].subEn!), maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
            ])),
          ),
        ),
      ],
    ]);
  }
}

Future<void> _openViewer(BuildContext context, List<_Kind> kinds, int start) =>
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, __, ___) => _HlViewer(kinds: kinds, start: start),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: c)),
    ));

// ─── pictures ──────────────────────────────────────────────────────────────

/// Big round picture: profile photo, else the mascot face (MomentAvatar does the fallback).
Widget _bigAvatar(MomentUser u, (Color, Color, Color) ring, {double size = 150}) => Container(
      width: size, height: size, padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ring.$1, ring.$2, ring.$3]),
          boxShadow: [BoxShadow(color: ring.$2.withValues(alpha: 0.45), blurRadius: 30)]),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0B0B0D)),
        padding: const EdgeInsets.all(3),
        child: MomentAvatar(user: u, size: size - 16),
      ),
    );

bool _hasPhoto(MomentUser u) => (u.avatar ?? '').isNotEmpty;

void _openUser(BuildContext context, MomentUser u) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => VisitorProfileSheet(userId: u.userId)));

void _openTeam(BuildContext context, Map<String, dynamic> r, Map<String, dynamic> t, MomentUser u) {
  if (u.uid == null) return;
  openProfileRoundSquad(context, userId: u.uid!, userName: u.name, username: u.username, avatarUrl: u.avatar,
      round: {'event_id': r['event_id'], 'name_en': r['name_en'], 'name_ar': r['name_ar'], 'rank': t['rank'], 'points': t['points'], 'mode': t['mode']});
}

Widget _pill(String text, {VoidCallback? onTap, Color? color, Color? fg}) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color ?? Colors.black38, borderRadius: BorderRadius.circular(20),
            border: color == null ? Border.all(color: Colors.white30) : null),
        child: Text(text, style: TextStyle(color: fg ?? Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ),
    );

Widget _label(String t, Color c) => Text(t, textAlign: TextAlign.center,
    style: TextStyle(color: c, fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w900));

String _placeLabel(int rank) => rank == 1 ? 'ROUND CHAMPION' : rank == 2 ? '2ND PLACE' : '3RD PLACE';

// ─── slides ────────────────────────────────────────────────────────────────

_Slide _championSlide(Map<String, dynamic> r, Map<String, dynamic> t) {
  final rank = (t['rank'] as num?)?.toInt() ?? 1;
  final u = MomentUser(Map<String, dynamic>.from(t['user'] as Map? ?? {}));
  final ring = _medal(rank);
  return _Slide(_bgOf(rank), (ctx) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _label(_placeLabel(rank), ring.$2),
        const SizedBox(height: 4),
        Text('${_round(r)} ${_flag('${r['arena']}')}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 22),
        GestureDetector(onTap: () => _openUser(ctx, u), child: _bigAvatar(u, ring)),
        Transform.translate(offset: const Offset(0, -22),
            child: Text(rank == 1 ? '🏆' : rank == 2 ? '🥈' : '🥉', style: const TextStyle(fontSize: 46))),
        GestureDetector(onTap: () => _openUser(ctx, u),
            child: Text(u.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
        if (u.username != null) Text('@${u.username}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 14),
        Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(_pts(t['points']), style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text('PTS', style: TextStyle(color: ring.$2, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        Text(AppLang.t('#$rank of ${_n((r['n'] as num?) ?? 0)} players', '#$rank من ${_n((r['n'] as num?) ?? 0)} لاعب'),
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 18),
        _pill(AppLang.t('👀 See the team', '👀 شوف التشكيلة'), onTap: () => _openTeam(ctx, r, t, u)),
      ]));
}

_Slide _monthSlide(Map<String, dynamic> m, Map<String, dynamic> w) {
  final u = MomentUser(Map<String, dynamic>.from(w['user'] as Map? ?? {}));
  return _Slide(const Color(0xFF4A3A10), (ctx) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _label('MONTH CHAMPION', _gold.$2),
        const SizedBox(height: 4),
        Text('${m['key']} · ${_arena('${m['arena']}')} ${_flag('${m['arena']}')}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 10),
        const Text('👑', style: TextStyle(fontSize: 46)),
        GestureDetector(onTap: () => _openUser(ctx, u), child: _bigAvatar(u, _gold, size: 160)),
        const SizedBox(height: 16),
        Text(u.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        if (u.username != null) Text('@${u.username}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 14),
        Text('${_pts(w['points'])} PTS', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
        Text(AppLang.t('Best of the whole month', 'الأحسن في الشهر كله'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]));
}

_Slide _govSlide(Map<String, dynamic> g) {
  final list = _list(g['list']);
  final mine = g['mine'] as Map?;
  return _Slide(const Color(0xFF5A1010), (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _label('TOP GOVERNORATES', const Color(0xFFFF8A8A)),
          const SizedBox(height: 4),
          Text('${_round(g)} ${_flag('${g['arena']}')} · ${AppLang.t('average points', 'متوسط النقط')}',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 22),
          for (final c in list) Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: c['rank'] == 1 ? const Color(0x33FFD27A) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: c['rank'] == 1 ? Border.all(color: const Color(0x88FFD27A)) : null,
            ),
            child: Row(children: [
              SizedBox(width: 26, child: Text('${c['rank']}', style: TextStyle(
                  color: c['rank'] == 1 ? const Color(0xFFFFD27A) : c['rank'] == 2 ? const Color(0xFFD9DDE4) : c['rank'] == 3 ? const Color(0xFFD08A4A) : Colors.white54,
                  fontWeight: FontWeight.w900, fontSize: 16))),
              Expanded(child: Text('${c['gov']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
              Text('${c['avg']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(width: 4),
              Text(AppLang.t('avg', 'متوسط'), style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
            ]),
          ),
          const SizedBox(height: 6),
          Text(AppLang.t('${g['govs']} governorates · min 5 players each', '${g['govs']} محافظة · 5 لعيبة على الأقل في كل واحدة'),
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 16),
          if (mine != null) _pill(AppLang.t('📍 Your governorate: ${mine['gov']} · #${mine['rank']}', '📍 محافظتك: ${mine['gov']} · #${mine['rank']}')),
          const SizedBox(height: 10),
          Text(AppLang.t('Next: the champion of each one →', 'الجاي: بطل كل محافظة ←'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ));
}

_Slide _govChampSlide(Map<String, dynamic> g, Map<String, dynamic> c) {
  final ch = Map<String, dynamic>.from(c['champ'] as Map);
  final u = MomentUser(Map<String, dynamic>.from(ch['user'] as Map? ?? {}));
  final ring = (c['rank'] as num?)?.toInt() == 1 ? _gold : _redR;
  return _Slide(const Color(0xFF4A1414), (ctx) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _label('#1 IN ${'${c['gov']}'.toUpperCase()}', const Color(0xFFFF8A8A)),
        const SizedBox(height: 4),
        Text(AppLang.t('Governorate #${c['rank']} · ${_round(g)} ${_flag('${g['arena']}')}', 'المحافظة رقم ${c['rank']} · ${_round(g)} ${_flag('${g['arena']}')}'),
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 24),
        GestureDetector(onTap: () => _openUser(ctx, u), child: _bigAvatar(u, ring, size: 140)),
        Transform.translate(offset: const Offset(0, -20), child: const Text('🥇', style: TextStyle(fontSize: 40))),
        Text(u.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
        if (u.username != null) Text('@${u.username}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 12),
        Text('${_pts(ch['points'])} PTS', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        _pill(AppLang.t('👀 See the team', '👀 شوف التشكيلة'), onTap: () => _openTeam(ctx, g, ch, u)),
      ]));
}

_Slide _prizeSlide(Map<String, dynamic> p, Map<String, dynamic> it) {
  final rank = (it['rank'] as num?)?.toInt() ?? 1;
  final u = MomentUser(Map<String, dynamic>.from(it['user'] as Map? ?? {}));
  final x = Map<String, dynamic>.from(it['x'] as Map? ?? {});
  final photo = '${it['photo'] ?? ''}';
  final prize = AppLang.t('${it['prize_en'] ?? ''}', '${it['prize_ar'] ?? it['prize_en'] ?? ''}');
  final ring = _medal(rank);
  final place = rank == 1 ? AppLang.t('🥇 1ST PLACE', '🥇 المركز الأول') : rank == 2 ? AppLang.t('🥈 2ND PLACE', '🥈 المركز التاني') : AppLang.t('🥉 3RD PLACE', '🥉 المركز التالت');
  final bottom = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: ring.$2, borderRadius: BorderRadius.circular(12)),
      child: Text(place, style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.w900)),
    ),
    const SizedBox(height: 10),
    Text(u.name, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(AppLang.t('Won $prize · ${_round(p)} ${_flag('${p['arena']}')}', 'كسب $prize · ${_round(p)} ${_flag('${p['arena']}')}'),
        style: const TextStyle(color: Colors.white, fontSize: 14.5)),
    const SizedBox(height: 4),
    Text(AppLang.t('${_pts(it['points'])} pts', '${_pts(it['points'])} نقطة'), style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
  ]);
  // 1) the dashboard photo (winner holding the prize)
  if (photo.startsWith('https://')) {
    return _Slide(Colors.black, (ctx) => Stack(fit: StackFit.expand, children: [
          Image(image: ResizeImage(MediaCache.image(photo), width: 1080), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _prizeFallback(u, x, ring, prize)),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000), Color(0xDD000000)], stops: [0, 0.4, 0.85]))),
          Positioned(left: 20, right: 20, bottom: 40, child: bottom),
        ]), );
  }
  // 2) profile photo + prize · 3) mascot + prize
  return _Slide(_bgOf(rank), (ctx) => Column(children: [
        const SizedBox(height: 30),
        Expanded(child: _prizeFallback(u, x, ring, prize, onUser: () => _openUser(ctx, u))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), child: Align(alignment: AlignmentDirectional.centerStart, child: bottom)),
      ]));
}

Widget _prizeFallback(MomentUser u, Map<String, dynamic> x, (Color, Color, Color) ring, String prize, {VoidCallback? onUser}) {
  final art = PrizeArt(category: '${x['category'] ?? ''}', imageUrl: '${x['image_url'] ?? ''}', label: prize, ring: ring);
  if (_hasPhoto(u)) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      GestureDetector(onTap: onUser, child: _bigAvatar(u, ring, size: 170)),
      const SizedBox(height: 18),
      art,
    ]);
  }
  // no photo at all → the BDGR mascot holds the spot
  return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
    Expanded(flex: 6, child: GestureDetector(onTap: onUser,
        child: Padding(padding: const EdgeInsetsDirectional.only(start: 16),
            child: ClipRRect(borderRadius: BorderRadius.circular(22),
                child: Image.asset(x['category'] == 'merch' ? kMascotFull : kMascotHoodie, fit: BoxFit.contain, cacheWidth: 720))))),
    Expanded(flex: 5, child: Center(child: art)),
  ]);
}

/// Prize picture: the prize image from the dashboard, else drawn per category.
class PrizeArt extends StatelessWidget {
  const PrizeArt({super.key, required this.category, required this.imageUrl, required this.label, required this.ring});
  final String category, imageUrl, label;
  final (Color, Color, Color) ring;

  static const _art = <String, List<String>>{
    'cash': ['💵', '💵', '💵'],
    'voucher': ['🎁'],
    'merch': ['👕'],
    'tickets': ['🎟️', '🎟️'],
    'electronics': ['📱'],
    'mobile_credit': ['📶'],
    'subscription': ['🏋️'],
    'experience': ['⭐'],
    'in_app': ['🏅'],
    'trophy': ['🏆'],
  };

  @override
  Widget build(BuildContext context) {
    final img = imageUrl.startsWith('https://');
    final e = _art[category] ?? const ['🎁'];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 130, height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [ring.$2.withValues(alpha: 0.55), ring.$3.withValues(alpha: 0.18), Colors.transparent]),
        ),
        alignment: Alignment.center,
        child: img
            ? ClipRRect(borderRadius: BorderRadius.circular(18),
                child: Image(image: ResizeImage(MediaCache.image(imageUrl), width: 360), width: 104, height: 104, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(e.first, style: const TextStyle(fontSize: 60))))
            : e.length == 1
                ? Text(e.first, style: const TextStyle(fontSize: 68))
                : SizedBox(width: 120, height: 100, child: Stack(alignment: Alignment.center, children: [
                    for (var i = 0; i < e.length; i++) Transform.rotate(
                      angle: (i - (e.length - 1) / 2) * 0.32,
                      child: Transform.translate(offset: Offset((i - (e.length - 1) / 2) * 16, 0),
                          child: Text(e[i], style: const TextStyle(fontSize: 54))),
                    ),
                  ])),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: ring.$2.withValues(alpha: 0.7))),
        child: Text(label, style: TextStyle(color: ring.$1, fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    ]);
  }
}

// ─── viewer ────────────────────────────────────────────────────────────────

class _HlViewer extends StatefulWidget {
  const _HlViewer({required this.kinds, required this.start});
  final List<_Kind> kinds;
  final int start;
  @override
  State<_HlViewer> createState() => _HlViewerState();
}

class _HlViewerState extends State<_HlViewer> with SingleTickerProviderStateMixin {
  late int _k = widget.start;
  int _i = 0;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..addStatusListener((s) { if (s == AnimationStatus.completed) _next(); })
    ..forward();

  void _next() {
    final n = widget.kinds[_k].slides.length;
    if (_i < n - 1) {
      setState(() => _i++);
    } else if (_k < widget.kinds.length - 1) {
      setState(() { _k++; _i = 0; });
      LocalStore.setFlag(widget.kinds[_k].seenKey);
    } else {
      Navigator.of(context).maybePop();
      return;
    }
    HapticFeedback.selectionClick();
    _c.forward(from: 0);
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
    } else if (_k > 0) {
      setState(() { _k--; _i = 0; });
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
    final kind = widget.kinds[_k];
    final s = kind.slides[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final w = MediaQuery.of(context).size.width;
            final left = d.globalPosition.dx < w / 3;
            (AppLang.isArabic ? !left : left) ? _prev() : _next();
          },
          onLongPressStart: (_) => _c.stop(),
          onLongPressEnd: (_) => _c.forward(),
          onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).maybePop(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [s.bg, const Color(0xFF120D0E), const Color(0xFF0B0B0D)], stops: const [0, 0.55, 1])),
            child: Stack(children: [
              Positioned.fill(child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (c, a) => FadeTransition(opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: c)),
                child: KeyedSubtree(key: ValueKey('$_k-$_i'), child: SafeArea(child: Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: s.build(context),
                ))),
              )),
              SafeArea(child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Row(children: [
                    for (var j = 0; j < kind.slides.length; j++) Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(animation: _c, builder: (_, __) => LinearProgressIndicator(
                        value: j < _i ? 1 : j == _i ? _c.value : 0, minHeight: 2.5,
                        backgroundColor: Colors.white24, color: Colors.white)),
                    )),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Image.asset('assets/badger_white.png', width: 22),
                    const SizedBox(width: 8),
                    const Text('BDGR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(kind.isPerson ? '· ${kind.user!.name}' : '· ${kind.icon} ${AppLang.t(kind.en, kind.ar).replaceAll('\n', ' ')}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12.5))),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white70)),
                  ]),
                ),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}
