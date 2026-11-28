part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// LAUNCH (branch `launch`, owner 26 Nov 2026): fantasy = DRAFT 7 + Badger League.
// · Round page (lobby) = title "Current Gameweek" + small deadline/prize card + matches + ONE button.
//   3 states: open & no squad → BUILD MY TEAM · open & saved → SHOW MY TEAM (edit inside) ·
//   locked/finished → SHOW MY TEAM (read only) or "you missed this round".
// · After saving: ONE sheet that points to the first missing thing (Badger League team → a league),
//   each at most once per round (LocalStore), "Not now" closes it.
// · Saved / locked rounds show ONE small line under the card with the same next step.
// · Ranking / Leagues / Badger League live in "My Fantasy" (header person icon), not on the round page.
// ═══════════════════════════════════════════════════════════════════════════

/// what the user is missing: Badger League team this month, a league (cached ~20 s)
class _LaunchStatus {
  final BLeagueInfo? bl;   // badger_league_home2 (null / hidden = the league is off)
  final String arena;      // the arena the user is in (owner 28 Nov: one league per arena)
  final int leagues, invites;
  const _LaunchStatus(this.bl, this.arena, this.leagues, this.invites);
  bool get blOn => bl != null && bl!.visible;
  Map? get team => blOn ? bl!.anyTeam(arena) : null;
  String? get month => bl?.month;
  /// my Badger League team is too small to be in the table
  bool get teamTooSmall => team != null && team!['in_table'] == false;
  /// 'badger' | 'bl_invite' (team not in the table yet) | 'league' | null (has all)
  String? get next => !blOn ? (leagues == 0 ? 'league' : null)
      : team == null ? 'badger' : teamTooSmall ? 'bl_invite' : (leagues == 0 ? 'league' : null);
}

_LaunchStatus? _lsCache;
DateTime? _lsAt;
Future<_LaunchStatus?> _launchStatus({bool fresh = false}) async {
  if (!fresh && _lsCache != null && _lsCache!.arena == _BLBoardCache.lastArena && _lsAt != null && DateTime.now().difference(_lsAt!) < const Duration(seconds: 20)) return _lsCache;
  try {
    final r = await Future.wait<dynamic>([
      BLeagueInfo.load(force: fresh),
      _sb.rpc('league_my_list'),
      _sb.rpc('league_inbox').catchError((_) => null),
    ]);
    final inbox = r[2] is Map ? r[2] as Map : const {};
    _lsCache = _LaunchStatus(r[0] as BLeagueInfo?, _BLBoardCache.lastArena,
        (r[1] as List?)?.length ?? 0, ((inbox['invites'] as List?) ?? const []).length);
    _lsAt = DateTime.now();
    return _lsCache;
  } catch (_) {
    return null;
  }
}

int _blMembers(Map team) {
  final m = team['members'];
  if (m is num) return m.toInt();
  if (m is List) return m.length;
  return 0;
}

Future<void> _openBLeague(BuildContext context) async {
  await openBadgerLeague(context, arena: _BLBoardCache.lastArena);
  _lsAt = null;
}

Future<void> _openLeaguesPage(BuildContext context, bool isArabic) async {
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) =>
      _LaunchSubPage(isArabic: isArabic, title: isArabic ? 'الليجز' : 'Leagues', child: FantasyLeaguesTab(isArabic: isArabic))));
  _lsAt = null;
}

Future<void> _openRankingPage(BuildContext context, bool isArabic, VoidCallback? onToggleLanguage) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) =>
        _LaunchSubPage(isArabic: isArabic, title: isArabic ? 'الترتيب' : 'Ranking',
            child: FantasyRankTab(isArabic: isArabic, onToggleLanguage: onToggleLanguage))));

/// full page with a back arrow around a fantasy tab (ranking / leagues)
class _LaunchSubPage extends StatelessWidget {
  const _LaunchSubPage({required this.isArabic, required this.title, required this.child});
  final bool isArabic;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(backgroundColor: bg, body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 16, 6), child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(backgroundColor: cardBg, side: BorderSide(color: line)),
          icon: Icon(isArabic ? Icons.arrow_forward : Icons.arrow_back, color: Colors.white)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
      ])),
      Expanded(child: child),
    ]))),
  );
}

// ─── round page (lobby) ─────────────────────────────────────────────────────
extension _LaunchLobby on _FancyPageState {
  Widget launchLobby(FantasyEvent event) {
    final ph = phaseOf(event);
    final has = _hasSquad || saved;
    final byDay = <String, List<FantasyMatch>>{};
    for (final m in event.matches) {
      (byDay[_dayLabel(m.kickoffAt)] ??= []).add(m);
    }
    final anyResult = event.matches.any((m) => m.finished);
    return LayoutBuilder(key: const ValueKey('lobby'), builder: (context, constraints) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // compact (fantasy_lobby_compact): the title + arena switch live in the top bar
        if (!_FancyPageState._lobbyCompact) ...[
          StaggerIn(index: 0, child: backHeader(label: '', onBack: () => _v2Set(() => step = 0),
              title: Text(t('Current GW', 'الجولة الحالية'), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)))),
          const SizedBox(height: 10),
          StaggerIn(index: 1, dy: 24, child: _lInfoCard(event, ph, has)),
          // the last finished round: "Round 1 · 9 pts · #5,457 ›" → the recap sheet
          StaggerIn(index: 2, child: this._recapLine(event)),
        ] else ...[
          StaggerIn(index: 1, dy: 24, child: _lDeadlineCard(event, ph, has)),
          const SizedBox(height: 10),
          StaggerIn(index: 2, dy: 24, child: _lPrizeCard(event)),
          // owner 28 Nov: Badger League announcement card while I have no team in this arena
          FutureBuilder<BLeagueInfo?>(
            future: BLeagueInfo.load(),
            builder: (_, snap) {
              final info = snap.data;
              final a = event.fantasyType == 'WORLD' ? 'WORLD' : 'LOCAL';
              if (info == null || !info.ui('lobby') || info.anyTeam(a) != null) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 10), child: StaggerIn(index: 2, dy: 24,
                  child: BLAnnounceCard(info: info, compact: true,
                      onTap: () => showBLAnnouncement(context, onOpen: (x) => openBadgerLeague(context, arena: x)))));
            }),
        ],
        // modes = both (DB): pick which squad this page shows
        if (_FancyPageState._modes == 'both' && event.draftOn)
          Padding(padding: const EdgeInsets.only(top: 10), child: StaggerIn(index: 2, child: draftModeSwitch(onPick: (d) => _lSetMode(event, d)))),
        // finished round: one calm line to the ranking
        if (ph == 'finished')
          StaggerIn(index: 2, child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openRankingPage(context, isArabic, null),
            child: Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
              const Icon(Icons.leaderboard_outlined, color: Brand.green, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(t('See your ranking', 'شوف ترتيبك'),
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
              Text(isArabic ? '‹' : '›', style: const TextStyle(color: Brand.green, fontSize: 18, fontWeight: FontWeight.w900)),
            ])))),
        // open + no squad: nothing else, the team comes first
        if (!_FancyPageState._lobbyCompact && _squadChecked && (ph != 'open' || has))
          StaggerIn(index: 2, child: LaunchNudgeLine(key: ValueKey('nudge_${event.eventId}_$has'), isArabic: isArabic)),
        const SizedBox(height: 14),
        StaggerIn(index: 3, child: Row(children: [
          Expanded(child: Text(t('MATCHES', 'الماتشات'), maxLines: 1,
            style: const TextStyle(color: muted, fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w800))),
          if (anyResult || ph != 'open')
            GestureDetector(
              onTap: () => openFixturesPage(context, type: event.fantasyType ?? 'WORLD'),
              child: Text(t('All results ›', 'كل النتايج ›'),
                style: const TextStyle(color: Brand.green, fontSize: 12.5, fontWeight: FontWeight.w800))),
        ])),
        const SizedBox(height: 4),
        Expanded(child: Builder(builder: (_) {
          var n = 4;   // matches come in one after the other, under the title
          return ListView(padding: const EdgeInsets.only(bottom: 8), children: [
            for (final entry in byDay.entries) ...[
              StaggerIn(index: n++, child: Padding(padding: const EdgeInsets.only(bottom: 6, top: 6),
                child: Text('${entry.key} · ${_fmtDate(entry.value.first.kickoffAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)))),
              ...entry.value.map((m) => StaggerIn(index: n++, dy: 26, child: _matchCard(m))),
            ],
          ]);
        })),
        const SizedBox(height: 8),
        // streak line above the button (compact lobby, open round)
        if (_FancyPageState._lobbyCompact && ph == 'open' && _squadChecked)
          StreakLobbyLine(key: ValueKey('streak_${event.eventId}_$has'), saved: has),
        StaggerIn(index: 3, dy: 40, durationMs: 560, child: _lButton(event, ph, has)),
      ]),
    ));
  }

  /// modes = both: switch the lobby between the draft and the normal 11 (each saved on its own)
  void _lSetMode(FantasyEvent event, bool draft) {
    if (_draftView == draft || _flying) return;
    _v2Set(() {
      _draftView = draft;
      clearSquad();
      saved = false; _hasSquad = false; _squadChecked = false; _gStage = -1;
      _flown.clear(); _landedId = null; _duelKey = null; _myRank = null;
      formation = v2Formation;
    });
    squadTick.value++;
    _loadSavedSquad(event.eventId);
    if (phaseOf(event) == 'finished') _loadMyRank(event.eventId);
  }

  Widget _lButton(FantasyEvent event, String ph, bool has) {
    final open = ph == 'open';
    // open + no squad = the one red action; everything else = calm dark button
    if (open && !has) {
      return Pressable(child: ShineSweep(child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: () => _v2Set(() { step = 2; _gStage = -1; _landedId = null; }),
        style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(t('BUILD MY TEAM', 'ابني فريقي'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15.5)),
          const SizedBox(width: 10), Icon(isArabic ? Icons.arrow_back : Icons.arrow_forward, size: 19),
        ])))));
    }
    if (!open && !has) {
      return Container(width: double.infinity, height: 52, alignment: Alignment.center,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
        child: Text(t('You missed this round · the next one is coming', 'فاتتك الجولة دي · استنى الجاية'),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 13.5)));
    }
    final pts = (!open && _myRank?['total_points'] != null) ? (_myRank!['total_points'] as num) : null;
    const btnStyle = TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 15);
    return Pressable(child: SizedBox(width: double.infinity, height: 52, child: OutlinedButton(
      onPressed: () {
        // came back from an unsaved edit: show the SAVED team, not the half-edited one
        if (!saved) { clearSquad(); _loadSavedSquad(event.eventId); }
        _v2Set(() { step = 2; saved = true; });
      },
      style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFF1B1D21), foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF3A3D42)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.visibility_outlined, size: 19), const SizedBox(width: 8),
        Text(t('SHOW MY TEAM', 'وريني تشكيلتي'), style: btnStyle),
        // finished: the points count up
        if (pts != null) ...[
          const Text(' · ', style: btnStyle),
          CountUp(pts, style: btnStyle, format: (v) => '$v ${t('pts', 'نقطة')}'),
        ],
      ]))));
  }

  /// small card: deadline (or state) in one line + the 1st prize in one line (tap → all prizes)
  Widget _lInfoCard(FantasyEvent event, String ph, bool has) {
    final left = _timeLeft;
    String pad(int n) => n.toString().padLeft(2, '0');
    final d = left.inDays, h = left.inHours.remainder(24), m = left.inMinutes.remainder(60), s = left.inSeconds.remainder(60);
    final when = '${_fmtDeadline(event.deadlineAt)} ${_fmtDate(event.deadlineAt)}';
    final (IconData ic, Color c, String title, String sub) = switch (ph) {
      'open' => (Icons.timer_outlined, Brand.green,
                 '${d > 0 ? t('${d}d ', '$dي ') : ''}${pad(h)}:${pad(m)}:${pad(s)}',
                 t('Closes $when', 'بتتقفل $when')),
      'live' => (Icons.lock_rounded, const Color(0xFFFF5C5C),
                 t('Teams locked', 'التشكيلات اتقفلت'),
                 t('Matches are on · points come with the results', 'الماتشات شغالة · النقط بتنزل مع النتايج')),
      _      => (Icons.flag_rounded, Colors.white70,
                 _myRank?['rank'] != null ? t('You finished #${_myRank!['rank']}', 'ترتيبك #${_myRank!['rank']}') : t('Round finished', 'الجولة خلصت'),
                 _myRank?['rank'] != null
                   ? t('${(_myRank!['total_points'] as num?)?.toStringAsFixed(0) ?? 0} pts · of ${_myRank!['total_players']} players',
                       '${(_myRank!['total_points'] as num?)?.toStringAsFixed(0) ?? 0} نقطة · من ${_myRank!['total_players']} لاعب')
                   : t('The next round is coming soon', 'الجولة الجاية قريب')),
    };
    const gold = Color(0xFFFFB300);
    final first = event.prizes.isEmpty ? null : event.prizes.reduce((a, b) => a.rank <= b.rank ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withOpacity(0.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ic, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (ph == 'open')
              // countdown: each digit rolls when it changes
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (d > 0) Text(t('${d}d ', '$dي '), style: _cdStyle),
                RollingText('${pad(h)}:${pad(m)}:${pad(s)}', style: _cdStyle),
              ])
            else
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c, fontSize: 15.5, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
            if (ph == 'open' && has) PopIn(delayMs: 250, child: Container(
              margin: const EdgeInsets.only(top: 3, bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Brand.green.withOpacity(0.6))),
              child: Text(t('✓ YOUR TEAM IS SAVED', '✓ تشكيلتك محفوظة'),
                style: const TextStyle(color: Brand.green, fontSize: 10, fontWeight: FontWeight.w900)))),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11.5)),
          ])),
          const SizedBox(width: 8),
          _phasePill(ph),
        ]),
        if (first != null) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1, color: line)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _lPrizesSheet(event),
            child: Row(children: [
              const Text('🏆', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(t('1st prize', 'أول جايزة'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(child: Text(first.text(isArabic), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: gold, fontSize: 14.5, fontWeight: FontWeight.w900))),
              Text(t('All prizes ›', 'كل الجوايز ›'), style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
    );
  }

  /// compact deadline card (owner 28 Nov): its own card, countdown in boxes, saved chip, closing time
  Widget _lDeadlineCard(FantasyEvent event, String ph, bool has) {
    final left = _timeLeft;
    String pad(int n) => n.toString().padLeft(2, '0');
    final d = left.inDays, h = left.inHours.remainder(24), m = left.inMinutes.remainder(60), s = left.inSeconds.remainder(60);
    final when = '${_fmtDeadline(event.deadlineAt)} ${_fmtDate(event.deadlineAt)}';
    final c = switch (ph) { 'open' => Brand.green, 'live' => const Color(0xFFFF5C5C), _ => Colors.white70 };
    Widget box(String v, String l) => Container(
      width: 62, padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFF0C0D10), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2B31))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        RollingText(v, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.1,
            fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(color: muted, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ]),
    );
    const colon = Padding(padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(':', style: TextStyle(color: Color(0xFF55585E), fontSize: 20, fontWeight: FontWeight.w900)));
    final String title;
    final String sub;
    if (ph == 'live') {
      title = t('Teams locked', 'التشكيلات اتقفلت');
      sub = t('Matches are on · points come with the results', 'الماتشات شغالة · النقط بتنزل مع النتايج');
    } else if (ph == 'finished') {
      title = _myRank?['rank'] != null ? t('You finished #${_myRank!['rank']}', 'ترتيبك #${_myRank!['rank']}') : t('Round finished', 'الجولة خلصت');
      sub = _myRank?['rank'] != null
          ? t('${(_myRank!['total_points'] as num?)?.toStringAsFixed(0) ?? 0} pts · of ${_myRank!['total_players']} players',
              '${(_myRank!['total_points'] as num?)?.toStringAsFixed(0) ?? 0} نقطة · من ${_myRank!['total_players']} لاعب')
          : t('The next round is coming soon', 'الجولة الجاية قريب');
    } else {
      title = '';
      sub = '';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withOpacity(0.5)),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color.lerp(cardBg, c, 0.12)!, cardBg]),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(ph == 'open' ? t('DEADLINE', 'آخر ميعاد') : ph == 'live' ? t('LIVE', 'شغالة') : t('FINISHED', 'خلصت'),
            style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 2))),
          if (ph == 'open' && has) PopIn(delayMs: 250, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.green.withOpacity(0.7))),
            child: Text(t('✓ Team saved', '✓ تشكيلتك محفوظة'),
              style: const TextStyle(color: Brand.green, fontSize: 10.5, fontWeight: FontWeight.w900)))),
          if (ph != 'open') _phasePill(ph),
        ]),
        const SizedBox(height: 10),
        if (ph == 'open') ...[
          Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (d > 0) ...[box('$d', t('DAYS', 'يوم')), colon],
            box(pad(h), t('HRS', 'ساعة')), colon,
            box(pad(m), t('MIN', 'دقيقة')),
            if (d == 0) ...[colon, box(pad(s), t('SEC', 'ثانية'))],
          ])),
          const SizedBox(height: 9),
          Text(t('Closes $when', 'بتتقفل $when'), style: const TextStyle(color: muted, fontSize: 12)),
        ] else ...[
          Text(title, textAlign: TextAlign.center,
            style: TextStyle(color: c, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ]),
    );
  }

  /// compact prize card: its own gold card under the deadline (tap → all prizes + the round sponsor)
  Widget _lPrizeCard(FantasyEvent event) {
    if (event.prizes.isEmpty) return const SizedBox.shrink();
    final first = event.prizes.reduce((a, b) => a.rank <= b.rank ? a : b);
    const gold = Color(0xFFFFC233);
    return Pressable(child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _lPrizesSheet(event),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF5C4A1A)),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF241D0C), cardBg]),
        ),
        child: Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('1st PRIZE', 'الجايزة الأولى'), style: const TextStyle(color: Color(0xFFC9A84A), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 1),
            Text(first.text(isArabic), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
          Text(t('All prizes ›', 'كل الجوايز ›'), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    ));
  }

  static const _cdStyle = TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900,
      fontFeatures: [FontFeature.tabularFigures()]);

  void _lPrizesSheet(FantasyEvent event) {
    final ad = _roundSponsorAd(event);
    showModalBottomSheet<void>(
      context: context, backgroundColor: bg, useRootNavigator: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            _prizesCard(event.prizes),
            if (ad != null) ...[const SizedBox(height: 12), Center(child: _sponsorBlock(ad))],
          ]),
        ),
      ),
    );
  }
}

// ─── one small line: the next step (Badger League team → league → my Badger team) ───
class LaunchNudgeLine extends StatefulWidget {
  const LaunchNudgeLine({super.key, required this.isArabic});
  final bool isArabic;
  @override
  State<LaunchNudgeLine> createState() => _LaunchNudgeLineState();
}

class _LaunchNudgeLineState extends State<LaunchNudgeLine> {
  _LaunchStatus? _s;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load({bool fresh = false}) async {
    final s = await _launchStatus(fresh: fresh);
    if (mounted) setState(() => _s = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final next = s.next;
    final team = s.team;
    final month = _blMonthName(s.month, widget.isArabic);
    final (Widget lead, String text, Color border, List<Color> grad, Future<void> Function() go) = switch (next) {
      'badger' => (const Text('🥇', style: TextStyle(fontSize: 18)),
                   s.arena == 'WORLD'
                       ? t('Make your World team · Badger League · $month', 'اعمل فريقك في دوري بادجر العالم · $month')
                       : t('Make your Egypt team · Badger League · $month', 'اعمل فريقك في دوري بادجر مصر · $month'),
                   const Color(0xFF6B5313), const [Color(0xFF2A2210), cardBg], () => _openBLeague(context)),
      'bl_invite' => (LeagueShield(icon: '${team!['icon']}', color: '${team['color']}', size: 24),
                   t('${team['name']} is not in the table yet · invite a friend', '${team['name']} لسه مش في الترتيب · اعزم صاحب'),
                   const Color(0xFF6B5313), const [Color(0xFF2A2210), cardBg], () => _openBLeague(context)),
      'league' => (const Text('🛡️', style: TextStyle(fontSize: 17)),
                   t('Start a league with your friends', 'اعمل ليج لصحابك أو الشغل'),
                   const Color(0xFF2A3A6B), const [Color(0xFF141C33), cardBg], () => _openLeaguesPage(context, widget.isArabic)),
      _        => (LeagueShield(icon: '${team!['icon']}', color: '${team['color']}', size: 24),
                   '${team['name']} · #${team['rank'] ?? '-'} · ${_blPts(team['points'])} ${t('pts', 'نقطة')}',
                   line, const [cardBg, cardBg], () => _openBLeague(context)),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async { await go(); _load(fresh: true); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
            gradient: LinearGradient(colors: grad)),
          child: Row(children: [
            lead, const SizedBox(width: 10),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
            Icon(widget.isArabic ? Icons.chevron_left : Icons.chevron_right, color: muted),
          ]),
        ),
      )),
    );
  }
}

// ─── after "save": one sheet with the next step (once per round per kind) ──────
/// returns true when a sheet was shown
Future<bool> showLaunchSavedNudge(BuildContext context, bool isArabic, String eventId) async {
  final s = await _launchStatus(fresh: true);
  final next = s?.next;
  if (next == null || !context.mounted) return false;
  final flag = 'launch_nudge_${next}_$eventId';
  if (await LocalStore.getFlag(flag)) return false;
  if (!context.mounted) return false;
  await LocalStore.setFlag(flag);
  String t(String en, String ar) => isArabic ? ar : en;
  final invite = next == 'bl_invite';
  final badger = next == 'badger' || invite;
  final team = s!.team;
  final month = _blMonthName(s.month, isArabic);
  const gold = Color(0xFFFFB300);
  final go = await showModalBottomSheet<bool>(
    context: context, useRootNavigator: true, isScrollControlled: true, backgroundColor: const Color(0xFF15171A),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFF3A3D42), borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 16),
          Text(t('✓ Your team is saved', '✓ تشكيلتك اتحفظت'), textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.green, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Center(child: PopIn(delayMs: 150, from: 0.3, child: invite
              ? LeagueShield(icon: '${team!['icon']}', color: '${team['color']}', size: 64)
              : badger
              ? const LeagueShield(icon: '🥇', color: '#F5B301', size: 64)
              : Container(width: 64, height: 64, alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFF141C33), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2A3A6B))),
                  child: const Text('🛡️', style: TextStyle(fontSize: 30))))),
          const SizedBox(height: 12),
          Text(invite ? t('${team!['name']} needs one more', '${team!['name']} محتاج واحد كمان')
              : badger ? (s.arena == 'WORLD' ? t('Badger League 🌍 World · $month', 'دوري بادجر 🌍 العالم · $month')
                                             : t('Badger League 🇪🇬 Egypt · $month', 'دوري بادجر 🇪🇬 مصر · $month'))
              : t('Play with your friends', 'العب مع صحابك'),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(invite
              ? t('Your team enters the Badger League table once it has 2 players. Send your code to a friend now.',
                  'فريقك بيدخل ترتيب دوري بادجر لما يبقى فيه اتنين. ابعت الكود لصاحبك دلوقتي.')
              : badger
              ? (s.bl!.startedIn(s.arena)
                  ? t('Make a team of 2 to 5 friends. Your points add up, so every friend you add raises your chances. If your team finishes #1 this month, all of you win the prize.',
                      'اعمل فريق من 2 لـ 5 صحاب. نقطكم بتتجمع، فكل صاحب بتضيفه فرصتكم بتكبر. ولو فريقكم طلع الأول الشهر ده، كلكم تكسبوا الجايزة.')
                  : t('${blStartLine(s.bl!)}. Make your team of 2 to 5 friends now, so it is ready. If your team finishes #1, all of you win the prize.',
                      '${blStartLine(s.bl!)}. اعمل فريقك من 2 لـ 5 صحاب من دلوقتي عشان يبقى جاهز. ولو فريقكم طلع الأول، كلكم تكسبوا الجايزة.'))
              : t('Make a league for your friends, family or work — any size — and see who is the best coach.',
                  'اعمل ليج لصحابك أو عيلتك أو الشغل، بأي عدد، وشوفوا مين أحسن مدرب.'),
            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC9CCD1), fontSize: 13.5, height: 1.5)),
          if (badger) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 5; i++) PopIn(delayMs: 380 + i * 90, child: Container(
                width: 34, height: 34, margin: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: i == 0 || (invite && i < _blMembers(team!)) ? const Color(0xFF2A2210) : null,
                  border: Border.all(color: i == 0 ? gold : const Color(0xFF6B5313), width: i == 0 ? 2 : 1.2)),
                child: Text(i == 0 ? t('YOU', 'إنت') : '+', style: const TextStyle(color: gold, fontSize: 10.5, fontWeight: FontWeight.w900)))),
            ]),
          ],
          const SizedBox(height: 18),
          SizedBox(height: 50, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: badger ? gold : brandRed, foregroundColor: badger ? Colors.black : Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(invite ? t('INVITE A FRIEND', 'اعزم صاحب')
                : badger ? t('MAKE OR JOIN A TEAM', 'اعمل فريق أو انضم لواحد') : t('MAKE OR JOIN A LEAGUE', 'اعمل ليج أو انضم لواحدة'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)))),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Not now', 'مش دلوقتي'), style: const TextStyle(color: muted, fontWeight: FontWeight.w700))),
        ]),
      )),
    ),
  );
  if (go == true && context.mounted) {
    if (badger) { await _openBLeague(context); } else { await _openLeaguesPage(context, isArabic); }
  }
  return true;
}

// ─── "My Fantasy": ranking · leagues · Badger League (header person icon) ────
void openMyFantasyHub(BuildContext context, bool isArabic, {VoidCallback? onToggleLanguage,
    bool showLanguage = false, VoidCallback? onRecap}) {
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) =>
      _LaunchHubPage(isArabic: isArabic, onToggleLanguage: onToggleLanguage, showLanguage: showLanguage, onRecap: onRecap)));
}

class _LaunchHubPage extends StatefulWidget {
  const _LaunchHubPage({required this.isArabic, this.onToggleLanguage, this.showLanguage = false, this.onRecap});
  final bool isArabic;
  final VoidCallback? onToggleLanguage;
  /// compact round page (owner 28 Nov): the language switch + the last-round recap live here
  final bool showLanguage;
  final VoidCallback? onRecap;
  @override
  State<_LaunchHubPage> createState() => _LaunchHubPageState();
}

class _LaunchHubPageState extends State<_LaunchHubPage> {
  _LaunchStatus? _s;
  late bool _ar = widget.isArabic;   // flips with the language button on this page
  bool get ar => _ar;
  String t(String en, String a) => ar ? a : en;

  int _chIn = 0;   // challenge invites waiting for me
  @override
  void initState() { super.initState(); _load(true); }
  Future<void> _load(bool fresh) async {
    ChallengeApi.badge().then((n) { if (mounted) setState(() => _chIn = n); });
    final s = await _launchStatus(fresh: fresh);
    if (mounted) setState(() => _s = s);
  }

  Widget _card({required Widget icon, required String title, required Widget sub, required VoidCallback onTap, bool gold = false, int i = 0}) =>
    StaggerIn(index: i, dy: 28, gate: false, child: Pressable(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Material(color: Colors.transparent, child: InkWell(
      borderRadius: BorderRadius.circular(18), onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gold ? const Color(0xFF6B5313) : line),
          gradient: LinearGradient(colors: gold ? const [Color(0xFF2A2210), cardBg] : const [cardBg, cardBg])),
        child: Row(children: [
          Container(width: 46, height: 46, alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF22252A), borderRadius: BorderRadius.circular(14)), child: icon),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            sub,
          ])),
          Icon(ar ? Icons.chevron_left : Icons.chevron_right, color: muted),
        ]),
      ),
    )))));

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final team = s?.team;
    const subStyle = TextStyle(color: muted, fontSize: 12.5);
    return _LaunchSubPage(isArabic: ar, title: t('My Fantasy', 'أنا في الفانتازي'), child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _card(icon: const Text('📊', style: TextStyle(fontSize: 22)), title: t('Ranking', 'الترتيب'),
          sub: Text(t('Egypt · World · round, month, season', 'مصر · عالمي · الجولة، الشهر، الموسم'), style: subStyle),
          onTap: () => _openRankingPage(context, ar, widget.onToggleLanguage)),
        _card(icon: const Text('🛡️', style: TextStyle(fontSize: 22)), title: t('Leagues', 'الليجز'),
          sub: s == null ? const Text('', style: subStyle) : Text.rich(TextSpan(style: subStyle, children: [
            TextSpan(text: s.leagues == 0 ? t('Make one or join with a code', 'اعمل ليج أو انضم بكود')
                : t('${s.leagues} ${s.leagues == 1 ? 'league' : 'leagues'}', '${s.leagues} ${s.leagues == 1 ? 'ليج' : 'ليجز'}')),
            if (s.invites > 0) TextSpan(text: ' · ${t('${s.invites} invite${s.invites == 1 ? '' : 's'}', '${s.invites} دعوة')}',
                style: const TextStyle(color: Color(0xFFFF5C5C), fontWeight: FontWeight.w800)),
          ])),
          i: 1, onTap: () async { await _openLeaguesPage(context, ar); _load(true); }),
        if (s != null && s.blOn) _card(gold: true, i: 2,
          icon: team != null ? LeagueShield(icon: '${team['icon']}', color: '${team['color']}', size: 30) : const Text('🥇', style: TextStyle(fontSize: 22)),
          title: t('Badger League', 'دوري بادجر'),
          sub: Text(team != null
              ? (s!.teamTooSmall
                  ? t('${team['name']} · not in the table yet · invite a friend (${_blMembers(team)}/5)', '${team['name']} · لسه مش في الترتيب · اعزم صاحب (${_blMembers(team)}/5)')
                  : '${team['name']} · #${team['rank'] ?? '-'} · ${_blPts(team['points'])} ${t('pts', 'نقطة')}${_blMembers(team) < 5 ? ' · ${t('invite a friend', 'اعزم صاحب')} (${_blMembers(team)}/5)' : ''}')
              : (s!.bl!.startedIn(s.arena) && s.bl!.ui('next'))
                  ? t('The ${_blMonthName(s.bl!.month, false)} league is on · get ready for ${_blMonthName(s.bl!.nextMonth, false)}: make your team now',
                      'دوري ${_blMonthName(s.bl!.month, true)} شغال · جهّز فريقك لدوري ${_blMonthName(s.bl!.nextMonth, true)} من دلوقتي')
                  : t('Team up with 1 to 4 friends · ${_blMonthName(s.bl!.newTeamMonthIn(s.arena), false)}', 'اعمل فريق من 2 لـ 5 صحاب · ${_blMonthName(s.bl!.newTeamMonthIn(s.arena), true)}'),
            maxLines: 2, overflow: TextOverflow.ellipsis, style: subStyle),
          onTap: () async { await _openBLeague(context); _load(true); }),
        _card(i: 3, icon: const Text('⚔️', style: TextStyle(fontSize: 22)), title: t('Challenges', 'التحديات'),
          sub: _chIn > 0
              ? Text(t('$_chIn new challenge${_chIn == 1 ? '' : 's'} waiting for you', '$_chIn تحدي جديد مستني ردك'),
                  style: const TextStyle(color: Color(0xFFFF5C5C), fontSize: 12.5, fontWeight: FontWeight.w800))
              : Text(t('1 vs 1 with anyone · max 5 per gameweek', 'واحد قصاد واحد مع أي حد · 5 بالكتير في الجولة'), style: subStyle),
          onTap: () async { await openChallengesPage(context); _load(true); }),
        if (widget.onRecap != null)
          _card(i: 3, icon: const Text('🏁', style: TextStyle(fontSize: 22)), title: t('Last round', 'آخر جولة'),
            sub: Text(t('Your points, rank and best player', 'نقطك وترتيبك وأحسن لاعب عندك'), style: subStyle),
            onTap: () => widget.onRecap!()),
        if (widget.showLanguage && widget.onToggleLanguage != null && AppLang.togglesEverywhere)
          _card(i: 4, icon: const Icon(Icons.language_rounded, color: Colors.white, size: 24), title: t('Language', 'اللغة'),
            sub: Text(ar ? 'العربية · دوس علشان English' : 'English · tap for العربية', style: subStyle),
            onTap: () { widget.onToggleLanguage!(); setState(() => _ar = !_ar); }),
      ],
    ));
  }
}
