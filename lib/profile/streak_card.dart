import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import 'profile_trophies.dart';
import 'trophy_cabinet.dart' show streakSteps, streakPointsFor;

// ═════════════════════════════════════════════════════════════════════════
// Streak = "the fuel" (owner, 28 Nov): its own card above the trophy cabinet.
// A gameweek counts when the user saves a squad in it (Egypt OR World, both together).
// An open round never breaks the run until its deadline; a missed gameweek resets the counter.
// Level points come from the BEST streak: every milestone reached adds its points (DB profile_streak_pts),
// in both arenas, and they never go down. Tap = a simple explainer with the table.
// ═════════════════════════════════════════════════════════════════════════

const _flameA = Color(0xFFFF8A3D), _flameB = Color(0xFFFF3B3B), _gold = Color(0xFFFFD27A);

class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.t, required this.isOwner});
  final ProfileTrophies t;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final cur = t.streakCurrent, best = t.streakBest;
    if (!isOwner && best == 0) return const SizedBox.shrink();
    final steps = streakSteps();
    final ms = steps.keys.toList();
    final next = ms.where((m) => m > best).cast<int?>().firstWhere((_) => true, orElse: () => null);
    final hot = cur > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showStreakExplainer(context, best: best, current: cur),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (hot ? _flameA : Colors.white24).withOpacity(0.45)),
          gradient: LinearGradient(colors: hot
              ? const [Color(0xFF2B1610), Color(0xFF1C1416), Color(0xF016171B)]
              : const [Color(0xFF1B1C21), Color(0xFF18191D), Color(0xF016171B)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(width: 40, height: 48, child: CustomPaint(painter: _FlamePainter(hot))),
            const SizedBox(width: 10),
            Text('$cur', style: TextStyle(color: hot ? Colors.white : Colors.white54, fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLang.t('STREAK', 'الستريك'), style: const TextStyle(color: _flameA, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w900)),
              Text(AppLang.t('gameweeks in a row', 'جولات ورا بعض'), style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(AppLang.t('BEST', 'الأحسن'), style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
              Text('$best', style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(width: 6),
            const Icon(Icons.info_outline, color: Colors.white38, size: 17),
          ]),
          const SizedBox(height: 12),
          // milestones: reached (by the best streak) lit, the next one dashed
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final m in ms) _Milestone(n: m, lit: best >= m, next: m == next),
          ]),
          if (isOwner) ...[
            const SizedBox(height: 10),
            Text(_hint(cur, best, next, steps), style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          ],
        ]),
      ),
    );
  }

  static String _hint(int cur, int best, int? next, Map<int, int> steps) {
    if (next == null) return AppLang.t('All milestones done 👑 keep the fire going', 'خلّصت كل المراحل 👑 خلّي النار والعة');
    final need = next - cur;
    final p = steps[next] ?? 0;
    if (cur == 0) {
      return AppLang.t('Save your team $need gameweeks in a row → +$p pts', 'احفظ تشكيلتك $need جولات ورا بعض ← +$p نقطة');
    }
    return need == 1
        ? AppLang.t('Next gameweek = $next in a row → +$p pts', 'الجولة الجاية = $next ورا بعض ← +$p نقطة')
        : AppLang.t('$need more gameweeks → $next in a row (+$p pts)', 'فاضل $need جولات ← $next ورا بعض (+$p نقطة)');
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.n, required this.lit, required this.next});
  final int n;
  final bool lit, next;
  @override
  Widget build(BuildContext context) => SizedBox(width: 34, height: 34, child: CustomPaint(
    painter: _RingPainter(lit, next),
    child: Center(child: Text('$n', style: TextStyle(
        color: lit ? const Color(0xFF2A1408) : next ? _flameA : Colors.white30, fontSize: 12.5, fontWeight: FontWeight.w900))),
  ));
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.lit, this.next);
  final bool lit, next;
  @override
  void paint(Canvas c, Size s) {
    final o = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 1.5;
    if (lit) {
      c.drawCircle(o, r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_gold, _flameA, _flameB]).createShader(Rect.fromCircle(center: o, radius: r)));
      return;
    }
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = next ? _flameA : Colors.white12;
    if (!next) { c.drawCircle(o, r, p); return; }
    const n = 12;   // dashed ring = the next milestone
    for (var i = 0; i < n; i++) {
      c.drawArc(Rect.fromCircle(center: o, radius: r), i * 2 * math.pi / n, math.pi / n, false, p);
    }
  }
  @override
  bool shouldRepaint(_RingPainter o) => o.lit != lit || o.next != next;
}

/// simple convex flame (two stacked drops), 3-stop gradient (Samsung rule)
class _FlamePainter extends CustomPainter {
  _FlamePainter(this.hot);
  final bool hot;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    Path drop(double cx, double top, double bw, double bottom) => Path()
      ..moveTo(cx, top)
      ..cubicTo(cx + bw * 0.55, top + (bottom - top) * 0.35, cx + bw * 0.62, bottom - bw * 0.25, cx, bottom)
      ..cubicTo(cx - bw * 0.62, bottom - bw * 0.25, cx - bw * 0.55, top + (bottom - top) * 0.35, cx, top)
      ..close();
    final outer = drop(w / 2, 0, w * 0.9, h);
    c.drawPath(outer, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: hot ? const [_flameA, _flameB, Color(0xFFB0102A)] : const [Color(0xFF6A6B72), Color(0xFF4A4B52), Color(0xFF34353B)])
        .createShader(Offset.zero & s));
    c.drawPath(drop(w / 2, h * 0.38, w * 0.48, h * 0.95), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: hot ? const [Colors.white, _gold, _flameA] : const [Color(0xFF9A9BA2), Color(0xFF7A7B82), Color(0xFF5A5B62)])
        .createShader(Offset.zero & s));
  }
  @override
  bool shouldRepaint(_FlamePainter o) => o.hot != hot;
}

/// "How the streak works" — rules in 4 lines + the points table
Future<void> showStreakExplainer(BuildContext context, {required int best, required int current}) {
  final steps = streakSteps();
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF16171B),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Directionality(
      textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text(AppLang.t('How the streak works 🔥', 'الستريك بيتحسب إزاي؟ 🔥'),
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final (e, en, ar) in const [
            ('✅', 'Save your team in a gameweek = +1 (Egypt or World, one is enough)', 'تحفظ تشكيلتك في الجولة = +1 (محلي أو دولي، واحد كفاية)'),
            ('⏳', 'An open gameweek never breaks it: you have until its deadline', 'الجولة المفتوحة مش بتكسره: معاك لحد الديدلاين بتاعها'),
            ('💔', 'Miss a whole gameweek → the counter goes back to 0', 'تفوّت جولة كاملة ← العداد يرجع 0'),
            ('🏆', 'Points come from your BEST streak, they add up and never drop', 'النقط على أحسن ستريك ليك، بتتجمع ومش بتقل أبداً'),
          ]) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(child: Text(AppLang.t(en, ar), style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.35))),
          ])),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Column(children: [
              _row(AppLang.t('In a row', 'ورا بعض'), AppLang.t('Points', 'نقط'), AppLang.t('Total', 'المجموع'), head: true),
              ...() {
                var sum = 0;
                return [
                  for (final e in steps.entries)
                    _row('${e.key} 🔥', '+${e.value}', '${sum += e.value}', lit: best >= e.key),
                ];
              }(),
            ]),
          ),
          const SizedBox(height: 12),
          Text(AppLang.t('Now: $current in a row · best $best → ${streakPointsFor(best)} pts in both arenas',
              'دلوقتي: $current ورا بعض · أحسن $best ← ${streakPointsFor(best)} نقطة في الاتنين'),
              style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ])),
    ),
  );
}

Widget _row(String a, String b, String c, {bool head = false, bool lit = false}) {
  final st = TextStyle(color: head ? Colors.white38 : lit ? _gold : Colors.white70,
      fontSize: head ? 11.5 : 13.5, fontWeight: head || lit ? FontWeight.w800 : FontWeight.w600);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(color: lit ? const Color(0x14FFD27A) : null,
        border: head ? null : const Border(top: BorderSide(color: Colors.white10))),
    child: Row(children: [
      Expanded(child: Text(a, style: st)),
      Expanded(child: Text(b, textAlign: TextAlign.center, style: st)),
      Expanded(child: Text(c, textAlign: TextAlign.end, style: st)),
    ]),
  );
}

/// Round page line (compact lobby, above the button): "🔥 N in a row · save this GW's team → N+1 (+X pts)".
class StreakLobbyLine extends StatefulWidget {
  const StreakLobbyLine({super.key, required this.saved});
  final bool saved;   // the open round already has a squad (then it is already counted)
  @override
  State<StreakLobbyLine> createState() => _StreakLobbyLineState();
}

class _StreakLobbyLineState extends State<StreakLobbyLine> {
  static int? _uid;
  ProfileTrophies? _t;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_uid == null) {
        final id = await Supabase.instance.client.rpc('get_my_iplay_user_id');
        _uid = id is num ? id.toInt() : int.tryParse('$id');
      }
      if (_uid == null) return;
      final t = await ProfileTrophies.load(_uid!);
      if (mounted) setState(() => _t = t);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return const SizedBox.shrink();
    final cur = t.streakCurrent, best = t.streakBest;
    final steps = streakSteps();
    String text;
    if (widget.saved) {
      if (cur < 1) return const SizedBox.shrink();
      text = AppLang.t('🔥 $cur in a row · keep it going next gameweek', '🔥 $cur ورا بعض · كمّل الجولة الجاية');
    } else {
      final after = cur + 1;
      final p = after > best ? (steps[after] ?? 0) : 0;
      final plus = p > 0 ? AppLang.t(' (+$p pts)', ' (+$p نقطة)') : '';
      text = cur == 0
          ? AppLang.t('🔥 Save this gameweek\'s team and start your streak$plus', '🔥 احفظ تشكيلة الجولة دي وابدأ الستريك$plus')
          : AppLang.t('🔥 $cur in a row · save this gameweek\'s team → $after$plus',
              '🔥 $cur ورا بعض · احفظ تشكيلة الجولة دي وتبقى $after$plus');
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showStreakExplainer(context, best: best, current: cur),
      child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _flameA, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.3))),
        const Icon(Icons.info_outline, color: Colors.white38, size: 15),
      ])),
    );
  }
}
