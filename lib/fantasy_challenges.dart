import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_lang.dart';
import 'feed/moments.dart' show MomentAvatar, MomentUser;

// ═════════════════════════════════════════════════════════════════════════
// Head-to-head challenges (owner, 28 Nov): from any user's post in the feed → "I want to challenge him/her" →
// pick Egypt / World / both → he gets a push + an invite in My Fantasy → Challenges; accept or decline (reason).
// The challenge plays the NEXT gameweek of that arena after he accepts; max 5 per gameweek per arena
// (app_settings.challenge_max_per_round). Winner = more points (tie → better rank). Wins go to the trophy cabinet.
// Server: fantasy_challenges + challenge_target / send / respond / cancel / badge / list.
// ═════════════════════════════════════════════════════════════════════════

const _bg = Color(0xFF16171B);
const _card = Color(0xFF1E2025);
const _red = Color(0xFFFF1A1A);
const _gold = Color(0xFFFFD27A);

String _arena(String a) => a == 'WORLD' ? AppLang.t('World 🌍', 'العالم 🌍') : AppLang.t('Egypt 🇪🇬', 'مصر 🇪🇬');

class ChallengeApi {
  ChallengeApi._();
  static SupabaseClient get _sb => Supabase.instance.client;
  static Future<Map<String, dynamic>> target(String uid) async =>
      Map<String, dynamic>.from(await _sb.rpc('challenge_target', params: {'p_uid': uid}) as Map);
  static Future<Map<String, dynamic>> send(String uid, List<String> arenas) async =>
      Map<String, dynamic>.from(await _sb.rpc('challenge_send', params: {'p_uid': uid, 'p_arenas': arenas}) as Map);
  static Future<Map<String, dynamic>> respond(String id, bool accept, [String? reason]) async =>
      Map<String, dynamic>.from(await _sb.rpc('challenge_respond', params: {'p_id': id, 'p_accept': accept, 'p_reason': reason}) as Map);
  static Future<void> cancel(String id) => _sb.rpc('challenge_cancel', params: {'p_id': id});
  static Future<int> badge() async {
    try {
      final r = await _sb.rpc('challenge_badge');
      return r is num ? r.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }
  static Future<Map<String, dynamic>> list() async => Map<String, dynamic>.from(await _sb.rpc('challenge_list') as Map);
}

/// him / her by gender (unknown = him, like the rest of the app)
String chHim(String? g) => g == 'female' ? AppLang.t('her', 'أتحداها') : AppLang.t('him', 'أتحداه');

String _errText(String? e) => switch (e) {
      'max' => AppLang.t('You already have the max challenges in this arena', 'وصلت لأقصى عدد تحديات في الأرينا دي'),
      'exists' => AppLang.t('You already have a challenge with him here', 'عندك تحدي معاه هنا بالفعل'),
      'blocked' => AppLang.t("You can't challenge this user", 'مينفعش تتحدى اليوزر ده'),
      'rate_limited' => AppLang.t('Too many challenges today', 'بعت تحديات كتير النهارده'),
      'off' => AppLang.t('Challenges are off right now', 'التحديات مقفولة دلوقتي'),
      'no_round' => AppLang.t('No open gameweek yet · challenge when the next one opens', 'مفيش جولة مفتوحة دلوقتي · اتحدى أول ما الجولة الجاية تفتح'),
      'cooldown' => AppLang.t('You two played 2 gameweeks in a row · take a little break 🔄', 'لعبتوا جولتين ورا بعض · استريحوا شوية 🔄'),
      'deadline' => AppLang.t('Too late · the deadline passed', 'فات الوقت · الديدلاين عدّى'),
      _ => AppLang.t('Something went wrong', 'حصلت مشكلة'),
    };

/// deadline as "Sat 29/11 · 15:00" (Cairo phone time)
String chDeadline(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const ar = ['الاتنين', 'التلات', 'الأربع', 'الخميس', 'الجمعة', 'السبت', 'الحد'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${AppLang.t(en[d.weekday - 1], ar[d.weekday - 1])} ${d.day}/${d.month} · ${two(d.hour)}:${two(d.minute)}';
}

Widget _handle() => Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)));

/// "I want to challenge him/her" → arena choice → send.
Future<void> showChallengeInvite(BuildContext context, {required String uid, Map<String, dynamic>? target}) async {
  Map<String, dynamic>? t = target;
  try {
    t ??= await ChallengeApi.target(uid);
  } catch (_) {}
  if (!context.mounted || t == null || t['self'] == true) return;
  final user = Map<String, dynamic>.from(t['user'] as Map? ?? {});
  final g = user['gender']?.toString();
  final max = (t['max'] as num?)?.toInt() ?? 5;
  final arenas = [for (final a in (t['arenas'] as List? ?? const [])) Map<String, dynamic>.from(a as Map)];
  final picked = <String>{};
  bool sending = false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context, useRootNavigator: true, useSafeArea: true, backgroundColor: _bg, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final title = g == 'female' ? AppLang.t('I want to challenge her', 'عايز أتحداها') : AppLang.t('I want to challenge him', 'عايز أتحداه');
      return Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 22), child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          const SizedBox(height: 14),
          MomentAvatar(user: MomentUser({'uid': uid, 'name': user['name'], 'avatar': user['avatar']}), size: 58),
          const SizedBox(height: 8),
          Text('⚔️ $title', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          Text('${user['name'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          Align(alignment: AlignmentDirectional.centerStart, child: Text(AppLang.t('In which arena? (one or both)', 'في أنهي أرينا؟ (واحدة أو الاتنين)'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          Row(children: [
            for (final a in arenas) ...[
              if (a != arenas.first) const SizedBox(width: 10),
              Expanded(child: Builder(builder: (_) {
                final code = '${a['arena']}';
                final used = (a['used'] as num?)?.toInt() ?? 0;
                final w = a['with']?.toString();
                final full = used >= max;
                final round = a['round'] is Map ? Map<String, dynamic>.from(a['round'] as Map) : null;
                final cool = (a['cooldown'] as num?)?.toInt();
                final off = w != null || full || round == null || cool != null;
                final on = picked.contains(code);
                return GestureDetector(
                  onTap: off ? null : () { HapticFeedback.selectionClick(); set(() => on ? picked.remove(code) : picked.add(code)); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: on ? const Color(0x33FF1A1A) : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? _red : Colors.white10, width: on ? 1.6 : 1),
                    ),
                    child: Opacity(opacity: off ? 0.45 : 1, child: Column(children: [
                      Text(_arena(code), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 4),
                      if (round != null) Text('${AppLang.t('${round['name_en'] ?? ''}', '${round['name_ar'] ?? round['name_en'] ?? ''}')} · ${chDeadline(round['deadline'])}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(round == null ? AppLang.t('No open gameweek yet', 'مفيش جولة مفتوحة')
                          : cool != null ? AppLang.t('Rest · again from GW $cool 🔄', 'استراحة · تاني من الجولة $cool 🔄')
                          : w == 'pending' ? AppLang.t('Waiting for answer', 'مستني رده')
                          : w == 'accepted' ? AppLang.t('Already on', 'شغال بالفعل')
                          : full ? AppLang.t('Full $used/$max', 'مليان $used/$max')
                          : AppLang.t('Your challenges $used/$max', 'تحدياتك $used/$max'),
                          style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                    ])),
                  ),
                );
              })),
            ],
          ]),
          const SizedBox(height: 12),
          Text(AppLang.t('It plays the open gameweek. He must accept before its deadline, or it ends. Most points wins.',
              'التحدي بيتلعب في الجولة المفتوحة. لازم يوافق قبل الديدلاين بتاعها وإلا يخلص. اللي يجيب نقط أكتر يكسب.'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 48, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: picked.isEmpty || sending ? null : () async {
              set(() => sending = true);
              String msg;
              try {
                final r = await ChallengeApi.send(uid, picked.toList()..sort());
                if (r['error'] != null) {
                  msg = _errText('${r['error']}');
                } else {
                  final res = [for (final x in (r['results'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
                  final ok = res.where((x) => x['ok'] == true).map((x) => _arena('${x['arena']}')).toList();
                  final bad = res.where((x) => x['ok'] != true).toList();
                  msg = ok.isNotEmpty
                      ? AppLang.t('⚔️ Challenge sent · ${ok.join(' · ')} · waiting for the answer', '⚔️ التحدي اتبعت · ${ok.join(' · ')} · مستنيين رده')
                      : _errText(bad.isEmpty ? null : '${bad.first['error']}');
                  if (ok.isNotEmpty) HapticFeedback.mediumImpact();
                }
              } catch (_) {
                msg = _errText(null);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              messenger?.showSnackBar(SnackBar(content: Text(msg)));
            },
            child: sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(AppLang.t('Send the challenge ⚔️', 'ابعت التحدي ⚔️'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          )),
        ])),
      );
    }),
  );
}

Route<void> challengesPageRoute() => MaterialPageRoute(builder: (_) => const ChallengesPage());
Future<void> openChallengesPage(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(challengesPageRoute());

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  Map<String, dynamic>? _d;
  bool _err = false;
  final Set<String> _busy = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await ChallengeApi.list();
      if (mounted) setState(() { _d = d; _err = false; });
    } catch (_) {
      if (mounted) setState(() => _err = true);
    }
  }

  List<Map<String, dynamic>> get _items => [for (final x in (_d?['items'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  Future<void> _accept(Map<String, dynamic> x) async {
    setState(() => _busy.add('${x['id']}'));
    try {
      final r = await ChallengeApi.respond('${x['id']}', true);
      if (r['error'] != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errText('${r['error']}'))));
      else HapticFeedback.mediumImpact();
    } catch (_) {}
    _busy.remove('${x['id']}');
    await _load();
  }

  static const _reasons = <(String, String, String)>[
    ('dont_know', "I don't know him", 'ماعرفوش'),
    ('not_now', 'Not now', 'مش دلوقتي'),
    ('busy', 'I have enough challenges', 'عندي تحديات كفاية'),
    ('no_reason', 'No reason', 'من غير سبب'),
  ];

  Future<void> _decline(Map<String, dynamic> x) async {
    String reason = 'no_reason';
    final go = await showModalBottomSheet<bool>(
      context: context, useRootNavigator: true, useSafeArea: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 22), child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          const SizedBox(height: 14),
          Text(AppLang.t('Decline the challenge', 'ترفض التحدي'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: reason, isExpanded: true, dropdownColor: _card,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: [for (final r in _reasons) DropdownMenuItem(value: r.$1, child: Text(AppLang.t(r.$2, r.$3)))],
              onChanged: (v) => set(() => reason = v ?? 'no_reason'),
            )),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 46, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLang.t('Decline', 'ارفض'), style: const TextStyle(fontWeight: FontWeight.w800)),
          )),
        ])),
      )),
    );
    if (go != true) return;
    setState(() => _busy.add('${x['id']}'));
    try { await ChallengeApi.respond('${x['id']}', false, reason); } catch (_) {}
    _busy.remove('${x['id']}');
    await _load();
  }

  Future<void> _cancel(Map<String, dynamic> x) async {
    setState(() => _busy.add('${x['id']}'));
    try { await ChallengeApi.cancel('${x['id']}'); } catch (_) {}
    _busy.remove('${x['id']}');
    await _load();
  }

  /// this result = the same as the previous finished challenge with the same person in the same arena
  bool _twoInARow(Map<String, dynamic> x) {
    final res = x['result']?.toString();
    if (res != 'win' && res != 'loss') return false;
    final who = (x['other'] as Map?)?['user_id'];
    final done = _items.where((y) => y['status'] == 'done' && y['arena'] == x['arena'] && (y['other'] as Map?)?['user_id'] == who).toList()
      ..sort((a, b) => '${b['decided_at']}'.compareTo('${a['decided_at']}'));
    final i = done.indexWhere((y) => y['id'] == x['id']);
    return i >= 0 && i + 1 < done.length && done[i + 1]['result'] == res;
  }

  String _reason(String? r) => _reasons.where((x) => x.$1 == r).map((x) => AppLang.t(x.$2, x.$3)).firstOrNull ?? '';

  String _pts(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }

  Widget _row(Map<String, dynamic> x) {
    final o = Map<String, dynamic>.from(x['other'] as Map? ?? {});
    final st = '${x['status']}';
    final dir = '${x['dir']}';
    final ev = x['event'] is Map ? Map<String, dynamic>.from(x['event'] as Map) : null;
    final busy = _busy.contains('${x['id']}');
    final res = x['result']?.toString();
    String sub;
    Color subC = Colors.white54;
    Widget? trail;
    final round = ev == null ? AppLang.t('next gameweek', 'الجولة الجاية') : AppLang.t('${ev['name_en'] ?? ''}', '${ev['name_ar'] ?? ev['name_en'] ?? ''}');
    switch (st) {
      case 'pending':
        if (dir == 'in') {
          sub = AppLang.t('Challenges you · answer before ${chDeadline(ev?['deadline'])}', 'بيتحداك · رد قبل ${chDeadline(ev?['deadline'])}');
          subC = _gold;
          trail = busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  _btn(AppLang.t('Decline', 'ارفض'), Colors.white12, () => _decline(x)),
                  const SizedBox(width: 6),
                  _btn(AppLang.t('Accept', 'وافق'), _red, () => _accept(x)),
                ]);
        } else {
          sub = AppLang.t('⏳ Waiting · until ${chDeadline(ev?['deadline'])}', '⏳ مستني رده · لحد ${chDeadline(ev?['deadline'])}');
          trail = busy ? null : TextButton(onPressed: () => _cancel(x),
              child: Text(AppLang.t('Cancel', 'إلغاء'), style: const TextStyle(color: Colors.white54)));
        }
      case 'accepted':
        sub = AppLang.t('✅ Accepted · plays $round', '✅ وافق · بيتلعب في $round');
        subC = const Color(0xFF6BE38F);
      case 'done':
        sub = '$round · ${_pts(x['my_pts'])} – ${_pts(x['his_pts'])}';
        // owner 28 Nov: same winner as their previous challenge → a fun line (no extra points)
        if (_twoInARow(x)) {
          sub += res == 'win' ? AppLang.t(' · 2 in a row 🔥', ' · كسبته مرتين ورا بعض 🔥')
              : AppLang.t(' · he beat you twice in a row 😅', ' · ده تقيل عليك قوي 😅 غلبك مرتين ورا بعض');
          subC = res == 'win' ? _gold : const Color(0xFFFF8A8A);
        }
        if (x['walkover'] == true) {
          sub = res == 'win'
              ? AppLang.t('$round · he had no team · no level points', '$round · مكانش عامل تشكيلة · من غير نقط ليفل')
              : AppLang.t("$round · you had no team", '$round · إنت مكنتش عامل تشكيلة');
        }
        if (res == 'loss' && o['user_id'] != null) {
          trail = _btn(AppLang.t('Revenge ⚔️', 'خد حقك ⚔️'), _red,
              () async { await showChallengeInvite(context, uid: '${o['user_id']}'); _load(); });
          break;
        }
        trail = Text(res == 'win' ? AppLang.t('WON 🏆', 'كسبت 🏆') : res == 'loss' ? AppLang.t('LOST', 'خسرت') : AppLang.t('DRAW', 'تعادل'),
            style: TextStyle(color: res == 'win' ? _gold : res == 'loss' ? Colors.white54 : Colors.white70, fontWeight: FontWeight.w900));
      case 'declined':
        sub = dir == 'out'
            ? AppLang.t('❌ Declined${x['reason'] != null ? ' · ${_reason(x['reason'])}' : ''}', '❌ رفض${x['reason'] != null ? ' · ${_reason(x['reason'])}' : ''}')
            : AppLang.t('You declined', 'إنت رفضت');
      case 'cancelled':
        sub = AppLang.t('Cancelled', 'اتلغى');
      default:
        sub = AppLang.t('No answer before the deadline', 'مفيش رد قبل الديدلاين');
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: st == 'pending' && dir == 'in' ? const Color(0x66FF1A1A) : Colors.white10)),
      child: Row(children: [
        MomentAvatar(user: MomentUser({'uid': o['user_id'], 'name': o['name'], 'avatar': o['avatar']}), size: 42),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o['name'] ?? '—'}  ${_arena('${x['arena']}')}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 3),
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: subC, fontSize: 12)),
        ])),
        if (trail != null) ...[const SizedBox(width: 8), trail],
      ]),
    );
  }

  Widget _btn(String t, Color c, VoidCallback f) => SizedBox(height: 34, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: f, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))));

  Widget _section(String t, List<Map<String, dynamic>> xs) => xs.isEmpty ? const SizedBox.shrink() : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
              child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.3))),
          for (final x in xs) _row(x),
        ]);

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final items = _items;
    final max = (d?['max'] as num?)?.toInt() ?? 5;
    int used(String a) => ((d?['used'] as Map?)?[a] as num?)?.toInt() ?? 0;
    final rec = Map<String, dynamic>.from(d?['record'] as Map? ?? {});
    return Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0F12),
        appBar: AppBar(backgroundColor: const Color(0xFF0E0F12), foregroundColor: Colors.white, elevation: 0,
            title: Text(AppLang.t('Challenges ⚔️', 'التحديات ⚔️'), style: const TextStyle(fontWeight: FontWeight.w900))),
        body: d == null
            ? Center(child: _err
                ? TextButton(onPressed: _load, child: Text(AppLang.t('Try again', 'جرّب تاني')))
                : const CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 28), children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x55FF1A1A)),
                      gradient: const LinearGradient(colors: [Color(0xFF2A1215), Color(0xFF17181C)])),
                  child: Row(children: [
                    for (final a in const ['LOCAL', 'WORLD']) Expanded(child: Column(children: [
                      Text(_arena(a), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${used(a)}/$max', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(AppLang.t('this gameweek', 'الجولة دي'), style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                    ])),
                    Container(width: 1, height: 44, color: Colors.white10),
                    Expanded(child: Column(children: [
                      Text(AppLang.t('Record', 'سجلك'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${rec['w'] ?? 0}-${rec['l'] ?? 0}-${rec['d'] ?? 0}', style: const TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(AppLang.t('W - L - D', 'كسب - خسارة - تعادل'), style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                    ])),
                  ]),
                ),
                if (items.isEmpty) Padding(padding: const EdgeInsets.only(top: 40), child: Column(children: [
                  const Text('⚔️', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 10),
                  Text(AppLang.t('No challenges yet', 'لسه مفيش تحديات'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(AppLang.t('Open any post in the feed and tap ⚔️ Challenge', 'افتح أي بوست في الفيد ودوس ⚔️ تحدّاه'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ])),
                _section(AppLang.t('INVITES', 'دعوات ليك'), items.where((x) => x['status'] == 'pending' && x['dir'] == 'in').toList()),
                _section(AppLang.t('ON', 'شغالة'), items.where((x) => x['status'] == 'accepted').toList()),
                _section(AppLang.t('SENT', 'بعتها'), items.where((x) => x['status'] == 'pending' && x['dir'] == 'out').toList()),
                _section(AppLang.t('HISTORY', 'اللي فات'), items.where((x) => !const {'pending', 'accepted'}.contains(x['status'])).toList()),
              ])),
      ),
    );
  }
}
