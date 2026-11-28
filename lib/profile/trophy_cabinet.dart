import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_lang.dart';
import '../motion_kit.dart';
import 'profile_trophies.dart';

// ═════════════════════════════════════════════════════════════════════════
// Trophy cabinet (owner, 28 Nov): a lit glass cabinet instead of numbers.
// Everything is computed on the phone from `profile_trophies` (rounds_list + titles): no new server call.
// Each finished round gives its BEST place only: #1 gold ball · #2 silver · #3 bronze ·
// top 1% crystal · 5% · 10% · 25% · 50% plaques. Titles: governorate #1, league #1, Badger Cup, Badger League.
// Journey: first round, 5/10/25/50 rounds, streak (gameweeks in a row, both arenas together), best points.
// Drawn in code (no files, no egress). Locked (faded + 🔒) goals only for the owner.
// ═════════════════════════════════════════════════════════════════════════

enum TrophyShape { ball, cup, shield, plaque, boot, shirt, flame, medal }

enum _Metal { gold, silver, bronze, crystal, red, dim }

const _metal = <_Metal, List<Color>>{
  _Metal.gold: [Color(0xFFFFF3B0), Color(0xFFE6B649), Color(0xFF8A5A12)],
  _Metal.silver: [Color(0xFFFFFFFF), Color(0xFFBFC6CE), Color(0xFF5E666E)],
  _Metal.bronze: [Color(0xFFFFD2A8), Color(0xFFC97B45), Color(0xFF6B3514)],
  _Metal.crystal: [Color(0xFFFFFFFF), Color(0xFFBFE6FF), Color(0xFF5A8FB8)],
  _Metal.red: [Color(0xFFFF9A9A), Color(0xFFD3242C), Color(0xFF5A0A0E)],
  _Metal.dim: [Color(0xFF3A3B42), Color(0xFF2A2B31), Color(0xFF1E1F24)],
};

class _Trophy {
  _Trophy(this.key, this.shape, this.metal, this.en, this.ar, this.howEn, this.howAr,
      {this.mark = '', this.count = 0, this.locked = false, this.value});
  final String key;
  final TrophyShape shape;
  final _Metal metal;
  final String en, ar; // plate
  final String howEn, howAr; // what it means / how to get it
  final String mark; // text on the trophy (5%, 25, GOV…)
  int count;
  bool locked;
  final String? value; // e.g. best points
  final List<Map<String, dynamic>> rounds = [];
  final Set<String> arenas = {};
}

class _Shelf {
  _Shelf(this.en, this.ar, this.items);
  final String en, ar;
  final List<_Trophy> items;
}

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 1;

/// The cabinet's content from the profile data.
class CabinetData {
  CabinetData._(this.shelves, this.total, this.played);
  final List<_Shelf> shelves;
  final int total; // earned trophies (×N counted)
  final bool played;

  static CabinetData of(ProfileTrophies t, {required bool owner}) {
    final rows = t.roundsList;
    _Trophy tr(String k, TrophyShape s, _Metal m, String en, String ar, String hEn, String hAr, {String mark = ''}) =>
        _Trophy(k, s, m, en, ar, hEn, hAr, mark: mark);

    final app1 = tr('app1', TrophyShape.ball, _Metal.gold, '#1 Round', '#1 الجولة',
        'Finished FIRST of everyone in a round', 'خلص الأول على الكل في جولة');
    final cup = tr('cup', TrophyShape.cup, _Metal.gold, 'Badger Cup', 'كاس بادجر',
        'Won the Badger Cup', 'كسب كاس بادجر');
    final bl = tr('bl', TrophyShape.shield, _Metal.gold, 'Badger League', 'دوري بادجر',
        'His team won the Badger League month', 'فريقه كسب دوري بادجر في شهر');
    final gov1 = tr('gov1', TrophyShape.medal, _Metal.gold, '#1 Governorate', '#1 المحافظة',
        'First in his governorate in a round', 'الأول في محافظته في جولة', mark: 'GOV');
    final lg1 = tr('league1', TrophyShape.medal, _Metal.gold, '#1 League', '#1 الليج',
        'First in his league in a round', 'الأول في الليج بتاعه في جولة', mark: 'L1');
    final r2 = tr('rank2', TrophyShape.ball, _Metal.silver, '#2 Round', '#2 الجولة',
        'Finished 2nd in a round', 'خلص التاني في جولة');
    final r3 = tr('rank3', TrophyShape.ball, _Metal.bronze, '#3 Round', '#3 الجولة',
        'Finished 3rd in a round', 'خلص التالت في جولة');
    final p1 = tr('top1', TrophyShape.plaque, _Metal.crystal, 'Top 1%', 'توب 1%',
        'In the top 1% of a round', 'في أحسن 1% في جولة', mark: '1%');
    final p5 = tr('top5', TrophyShape.plaque, _Metal.gold, 'Top 5%', 'توب 5%',
        'In the top 5% of a round', 'في أحسن 5% في جولة', mark: '5%');
    final p10 = tr('top10', TrophyShape.plaque, _Metal.silver, 'Top 10%', 'توب 10%',
        'In the top 10% of a round', 'في أحسن 10% في جولة', mark: '10%');
    final p25 = tr('top25', TrophyShape.plaque, _Metal.bronze, 'Top 25%', 'توب 25%',
        'In the top 25% of a round', 'في أحسن 25% في جولة', mark: '25%');
    final p50 = tr('top50', TrophyShape.plaque, _Metal.crystal, 'Top half', 'فوق النص',
        'In the top half of a round', 'في النص الأولاني من الترتيب في جولة', mark: '50%');

    for (final r in rows) {
      final rank = _i(r['rank']);
      final pct = _d(r['pct']);
      final _Trophy? best = rank == 1 ? app1 : rank == 2 ? r2 : rank == 3 ? r3
          : pct <= 0.01 ? p1 : pct <= 0.05 ? p5 : pct <= 0.10 ? p10 : pct <= 0.25 ? p25 : pct <= 0.50 ? p50 : null;
      void add(_Trophy x) { x.count++; x.rounds.add(r); x.arenas.add('${r['arena']}'); }
      if (best != null && rank > 0) add(best);
      if (r['gov1'] == true) add(gov1);
      if (_i(r['league_bonus']) > 0) add(lg1);
    }
    for (final x in t.titles) {
      if (x['kind'] == 'cup') { cup.count++; if (x['arena'] != null) cup.arenas.add('${x['arena']}'); }
      if (x['kind'] == 'bl') bl.count++;
    }

    // journey
    final n = rows.length;
    final debut = tr('debut', TrophyShape.boot, _Metal.silver, 'First round', 'أول جولة',
        'Played his first round', 'لعب أول جولة')..count = n > 0 ? 1 : 0;
    const steps = [5, 10, 25, 50];
    final reached = steps.where((s) => n >= s).toList();
    final nextStep = steps.firstWhere((s) => n < s, orElse: () => 0);
    final shirtN = reached.isEmpty ? nextStep : reached.last;
    final shirt = tr('rounds', TrophyShape.shirt, reached.isEmpty ? _Metal.silver : (shirtN >= 25 ? _Metal.gold : _Metal.silver),
        '$shirtN rounds', '$shirtN جولة', 'Played $shirtN rounds', 'لعب $shirtN جولة', mark: '$shirtN')
      ..count = reached.isEmpty ? 0 : 1;
    // streak = finished gameweeks in a row (round numbers), any arena
    final nos = rows.map((r) => _i(r['round_no'])).where((x) => x > 0).toSet().toList()..sort();
    var bestRun = 0, run = 0, prev = -9;
    for (final x in nos) {
      run = x == prev + 1 ? run + 1 : 1;
      prev = x;
      bestRun = math.max(bestRun, run);
    }
    final streakGoal = bestRun >= 2 ? bestRun : 3;
    final streak = tr('streak', TrophyShape.flame, _Metal.red, '$streakGoal in a row', '$streakGoal ورا بعض',
        'Played $streakGoal gameweeks in a row (Egypt or World)', 'لعب $streakGoal جولات ورا بعض (محلي أو دولي)',
        mark: '$streakGoal')..count = bestRun >= 2 ? 1 : 0;
    num bestPts = -1 << 30;
    Map<String, dynamic>? bestRow;
    for (final r in rows) {
      final p = r['points'];
      if (p is num && p > bestPts) { bestPts = p; bestRow = r; }
    }
    final bestTxt = bestRow == null ? null : (bestPts == bestPts.roundToDouble() ? '${bestPts.toInt()}' : '$bestPts');
    final pb = tr('best', TrophyShape.medal, _Metal.silver, 'Best: ${bestTxt ?? '—'} pts', 'أحسن: ${bestTxt ?? '—'} نقطة',
        'His best points in one round', 'أعلى نقط جابها في جولة', mark: '★')..count = bestRow == null ? 0 : 1;
    if (bestRow != null) pb.rounds.add(bestRow);

    // locked goals (owner only)
    List<_Trophy> pick(List<_Trophy> all, List<_Trophy> goals) {
      final out = <_Trophy>[];
      for (final x in all) {
        if (x.count > 0) {
          out.add(x);
        } else if (owner && goals.contains(x)) {
          out.add(x..locked = true);
        }
      }
      return out;
    }
    final anyTop10 = p1.count + p5.count + p10.count > 0;
    // never played: one calm shelf of first goals (owner) instead of 4 faded shelves
    if (n == 0 && cup.count + bl.count == 0) {
      return CabinetData._(owner ? [_Shelf('Your first trophies', 'أول كاساتك',
          [debut..locked = true, app1..locked = true, p10..locked = true])] : const [], 0, false);
    }
    final shelves = <_Shelf>[
      _Shelf('Titles', 'الألقاب', pick([app1, cup, bl, gov1, lg1], [app1, cup, bl])),
      _Shelf('Podium', 'المنصة', pick([r2, r3, p1], r2.count + r3.count == 0 ? [r3] : [])),
      _Shelf('Elite', 'النخبة', pick([p5, p10, p25, p50], anyTop10 ? [] : [p10])),
      _Shelf('Journey', 'المشوار', pick([debut, shirt, streak, pb], [debut, shirt, streak])),
    ].where((s) => s.items.isNotEmpty).toList();
    final total = shelves.expand((s) => s.items).where((x) => !x.locked).fold<int>(0, (a, x) => a + x.count);
    return CabinetData._(shelves, total, n > 0);
  }
}

extension ProfileCabinetCount on ProfileTrophies {
  /// the number on the profile line when the cabinet is on
  int cabinetTotal() => CabinetData.of(this, owner: false).total;
}

/// The lit glass cabinet.
class TrophyCabinet extends StatelessWidget {
  const TrophyCabinet({super.key, required this.t, required this.isOwner, this.onPlay, this.onRound});
  final ProfileTrophies? t;
  final bool isOwner;
  final VoidCallback? onPlay;
  final void Function(Map<String, dynamic> round)? onRound;

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    if (t == null) {
      return const Padding(padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(color: Color(0xFFFF2B2B), strokeWidth: 2)));
    }
    final data = CabinetData.of(t, owner: isOwner);
    final empty = data.shelves.every((s) => s.items.every((x) => x.locked));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xF0232429), Color(0xF016171B)]),
          border: Border.all(color: const Color(0xFF34353D)),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Stack(children: [
          // LED strip on top
          Positioned(top: 0, left: 24, right: 24, child: Container(height: 3,
            decoration: BoxDecoration(color: const Color(0xFFFFF8E0), borderRadius: BorderRadius.circular(3),
                boxShadow: const [BoxShadow(color: Color(0x59FFF0C8), blurRadius: 18, spreadRadius: 6)]))),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in data.shelves) _shelf(context, s),
              if (empty) _emptyNote(data.played),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _emptyNote(bool played) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
    child: Column(children: [
      Text(isOwner ? AppLang.t('Your cabinet is waiting 🏆', 'الدولاب مستنيك 🏆')
                   : AppLang.t('No trophies yet', 'لسه مفيش كاسات'),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      if (isOwner) ...[
        const SizedBox(height: 4),
        Text(played ? AppLang.t('Your trophies appear after your rounds finish', 'كاساتك هتظهر لما جولاتك تخلص')
                    : AppLang.t('Play your first round and your first trophy is yours', 'العب أول جولة وأول كاس هيبقى ليك'),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (onPlay != null && !played) ...[
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onPlay,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000), foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: Text(AppLang.t('Play now ›', 'العب دلوقتي ›'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ],
    ]),
  );

  Widget _shelf(BuildContext context, _Shelf s) {
    final rows = <List<_Trophy>>[];
    for (var i = 0; i < s.items.length; i += 4) {
      rows.add(s.items.sublist(i, math.min(i + 4, s.items.length)));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(AppLang.t(s.en, s.ar), style: const TextStyle(color: Color(0xFF9A9AA3), fontSize: 10.5, letterSpacing: 0.5))),
        for (final row in rows) ...[
          Container(
            padding: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x12FFF5D7), Color(0x00FFFFFF)])),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final x in row) _item(context, x),
            ]),
          ),
          // glass shelf
          Container(height: 5, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x59FFFFFF), Color(0x0DFFFFFF)]),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3))])),
        ],
      ]),
    );
  }

  Widget _item(BuildContext context, _Trophy x) {
    final flag = x.arenas.length == 1 ? (x.arenas.first == 'WORLD' ? ' 🌍' : ' 🇪🇬') : '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () { Buzz.tap(); _openSheet(context, x); },
      child: SizedBox(
        width: 74,
        child: Column(children: [
          SizedBox(height: 70, child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
            Opacity(opacity: x.locked ? 0.55 : 1,
                child: SizedBox(width: 54, height: 70, child: CustomPaint(painter: TrophyPainter(x.shape, x.locked ? _Metal.dim : x.metal, x.mark)))),
            if (x.locked) const Positioned(bottom: 16, child: Text('🔒', style: TextStyle(fontSize: 12))),
            if (!x.locked && x.count > 1)
              Positioned(top: 0, left: 6, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFE00000), borderRadius: BorderRadius.circular(8)),
                child: Text('×${x.count}', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)))),
          ])),
          Container(
            margin: const EdgeInsets.fromLTRB(2, 4, 2, 4),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(color: const Color(0x10E9E9EC), borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0x14FFFFFF))),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLang.t(x.en, x.ar) + flag, maxLines: 1,
                style: TextStyle(color: x.locked ? Colors.white30 : const Color(0xFFD8D8DD), fontSize: 9.5))),
          ),
        ]),
      ),
    );
  }

  void _openSheet(BuildContext context, _Trophy x) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16171B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            SizedBox(width: 92, height: 120, child: CustomPaint(
                painter: TrophyPainter(x.shape, x.locked ? _Metal.dim : x.metal, x.mark))),
            const SizedBox(height: 10),
            Text(AppLang.t(x.en, x.ar) + (x.count > 1 ? '  ×${x.count}' : ''),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(x.locked ? AppLang.t('How to get it: ${x.howEn}', 'إزاي تاخده: ${x.howAr}') : AppLang.t(x.howEn, x.howAr),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            if (x.rounds.isNotEmpty) ...[
              const SizedBox(height: 14),
              Flexible(child: ListView(shrinkWrap: true, children: [
                for (final r in x.rounds) _roundLine(ctx, r),
              ])),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _roundLine(BuildContext ctx, Map<String, dynamic> r) {
    final pts = r['points'];
    final ptsTxt = pts is num ? (pts == pts.roundToDouble() ? '${pts.toInt()}' : '$pts') : '—';
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF1F2026), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(r['arena'] == 'WORLD' ? '🌍' : '🇪🇬', style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(child: Text(AppLang.t('${r['name_en'] ?? ''}', '${r['name_ar'] ?? ''}'),
            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600))),
        Text(AppLang.t('$ptsTxt pts', '$ptsTxt نقطة'), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Text('#${fmtInt(_i(r['rank']))}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (onRound != null) const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
      ]),
    );
    if (onRound == null) return row;
    return GestureDetector(onTap: () { Navigator.pop(ctx); onRound!(r); }, child: row);
  }
}

/// Draws one trophy (convex shapes only, every gradient has 3 stops — safe on Samsung GPUs).
class TrophyPainter extends CustomPainter {
  TrophyPainter(this.shape, this.metal, this.mark);
  final TrophyShape shape;
  final _Metal metal;
  final String mark;

  @override
  void paint(Canvas c, Size size) {
    // drawn on a 60 × 80 grid
    c.save();
    final s = math.min(size.width / 60, size.height / 80);
    c.translate((size.width - 60 * s) / 2, size.height - 80 * s);
    c.scale(s);
    final cols = _metal[metal]!;
    Paint fill(Rect r) => Paint()..shader = RadialGradient(center: const Alignment(-0.3, -0.4), radius: 0.9,
        colors: cols, stops: const [0, 0.45, 1]).createShader(r);
    final base = Paint()..color = const Color(0xFF16171B);
    final dark = Paint()..color = const Color(0xFF0D0E11);
    final line = Paint()..color = const Color(0x47000000)..style = PaintingStyle.stroke..strokeWidth = 1.4;
    final glow = Paint()..color = (metal == _Metal.dim ? Colors.transparent : const Color(0x22FFDC8C))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    void text(String t, Offset at, double size) {
      if (t.isEmpty) return;
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: const Color(0x8C000000), fontSize: size,
          fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
    }

    switch (shape) {
      case TrophyShape.ball:
        c.drawCircle(const Offset(30, 34), 24, glow);
        c.drawRRect(RRect.fromLTRBR(20, 58, 40, 72, const Radius.circular(2)), base);
        c.drawRRect(RRect.fromLTRBR(16, 70, 44, 77, const Radius.circular(1.5)), dark);
        final r = Rect.fromCircle(center: const Offset(30, 34), radius: 22);
        c.drawCircle(const Offset(30, 34), 22, fill(r));
        final p = Path()..moveTo(30, 23)..lineTo(38.5, 29)..lineTo(35.5, 38.5)..lineTo(24.5, 38.5)..lineTo(21.5, 29)..close();
        c.drawPath(p, line);
        for (final seg in const [[30.0, 23.0, 30.0, 13.0], [38.5, 29.0, 49.0, 26.0], [35.5, 38.5, 42.0, 47.0],
            [24.5, 38.5, 18.0, 47.0], [21.5, 29.0, 11.0, 26.0]]) {
          c.drawLine(Offset(seg[0], seg[1]), Offset(seg[2], seg[3]), line);
        }
      case TrophyShape.cup:
        c.drawCircle(const Offset(30, 28), 22, glow);
        final handles = Paint()..color = cols[1]..style = PaintingStyle.stroke..strokeWidth = 3;
        c.drawArc(const Rect.fromLTRB(5, 12, 21, 30), math.pi / 2, math.pi, false, handles);
        c.drawArc(const Rect.fromLTRB(39, 12, 55, 30), -math.pi / 2, math.pi, false, handles);
        final bowl = Path()..moveTo(14, 10)..lineTo(46, 10)..lineTo(46, 18)
          ..quadraticBezierTo(46, 42, 30, 42)..quadraticBezierTo(14, 42, 14, 18)..close();
        c.drawPath(bowl, fill(const Rect.fromLTRB(14, 10, 46, 42)));
        c.drawRect(const Rect.fromLTRB(27, 41, 33, 55), Paint()..color = cols[2]);
        final foot = Path()..moveTo(18, 55)..lineTo(42, 55)..lineTo(45, 65)..lineTo(15, 65)..close();
        c.drawPath(foot, fill(const Rect.fromLTRB(15, 55, 45, 65)));
        c.drawRRect(RRect.fromLTRBR(13, 65, 47, 75, const Radius.circular(1.5)), base);
      case TrophyShape.shield:
        c.drawCircle(const Offset(30, 32), 22, glow);
        final sh = Path()..moveTo(30, 6)..lineTo(50, 13)..lineTo(50, 31)
          ..quadraticBezierTo(50, 52, 30, 62)..quadraticBezierTo(10, 52, 10, 31)..lineTo(10, 13)..close();
        c.drawPath(sh, fill(const Rect.fromLTRB(10, 6, 50, 62)));
        text('★', const Offset(30, 32), 18);
        c.drawRRect(RRect.fromLTRBR(16, 66, 44, 75, const Radius.circular(1.5)), base);
      case TrophyShape.plaque:
        c.drawCircle(const Offset(30, 32), 22, glow);
        final pl = Path()..moveTo(16, 8)..lineTo(44, 8)..lineTo(48, 58)..lineTo(12, 58)..close();
        c.drawPath(pl, fill(const Rect.fromLTRB(12, 8, 48, 58)));
        text(mark, const Offset(30, 33), mark.length > 2 ? 11 : 13);
        c.drawRect(const Rect.fromLTRB(10, 58, 50, 65), base);
        c.drawRRect(RRect.fromLTRBR(7, 65, 53, 75, const Radius.circular(1.5)), dark);
      case TrophyShape.boot:
        c.drawCircle(const Offset(30, 40), 22, glow);
        final bt = Path()..moveTo(12, 22)..lineTo(26, 22)..lineTo(29, 36)
          ..quadraticBezierTo(42, 39, 47, 45)..quadraticBezierTo(49, 52, 43, 52)..lineTo(12, 52)..close();
        c.drawPath(bt, fill(const Rect.fromLTRB(12, 22, 48, 52)));
        final studs = Paint()..color = cols[2];
        for (final x in const [15.0, 24.0, 36.0]) { c.drawRect(Rect.fromLTWH(x, 52, 3, 4), studs); }
        c.drawPath(Path()..moveTo(8, 60)..lineTo(52, 60)..lineTo(49, 66)..lineTo(11, 66)..close(),
            Paint()..color = metal == _Metal.dim ? const Color(0xFF2A2B31) : const Color(0xFFD3242C));
        c.drawRRect(RRect.fromLTRBR(10, 66, 50, 75, const Radius.circular(1.5)), base);
      case TrophyShape.shirt:
        c.drawCircle(const Offset(30, 34), 22, glow);
        // body + sleeves as separate convex pieces (no concave path)
        final f = fill(const Rect.fromLTRB(8, 10, 52, 58));
        c.drawPath(Path()..moveTo(19, 12)..lineTo(41, 12)..lineTo(41, 58)..lineTo(19, 58)..close(), f);
        c.drawPath(Path()..moveTo(20, 10)..lineTo(8, 18)..lineTo(13, 28)..lineTo(20, 24)..close(), f);
        c.drawPath(Path()..moveTo(40, 10)..lineTo(52, 18)..lineTo(47, 28)..lineTo(40, 24)..close(), f);
        c.drawOval(const Rect.fromLTRB(25, 9, 35, 15), Paint()..color = const Color(0xFF1A1B20));
        text(mark, const Offset(30, 38), mark.length > 1 ? 14 : 16);
        c.drawRRect(RRect.fromLTRBR(14, 64, 46, 75, const Radius.circular(1.5)), base);
      case TrophyShape.flame:
        c.drawCircle(const Offset(30, 38), 22, glow);
        final fl = Path()..moveTo(30, 6)
          ..cubicTo(36, 16, 46, 22, 46, 38)..arcToPoint(const Offset(14, 38), radius: const Radius.circular(16))
          ..cubicTo(14, 28, 22, 16, 30, 6)..close();
        c.drawPath(fl, fill(const Rect.fromLTRB(14, 6, 46, 54)));
        text(mark, const Offset(30, 41), 13);
        c.drawRRect(RRect.fromLTRBR(16, 64, 44, 75, const Radius.circular(1.5)), base);
      case TrophyShape.medal:
        c.drawCircle(const Offset(30, 38), 20, glow);
        final rib = Paint()..color = metal == _Metal.dim ? const Color(0xFF2A2B31) : const Color(0xFFC8102E);
        c.drawPath(Path()..moveTo(20, 4)..lineTo(28, 4)..lineTo(32, 22)..lineTo(24, 22)..close(), rib);
        c.drawPath(Path()..moveTo(40, 4)..lineTo(32, 4)..lineTo(28, 22)..lineTo(36, 22)..close(), rib);
        c.drawCircle(const Offset(30, 38), 16, fill(Rect.fromCircle(center: const Offset(30, 38), radius: 16)));
        text(mark, const Offset(30, 38), mark.length > 2 ? 9.5 : 12);
        c.drawRRect(RRect.fromLTRBR(16, 64, 44, 75, const Radius.circular(1.5)), base);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(TrophyPainter o) => o.shape != shape || o.metal != metal || o.mark != mark;
}
