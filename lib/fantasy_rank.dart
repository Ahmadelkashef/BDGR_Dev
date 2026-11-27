part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// صفحة الترتيب: محلي/عالمي × الأسبوع/الشهر/الموسم × الكل/محافظتي/منطقتي/ليج
// كل الحسابات في السيرفر (fantasy_leaderboard)
// ═══════════════════════════════════════════════════════════════════════════

const Color _gold   = Color(0xFFFFB300);
const Color _silver = Color(0xFFB8BCC6);
const Color _bronze = Color(0xFFCD7F32);

class FantasyRankTab extends StatefulWidget {
  final bool isArabic;
  final String? leagueId;      // لو جوه صفحة ليج: الترتيب بين أعضاءها بس
  final VoidCallback? onToggleLanguage;
  const FantasyRankTab({super.key, required this.isArabic, this.leagueId, this.onToggleLanguage});
  @override
  State<FantasyRankTab> createState() => _FantasyRankTabState();
}

class _FantasyRankTabState extends State<FantasyRankTab> {
  String _type = 'LOCAL';            // LOCAL | WORLD
  String _period = 'round';          // round | month | season
  String? _key;                      // رقم الجولة / 2026-10 / 2026-27
  String _scope = 'all';             // all | governorate | city | league
  // modes from the DB (fantasy_modes): draft → draft ranking · normal → normal · both → a menu
  String _mode = _FancyPageState._modes == 'normal' ? 'normal' : 'draft';
  String? _leagueId;
  bool _showRest = false;   // places 4+ hidden until "Show 4 – 10"
  /// the server answers with its own mode: a round with no draft (e.g. Round 1) comes back as the normal ranking
  bool get _boardDraft => ((_board?['mode'] as String?) ?? _mode) == 'draft';

  Map<String, dynamic>? _periods;
  Map<String, dynamic>? _board;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _leagues = [];
  bool _loading = true, _loadingMore = false;
  String? _error;
  int _token = 0;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    if (widget.leagueId != null) { _scope = 'league'; _leagueId = widget.leagueId; }
    _loadLeagues();
    _loadPeriods();
  }

  Future<void> _loadLeagues() async {
    try {
      final r = await _sb.rpc('league_my_list');
      if (!mounted) return;
      setState(() => _leagues = ((r as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  Future<void> _loadPeriods() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('fantasy_periods', params: {'p_type': _type}) as Map);
      if (!mounted) return;
      _periods = r;
      _key = _defaultKey();
      await _loadBoard();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _roundList =>
      ((_periods?['rounds'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get _monthList =>
      ((_periods?['months'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  String? _defaultKey() {
    switch (_period) {
      case 'round':
        final d = _periods?['default_round'];
        if (d != null) return '$d';
        return _roundList.isNotEmpty ? '${_roundList.first['key']}' : null;
      case 'month':
        // أول شهر فيه جولة خلصت
        final m = _monthList.firstWhere((x) => (x['finished'] as num? ?? 0) > 0, orElse: () => _monthList.isNotEmpty ? _monthList.first : {});
        return m['key']?.toString();
      default:
        return (_periods?['season'] as Map?)?['key']?.toString();
    }
  }

  Future<void> _loadBoard({bool more = false}) async {
    if (_key == null) { setState(() { _loading = false; _board = null; _rows = []; }); return; }
    final tok = ++_token;
    setState(() { if (more) { _loadingMore = true; } else { _loading = true; _error = null; _showRest = false; } });
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc(_mode == 'draft' ? 'fantasy_leaderboard_draft' : 'fantasy_leaderboard', params: {
        'p_type': _type, 'p_period': _period, 'p_key': _key, 'p_scope': _scope,
        'p_league_id': _scope == 'league' ? _leagueId : null,
        'p_limit': 10, 'p_offset': more ? _rows.length : 0,
      }) as Map);
      if (!mounted || tok != _token) return;
      final rows = ((r['rows'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _board = r;
        _rows = more ? [..._rows, ...rows] : rows;
        _loading = false; _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || tok != _token) return;
      setState(() { _loading = false; _loadingMore = false; _error = e.toString(); });
    }
  }

  // ─── labels ────────────────────────────────────────────────────────────
  static const _monthsAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  static const _monthsEn = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  String _monthLabel(String key) {
    final p = key.split('-');
    if (p.length != 2) return key;
    final m = int.tryParse(p[1]) ?? 1;
    return widget.isArabic ? _monthsAr[m - 1] : _monthsEn[m - 1];
  }

  String get _periodTitle {
    final b = _board;
    if (b == null) return '';
    switch (_period) {
      case 'round':  return widget.isArabic ? '${b['label_ar']}' : '${b['label_en']}';
      case 'month':  return t('${_monthLabel(_key ?? '')} month', 'شهر ${_monthLabel(_key ?? '')}');
      default:       return widget.isArabic ? '${b['label_ar']}' : '${b['label_en']}';
    }
  }

  String get _badgerTitle => switch (_period) {
    'round' => t('BDGR of the week', 'بادجر الأسبوع'),
    'month' => t('BDGR of the month', 'بادجر الشهر'),
    _       => t('BDGR of the season', 'بادجر الموسم'),
  };

  Map<String, dynamic>? get _selectedRound =>
      _roundList.cast<Map<String, dynamic>?>().firstWhere((r) => r?['key']?.toString() == _key, orElse: () => null);

  // ─── build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _viewH = c.maxHeight;
      return BadgerRefresh(
      onRefresh: () => _loadBoard(),
      child: CustomScrollView(slivers: [
        // الفلاتر ثابتة فوق: مصر/عالمي · أسبوع/شهر/موسم · أنهي جولة · مين
        // الفلاتر: سطر واحد صغير — مصر/عالمي · الفترة ▾ · مين ▾
        SliverPersistentHeader(pinned: true, delegate: _FixedHeader(height: 50, child: Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(children: [
            Expanded(child: _periodButton()),
            if (widget.leagueId == null) ...[
              if (_FancyPageState._modes == 'both') _FilterMenu(value: _mode,
                items: [('draft', t('🎯 Small team', '🎯 التشكيلة الصغيرة')), ('normal', t('⚽ 11 players', '⚽ 11 لاعب'))],
                onChanged: (v) {
                  if (v == _mode) return;
                  setState(() => _mode = v);   // leagues rank on both
                  _loadBoard();
                }),
              const SizedBox(width: 8), _scopeButton()],
          ]),
        ))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 6), child: _typeSwitcher())),
        // راعي الترتيب: "الترتيب برعاية X"
        const SliverToBoxAdapter(child: AdSlot('fantasy_leaderboard', center: true, padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            prefixEn: 'Leaderboard by', prefixAr: 'الترتيب برعاية')),
        if (_loading)
          const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: brandRed)))
        else if (_error != null)
          SliverFillRemaining(hasScrollBody: false, child: _message('⚠️', t('Could not load the ranking.', 'مش قادرين نحمّل الترتيب.'), _error))
        else if (_key == null)
          SliverFillRemaining(hasScrollBody: false, child: _message('🗓️', t('No rounds yet.', 'مفيش جولات لسه.'), null))
        else ..._content(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
    });
  }

  double _viewH = 0;
  /// البوديوم بياخد اللي فاضل بعد الفلاتر + ترتيبي + زرار "اعرض من 4"، علشان التلاتة يبانوا من غير سكرول
  double get _heroH {
    final v = _viewH > 0 ? _viewH : MediaQuery.of(context).size.height * 0.75;
    return (v - 250).clamp(280.0, 470.0);
  }

  List<Widget> _content() {
    final b = _board ?? {};
    final state = b['state']?.toString();
    final total = (b['total'] as num?)?.toInt() ?? 0;

    // الجولة لسه شغالة: النتايج يوم الخميس
    if (_period == 'round' && state != 'finished') {
      final res = DateTime.tryParse('${_selectedRound?['results_at'] ?? ''}')?.toLocal();
      return [SliverFillRemaining(hasScrollBody: false, child: _message('🔴',
        t('This round is still running', 'الجولة دي لسه شغالة'),
        res == null ? null : t('Results on ${_dayName(res)} at ${_hour(res)}', 'النتايج ${_dayName(res)} الساعة ${_hour(res)}')))];
    }
    // فلتر محافظة/منطقة واليوزر معندوش موقع متأكد منه: نشرحله الفايدة ونطلب الموقع
    if ((_scope == 'governorate' || _scope == 'city') && b['scope_value'] == null) {
      return [SliverFillRemaining(hasScrollBody: false, child: Center(child: SingleChildScrollView(
        child: LocationNeededCard(isArabic: widget.isArabic, onDone: () => _loadBoard()))))];
    }
    if (total == 0) {
      return [SliverFillRemaining(hasScrollBody: false, child: _message('🫥',
        _scope == 'all' ? t('No results yet.', 'مفيش نتايج لسه.') : t('Nobody here yet.', 'مفيش حد هنا لسه.'),
        _scope == 'governorate' || _scope == 'city' ? t('Add your governorate and city in your profile.', 'ضيف محافظتك ومنطقتك في البروفايل.') : null))];
    }
    final top = _rows.take(3).toList();
    final rest = _rows.skip(3).toList();
    return [
      // calm podium: three tall bars (3 · 2 · 1, the winner on the right), then my card, then the list
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 250) _switchType();
        },
        child: _podium(top)))),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: _myStrip())),
      if (state == 'running')
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text(t('Still running — points are added after each round finishes.', 'لسه شغال — النقط بتتضاف بعد ما كل جولة تخلص.'),
            style: const TextStyle(color: muted, fontSize: 12)))),
      // places 4+ stay hidden until asked: "Show 4 – 10", then 10 more each time
      if (!_showRest && rest.isNotEmpty) _moreButton(t('Show 4 – ${rest.length + 3}', 'اعرض من 4 لـ ${rest.length + 3}'),
        () => setState(() => _showRest = true)),
      if (_showRest && rest.isNotEmpty) SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.separated(
          itemCount: rest.length,
          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFF1E2024)),
          itemBuilder: (_, i) => _row(rest[i]),
        ),
      ),
      if (_showRest && _rows.length < total)
        _moreButton(t('Show ${_rows.length + 1} – ${(_rows.length + 10).clamp(0, total)}', 'اعرض من ${_rows.length + 1} لـ ${(_rows.length + 10).clamp(0, total)}'),
          _loadingMore ? null : () => _loadBoard(more: true), busy: _loadingMore),
    ];
  }

  Widget _moreButton(String label, VoidCallback? onTap, {bool busy = false}) => SliverToBoxAdapter(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Center(child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFF2A2D32)))),
      child: busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: muted))
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    ))));

  // ─── controls ──────────────────────────────────────────────────────────
  String get _scopeLabel {
    switch (_scope) {
      case 'governorate': return t('📍 Governorate', '📍 محافظتي');
      case 'city': return t('🏘️ Area', '🏘️ منطقتي');
      case 'league':
        final l = _leagues.cast<Map<String, dynamic>?>().firstWhere((x) => x?['league_id'] == _leagueId, orElse: () => null);
        return l == null ? t('🏟️ League', '🏟️ ليج') : '${l['icon']} ${l['name']}';
      default: return t('🌐 Everyone', '🌐 الكل');
    }
  }

  Widget _scopeButton() => GestureDetector(
    onTap: _pickScope,
    child: Container(
      height: 34, constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _scope == 'all' ? cardBg : Brand.green.withOpacity(0.12), borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _scope == 'all' ? line : Brand.green)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(_scopeLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _scope == 'all' ? Colors.white : Brand.green, fontSize: 12, fontWeight: FontWeight.w800))),
        const SizedBox(width: 2),
        Icon(Icons.expand_more_rounded, size: 18, color: _scope == 'all' ? Colors.white70 : Brand.green),
      ]),
    ),
  );

  Future<void> _pickScope() async {
    final r = await showModalBottomSheet<(String, String?)>(
      context: context, backgroundColor: cardBg, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget tile(String icon, String title, String? sub, (String, String?) v) {
          final on = v.$1 == _scope && (v.$1 != 'league' || v.$2 == _leagueId);
          return ListTile(
            onTap: () => Navigator.pop(ctx, v),
            leading: Text(icon, style: const TextStyle(fontSize: 22)),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            subtitle: sub == null ? null : Text(sub, style: const TextStyle(color: muted)),
            trailing: on ? const Icon(Icons.check_circle, color: Brand.green) : null,
          );
        }
        return SafeArea(child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 14, 8, 12), children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(t('Show ranking for', 'الترتيب بين'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
            tile('🌐', t('Everyone', 'الكل'), null, ('all', null)),
            tile('📍', t('My governorate', 'محافظتي'), null, ('governorate', null)),
            tile('🏘️', t('My area', 'منطقتي'), null, ('city', null)),
            if (_leagues.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(t('MY LEAGUES', 'ليجزي'), style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1))),
            for (final l in _leagues)
              tile('${l['icon']}', '${l['name']}', t('${l['members']} members', '${l['members']} عضو'), ('league', l['league_id'] as String)),
          ]),
        ));
      },
    );
    if (r == null || !mounted) return;
    setState(() { _scope = r.$1; _leagueId = r.$2; });
    _loadBoard();
  }

  void _switchType() {
    setState(() => _type = _type == 'LOCAL' ? 'WORLD' : 'LOCAL');
    _loadPeriods();
  }

  /// ‹  فانتازي مصر · الدوري المصري  ›  — اسحب أو دوس السهم
  Widget _typeSwitcher() {
    final local = _type == 'LOCAL';
    Widget arrow(IconData i) => GestureDetector(
      onTap: _switchType,
      child: Container(width: 36, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
        child: Icon(i, color: Colors.white70, size: 22)),
    );
    return GestureDetector(
      onHorizontalDragEnd: (d) { if ((d.primaryVelocity ?? 0).abs() > 250) _switchType(); },
      child: Row(children: [
        arrow(Icons.chevron_left_rounded),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(key: ValueKey(_type), mainAxisSize: MainAxisSize.min, children: [
            Text(local ? t('EGYPT FANTASY', 'فانتازي مصر') : t('WORLD FANTASY', 'فانتازي العالم'),
              style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final k in ['LOCAL', 'WORLD']) Container(
                width: _type == k ? 18 : 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: _type == k ? Brand.green : Colors.white24, borderRadius: BorderRadius.circular(3))),
            ]),
          ]),
        )),
        arrow(Icons.chevron_right_rounded),
      ]),
    );
  }

  String get _keyLabel {
    switch (_period) {
      case 'round':  return t('Round $_key', 'الجولة $_key');
      case 'month':  return t('${_monthLabel(_key ?? '')}', 'شهر ${_monthLabel(_key ?? '')}');
      default:       return t('Season', 'الموسم');
    }
  }

  Widget _periodButton() => GestureDetector(
    onTap: _pickPeriod,
    child: Container(
      height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(11), border: Border.all(color: line)),
      child: Row(children: [
        const Icon(Icons.calendar_month_rounded, color: Colors.white60, size: 17),
        const SizedBox(width: 6),
        Expanded(child: Text(_keyLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
        const Icon(Icons.expand_more_rounded, color: Colors.white60, size: 18),
      ]),
    ),
  );

  Future<void> _pickPeriod() async {
    final r = await showModalBottomSheet<(String, String)>(
      context: context, backgroundColor: cardBg, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget head(String s) => Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(s, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)));
        Widget chip(String period, String key, String label, {String? tag}) {
          final on = period == _period && key == _key;
          return GestureDetector(
            onTap: () => Navigator.pop(ctx, (period, key)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: on ? Colors.white : bg, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: on ? Colors.white : line)),
              child: Text(tag == null ? label : '$label $tag',
                style: TextStyle(color: on ? Colors.black : Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          );
        }
        final season = _periods?['season'] as Map?;
        return SafeArea(child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
            head(t('WEEK', 'الأسبوع')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in _roundList) chip('round', '${r['key']}', t('Round ${r['key']}', 'الجولة ${r['key']}'),
                tag: r['state'] == 'finished' ? null : (r['state'] == 'live' ? '🔴' : '🟢')),
            ])),
            if (_monthList.isNotEmpty) ...[
              head(t('MONTH', 'الشهر')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in _monthList) chip('month', '${m['key']}', _monthLabel('${m['key']}')),
              ])),
            ],
            if (season != null) ...[
              head(t('SEASON', 'الموسم')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(children: [chip('season', '${season['key']}', widget.isArabic ? '${season['label_ar']}' : '${season['label_en']}')])),
            ],
          ]),
        ));
      },
    );
    if (r == null || !mounted) return;
    setState(() { _period = r.$1; _key = r.$2; });
    _loadBoard();
  }

  // ─── podium ────────────────────────────────────────────────────────────
  static const _bar = Color(0xFF1C1E22);       // bar fill
  static const _barLine = Color(0xFF2A2D32);   // bar edge
  static const _crown = Color(0xFFE8C46A);     // only the winner's picture frame

  Widget _podium(List<Map<String, dynamic>> top) {
    final prizes = ((_board?['prizes'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    String? prizeFor(int rank) {
      final p = prizes.cast<Map<String, dynamic>?>().firstWhere((x) => (x?['rank'] as num?)?.toInt() == rank, orElse: () => null);
      if (p == null || _scope != 'all') return null;
      return withPrizeIcon(prizeIconOf(p), widget.isArabic ? '${p['prize_ar']}' : '${p['prize_en']}');
    }
    Map<String, dynamic>? at(int i) => top.length > i ? top[i] : null;
    return Column(children: [
      Text(_badgerTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(_periodTitle, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 18),
      // 1 · 2 · 3 in reading order: English 1 on the left, Arabic 1 on the right
      SizedBox(height: 350, child: Row(
        crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _podiumSpot(at(0), 1, 236, prizeFor(1))),
          const SizedBox(width: 10),
          Expanded(child: _podiumSpot(at(1), 2, 192, prizeFor(2))),
          const SizedBox(width: 10),
          Expanded(child: _podiumSpot(at(2), 3, 150, prizeFor(3))),
        ])),
    ]);
  }

  Widget _podiumSpot(Map<String, dynamic>? r, int place, double barH, String? prize) {
    if (r == null) return const SizedBox.shrink();
    final me = r['is_me'] == true;
    final first = place == 1;
    return GestureDetector(
      onTap: () => _openUser(r),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _avatarSq(r, first ? 58 : 50, frame: first ? _crown : null),
        const SizedBox(height: 8),
        Text(me ? t('You', 'إنت') : '${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(color: me ? Brand.green : Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        Text(t('${r['points']} pts', '${r['points']} نقطة'),
          style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          height: barH, width: 78,   // slim, tall bars (owner)
          decoration: BoxDecoration(
            color: first ? brandRed.withOpacity(0.16) : _bar,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: first ? brandRed.withOpacity(0.45) : _barLine)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$place', style: TextStyle(color: Colors.white, fontSize: first ? 34 : 28, fontWeight: FontWeight.w300, height: 1)),
            if (prize != null) ...[
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FittedBox(
                child: Text(prize, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)))),
            ],
          ]),
        ),
      ]),
    );
  }

  /// rounded-square picture (initial when there is none)
  Widget _avatarSq(Map<String, dynamic>? r, double size, {Color? frame}) {
    final url = r?['avatar']?.toString();
    final name = '${r?['name'] ?? '?'}'.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Center(child: Text(initial, style: TextStyle(color: Colors.white, fontSize: size * 0.38, fontWeight: FontWeight.w800)));
    return Container(
      width: size, height: size, padding: EdgeInsets.all(frame == null ? 0 : 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * 0.3),
        border: frame == null ? null : Border.all(color: frame, width: 1.6)),
      child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.26), child: Container(color: surface2,
        child: url != null && url.isNotEmpty ? _netImage(url, fit: BoxFit.cover, fallback: fallback) : fallback)),
    );
  }

  bool _recapBusy = false;
  /// "You" card → the recap of the round on screen (dynamic: normal / draft of any size / both)
  Future<void> _openMyRoundRecap() async {
    final ev = _selectedRound?['event_id']?.toString();
    if (ev == null || _recapBusy) return;
    _recapBusy = true;
    try {
      var rc = _recapByEvent[ev];
      if (rc == null) {
        final r = await _sb.rpc('fantasy_round_recap', params: {'p_type': _type, 'p_event': ev});
        if (r is Map && r['none'] != true) { rc = Map<String, dynamic>.from(r); _recapByEvent[ev] = rc; }
      }
      if (rc == null || !mounted) return;
      final act = await showModalBottomSheet<String>(
        context: context, useRootNavigator: true, useSafeArea: true, isScrollControlled: true, backgroundColor: bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (_) => _RecapSheet(recap: rc!, isArabic: widget.isArabic, canBuild: false));
      if (!mounted || act == null || !act.startsWith('squad:')) return;
      final parts = act.split(':');
      final mode = parts[1];
      final eid = parts.length > 2 ? parts[2] : ev;
      final r2 = _recapByEvent[eid] ?? rc;
      final m = ((r2['modes'] as List?) ?? const []).cast<Map>().firstWhere((x) => x['mode'] == mode, orElse: () => const {});
      final me = _sb.auth.currentUser?.id;
      if (me == null) return;
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => _UserSquadPage(
        userId: me, userName: t('You', 'إنت'), eventId: eid,
        roundName: widget.isArabic ? '${r2['name_ar'] ?? r2['name_en']}' : '${r2['name_en']}',
        rank: (m['rank'] as num?)?.toInt(), points: m['points'], isArabic: widget.isArabic, draft: mode == 'draft')));
    } catch (_) {
    } finally {
      _recapBusy = false;
    }
  }

  // my card: red, picture · points · rank · of
  Widget _myStrip() {
    final me = _board?['me'] as Map?;
    final total = (_board?['total'] as num?)?.toInt() ?? 0;
    Widget stat(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      // الأرقام بتتعد (موشن المرحلة ١): "#123" → يتعد الرقم ويفضل الـ #
      Builder(builder: (_) {
        const st = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800);
        final hash = value.startsWith('#');
        final n = int.tryParse(hash ? value.substring(1) : value);
        if (n == null) return Text(value, maxLines: 1, style: st);
        return CountUp(n, ms: 900, style: st, format: (v) => hash ? '#$v' : '$v');
      }),
    ]));
    return GestureDetector(
      // a round: that round's recap with the squad(s) it was played with (draft / normal / both); month & season: no tap
      onTap: _period == 'round' && _board?['me'] != null ? _openMyRoundRecap : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFD81818), Color(0xFFA30F0F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20)),
        child: me == null
          ? Text(t("You didn't play this one — next round opens soon", 'ما لعبتش في دي — الجولة الجاية قريب'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))
          : Row(children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                _avatarSq(Map<String, dynamic>.from(me), 42),
                const SizedBox(height: 4),
                Text(t('You', 'إنت'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(width: 16),
              stat(t('Points', 'النقط'), '${me['points']}'),
              stat(t('Rank', 'الترتيب'), '#${me['rank']}'),
              stat(t('Players', 'من'), '$total'),
              _move(me['move']?.toString(), big: true),
            ]),
      ));
  }

  Widget _avatar(Map<String, dynamic> r, double size, {Color? ring}) => _avatarSq(r, size, frame: ring);

  // ─── rows: rank · name + points · movement ─────────────────────────────
  Widget _row(Map<String, dynamic> r) {
    final me = r['is_me'] == true;
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: () => _openUser(r),
      child: Container(
        color: me ? Brand.green.withOpacity(0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Row(children: [
          SizedBox(width: 46, child: Text(rank < 10 ? '0$rank' : '$rank', maxLines: 1,
            style: const TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.w300,
              fontFeatures: [FontFeature.tabularFigures()]))),
          _avatarSq(r, 38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me ? t('You', 'إنت') : '${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: me ? Brand.green : Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Text(_period == 'round' ? t('${r['points']} pts', '${r['points']} نقطة')
                  : t('${r['points']} pts · ${r['rounds']} rds', '${r['points']} نقطة · ${r['rounds']} جولة'),
                style: const TextStyle(color: muted, fontSize: 12)),
              if (r['tied'] == true) GestureDetector(
                onTap: () => showTieBreakSheet(context, widget.isArabic, period: _period, draft: _boardDraft, tb: r['tb'] as Map?, name: me ? t('You', 'إنت') : '${r['name']}'),
                child: const Padding(padding: EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.info_outline, color: Colors.white38, size: 14))),
            ]),
          ])),
          _move(r['move']?.toString(), big: true),
        ]),
      ),
    );
  }

  void _openUser(Map<String, dynamic> r) {
    final ev = _selectedRound?['event_id']?.toString();
    if (_period == 'round' && ev != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _UserSquadPage(
        userId: '${r['user_id']}', userName: '${r['name']}', eventId: ev, roundName: _periodTitle,
        username: r['username']?.toString(), avatarUrl: r['avatar']?.toString(),
        rank: (r['rank'] as num?)?.toInt(), points: r['points'], isArabic: widget.isArabic, draft: _boardDraft)));
    } else {
      _openVisitorProfile(context, userId: '${r['user_id']}', username: '${r['username'] ?? ''}',
          displayName: '${r['name']}', avatarUrl: r['avatar']?.toString());
    }
  }

  // ⬆️⬇️ طلع / نزل / زي ما هو / جديد (ولا حاجة في أول أسبوع)
  Widget _move(String? m, {bool big = false}) {
    final s = big ? 16.0 : 12.0;
    switch (m) {
      case 'up':   return Icon(Icons.arrow_drop_up_rounded, color: Brand.green, size: s + 10);
      case 'down': return Icon(Icons.arrow_drop_down_rounded, color: const Color(0xFFFF5C5C), size: s + 10);
      case 'same': return Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                     child: Container(width: s, height: 2.5, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2))));
      case 'new':  return Container(
                     margin: const EdgeInsets.only(top: 2),
                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                     decoration: BoxDecoration(color: const Color(0xFF5AA9FF).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                     child: Text(t('NEW', 'جديد'), style: TextStyle(color: const Color(0xFF5AA9FF), fontSize: big ? 11 : 8.5, fontWeight: FontWeight.w900)));
      default:     return const SizedBox.shrink();
    }
  }

  // المنصة لما تصغر وهي ثابتة فوق
  Widget _podiumCompact(List<Map<String, dynamic>> top) => Container(
    color: bg,
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF1C170B), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withOpacity(0.35))),
      child: Row(children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: Row(children: [
            Text(['🥇','🥈','🥉'][i], style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            _avatar(top[i], 26, ring: [_gold, _silver, _bronze][i]),
            const SizedBox(width: 6),
            Expanded(child: Text(top[i]['is_me'] == true ? t('You', 'إنت') : '${top[i]['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          ])),
        ],
      ]),
    ),
  );

  // ─── helpers ───────────────────────────────────────────────────────────
  Widget _message(String emoji, String title, String? sub) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      if (sub != null) ...[
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13, height: 1.4)),
      ],
    ]),
  );

  String _dayName(DateTime d) {
    const ar = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const en = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return widget.isArabic ? ar[d.weekday - 1] : en[d.weekday - 1];
  }
  String _hour(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? t('PM', 'م') : t('AM', 'ص');
    return '$h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}


// المنصة: كبيرة فوق، وبتصغر لصف واحد وتفضل ظاهرة وإنت بتعمل سكرول في الباقي
class _PodiumHeader extends SliverPersistentHeaderDelegate {
  final Widget full, compact;
  final double maxH;
  _PodiumHeader({required this.full, required this.compact, this.maxH = 300});
  @override double get maxExtent => maxH;
  @override double get minExtent => 62;
  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    final p = (shrink / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return Container(color: bg, child: Stack(fit: StackFit.expand, children: [
      Opacity(opacity: 1 - p, child: ClipRect(child: OverflowBox(alignment: Alignment.topCenter, minHeight: 0, maxHeight: maxExtent, child: full))),
      if (p > 0.55) Opacity(opacity: ((p - 0.55) / 0.45).clamp(0.0, 1.0), child: Align(alignment: Alignment.bottomCenter, child: compact)),
    ]));
  }
  @override bool shouldRebuild(_PodiumHeader o) => o.full != full || o.compact != compact;
}

// ═══ قواعد كسر التعادل (بتظهر في الترتيب، وبعد حفظ التشكيلة، وفي الإرشادات) ═══
class FantasyTieRules extends StatelessWidget {
  final bool isArabic;
  final String period;        // round | month | season
  final Map? tb;              // قيم الشخص (لو فاتحها من صف في الترتيب)
  final String? name;
  final bool draft;           // draft squad: score predictions break the tie
  const FantasyTieRules({super.key, required this.isArabic, this.period = 'round', this.tb, this.name, this.draft = false});

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final week = draft ? [
      ('🎯', t('More exact scores', 'نتايج مظبوطة أكتر'), t('Your score predictions that were exactly right.', 'توقعاتك اللي جت النتيجة بالظبط.'),
        tb == null || tb!['exact'] == null ? null : '${tb!['exact']}'),
      ('✅', t('More right results', 'فايز / تعادل صح أكتر'), t('You got the winner (or the draw) right, even if the score was not exact.', 'جبت الفايز أو التعادل صح، حتى لو النتيجة مش بالظبط.'),
        tb == null || tb!['outcome'] == null ? null : '${tb!['outcome']}'),
      ('⏱️', t('Saved earlier', 'حفظ التشكيلة بدري'), t('Your final squad was saved earlier (to the second).', 'آخر حفظ لتشكيلتك كان أبدر (بالثانية).'),
        tb == null || tb!['saved_at'] == null ? null : _fmtTime(DateTime.tryParse('${tb!['saved_at']}')?.toLocal())),
    ] : [
      ('💰', t('More money left', 'فلوس متبقية أكتر'), t('Same points with a cheaper squad = smarter team.', 'نفس النقط بفلوس أقل = فريق أذكى.'),
        tb == null || tb!['remaining'] == null ? null : '${tb!['remaining']}M'),
      ('©️', t('Higher captain points', 'نقط الكابتن أعلى'), t('Your captain scored more.', 'الكابتن بتاعك جاب نقط أكتر.'),
        tb == null || tb!['captain_points'] == null ? null : t('${tb!['captain_points']} pts', '${tb!['captain_points']} نقطة')),
      ('⏱️', t('Saved earlier', 'حفظ التشكيلة بدري'), t('Your final squad was saved earlier (to the second).', 'آخر حفظ لتشكيلتك كان أبدر (بالثانية).'),
        tb == null || tb!['saved_at'] == null ? null : _fmtTime(DateTime.tryParse('${tb!['saved_at']}')?.toLocal())),
    ];
    final cumulative = [
      ('🔥', t('Best single week', 'أعلى أسبوع لوحده'), t('Your best week in the period.', 'أحسن أسبوع ليك في الفترة.'),
        tb == null || tb!['best_week'] == null ? null : t('${tb!['best_week']} pts', '${tb!['best_week']} نقطة')),
      ('🔟', t('More top-10 finishes', 'مرات أكتر في التوب 10'), t('How many weeks you finished in the top 10.', 'كام أسبوع طلعت فيه في التوب 10.'),
        tb == null || tb!['top10'] == null ? null : '${tb!['top10']}'),
      ('📈', t('Higher participation', 'نسبة مشاركة أعلى'), t('Weeks you played ÷ weeks available since you joined Fantasy.', 'الأسابيع اللي لعبتها ÷ الأسابيع اللي كانت متاحة لك من ساعة ما دخلت الفانتازي.'),
        tb == null || tb!['rate'] == null ? null : '${tb!['rate']}%'),
      ('🗓️', t('Joined Fantasy earlier', 'دخل الفانتازي بدري'), t('Your first ever saved squad (to the second).', 'أول تشكيلة حفظتها في الفانتازي (بالثانية).'),
        tb == null || tb!['signup'] == null ? null : _fmtDate(DateTime.tryParse('${tb!['signup']}')?.toLocal())),
    ];
    Widget block(String title, List<(String, String, String, String?)> rules, bool highlight) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlight ? Brand.green.withOpacity(0.5) : line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(t('Same points? We compare in this order:', 'نفس النقط؟ بنقارن بالترتيب ده:'), style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 8),
        for (var i = 0; i < rules.length; i++)
          Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 22, height: 22, alignment: Alignment.center,
              decoration: BoxDecoration(color: Brand.green.withOpacity(0.15), shape: BoxShape.circle),
              child: Text('${i + 1}', style: const TextStyle(color: Brand.green, fontSize: 12, fontWeight: FontWeight.w900))),
            const SizedBox(width: 8),
            Text(rules[i].$1, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rules[i].$2, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
              Text(rules[i].$3, style: const TextStyle(color: muted, fontSize: 12, height: 1.35)),
            ])),
            if (rules[i].$4 != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _gold.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
              child: Text(rules[i].$4!, style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w900))),
          ])),
      ]),
    );
    final isWeek = period == 'round';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (name != null) Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Text(t('$name is tied on points — here are the numbers that decided the order.', '$name متعادل في النقط — دي الأرقام اللي حسمت الترتيب.'),
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
      if (tb == null || isWeek) block(t('⚖️ Weekly ranking', '⚖️ ترتيب الأسبوع'), week, isWeek),
      if (tb == null || !isWeek) block(t('⚖️ Month & season ranking', '⚖️ ترتيب الشهر والموسم'), cumulative, !isWeek),
      Text(t('Every position goes to exactly one player — no shared prizes.', 'كل مركز لواحد بس — مفيش جوايز متقسمة.'),
        style: const TextStyle(color: muted, fontSize: 12)),
    ]);
  }

  String? _fmtTime(DateTime? d) => d == null ? null
      : '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  String? _fmtDate(DateTime? d) => d == null ? null : '${d.day}/${d.month}/${d.year}';
}

Future<void> showTieBreakSheet(BuildContext context, bool isArabic, {String period = 'round', Map? tb, String? name, bool draft = false}) {
  return showModalBottomSheet<void>(
    context: context, isScrollControlled: true, backgroundColor: bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.4,
      builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text(isArabic ? 'لو اتعادلت في النقط' : 'If points are tied', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        FantasyTieRules(isArabic: isArabic, period: period, tb: tb, name: name, draft: draft),
      ]),
    ),
  );
}


class _FixedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _FixedHeader({required this.height, required this.child});
  @override double get maxExtent => height;
  @override double get minExtent => height;
  @override Widget build(BuildContext context, double shrink, bool overlaps) => child;
  @override bool shouldRebuild(_FixedHeader o) => true;
}
