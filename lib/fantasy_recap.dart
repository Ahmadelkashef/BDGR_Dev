part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ROUND RECAP (launch, owner 26 Nov 2026, item 9)
// After a round's results are in, the user sees ONE sheet: his points (count up), rank of N,
// up/down vs the round before, best / worst player, average + top score, his Badger League team,
// a share card, and 3 buttons (build the next round · my squad with points · full ranking).
// · Opens by itself once per round (LocalStore `recap_seen_<event>`), and from the "Round N · pts · #rank ›" line.
// · Tapping the "your points are out" push opens it (FantasyMotion.pendingRecapEvent).
// · Top 10% = gold badge + confetti. Did not play = a short "you missed it" version.
// · Server: fantasy_round_recap(type) = numbers only, one call per arena per app run (egress-light).
// ═══════════════════════════════════════════════════════════════════════════

/// recap per arena type (LOCAL / WORLD), kept for the app run
final Map<String, Map<String, dynamic>> _recapCache = {};
/// recaps by event id (swiping to older rounds) + finished rounds list per arena, kept for the app run
final Map<String, Map<String, dynamic>> _recapByEvent = {};
final Map<String, List<Map<String, dynamic>>> _recapRoundsCache = {};

String _fmtInt(num? n) {
  if (n == null) return '—';
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

extension _RoundRecap on _FancyPageState {
  String get _recapType => arena == 'EGYPT' ? 'LOCAL' : 'WORLD';

  Map<String, dynamic>? get _recap {
    final r = _recapCache[_recapType];
    if (r == null || r['none'] == true || r['event_id'] == null) return null;
    return r;
  }

  /// the main mode of the recap (draft first when both)
  Map<String, dynamic>? get _recapMain {
    final ms = (_recap?['modes'] as List?) ?? const [];
    return ms.isEmpty ? null : Map<String, dynamic>.from(ms.first as Map);
  }

  /// loads the last finished round of this arena; opens the sheet once per round (or when the push asked for it)
  Future<void> _loadRecap({bool force = false}) async {
    final type = _recapType;
    try {
      if (force || !_recapCache.containsKey(type)) {
        final r = await _sb.rpc('fantasy_round_recap', params: {'p_type': type});
        if (r is Map) _recapCache[type] = Map<String, dynamic>.from(r);
      }
      if (!mounted || type != _recapType) return;
      this._v2Set(() {});
      final rc = _recap;
      if (rc == null) return;
      final id = '${rc['event_id']}';
      final pushed = FantasyMotion.pendingRecapEvent == id;
      if (pushed) FantasyMotion.pendingRecapEvent = null;
      var seen = false;
      try { seen = await LocalStore.getFlag('recap_seen_$id'); } catch (_) {}
      if (seen && !pushed) return;
      try { await LocalStore.setFlag('recap_seen_$id'); } catch (_) {}
      // let the lobby come in first
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted && step == 1 && type == _recapType) _openRecap();
    } catch (_) {}
  }

  /// the small line in the round page: "Round 1 · 9 pts · #5,457 ›" (or "you missed Round 1")
  Widget _recapLine(FantasyEvent current) {
    final rc = _recap, m = _recapMain;
    if (rc == null || m == null) return const SizedBox.shrink();
    if ('${rc['event_id']}' == current.eventId && phaseOf(current) != 'finished') return const SizedBox.shrink();
    final played = m['played'] == true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openRecap,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: m['top10'] == true ? const Color(0x88FFB300) : line)),
        child: Row(children: [
          Icon(m['top10'] == true ? Icons.workspace_premium_rounded : Icons.flag_rounded,
            color: m['top10'] == true ? const Color(0xFFFFB300) : Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            played
              ? '${t('Last round', 'آخر جولة')} · ${_fmtInt(m['points'] as num?)} ${t('pts', 'نقطة')} · #${_fmtInt(m['rank'] as num?)}'
              : t('You missed the last round', 'فاتتك آخر جولة'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
          Text(t('Recap', 'الملخص'), style: const TextStyle(color: Brand.green, fontSize: 12, fontWeight: FontWeight.w800)),
          Text(isArabic ? ' ‹' : ' ›', style: const TextStyle(color: Brand.green, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  void _openRecap() {
    final rc0 = _recap;
    if (rc0 == null) return;
    final rc = rc0;
    final cur = currentEvent;
    final canBuild = cur != null && phaseOf(cur) == 'open' && !(_hasSquad || saved) && '${rc['event_id']}' != cur.eventId;
    showModalBottomSheet<String>(
      context: context, useRootNavigator: true, useSafeArea: true, isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _RecapSheet(recap: rc, isArabic: isArabic, canBuild: canBuild),
    ).then((act) {
      if (!mounted || act == null) return;
      if (act == 'build') {
        this._v2Set(() { step = 2; _gStage = -1; _landedId = null; });
      } else if (act == 'rank') {
        _openRankingPage(context, isArabic, null);
      } else if (act.startsWith('squad:')) {
        final parts = act.split(':');
        final mode = parts[1];
        final rc = _recapByEvent[parts.length > 2 ? parts[2] : ''] ?? rc0;
        final m = ((rc['modes'] as List?) ?? const []).cast<Map>().firstWhere((x) => x['mode'] == mode, orElse: () => const {});
        final me = _sb.auth.currentUser?.id;
        if (me == null) return;
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => _UserSquadPage(
          userId: me, userName: t('You', 'إنت'), eventId: '${rc['event_id']}',
          roundName: isArabic ? '${rc['name_ar'] ?? rc['name_en']}' : '${rc['name_en']}',
          rank: (m['rank'] as num?)?.toInt(), points: m['points'], isArabic: isArabic, draft: mode == 'draft')));
      }
    });
  }
}

class _RecapSheet extends StatefulWidget {
  final Map<String, dynamic> recap;
  final bool isArabic, canBuild;
  const _RecapSheet({required this.recap, required this.isArabic, required this.canBuild});
  @override
  State<_RecapSheet> createState() => _RecapSheetState();
}

class _RecapSheetState extends State<_RecapSheet> {
  final _cardKey = GlobalKey();
  int _tab = 0, _i = 0, _dir = 1;
  bool _sharing = false, _loading = false;
  List<Map<String, dynamic>> _rounds = [];
  final Set<String> _confettiDone = {};
  static const _gold = Color(0xFFFFB300);

  String t(String en, String ar) => widget.isArabic ? ar : en;
  /// the recap on screen (page 0 = the last round)
  Map<String, dynamic> get _rc {
    if (_rounds.isEmpty) return widget.recap;
    return _recapByEvent['${_rounds[_i]['event_id']}'] ?? (_i == 0 ? widget.recap : const {});
  }
  List<Map<String, dynamic>> get _modes =>
      [for (final m in (_rc['modes'] as List?) ?? const []) Map<String, dynamic>.from(m as Map)];
  Map<String, dynamic> get _m => _modes.isEmpty ? const {} : _modes[_tab.clamp(0, _modes.length - 1).toInt()];
  String get _roundName => widget.isArabic ? '${_rc['name_ar'] ?? _rc['name_en'] ?? ''}' : '${_rc['name_en'] ?? ''}';
  String get _arena => widget.recap['type'] == 'LOCAL' ? t('Egypt', 'مصر') : t('World', 'عالمي');

  @override
  void initState() {
    super.initState();
    _recapByEvent['${widget.recap['event_id']}'] = widget.recap;
    _rounds = [{'event_id': widget.recap['event_id'], 'name_en': widget.recap['name_en'], 'name_ar': widget.recap['name_ar']}];
    _loadRounds();
    _maybeConfetti();
  }

  /// the list of finished rounds of this arena (names only, once per app run)
  Future<void> _loadRounds() async {
    final type = '${widget.recap['type']}';
    try {
      var list = _recapRoundsCache[type];
      if (list == null) {
        final r = await _sb.rpc('fantasy_recap_rounds', params: {'p_type': type});
        list = [for (final x in (r as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        _recapRoundsCache[type] = list;
      }
      if (!mounted || list.isEmpty) return;
      final cur = '${_rounds[_i]['event_id']}';
      setState(() {
        _rounds = list!;
        final k = _rounds.indexWhere((x) => '${x['event_id']}' == cur);
        _i = k < 0 ? 0 : k;
      });
    } catch (_) {}
  }

  /// top 10%: confetti once per round, after the numbers counted up
  void _maybeConfetti() {
    final id = '${_rc['event_id']}';
    if (_modes.any((m) => m['top10'] == true) && _confettiDone.add(id)) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && '${_rc['event_id']}' == id) { showStadiumConfetti(context); HapticFeedback.mediumImpact(); }
      });
    }
  }

  /// older = +1, newer = -1
  Future<void> _go(int step) async {
    final n = _i + step;
    if (n < 0 || n >= _rounds.length || _loading) return;
    final id = '${_rounds[n]['event_id']}';
    HapticFeedback.selectionClick();
    if (!_recapByEvent.containsKey(id)) {
      setState(() => _loading = true);
      try {
        final r = await _sb.rpc('fantasy_round_recap', params: {'p_type': widget.recap['type'], 'p_event': id});
        if (r is Map) _recapByEvent[id] = Map<String, dynamic>.from(r);
      } catch (_) {}
      if (!mounted) return;
      _loading = false;
      if (!_recapByEvent.containsKey(id)) { setState(() {}); return; }
    }
    setState(() { _dir = step; _i = n; _tab = 0; });
    _maybeConfetti();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ImageByteFormat.png);
      if (data == null) return;
      final m = _m;
      await Share.shareXFiles(
        [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'bdgr_round.png')],
        text: t('I got ${_fmtInt(m['points'] as num?)} pts in $_roundName on BDGR Fantasy ⚽ beat me: ${Brand.shareLinkBase}',
            'جبت ${_fmtInt(m['points'] as num?)} نقطة في $_roundName على BDGR فانتازي ⚽ تعالى اغلبني: ${Brand.shareLinkBase}'),
      );
    } catch (e) {
      debugPrint('recap share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// ‹ older · title · newer ›  (+ dots); the older round is on the reading-start side
  Widget _navHeader() {
    final older = _i < _rounds.length - 1, newer = _i > 0;
    Widget arrow(bool toOlder, bool on) {
      // start side = older: left in English, right in Arabic
      final icon = (toOlder != widget.isArabic) ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;
      return Pressable(child: GestureDetector(
        onTap: on ? () => _go(toOlder ? 1 : -1) : null,
        child: Container(width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFF1F2125) : Colors.transparent,
            border: Border.all(color: on ? const Color(0xFF3A3D42) : Colors.transparent)),
          child: Icon(icon, color: on ? Colors.white : Colors.white12, size: 26))));
    }
    return Column(children: [
      Row(children: [
        arrow(true, older),
        Expanded(child: Column(children: [
          Text(_i == 0 ? t('LAST ROUND', 'آخر جولة') : _roundName.toUpperCase(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(_i == 0 ? '$_roundName · $_arena' : _arena,
            style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ])),
        arrow(false, newer),
      ]),
      if (_rounds.length > 1) ...[
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_rounds.length <= 12)
            // dots: the last round sits on the reading-end side, older ones before it
            for (var k = _rounds.length - 1; k >= 0; k--)
              AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3),
                width: k == _i ? 16 : 6, height: 6,
                decoration: BoxDecoration(color: k == _i ? brandRed : Colors.white24, borderRadius: BorderRadius.circular(3)))
          else
            Text('${_rounds.length - _i} / ${_rounds.length}', style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        Text(t('Swipe or use the arrows for older rounds', 'اسحب أو دوس على الأسهم للجولات اللي قبل كده'),
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final played = m['played'] == true;
    final bl = _rc['bleague'] is Map ? Map<String, dynamic>.from(_rc['bleague'] as Map) : null;
    final id = '${_rc['event_id']}';
    final content = ListView(key: ValueKey('rc_${id}_$_tab'), padding: const EdgeInsets.fromLTRB(18, 4, 18, 12), children: [
      if (_modes.length > 1) ...[_modeTabs(), const SizedBox(height: 12)],
      if (!played) _missed(m) else ...[
        RepaintBoundary(key: _cardKey, child: _shareCard(m)),
        const SizedBox(height: 12),
        _statsRow(m),
        const SizedBox(height: 12),
        if (m['best'] is Map) _playerRow(Map<String, dynamic>.from(m['best'] as Map), best: true),
        if (m['worst'] is Map && (m['worst'] as Map)['id'] != (m['best'] as Map?)?['id'])
          Padding(padding: const EdgeInsets.only(top: 8), child: _playerRow(Map<String, dynamic>.from(m['worst'] as Map), best: false)),
        if (bl != null) ...[const SizedBox(height: 12), _blCard(bl)],
      ],
    ]);
    // older content comes in from the start side (left in English, right in Arabic)
    final fromStart = _dir > 0;
    final dx = (fromStart != widget.isArabic) ? -1.0 : 1.0;
    return FractionallySizedBox(heightFactor: 0.9, child: Column(children: [
      const SizedBox(height: 10),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 10), child: _navHeader()),
      Expanded(child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 250) return;
          final towardEnd = v > 0;   // finger moved left → right
          // pulling the content toward the reading end shows the older round
          _go((towardEnd != widget.isArabic) ? 1 : -1);
        },
        child: Stack(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, a) {
              final incoming = child.key == ValueKey('rc_${id}_$_tab');
              final begin = Offset(incoming ? dx * 0.35 : -dx * 0.35, 0);
              return FadeTransition(opacity: a, child: SlideTransition(
                position: Tween(begin: begin, end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: child));
            },
            child: content),
          if (_loading) const Positioned(top: 8, left: 0, right: 0,
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: muted)))),
        ]),
      )),
      _buttons(played),
    ]));
  }

  Widget _modeTabs() {
    Widget seg(int i, String label) => Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180), height: 34, alignment: Alignment.center,
        decoration: BoxDecoration(color: _tab == i ? brandRed : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        child: Text(label, style: TextStyle(color: _tab == i ? Colors.white : muted, fontSize: 12.5, fontWeight: FontWeight.w900)))));
    return Container(padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Row(children: [
        for (var i = 0; i < _modes.length; i++)
          seg(i, _modes[i]['mode'] == 'draft' ? t('🎯 Small team', '🎯 التشكيلة الصغيرة') : t('⚽ 11 players', '⚽ 11 لاعب')),
      ]));
  }

  /// the card people share: points + rank of N + badge
  Widget _shareCard(Map<String, dynamic> m) {
    final top10 = m['top10'] == true;
    final rank = (m['rank'] as num?)?.toInt();
    final prev = (m['prev_rank'] as num?)?.toInt();
    final up = (rank != null && prev != null) ? prev - rank : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: top10 ? const [Color(0xFF3A2A00), Color(0xFF141414)] : const [Color(0xFF2A0D0D), Color(0xFF141414)]),
        border: Border.all(color: top10 ? _gold.withOpacity(0.7) : brandRed.withOpacity(0.45), width: 1.2),
      ),
      child: Column(children: [
        Row(children: [
          Image.asset('assets/badger_white.png', width: 22, height: 22),
          const SizedBox(width: 6),
          const Text('BDGR FANTASY', style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('$_roundName · $_arena', style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        if (top10) PopIn(delayMs: 700, child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)),
          child: Text(t('🏅 TOP 10%', '🏅 من أحسن 10%'), style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.w900)))),
        CountUp((m['points'] as num?) ?? 0, ms: 1100,
          style: TextStyle(color: top10 ? _gold : Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1,
            fontFeatures: const [FontFeature.tabularFigures()]),
          format: (v) => _fmtInt(v)),
        Text(t('points', 'نقطة'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('#', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          // الترتيب بيتحرك من ترتيبك اللي فات للجديد (موشن المرحلة ١)
          CountBetween(from: prev ?? rank ?? 0, to: rank ?? 0, ms: 1400, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()]), format: (v) => _fmtInt(v)),
          Text(t('  of ${_fmtInt(m['total'] as num?)}', '  من ${_fmtInt(m['total'] as num?)}'),
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
          if (up != null && up != 0) ...[
            const SizedBox(width: 8),
            PopIn(delayMs: 1300, child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: up > 0 ? Brand.green : const Color(0xFFFF5C5C), size: 18),
              Text(_fmtInt(up.abs()), style: TextStyle(color: up > 0 ? Brand.green : const Color(0xFFFF5C5C),
                fontSize: 13, fontWeight: FontWeight.w900)),
            ])),
          ],
        ]),
      ]),
    );
  }

  Widget _statsRow(Map<String, dynamic> m) {
    Widget box(String label, String v) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Column(children: [
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ])));
    final avg = (m['avg'] as num?);
    return Row(children: [
      box(t('Average', 'المتوسط'), avg == null ? '—' : (avg == avg.roundToDouble() ? avg.toStringAsFixed(0) : avg.toStringAsFixed(1))),
      const SizedBox(width: 8),
      box(t('Top score', 'أعلى رقم'), _fmtInt(m['top'] as num?)),
      const SizedBox(width: 8),
      box(t('Players', 'لاعيبة'), _fmtInt(m['total'] as num?)),
    ]);
  }

  Widget _playerRow(Map<String, dynamic> p, {required bool best}) {
    final name = widget.isArabic ? '${p['name_ar'] ?? p['name_en']}' : '${p['name_en']}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Row(children: [
        Text(best ? '⭐' : '🥶', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(best ? t('Your best player', 'أحسن لاعب عندك') : t('Your weakest player', 'أضعف لاعب عندك'),
            style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        ])),
        Text('${_fmtInt(p['pts'] as num?)} ${t('pts', 'نقطة')}',
          style: TextStyle(color: best ? Brand.green : Colors.white70, fontSize: 14, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _blCard(Map<String, dynamic> bl) {
    final rank = (bl['rank'] as num?)?.toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.35))),
      child: Row(children: [
        Text('${bl['icon'] ?? '🦡'}', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Badger League · your team', 'دوري بادجر · فريقك'), style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
          Text('${bl['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          Text(rank == null
              ? t('Not in the table yet · invite a friend', 'لسه مش في الترتيب · اعزم صاحب')
              : t('#${_fmtInt(rank)} of ${_fmtInt(bl['teams'] as num?)} teams this month', '#${_fmtInt(rank)} من ${_fmtInt(bl['teams'] as num?)} فريق الشهر ده'),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ])),
        Text('+${_fmtInt(bl['round_points'] as num?)}', style: const TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _missed(Map<String, dynamic> m) => Container(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
    child: Column(children: [
      const Text('😴', style: TextStyle(fontSize: 38)),
      const SizedBox(height: 8),
      Text(t('You missed $_roundName', 'فاتتك $_roundName'),
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(t('The top player got ${_fmtInt(m['top'] as num?)} pts · ${_fmtInt(m['total'] as num?)} played',
             'الأول جاب ${_fmtInt(m['top'] as num?)} نقطة · لعب ${_fmtInt(m['total'] as num?)} لاعب'),
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ]),
  );

  Widget _buttons(bool played) {
    final m = _m;
    return SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 10), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        if (widget.canBuild)
          Pressable(child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop('build'),
            style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(t('BUILD NEXT ROUND\'S TEAM', 'ابني فريق الجولة الجاية'),
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 14.5))))),
        if (widget.canBuild) const SizedBox(height: 8),
        Row(children: [
          if (played) Expanded(child: _ghost(Icons.share_rounded, t('Share', 'شير'), _sharing ? null : _share)),
          if (played) const SizedBox(width: 8),
          if (played) Expanded(child: _ghost(Icons.groups_2_outlined, t('My squad', 'تشكيلتي'),
            () => Navigator.of(context).pop('squad:${m['mode']}:${_rc['event_id']}'))),
          if (played) const SizedBox(width: 8),
          Expanded(child: _ghost(Icons.leaderboard_outlined, t('Ranking', 'الترتيب'), () => Navigator.of(context).pop('rank'))),
        ]),
        if (!widget.canBuild) TextButton(onPressed: () => Navigator.of(context).pop(),
          child: Text(t('Close', 'تمام'), style: const TextStyle(color: muted, fontWeight: FontWeight.w700))),
      ])));
  }

  Widget _ghost(IconData ic, String label, VoidCallback? onTap) => Pressable(child: SizedBox(height: 44, child: OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFF1B1D21), foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF3A3D42)), padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: FittedBox(child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ic, size: 17), const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    ])))));
}
