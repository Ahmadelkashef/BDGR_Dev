import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_lang.dart';
import '../motion_kit.dart';
import 'profile_trophies.dart';
import 'streak_card.dart' show StreakCard;

// ═════════════════════════════════════════════════════════════════════════
// Trophy cabinet (owner, 28 Nov): a lit glass cabinet instead of numbers.
// Everything is computed on the phone from `profile_trophies` (rounds_list + titles): no new server call.
// Each finished round gives its BEST place only: #1 gold ball · #2 silver · #3 bronze ·
// top 1% crystal · 5% · 10% · 25% · 50% plaques (a round lights its place and every easier one; points = best only). Titles: governorate #1, league #1, Badger Cup, Badger League.
// Rounds: shirts 5/10/20/50. Streak = the fuel card (both arenas). One-time: first round, complete profile, best points.
// The level (higher arena) sits above the cabinet as one slim line (CabinetLevelLine).
// Drawn in code (no files, no egress). Locked (faded + 🔒) goals only for the owner.
// ═════════════════════════════════════════════════════════════════════════

enum TrophyShape { ball, cup, shield, plaque, boot, shirt, flame, medal, ticket, profile }

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
      {this.mark = '', this.count = 0, this.locked = false, this.value, this.countable = true});
  final String key;
  final TrophyShape shape;
  final _Metal metal;
  final String en, ar; // plate
  final String howEn, howAr; // what it means / how to get it
  final String mark; // text on the trophy (5%, 25, GOV…)
  int count;
  bool locked;
  final String? value; // e.g. best points
  /// false = milestones (first round, N rounds, streak, best points): no ×N under them
  final bool countable;
  final List<Map<String, dynamic>> rounds = [];
  final Set<String> arenas = {};
  /// lit with ×0 (challenges: lights after the first one played, counts the wins)
  bool lit = false;
}

class _Shelf {
  _Shelf(this.en, this.ar, this.items, {this.streak = false, this.season = false});
  /// the season champion vault: one big trophy, full width
  final bool season;
  final String en, ar;
  final List<_Trophy> items;
  /// the streak "fuel" card lives here instead of trophies
  final bool streak;
}

/// '2026-11' → 'Nov 2026', '2026-27' → '2026/27'
String _periodName(String k) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(k);
  if (m == null) return k;
  final y = int.parse(m.group(1)!), n = int.parse(m.group(2)!);
  if (n > 12) return '$y/${m.group(2)}';
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${names[n - 1]} $y';
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
        _Trophy(k, s, m, en, ar, hEn, hAr, mark: mark,
            countable: !k.startsWith('rounds') && !const {'debut', 'streak', 'best', 'profile', 'level'}.contains(k));

    final app1 = tr('app1', TrophyShape.ball, _Metal.gold, '#1 Round', '#1 الجولة',
        'Finished FIRST of everyone in a round', 'خلص الأول على الكل في جولة');
    final cup = tr('cup', TrophyShape.cup, _Metal.gold, 'Badger Cup', 'كاس بادجر',
        'Won the Badger Cup', 'كسب كاس بادجر');
    // owner 28 Nov: month champion (#1 of a finished month) + season champion (#1 of the whole season, its own vault)
    final month1 = tr('month1', TrophyShape.medal, _Metal.gold, 'Month champion', 'بطل الشهر',
        'Finished #1 in the month ranking', 'خلص الأول في ترتيب الشهر', mark: 'MON');
    final season1 = tr('season1', TrophyShape.cup, _Metal.gold, 'Season champion', 'بطل السيزون',
        'Finished #1 in the whole season ranking', 'خلص الأول في ترتيب السيزون كله');
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
      void add(_Trophy x) { x.count++; x.rounds.add(r); x.arenas.add('${r['arena']}'); }
      // owner 28 Nov: a round lights its place AND every easier one (top 25% also lights top half; #2 also lights #3).
      // Level POINTS still come from the best place only (ArenaLevel), so nothing is counted twice.
      if (rank > 0) {
        if (rank == 1) add(app1);
        if (rank == 2) { add(r2); add(r3); }
        if (rank == 3) add(r3);
        if (pct <= 0.01) add(p1);
        if (pct <= 0.05) add(p5);
        if (pct <= 0.10) add(p10);
        if (pct <= 0.25) add(p25);
        if (pct <= 0.50) add(p50);
      }
      if (r['gov1'] == true) add(gov1);
      if (_i(r['league_bonus']) > 0) add(lg1);
    }
    for (final x in t.titles) {
      if (x['kind'] == 'cup') { cup.count++; if (x['arena'] != null) cup.arenas.add('${x['arena']}'); }
      if (x['kind'] == 'bl') bl.count++;
      for (final (k, tr0) in [('month1', month1), ('season1', season1)]) {
        if (x['kind'] == k) {
          tr0.count++;
          if (x['arena'] != null) tr0.arenas.add('${x['arena']}');
          tr0.rounds.add({'arena': x['arena'], 'name_en': _periodName('${x['key']}'), 'name_ar': _periodName('${x['key']}'), 'rank': 1});
        }
      }
    }

    // journey
    // rounds played = rounds with a SAVED squad (owner 28 Nov: the first trophy comes at the first save)
    final savedAll = t.savedRounds('LOCAL') + t.savedRounds('WORLD');
    final n = savedAll > rows.length ? savedAll : rows.length;
    final debut = tr('debut', TrophyShape.ticket, _Metal.silver, 'First round', 'أول جولة',
        'Played his first round', 'لعب أول جولة', mark: 'GW1')..count = n > 0 ? 1 : 0;
    // owner 28 Nov: the shirts are their own shelf, one shirt per milestone
    const steps = [5, 10, 20, 50];
    final shirts = [
      for (final st in steps)
        tr('rounds$st', TrophyShape.shirt, st >= 20 ? _Metal.gold : _Metal.silver,
            '$st rounds', '$st جولة', 'Played $st rounds', 'لعب $st جولة', mark: '$st')..count = n >= st ? 1 : 0,
    ];
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
    final prof = tr('profile', TrophyShape.profile, _Metal.crystal, 'Complete profile', 'بروفايل كامل',
        'Name, username, governorate and birth date are all set', 'الاسم واليوزرنيم والمحافظة وتاريخ الميلاد كلهم متسجلين',
        mark: '100%')..count = t.profileComplete ? 1 : 0;
    // owner 28 Nov: head-to-head challenges won (Egypt + World)
    final h2h = tr('h2h', TrophyShape.shield, _Metal.red, 'Challenge wins', 'تحديات كسبها',
        'Won a 1-vs-1 challenge in a gameweek', 'كسب تحدي واحد قصاد واحد في جولة', mark: 'H2H');
    for (final a in const ['LOCAL', 'WORLD']) {
      final w = t.h2hWins(a);
      h2h.count += w;
      if (t.h2hPlayed(a) > 0) { h2h.lit = true; h2h.arenas.add(a); }
    }
    // locked goals (owner only)
    List<_Trophy> pick(List<_Trophy> all, List<_Trophy> goals) {
      final out = <_Trophy>[];
      for (final x in all) {
        if (x.count > 0 || x.lit) {
          out.add(x);
        } else if (owner && goals.contains(x)) {
          out.add(x..locked = true);
        }
      }
      return out;
    }
    // never played: one calm shelf of first goals (owner) instead of 4 faded shelves
    if (n == 0 && cup.count + bl.count == 0) {
      final first = <_Trophy>[debut..locked = true, app1..locked = true, p10..locked = true];
      if (prof.count > 0) {
        first.add(prof);
      } else if (owner) {
        first.add(prof..locked = true);
      }
      final shown = owner ? first : first.where((x) => !x.locked).toList();
      return CabinetData._(shown.isEmpty ? const [] : [_Shelf('Your first trophies', 'أول كاساتك', shown)],
          prof.count, false);
    }
    // owner 28 Nov, top → bottom: Titles · Podium · Elite (1–50%) · Rounds (shirts) · Streak · One-time
    final elite = [p1, p5, p10, p25, p50];
    final shelves = <_Shelf>[
      // owner 28 Nov, top → bottom: One-time (always something lit) · Season vault · Titles (by value) · Podium ·
      // Elite · Rounds · Streak — the lower, the easier
      _Shelf('One-time', 'لمرة واحدة', pick([debut, prof, pb], [debut, prof])),
      _Shelf('Season', 'السيزون', pick([season1], [season1]), season: true),
      _Shelf('Titles', 'الألقاب', pick([month1, cup, bl, app1, gov1, lg1], [month1, cup, bl, app1])),
      _Shelf('Podium', 'المنصة', pick([r2, r3], [r2, r3])),
      _Shelf('Head to head', 'التحديات', pick([h2h], [h2h])),
      _Shelf('Elite', 'النخبة', pick(elite, elite)),
      _Shelf('Rounds', 'الجولات', pick(shirts, shirts)),
      if (owner || t.streakBest > 0) _Shelf('Streak', 'الستريك', const [], streak: true),
    ].where((s) => s.items.isNotEmpty || s.streak).toList();
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
  const TrophyCabinet({super.key, required this.t, required this.isOwner, this.onPlay, this.onRound, this.onCompleteProfile,
      this.highlight});
  /// a trophy key that just landed (e.g. 'debut' after the first save): it drops onto its shelf and glows
  final String? highlight;
  /// owner: the locked "Complete profile" trophy glows and opens the complete-profile sheet
  final VoidCallback? onCompleteProfile;
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
    final empty = data.shelves.every((s) => s.items.every((x) => x.locked || x.key == 'profile'));
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
              // a trophy that just landed: its shelf comes first, so it is what he sees
              for (final s in [
                ...data.shelves.where((s) => highlight != null && s.items.any((x) => x.key == highlight)),
                ...data.shelves.where((s) => !(highlight != null && s.items.any((x) => x.key == highlight))),
              ]) _shelf(context, s),
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
    if (s.season) return _seasonVault(context, s.items.first);
    if (s.streak) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(AppLang.t(s.en, s.ar), style: const TextStyle(color: Color(0xFF9A9AA3), fontSize: 10.5, letterSpacing: 0.5))),
          StreakCard(t: t!, isOwner: isOwner, embedded: true),
        ]),
      );
    }
    final rows = <List<_Trophy>>[];
    for (var i = 0; i < s.items.length; i += 5) {
      rows.add(s.items.sublist(i, math.min(i + 5, s.items.length)));
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
              // up to 5 in a row: a narrow phone scales the trophies down instead of overflowing
              for (final x in row) Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _item(context, x))),
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

  /// Season champion = its own lit vault (owner 28 Nov): big gold cup, light from above, the seasons won.
  Widget _seasonVault(BuildContext context, _Trophy x) {
    final won = !x.locked;
    final seasons = x.rounds.map((r) => '${r['name_en']}${r['arena'] == 'WORLD' ? ' 🌍' : ' 🇪🇬'}').join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { Buzz.tap(); _openSheet(context, x); },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: won ? const Color(0xAAFFD27A) : const Color(0x22FFFFFF)),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: won
                ? const [Color(0xFF3A2C10), Color(0xFF1F1A10), Color(0xFF16171B)]
                : const [Color(0xFF222328), Color(0xFF1B1C20), Color(0xFF17181C)]),
            boxShadow: won ? const [BoxShadow(color: Color(0x40FFD27A), blurRadius: 22, spreadRadius: 1)] : null,
          ),
          child: Row(children: [
            SizedBox(width: 78, height: 96, child: Stack(alignment: Alignment.center, children: [
              if (won) Container(width: 78, height: 78, decoration: const BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x66FFD27A), Color(0x22FFD27A), Color(0x00FFD27A)]))),
              Opacity(opacity: won ? 1 : 0.5, child: SizedBox(width: 66, height: 86,
                  child: CustomPaint(painter: TrophyPainter(TrophyShape.cup, won ? _Metal.gold : _Metal.dim, '')))),
              if (!won) const Positioned(bottom: 26, child: Text('🔒', style: TextStyle(fontSize: 14))),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SEASON CHAMPION', style: TextStyle(color: won ? const Color(0xFFFFD27A) : Colors.white38,
                  fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(won ? (x.count > 1 ? '$seasons  ×${x.count}' : seasons)
                       : AppLang.t('Finish #1 of the whole season', 'خلّص الأول في السيزون كله'),
                  style: TextStyle(color: won ? Colors.white : Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(AppLang.t('The biggest title in BDGR · +${ProfileUi.levelPts['season1'] ?? 500} pts',
                  'أكبر لقب في BDGR · +${ProfileUi.levelPts['season1'] ?? 500} نقطة'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, _Trophy x) =>
      highlight != null && x.key == highlight && !x.locked ? _DropGlow(child: _itemInner(context, x)) : _itemInner(context, x);

  Widget _itemInner(BuildContext context, _Trophy x) {
    final flag = x.arenas.length == 1 ? (x.arenas.first == 'WORLD' ? ' 🌍' : ' 🇪🇬') : '';
    final glow = x.key == 'profile' && x.locked && isOwner && onCompleteProfile != null;
    if (glow) {
      // owner 28 Nov: the missing "Complete profile" trophy breathes on and off, tap = fill the profile
      return _Breathe(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { Buzz.tap(); onCompleteProfile!(); },
        child: SizedBox(width: 74, child: Column(children: [
          SizedBox(height: 70, child: CustomPaint(size: const Size(54, 70), painter: TrophyPainter(x.shape, x.metal, x.mark))),
          Container(
            margin: const EdgeInsets.fromLTRB(2, 4, 2, 4),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(color: const Color(0x33FFD27A), borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0x88FFD27A))),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLang.t('Complete profile', 'كمّل بروفايلك'), maxLines: 1,
                style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 9.5, fontWeight: FontWeight.w800))),
          ),
          SizedBox(height: 14, child: Text(AppLang.t('+30 pts', '+30 نقطة'),
              style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 10.5, fontWeight: FontWeight.w900))),
        ])),
      ));
    }
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
          ])),
          Container(
            margin: const EdgeInsets.fromLTRB(2, 4, 2, 4),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(color: const Color(0x10E9E9EC), borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0x14FFFFFF))),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLang.t(x.en, x.ar) + flag, maxLines: 1,
                style: TextStyle(color: x.locked ? Colors.white30 : const Color(0xFFD8D8DD), fontSize: 9.5))),
          ),
          // how many times (owner: every countable trophy shows its count, even ×1)
          SizedBox(height: 14, child: x.countable && !x.locked
              ? Text('×${x.count}', style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 11, fontWeight: FontWeight.w900))
              : null),
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
            Text(AppLang.t(x.en, x.ar) + (x.countable && !x.locked ? '  ×${x.count}' : ''),
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
        if (onRound != null && r['event_id'] != null) const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
      ]),
    );
    // month / season titles have no single round to open
    if (onRound == null || r['event_id'] == null) return row;
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

    void text(String t, Offset at, double size, {Color color = const Color(0x8C000000)}) {
      if (t.isEmpty) return;
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Roboto', color: color, fontSize: size,
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
        text(mark, const Offset(30, 37), mark.length > 1 ? 9.5 : 11);   // owner: small numbers
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
      case TrophyShape.ticket:
        // First round = a match ticket "GW1" (owner 28 Nov): body + two side notches as dark circles on top
        c.drawCircle(const Offset(30, 34), 22, glow);
        final tk = RRect.fromLTRBR(8, 20, 52, 48, const Radius.circular(5));
        c.drawRRect(tk, fill(tk.outerRect));
        final notch = Paint()..color = const Color(0xFF1B1C21);
        c.drawCircle(const Offset(8, 34), 5, notch);
        c.drawCircle(const Offset(52, 34), 5, notch);
        final dash = Paint()..color = const Color(0x55000000)..strokeWidth = 1;
        for (var y = 23.0; y < 46; y += 4) { c.drawLine(Offset(40, y), Offset(40, y + 2), dash); }
        text(mark, const Offset(24, 34), 10.5);
        c.drawRRect(RRect.fromLTRBR(16, 64, 44, 75, const Radius.circular(1.5)), base);
      case TrophyShape.profile:
        // Complete profile = medal with a person, "100%" under it and a green ✓ badge (owner: all three)
        c.drawCircle(const Offset(30, 38), 20, glow);
        final rib2 = Paint()..color = metal == _Metal.dim ? const Color(0xFF2A2B31) : const Color(0xFFC8102E);
        c.drawPath(Path()..moveTo(20, 4)..lineTo(28, 4)..lineTo(32, 22)..lineTo(24, 22)..close(), rib2);
        c.drawPath(Path()..moveTo(40, 4)..lineTo(32, 4)..lineTo(28, 22)..lineTo(36, 22)..close(), rib2);
        c.drawCircle(const Offset(30, 38), 16, fill(Rect.fromCircle(center: const Offset(30, 38), radius: 16)));
        final ink = Paint()..color = metal == _Metal.dim ? const Color(0x66000000) : const Color(0xFF23344A);
        c.drawCircle(const Offset(30, 32.5), 4.2, ink);
        c.drawOval(const Rect.fromLTRB(22.5, 37.5, 37.5, 46), ink);
        if (metal != _Metal.dim) {
          c.drawCircle(const Offset(42, 49), 5.5, Paint()..color = const Color(0xFF2ECC71));
          c.drawPath(Path()..moveTo(39.5, 49)..lineTo(41.5, 51)..lineTo(44.8, 47), Paint()
            ..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round);
        }
        c.drawRRect(RRect.fromLTRBR(14, 62, 46, 76, const Radius.circular(1.5)), base);
        text(mark, const Offset(30, 69), 8, color: metal == _Metal.dim ? const Color(0x55FFFFFF) : const Color(0xFFBFF5D6));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(TrophyPainter o) => o.shape != shape || o.metal != metal || o.mark != mark;
}

// ═════════════════════════════════════════════════════════════════════════
// Arena level (owner, 28 Nov): every trophy gives points in its arena; the total sets a level with a
// grand name (Rookie → Icon). Points never shrink, the level is what people see.
// Points + thresholds come from the DB (`profile_level_pts` / `profile_level_steps`), defaults below.
// Badger League counts in both arenas (it is played on both).
// ═════════════════════════════════════════════════════════════════════════

// owner 28 Nov: New → Rookie fast (profile 30 + 2 saved rounds = 34); league #1 under top 25% / top half
// owner 28 Nov: the harder it is, the more it gives (season 500 > month 200 > cup 150 > Badger League 120 > #1 round 100 …)
const _defPts = {'season1': 500, 'month1': 200, 'cup': 150, 'bl': 120, 'app1': 100, 'rank2': 70, 'rank3': 50, 'top1': 40,
    'profile': 30, 'top5': 25, 'gov1': 20, 'top10': 15, 'top25': 10, 'top50': 6, 'h2h': 8, 'h2h2': 4, 'league1': 4, 'round': 2};
const _defSteps = [0, 34, 150, 400, 900, 1800, 3500, 6000];
// level names are ALWAYS English (owner 28 Nov), even in Arabic; the DB can rename them (profile_level_names)
const _lvl = <(String, _Metal)>[
  ('New', _Metal.dim), ('Rookie', _Metal.bronze), ('Semi-Pro', _Metal.bronze),
  ('Pro', _Metal.silver), ('Elite', _Metal.silver), ('Master', _Metal.gold),
  ('Legend', _Metal.gold), ('Icon', _Metal.red),
];
/// level name (English, from the DB when set)
String levelName(int i) => ProfileUi.levelNames.length == _lvl.length ? ProfileUi.levelNames[i] : _lvl[i].$1;
const _roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
const _rowNames = <String, (String, String)>{
  'season1': ('Season champion', 'بطل السيزون'), 'month1': ('Month champion', 'بطل الشهر'),
  'app1': ('#1 Round', '#1 الجولة'), 'rank2': ('#2 Round', '#2 الجولة'), 'rank3': ('#3 Round', '#3 الجولة'),
  'top1': ('Top 1%', 'توب 1%'), 'top5': ('Top 5%', 'توب 5%'), 'top10': ('Top 10%', 'توب 10%'),
  'top25': ('Top 25%', 'توب 25%'), 'top50': ('Top half', 'فوق النص'), 'gov1': ('#1 Governorate', '#1 المحافظة'),
  'league1': ('#1 League', '#1 الليج'), 'cup': ('Badger Cup', 'كاس بادجر'), 'bl': ('Badger League', 'دوري بادجر'),
  'h2h': ('Challenge wins', 'تحديات كسبتها'),
  'h2h2': ('Beat him again 🔥', 'كسبته تاني 🔥'),
  'round': ('Rounds played', 'جولات لعبها'),
  'profile': ('Complete profile', 'بروفايل كامل'),
  'streak': ('Streak 🔥', 'الستريك 🔥'),
};

/// streak milestones → points (they add up; owner 28 Nov). DB `profile_streak_pts` wins.
const _defStreak = <int, int>{2: 5, 3: 10, 4: 15, 5: 25, 10: 60, 15: 100, 20: 150};
Map<int, int> streakSteps() {
  final m = ProfileUi.streakPts.isNotEmpty ? ProfileUi.streakPts : _defStreak;
  return Map.fromEntries(m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}
/// level points earned by a best streak (sum of every milestone reached)
int streakPointsFor(int best) => streakSteps().entries.where((e) => best >= e.key).fold(0, (a, e) => a + e.value);

class ArenaLevel {
  ArenaLevel._(this.points, this.level, this.floor, this.next, this.rows);
  final int points;
  final int level; // 0..7
  final int floor; // points of this level
  final int? next; // points of the next level (null = top)
  final List<(String key, int count, int each)> rows;

  String get name => levelName(level);
  /// colour of the level (Rookie grey → bronze → silver → gold → Icon red)
  Color get color => level == 0 ? const Color(0xFFBFC2C8) : _metal[_lvl[level].$2]![level == 7 ? 1 : 0];

  static ArenaLevel of(ProfileTrophies t, String arena) {
    final pts = {..._defPts, ...ProfileUi.levelPts};
    final steps = ProfileUi.levelSteps.length == _lvl.length ? ProfileUi.levelSteps : _defSteps;
    final c = <String, int>{};
    void add(String k) => c[k] = (c[k] ?? 0) + 1;
    // rounds played = rounds with a SAVED squad (counts at save time); finished rounds as a floor
    final arenaRows = t.roundsList.where((r) => r['arena'] == arena).toList();
    final saved = t.savedRounds(arena);
    c['round'] = saved > arenaRows.length ? saved : arenaRows.length;
    for (final r in arenaRows) {
      final rank = _i(r['rank']);
      final pct = _d(r['pct']);
      final k = rank == 1 ? 'app1' : rank == 2 ? 'rank2' : rank == 3 ? 'rank3'
          : pct <= 0.01 ? 'top1' : pct <= 0.05 ? 'top5' : pct <= 0.10 ? 'top10' : pct <= 0.25 ? 'top25' : pct <= 0.50 ? 'top50' : null;
      if (k != null && rank > 0) add(k);
      if (r['gov1'] == true) add('gov1');
      if (_i(r['league_bonus']) > 0) add('league1');
    }
    for (final x in t.titles) {
      if (x['kind'] == 'cup' && x['arena'] == arena) add('cup');
      if ((x['kind'] == 'month1' || x['kind'] == 'season1') && x['arena'] == arena) add('${x['kind']}');
      if (x['kind'] == 'bl') add('bl');
    }
    if (t.profileComplete) add('profile');   // counts in both arenas (owner 28 Nov)
    if (t.h2hWins(arena) > 0) c['h2h'] = t.h2hWins(arena);
    if (t.h2hRematch(arena) > 0) c['h2h2'] = t.h2hRematch(arena);   // owner 28 Nov: every challenge won in this arena
    final rows = <(String, int, int)>[
      for (final k in _rowNames.keys) if (k != 'streak' && (c[k] ?? 0) > 0) (k, c[k]!, pts[k] ?? 0),
    ];
    rows.sort((x, y) => y.$3.compareTo(x.$3));   // biggest first, so the table reads logically
    // streak (both arenas, best ever, milestones add up): shown as "best N" × its total points
    final sp = streakPointsFor(t.streakBest);
    if (sp > 0) rows.add(('streak', 1, sp));
    final total = rows.fold<int>(0, (a, r) => a + r.$2 * r.$3);
    var lv = 0;
    for (var i = 0; i < steps.length; i++) {
      if (total >= steps[i]) lv = i;
    }
    return ArenaLevel._(total, lv, steps[lv], lv + 1 < steps.length ? steps[lv + 1] : null, rows);
  }
}

/// Level card at the top of the Egypt / World tab: medal + level name + points + bar to the next level,
/// and "how the points add up" (tap to open).
class ArenaLevelCard extends StatefulWidget {
  const ArenaLevelCard({super.key, required this.t, required this.arena});
  final ProfileTrophies t;
  final String arena;
  @override
  State<ArenaLevelCard> createState() => _ArenaLevelCardState();
}

class _ArenaLevelCardState extends State<ArenaLevelCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final lv = ArenaLevel.of(widget.t, widget.arena);
    final metal = _lvl[lv.level].$2;
    final accent = _metal[metal == _Metal.dim ? _Metal.silver : metal]![1];
    final next = lv.next;
    final frac = next == null ? 1.0 : ((lv.points - lv.floor) / (next - lv.floor)).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(color: const Color(0xD9141418), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 44, height: 56, child: CustomPaint(painter: TrophyPainter(TrophyShape.medal, metal, _roman[lv.level]))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLang.t('LEVEL', 'المستوى'), style: const TextStyle(color: Colors.white38, fontSize: 10.5, letterSpacing: 1.5)),
            Text(lv.name, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w900)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtInt(lv.points), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(AppLang.t('points', 'نقطة'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(height: 6, child: Stack(children: [
          Container(color: Colors.white10),
          FractionallySizedBox(widthFactor: frac, child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent.withOpacity(0.6), accent])))),
        ]))),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(next == null ? AppLang.t('Top level 👑', 'أعلى مستوى 👑')
              : AppLang.t('${fmtInt(next - lv.points)} pts to ${levelName(lv.level + 1)}', 'فاضل ${fmtInt(next - lv.points)} نقطة لـ ${levelName(lv.level + 1)}'),
              style: const TextStyle(color: Colors.white54, fontSize: 11.5))),
          if (lv.rows.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: Row(children: [
                Text(AppLang.t('How?', 'اتحسبت إزاي؟'), style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: Colors.white54, size: 18),
              ]),
            ),
        ]),
        AnimatedSize(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, child: !_open ? const SizedBox(width: double.infinity) : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(children: [
            for (final (k, n, each) in lv.rows)
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                Expanded(child: Text(AppLang.t(_rowNames[k]!.$1, _rowNames[k]!.$2), style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
                SizedBox(width: 44, child: Text(k == 'streak' ? '${widget.t.streakBest}🔥' : '×$n', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, fontWeight: FontWeight.w800))),
                SizedBox(width: 52, child: Text(k == 'streak' ? '—' : fmtInt(each), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12))),
                SizedBox(width: 56, child: Text(fmtInt(n * each), textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
              ])),
            const Divider(color: Colors.white10, height: 12),
            Row(children: [
              Expanded(child: Text(AppLang.t('Levels: ', 'المستويات: ') + List.generate(_lvl.length, levelName).join(' › '),
                  style: const TextStyle(color: Colors.white38, fontSize: 10.5))),
            ]),
          ]),
        )),
      ]),
    );
  }
}


/// Owner 28 Nov: the level sits right above the cabinet as ONE slim line:
/// [badge] Rookie ──── 34 / 150 ──→ [faded badge] Semi-Pro · "116 pts to Semi-Pro". Higher arena wins.
class CabinetLevelLine extends StatelessWidget {
  const CabinetLevelLine({super.key, required this.t});
  final ProfileTrophies t;

  Widget _badge(int level, {required bool dim}) {
    final m = _lvl[level].$2;
    return Opacity(opacity: dim ? 0.35 : 1, child: SizedBox(width: 26, height: 32,
        child: CustomPaint(painter: TrophyPainter(TrophyShape.shield, m == _Metal.dim ? _Metal.silver : m, ''))));
  }

  @override
  Widget build(BuildContext context) {
    final a = ArenaLevel.of(t, 'LOCAL'), b = ArenaLevel.of(t, 'WORLD');
    final lv = a.points >= b.points ? a : b;
    final next = lv.next;
    final frac = next == null ? 1.0 : ((lv.points - lv.floor) / (next - lv.floor)).clamp(0.0, 1.0).toDouble();
    final accent = lv.level == 0 ? const Color(0xFFBFC2C8) : lv.color;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Directionality(
        textDirection: AppLang.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _badge(lv.level, dim: false),
          const SizedBox(width: 6),
          Text(lv.name, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(height: 5, child: Stack(children: [
                Container(color: Colors.white10),
                FractionallySizedBox(widthFactor: frac, child: Container(decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent.withOpacity(0.55), accent])))),
              ])))),
              if (next != null) Icon(AppLang.isArabic ? Icons.chevron_left : Icons.chevron_right, color: Colors.white38, size: 16),
            ]),
            const SizedBox(height: 3),
            Text(next == null ? AppLang.t('Top level 👑', 'أعلى مستوى 👑')
                : AppLang.t('${fmtInt(lv.points)} / ${fmtInt(next)} · ${fmtInt(next - lv.points)} pts to go',
                    '${fmtInt(lv.points)} / ${fmtInt(next)} · فاضل ${fmtInt(next - lv.points)} نقطة'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
          ])),
          if (next != null) ...[
            const SizedBox(width: 4),
            Column(mainAxisSize: MainAxisSize.min, children: [
              _badge(lv.level + 1, dim: true),
              Text(levelName(lv.level + 1), style: const TextStyle(color: Colors.white30, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// slow on/off glow (the trophy that wants to be earned); still when animations are off
class _Breathe extends StatefulWidget {
  const _Breathe({required this.child});
  final Widget child;
  @override
  State<_Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<_Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!calmMotion(context) && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Opacity(opacity: 0.45 + 0.55 * _c.value,
        child: Transform.scale(scale: 0.96 + 0.06 * _c.value, child: child)),
    child: widget.child,
  );
}


/// a trophy that just landed: drops onto the shelf from above, then a soft light pulses around it a few times
class _DropGlow extends StatefulWidget {
  const _DropGlow({required this.child});
  final Widget child;
  @override
  State<_DropGlow> createState() => _DropGlowState();
}

class _DropGlowState extends State<_DropGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (calmMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = _c.value;
        final drop = Curves.bounceOut.transform((v / 0.3).clamp(0.0, 1.0).toDouble());
        final glow = v < 0.3 ? 0.0 : (0.5 + 0.5 * math.sin((v - 0.3) * math.pi * 8)) * (1 - v);
        return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Positioned(top: 4, child: IgnorePointer(child: Container(width: 70, height: 70,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [
                const Color(0xFFFFE6A0).withOpacity(0.55 * glow), const Color(0x00FFE6A0)]))))),
          Opacity(opacity: v == 0 ? 0 : 1, child: Transform.translate(offset: Offset(0, -90 * (1 - drop)),
              child: Transform.scale(scale: 1 + 0.25 * (1 - drop), child: child))),
        ]);
      },
      child: widget.child,
    );
  }
}


/// the "First round" trophy drawing, for screens outside the cabinet (first-achievement moment)
Widget debutTrophyArt(double w) => SizedBox(width: w, height: w * 80 / 60,
    child: CustomPaint(painter: TrophyPainter(TrophyShape.ticket, _Metal.silver, 'GW1')));
