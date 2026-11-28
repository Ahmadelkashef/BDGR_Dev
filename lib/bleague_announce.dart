import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';

import 'app_lang.dart';
import 'brand.dart';
import 'bleague_info.dart';
import 'local_store.dart';

// ═════════════════════════════════════════════════════════════════════════
// Badger League announcement (owner, 28 Nov): a product launch inside the app.
// The BDGR mascot is the hero. Shown once in Fantasy (phone key `bl_announce_<month>`),
// and from the lobby card, the feed story / pinned card and the home card.
// Drawn in code + the bundled mascot = zero egress.
// ═════════════════════════════════════════════════════════════════════════

const _gold = Color(0xFFFFC23D);
const _gold2 = Color(0xFFE09A1A);
const _bg = Color(0xFF0B0B0E);
const _red = Color(0xFFE53935);
const kBLMascot = 'assets/mascot/badger_jersey.webp';
const kBLMascotFace = 'assets/mascot/badger_jersey_face.webp';

/// opens the announcement; [onOpen] opens the league page of an arena ('LOCAL' / 'WORLD')
Future<void> showBLAnnouncement(BuildContext context, {required Future<void> Function(String arena) onOpen}) async {
  final info = await BLeagueInfo.load();
  if (info == null || !info.visible || !context.mounted) return;
  await LocalStore.setFlag('bl_announce_${info.newTeamMonth}');
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, __, ___) => _BLAnnouncePage(info: info, onOpen: onOpen),
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c)),
  ));
}

/// when the fantasy tab opens (owner 28 Nov):
/// · no team at all → the big announcement, once per league month (switch ui.popup)
/// · captain of a team that is not full → "complete your team" pop-up in the middle, once a day (switch ui.complete)
/// · full team(s) → nothing
Future<void> maybeShowBLAnnouncement(BuildContext context, {required Future<void> Function(String arena) onOpen}) async {
  final info = await BLeagueInfo.load(force: true);
  if (info == null || !info.visible || !context.mounted) return;
  if (!info.hasAnyTeam) {
    if (!info.ui('popup')) return;
    if (await LocalStore.getFlag('bl_announce_${info.newTeamMonth}')) return;
    if (!context.mounted) return;
    await showBLAnnouncement(context, onOpen: onOpen);
    return;
  }
  final open = info.captainNotFull;
  if (open.isEmpty || !info.ui('complete')) return;
  final now = DateTime.now();
  final key = 'bl_complete_${now.year}${now.month}${now.day}';
  if (await LocalStore.getFlag(key)) return;
  await LocalStore.setFlag(key);
  if (!context.mounted) return;
  await showCompleteTeamPopup(context, info, open.first, onOpen: onOpen);
}

/// "Complete your team" in the middle of the screen (captain only)
Future<void> showCompleteTeamPopup(BuildContext context, BLeagueInfo info, Map<String, dynamic> team,
    {required Future<void> Function(String arena) onOpen}) async {
  final ar = AppLang.isArabic;
  final n = (team['members_count'] as num?)?.toInt() ?? 1;
  final max = info.maxMembers;
  final a = '${team['arena'] ?? 'LOCAL'}';
  final w = a == 'WORLD';
  final code = '${team['code'] ?? ''}';
  final inTable = team['in_table'] == true;
  await showGeneralDialog<void>(
    context: context, useRootNavigator: true, barrierDismissible: true, barrierLabel: 'bl',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 320),
    transitionBuilder: (_, an, __, c) => FadeTransition(opacity: an,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: an, curve: Curves.easeOutBack)), child: c)),
    pageBuilder: (ctx, _, __) => Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Center(child: Material(color: Colors.transparent, child: Container(
        width: 330, margin: const EdgeInsets.all(20), padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF2E2208), Color(0xFF17130C), Color(0xFF111014)]),
          border: Border.all(color: _gold.withValues(alpha: 0.6)),
          boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.18), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipOval(child: Image.asset(kBLMascotFace, width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 230)),
          const SizedBox(height: 10),
          Text(_t('Complete your team', 'كمّل فريقك'),
              style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${team['icon'] ?? ''} ${team['name'] ?? ''} · ${w ? _t('🌍 World', '🌍 العالم') : _t('🇪🇬 Egypt', '🇪🇬 مصر')}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _gold, fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < max; i++) Container(
              width: 36, height: 36, margin: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: i < n ? const LinearGradient(colors: [Color(0xFFFFE9A8), _gold, _gold2]) : null,
                  border: i < n ? null : Border.all(color: _gold.withValues(alpha: 0.5), width: 1.3)),
              child: i < n ? const Icon(Icons.person, color: Color(0xFF4A3208), size: 20)
                  : Text('+', style: TextStyle(color: _gold.withValues(alpha: 0.8), fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(inTable
              ? _t('$n/$max · every friend you add adds his points to the team.', '$n/$max · كل صاحب بتضيفه نقطه بتتجمع للفريق.')
              : _t('$n/$max · your team enters the table with ${info.minMembers}. Invite a friend now.',
                   '$n/$max · فريقك بيدخل الترتيب من ${info.minMembers}. اعزم صاحب دلوقتي.'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
          if (code.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
              child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w900)),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: code.isEmpty ? null : () => Share.share(_t(
                'Join my team "${team['name']}" in the Badger League ${w ? '🌍 World' : '🇪🇬 Egypt'} 🥇\nCode: $code\n${Brand.shareLinkBase}?b=$code',
                'انضم لفريقي "${team['name']}" في دوري بادجر ${w ? '🌍 العالم' : '🇪🇬 مصر'} 🥇\nالكود: $code\n${Brand.shareLinkBase}?b=$code')),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(_t('📤 Send the code', '📤 ابعت الكود'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          )),
          Row(children: [
            Expanded(child: TextButton(onPressed: () { Navigator.of(ctx).pop(); onOpen(a); },
                child: Text(_t('My team', 'فريقي'), style: const TextStyle(color: _gold, fontWeight: FontWeight.w800)))),
            Expanded(child: TextButton(onPressed: () => Navigator.of(ctx).pop(),
                child: Text(_t('Later', 'بعدين'), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)))),
          ]),
        ]),
      ))),
    ),
  );
}

String _t(String en, String ar) => AppLang.t(en, ar);

/// "Starts 1 December · Round 3 → the last December gameweek"
String blStartLine(BLeagueInfo info) {
  final ar = AppLang.isArabic;
  final m = blMonthLabel(info.started ? info.nextMonth : info.month, ar, withYear: false);
  if (info.started) return ar ? 'الدوري الجاي يبدأ 1 $m' : 'Next league starts 1 $m';
  return ar ? 'يبدأ 1 $m' : 'Starts 1 $m';
}

/// prize per member of the league a new team plays in
int? blTargetPerMember(BLeagueInfo info) => info.started
    ? (info.nextPerMember('LOCAL') ?? info.nextPerMember('WORLD') ?? info.perMember('LOCAL') ?? info.perMember('WORLD'))
    : (info.perMember('LOCAL') ?? info.perMember('WORLD'));

String blRoundsLine(BLeagueInfo info) {
  final ar = AppLang.isArabic;
  if (info.started) {
    final cur = blMonthLabel(info.month, ar, withYear: false);
    final nx = blMonthLabel(info.nextMonth, ar, withYear: false);
    return ar ? 'دوري $cur شغال دلوقتي · جهّز فريقك لدوري $nx' : 'The $cur league is on now · get your team ready for $nx';
  }
  final m = blMonthLabel(info.month, ar, withYear: false);
  final nos = [
    for (final a in ['LOCAL', 'WORLD'])
      for (final r in info.rounds(a)) (r['round_no'] as num?)?.toInt(),
  ].whereType<int>().toList()..sort();
  if (nos.isEmpty) {
    return ar ? 'كل جولات $m · من أول جولة لآخر جولة في الشهر' : 'Every $m gameweek · from the first to the last one of the month';
  }
  return ar ? 'من الجولة ${nos.first} لحد آخر جولة في $m' : 'From Gameweek ${nos.first} to the last gameweek of $m';
}

/// the page itself (used by render tests)
Widget blAnnouncePreview(BLeagueInfo info) => _BLAnnouncePage(info: info, onOpen: (_) async {});

class _BLAnnouncePage extends StatefulWidget {
  const _BLAnnouncePage({required this.info, required this.onOpen});
  final BLeagueInfo info;
  final Future<void> Function(String arena) onOpen;
  @override
  State<_BLAnnouncePage> createState() => _BLAnnouncePageState();
}

class _BLAnnouncePageState extends State<_BLAnnouncePage> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _in.value = 1;
      } else {
        _in.forward();
        _float.repeat(reverse: true);
      }
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _float.dispose();
    super.dispose();
  }

  /// piece [i] of the page fades + rises in, one after the other
  Widget _step(int i, Widget child) => AnimatedBuilder(
        animation: _in,
        builder: (_, c) {
          final v = Curves.easeOutCubic.transform(((_in.value * 1.6 - i * 0.09)).clamp(0.0, 1.0));
          return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 22), child: c));
        },
        child: child,
      );

  Future<void> _open(String arena) async {
    HapticFeedback.selectionClick();
    final nav = Navigator.of(context);
    await widget.onOpen(arena);
    BLeagueInfo.clear();
    if (mounted && nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final ar = AppLang.isArabic;
    final per = blTargetPerMember(info);
    final max = info.maxMembers;
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [
          // warm stadium glow behind the mascot
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
            center: const Alignment(0, -0.62), radius: 0.95,
            colors: [_gold2.withValues(alpha: 0.30), const Color(0xFF2A1606).withValues(alpha: 0.55), _bg],
            stops: const [0, 0.45, 1])))),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _RaysPainter()))),
          SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 0), child: Row(children: [
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white70)),
              const Spacer(),
              Image.asset('assets/badger_white.png', height: 18, cacheHeight: 60),
              const SizedBox(width: 6),
              const Text('BDGR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12.5)),
              const Spacer(),
              const SizedBox(width: 48),
            ])),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), children: [
              // mascot hero
              _step(0, SizedBox(height: 236, child: Stack(alignment: Alignment.center, children: [
                Container(width: 210, height: 210, decoration: BoxDecoration(shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 80, spreadRadius: 6)])),
                AnimatedBuilder(animation: _float, builder: (_, c) => Transform.translate(
                    offset: Offset(0, -6 + 12 * Curves.easeInOut.transform(_float.value)), child: c),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _gold.withValues(alpha: 0.8), width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10))]),
                    child: ClipRRect(borderRadius: BorderRadius.circular(26),
                        child: Image.asset(kBLMascot, height: 222, fit: BoxFit.cover, cacheHeight: 700)))),
                PositionedDirectional(top: 18, end: 24, child: Transform.rotate(angle: ar ? 0.12 : -0.12, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.5), blurRadius: 14)]),
                  child: Text(_t('NEW', 'جديد'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
                ))),
              ]))),
              _step(1, Column(children: [
                Text(_t('BADGER LEAGUE', 'دوري بادجر'), textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: ar ? 34 : 32, fontWeight: FontWeight.w900, letterSpacing: ar ? 0 : 2, height: 1.1)),
                const SizedBox(height: 6),
                Text(_t('Your friends. One team. One month.', 'صحابك. فريق واحد. شهر كامل.'), textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: _gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _gold.withValues(alpha: 0.6))),
                  child: Text('📅  ${blStartLine(info)}', style: const TextStyle(color: _gold, fontSize: 13.5, fontWeight: FontWeight.w900)),
                )),
                const SizedBox(height: 6),
                Text(blRoundsLine(info), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
              const SizedBox(height: 22),
              // the prize
              _step(2, Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF3A2A08), Color(0xFF1C1408), Color(0xFF141012)]),
                  border: Border.all(color: _gold.withValues(alpha: 0.55)),
                  boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.12), blurRadius: 24)],
                ),
                child: Column(children: [
                  Text(_t('THE #1 TEAM WINS', 'الفريق الأول يكسب'),
                      style: TextStyle(color: _gold.withValues(alpha: 0.9), fontSize: 11.5, letterSpacing: ar ? 0 : 2.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (per != null) ...[
                    Text(_t('${blMoney(per)} EGP', '${blMoney(per)} جنيه'),
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.05)),
                    Text(_t('for EVERY member of the team', 'لكل عضو في الفريق'),
                        style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < max; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _PersonCoin(index: i, anim: _in)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_t('Team of $max = ${blMoney(per * max)} EGP · in each arena', 'فريق من $max = ${blMoney(per * max)} جنيه · في كل أرينا'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ] else
                    Text(_t('Prize for every member of the team', 'جايزة لكل عضو في الفريق'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ]),
              )),
              const SizedBox(height: 18),
              // two leagues
              _step(3, Row(children: [
                Expanded(child: _arenaCard('🇪🇬', _t('Egypt league', 'دوري مصر'), info.anyTeam('LOCAL'))),
                const SizedBox(width: 10),
                Expanded(child: _arenaCard('🌍', _t('World league', 'دوري العالم'), info.anyTeam('WORLD'))),
              ])),
              const SizedBox(height: 6),
              _step(3, Text(_t('Two separate leagues, each with its own table and prize. One team in each.',
                  'دوريين منفصلين، كل واحد بترتيبه وجايزته. فريق واحد بس في كل واحد.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))),
              const SizedBox(height: 20),
              _step(4, Text(_t('HOW IT WORKS', 'ماشي إزاي'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5, letterSpacing: ar ? 0 : 2.5, fontWeight: FontWeight.w900))),
              const SizedBox(height: 10),
              for (final (i, e) in [
                ('👥', _t('Make a team', 'اعمل فريقك'),
                    _t('${info.minMembers} to ${info.maxMembers} friends. Make it, or join with a code.', 'من ${info.minMembers} لـ ${info.maxMembers} صحاب. اعمله إنت أو ادخل بكود.')),
                ('⚽', _t('Play every gameweek', 'العب كل جولة'),
                    _t('Each of you picks his own draft team, as usual.', 'كل واحد بيختار تشكيلة الدرافت بتاعته عادي.')),
                ('➕', _t('Points add up', 'النقط بتتجمع'),
                    _t('Your team = the sum of all of you, every gameweek of the month.', 'فريقك = مجموع نقطكم كلكم في كل جولات الشهر.')),
                ('🏆', _t('Win together', 'اكسبوا سوا'),
                    per != null ? _t('The #1 team: ${blMoney(per)} EGP for each of you.', 'الفريق الأول: ${blMoney(per)} جنيه لكل واحد فيكم.')
                        : _t('The #1 team wins, all of you.', 'الفريق الأول يكسب، كلكم.')),
              ].indexed)
                _step(5 + i, _howRow(i + 1, e.$1, e.$2, e.$3)),
              const SizedBox(height: 8),
              _step(9, Text(_t('A team enters the table with ${info.minMembers} members · nobody can leave or be removed · tie = more exact predictions, then the older team.',
                  'الفريق بيدخل الترتيب من ${info.minMembers} أعضاء · ماحدش يخرج ولا يتشال · التعادل = توقعات أدق، وبعدها الفريق الأقدم.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.45))),
            ])),
            // actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(color: _bg, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: _cta('LOCAL', '🇪🇬', _t('Egypt team', 'فريق مصر'), info.anyTeam('LOCAL') != null)),
                  const SizedBox(width: 10),
                  Expanded(child: _cta('WORLD', '🌍', _t('World team', 'فريق العالم'), info.anyTeam('WORLD') != null)),
                ]),
                TextButton(onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(_t('Later', 'بعدين'), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700))),
              ]),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _arenaCard(String flag, String name, Map<String, dynamic>? team) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: team != null ? const Color(0xFF43A047) : Colors.white12)),
        child: Column(children: [
          Text(flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(team != null ? '✓ ${team['name']}' : _t('Own table + prize', 'ترتيب وجايزة لوحده'), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: team != null ? const Color(0xFF66BB6A) : Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _howRow(int n, String icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10)),
          child: Row(children: [
            Container(width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _gold.withValues(alpha: 0.12), border: Border.all(color: _gold.withValues(alpha: 0.45))),
                child: Text(icon, style: const TextStyle(fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$n · $title', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.35)),
            ])),
          ]),
        ),
      );

  Widget _cta(String arena, String flag, String label, bool has) => SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: () => _open(arena),
          style: ElevatedButton.styleFrom(
            backgroundColor: has ? const Color(0xFF1E2A1F) : _red, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
                side: has ? const BorderSide(color: Color(0xFF43A047)) : BorderSide.none),
          ),
          child: FittedBox(child: Text(has ? '$flag ✓ $label' : '$flag  ${_t('Make my', 'اعمل')} $label',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
        ),
      );
}

/// one gold coin per team member (pops in one after the other)
class _PersonCoin extends StatelessWidget {
  const _PersonCoin({required this.index, required this.anim});
  final int index;
  final Animation<double> anim;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          final v = Curves.easeOutBack.transform(((anim.value - 0.35 - index * 0.06) * 3).clamp(0.0, 1.0));
          return Transform.scale(scale: v, child: Container(
            width: 34, height: 34, alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE9A8), _gold, _gold2])),
            child: const Icon(Icons.person, color: Color(0xFF4A3208), size: 20),
          ));
        },
      );
}

/// soft light rays from the top (convex wedges only, 3-stop gradient: safe on Samsung)
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, -40);
    final r = size.height * 0.8;
    for (var i = 0; i < 7; i++) {
      final a = math.pi / 2 + (i - 3) * 0.22;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.04), c.dy + r * math.sin(a - 0.04))
        ..lineTo(c.dx + r * math.cos(a + 0.04), c.dy + r * math.sin(a + 0.04))
        ..close();
      canvas.drawPath(p, Paint()
        ..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.10), _gold.withValues(alpha: 0.03), Colors.transparent],
            stops: const [0, 0.5, 1]).createShader(Rect.fromCircle(center: c, radius: r)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// small card used in the lobby / feed / home: mascot face + "Badger League · starts 1 Dec" → the announcement
class BLAnnounceCard extends StatelessWidget {
  const BLAnnounceCard({super.key, required this.info, required this.onTap, this.compact = false});
  final BLeagueInfo info;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final per = blTargetPerMember(info);
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: EdgeInsets.fromLTRB(10, compact ? 8 : 10, 12, compact ? 8 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF3A2A08), Color(0xFF1C1408), Color(0xFF141217)]),
          border: Border.all(color: _gold.withValues(alpha: 0.55)),
        ),
        child: Row(children: [
          ClipOval(child: Image.asset(kBLMascotFace, width: compact ? 40 : 50, height: compact ? 40 : 50, fit: BoxFit.cover, cacheWidth: 160)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(child: Text(_t('Badger League', 'دوري بادجر'), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(8)),
                  child: Text(_t('NEW', 'جديد'), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 2),
            Text(
              info.started
                  ? '${blStartLine(info)} · ${_t('make your team', 'اعمل فريقك')}'
                  : '${blStartLine(info)} · ${per != null ? _t('${blMoney(per)} EGP each', '${blMoney(per)} جنيه لكل عضو') : _t('team prize', 'جايزة للفريق')}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ])),
          Text(AppLang.isArabic ? '‹' : '›', style: const TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}
