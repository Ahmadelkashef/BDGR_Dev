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
    final name = isArabic ? '${rc['name_ar'] ?? rc['name_en']}' : '${rc['name_en']}';
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
              ? '$name · ${_fmtInt(m['points'] as num?)} ${t('pts', 'نقطة')} · #${_fmtInt(m['rank'] as num?)}'
              : t('You missed $name', 'فاتتك $name'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
          Text(t('Recap', 'الملخص'), style: const TextStyle(color: Brand.green, fontSize: 12, fontWeight: FontWeight.w800)),
          Text(isArabic ? ' ‹' : ' ›', style: const TextStyle(color: Brand.green, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  void _openRecap() {
    final rc = _recap;
    if (rc == null) return;
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
        final mode = act.substring(6);
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
  int _tab = 0;
  bool _sharing = false, _confetti = false;
  static const _gold = Color(0xFFFFB300);

  String t(String en, String ar) => widget.isArabic ? ar : en;
  List<Map<String, dynamic>> get _modes =>
      [for (final m in (widget.recap['modes'] as List?) ?? const []) Map<String, dynamic>.from(m as Map)];
  Map<String, dynamic> get _m => _modes.isEmpty ? const {} : _modes[_tab.clamp(0, _modes.length - 1).toInt()];
  String get _roundName => widget.isArabic ? '${widget.recap['name_ar'] ?? widget.recap['name_en']}' : '${widget.recap['name_en']}';
  String get _arena => widget.recap['type'] == 'LOCAL' ? t('Egypt', 'مصر') : t('World', 'عالمي');

  @override
  void initState() {
    super.initState();
    // top 10%: confetti once, after the numbers counted up
    if (_modes.any((m) => m['top10'] == true)) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_confetti) { _confetti = true; showStadiumConfetti(context); HapticFeedback.mediumImpact(); }
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final played = m['played'] == true;
    final bl = widget.recap['bleague'] is Map ? Map<String, dynamic>.from(widget.recap['bleague'] as Map) : null;
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.9, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (ctx, sc) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Expanded(child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(18, 14, 18, 12), children: [
          Row(children: [
            Expanded(child: Text(t('ROUND RECAP', 'ملخص الجولة'),
              style: const TextStyle(color: muted, fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w800))),
            Text('$_roundName · $_arena', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          if (_modes.length > 1) ...[const SizedBox(height: 10), _modeTabs()],
          const SizedBox(height: 12),
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
        ])),
        _buttons(played),
      ]),
    );
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
          CountUp(rank ?? 0, ms: 1100, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()]), format: (v) => _fmtInt(v)),
          Text(t('  of ${_fmtInt(m['total'] as num?)}', '  من ${_fmtInt(m['total'] as num?)}'),
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
          if (up != null && up != 0) ...[
            const SizedBox(width: 8),
            Icon(up > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: up > 0 ? Brand.green : const Color(0xFFFF5C5C), size: 18),
            Text(_fmtInt(up.abs()), style: TextStyle(color: up > 0 ? Brand.green : const Color(0xFFFF5C5C),
              fontSize: 13, fontWeight: FontWeight.w900)),
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
            () => Navigator.of(context).pop('squad:${m['mode']}'))),
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
