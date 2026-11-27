part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// إحصائياتي: رحلة اليوزر في الفانتازي
// - كارت "رحلتك": ترتيب الموسم + دايرة لكل جولة (لعبها / فاتته)
// - "طريقك للقمة": خط بيطلع كل ما الترتيب يتحسن (أو النقط مقابل المتوسط)
// - أرقامه القياسية + "المسافة للأول" (كل مصر / محافظته / مدينته)
// - نصايح مبنية على أرقامه + جولاته بالأسهم مع التشكيلة ونقط كل لاعب
// الصفحة بتتغير حسب خبرته: لسه ما لعبش / مستني أول نتيجة / جولة / 2-3 / كتير
// الداتا كلها من fantasy_my_stats (بترجع بيانات اليوزر اللي داخل بس)
// ═══════════════════════════════════════════════════════════════════════════

const _msPanel  = Color(0xFF151518);
const _msPanel2 = Color(0xFF1C1C21);
const _msHair   = Color(0x1AFFFFFF);
const _msUp     = Color(0xFF4CD964);
const _msDown   = Color(0xFFFF6B6B);

void openMyFantasyStats(BuildContext context, bool isArabic, {String type = 'LOCAL', VoidCallback? onToggleLanguage}) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => FantasyMyStatsPage(isArabic: isArabic, type: type, onToggleLanguage: onToggleLanguage),
    transitionsBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: c, child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(c), child: child));
    },
  ));
}

class FantasyMyStatsPage extends StatefulWidget {
  final bool isArabic;
  final String type;
  /// بيغيّر لغة الفانتازي كلها (مش الصفحة دي بس)
  final VoidCallback? onToggleLanguage;
  const FantasyMyStatsPage({super.key, required this.isArabic, this.type = 'LOCAL', this.onToggleLanguage});
  @override
  State<FantasyMyStatsPage> createState() => _MyStatsState();
}

class _MyStatsState extends State<FantasyMyStatsPage> with TickerProviderStateMixin {
  late String _type = widget.type;
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, Map<String, dynamic>?> _squads = {};
  final Set<String> _squadLoading = {};
  bool _loading = true;
  String? _err;
  int _sel = -1;              // الجولة المختارة (index في rounds)
  bool _chartPoints = false;  // false = الترتيب، true = النقط
  bool _byMonth = false;      // التشارت: جولات ولا شهور
  int? _winEnd;               // آخر جولة ظاهرة في التشارت (بنعرض آخر 10 والباقي بالسحب)
  double _dragAcc = 0;
  static const _win = 10;
  final Map<String, List<Map<String, dynamic>>> _monthsCache = {};
  bool _month = false;        // المسافة للأول: الشهر ولا الموسم

  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  late bool _ar = widget.isArabic;
  bool get ar => _ar;

  void _toggleLang() {
    HapticFeedback.selectionClick();
    setState(() => _ar = !_ar);
    if (widget.onToggleLanguage != null) {
      widget.onToggleLanguage!();
    } else {
      final lang = _ar ? 'ar' : 'en';
      AppLang.set(lang);
      LocalStore.setLang(lang);
    }
  }
  String t(String en, String a) => ar ? a : en;
  Map<String, dynamic>? get _d => _cache[_type];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _intro.dispose(); _pulse.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (_cache[_type] != null) { _afterLoad(); return; }
    setState(() { _loading = true; _err = null; });
    try {
      final res = await Future.wait([
        _sb.rpc('fantasy_my_stats', params: {'p_type': _type}),
        _sb.rpc('fantasy_my_months', params: {'p_type': _type}).catchError((_) => <dynamic>[]),
      ]);
      _cache[_type] = Map<String, dynamic>.from(res[0] as Map);
      _monthsCache[_type] = ((res[1] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _winEnd = null;
      if (!mounted) return;
      _afterLoad();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _err = e.toString(); });
    }
  }

  void _afterLoad() {
    final rs = _rounds;
    var sel = -1;
    for (var i = rs.length - 1; i >= 0; i--) { if (rs[i]['points'] != null) { sel = i; break; } }
    if (sel < 0) { for (var i = rs.length - 1; i >= 0; i--) { if (rs[i]['played'] == true) { sel = i; break; } } }
    if (sel < 0) sel = rs.length - 1;
    setState(() { _loading = false; _sel = sel; });
    _intro.forward(from: 0);
    _ensureSquad();
  }

  void _switchType() {
    HapticFeedback.selectionClick();
    setState(() => _type = _type == 'LOCAL' ? 'WORLD' : 'LOCAL');
    _load();
  }

  // ── داتا مشتقة ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _rounds =>
      ((_d?['rounds'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get _scored => _rounds.where((r) => r['points'] != null).toList();
  Map<String, dynamic>? _stand(String k) {
    final m = (_d?['standing'] as Map?)?[k];
    return m == null ? null : Map<String, dynamic>.from(m as Map);
  }

  /// empty / waiting / one / few / rich
  String get _stage {
    final s = _scored.length;
    if (s == 0) return _rounds.any((r) => r['played'] == true) ? 'waiting' : 'empty';
    if (s == 1) return 'one';
    if (s < 4) return 'few';
    return 'rich';
  }

  static num? _n(dynamic v) => v is num ? v : (v == null ? null : num.tryParse('$v'));
  static String _int(num? v) {
    if (v == null) return '—';
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
  static String _pts(num? v) => v == null ? '—' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1));

  static const _mAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  static const _mEn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _date(dynamic iso) {
    final d = iso == null ? null : DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '—';
    return ar ? '${d.day} ${_mAr[d.month - 1]}' : '${_mEn[d.month - 1]} ${d.day}';
  }
  String _rLabel(dynamic no) => t('Round $no', 'الجولة $no');
  String get _arenaName => _type == 'LOCAL' ? t('Fantasy Egypt', 'فانتازي مصر') : t('Fantasy World', 'فانتازي العالم');
  String get _allName => t('All BDGR', 'كل BDGR');
  String? get _govName {
    final d = _d;
    if (d == null || d['governorate'] == null) return null;
    return '${ar ? (d['governorate_ar'] ?? d['governorate']) : d['governorate']}';
  }
  String? get _cityName => _d?['city']?.toString();

  // ── التشكيلة بتاعت الجولة المختارة ───────────────────────────────────────
  Future<void> _ensureSquad() async {
    if (_sel < 0 || _sel >= _rounds.length) return;
    final r = _rounds[_sel];
    final ev = '${r['event_id']}';
    if (r['played'] != true || r['phase'] == 'open' || _squads.containsKey(ev) || _squadLoading.contains(ev)) return;
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    _squadLoading.add(ev);
    try {
      final d = await _sb.rpc('get_user_squad_public', params: {'p_target_user_id': me, 'p_event_id': ev});
      _squads[ev] = d == null ? null : Map<String, dynamic>.from(d as Map);
    } catch (_) {
      _squads[ev] = null;
    }
    _squadLoading.remove(ev);
    if (mounted) setState(() {});
  }

  void _selectRound(int i) {
    if (i < 0 || i >= _rounds.length || i == _sel) return;
    HapticFeedback.selectionClick();
    setState(() => _sel = i);
    _ensureSquad();
  }

  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      backgroundColor: bg,
      body: SafeArea(bottom: false, child: Column(children: [
        _topBar(),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 2.4))
          : _err != null
            ? _errorView()
            : BadgerRefresh(
                onRefresh: () async { _cache.remove(_type); _squads.clear(); await _load(); },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    const AdSlot('fantasy_mystats', padding: EdgeInsets.only(bottom: 10),
                        prefixEn: 'Stats by', prefixAr: 'الإحصائيات برعاية'),
                    ..._sections(),
                  ],
                ))),
      ])),
    ));
  }

  List<Widget> _sections() {
    final st = _stage;
    final w = <Widget>[_typeSwitch(), const SizedBox(height: 14)];
    if (st == 'empty') {
      w.add(_reveal(0, _emptyHero()));
      return w;
    }
    if (st == 'waiting') {
      w.add(_reveal(0, _waitingCard()));
      w..add(const SizedBox(height: 14))..add(_reveal(1, _roundsSection()));
      return w;
    }
    // أول حاجة: أعلى ترتيب · أعلى نقط · متوسطك، وتحتها التشارت
    w.add(_reveal(0, _recordsStrip()));
    if (st == 'one') {
      w..add(const SizedBox(height: 14))..add(_reveal(1, _firstRoundCard()));
    } else {
      w..add(const SizedBox(height: 14))..add(_reveal(1, _chartCard()));
    }
    final ins = _insights();
    if (ins.isNotEmpty) w..add(const SizedBox(height: 14))..add(_reveal(3, _insightsCard(ins)));
    w..add(const SizedBox(height: 14))..add(_reveal(4, _standingCard()));
    w..add(const SizedBox(height: 14))..add(_reveal(5, _roundsSection()));
    return w;
  }

  Widget _reveal(int i, Widget child) {
    final start = (i * 0.09).clamp(0.0, 0.6);
    final a = CurvedAnimation(parent: _intro, curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic));
    return FadeTransition(opacity: a, child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: child));
  }

  // ── top ─────────────────────────────────────────────────────────────────
  Widget _topBar() {
    final d0 = _d;
    final season = d0 == null ? null : '${ar ? d0['season_ar'] : d0['season_en']}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _msPanel, shape: BoxShape.circle, border: Border.all(color: _msHair)),
            child: Icon(ar ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, color: Colors.white, size: 19)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t('My stats', 'إحصائياتي'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.15)),
          if (season != null && season.isNotEmpty && season != 'null')
            Text(season, style: const TextStyle(color: Colors.white38, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ])),
        FantasyLangToggle(isArabic: ar, onTap: _toggleLang),
      ]),
    );
  }

  Widget _typeSwitch() {
    Widget arrow(bool back) => GestureDetector(
      onTap: _switchType, behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Icon(back ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14)));
    return GestureDetector(
      onHorizontalDragEnd: (d) { if ((d.primaryVelocity ?? 0).abs() > 200) _switchType(); },
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        arrow(true),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(key: ValueKey(_type), mainAxisSize: MainAxisSize.min, children: [
            Text(_type == 'LOCAL' ? '🇪🇬' : '🌍', style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(_arenaName, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
          ])),
        arrow(false),
      ]),
    );
  }

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.cloud_off_rounded, color: Colors.white24, size: 40),
    const SizedBox(height: 10),
    Text(t("Couldn't load your stats.", 'مقدرناش نجيب إحصائياتك.'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
    const SizedBox(height: 14),
    TextButton(onPressed: _load, child: Text(t('Try again', 'جرّب تاني'), style: const TextStyle(color: brandRed, fontWeight: FontWeight.w800))),
  ])));

  // ── panel: شكل الكروت (خط رفيع + لمعة خفيفة في الركن) ───────────────────
  Widget _panel({required Widget child, Color glow = brandRed, EdgeInsets? padding, bool strong = false}) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_msPanel2, _msPanel]),
      border: Border.all(color: strong ? glow.withOpacity(0.35) : _msHair),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Stack(children: [
      PositionedDirectional(top: -70, end: -60, child: IgnorePointer(child: Container(width: 180, height: 180,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(
          colors: [glow.withOpacity(strong ? 0.22 : 0.12), glow.withOpacity(0)]))))),
      Padding(padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 18, 18), child: child),
    ])),
  );

  Widget _label(String s) => Text(s, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2));

  Widget _countUp(num? v, {required TextStyle style, String prefix = '', String suffix = ''}) {
    if (v == null) return Text('—', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v.toDouble()),
      duration: const Duration(milliseconds: 1100), curve: Curves.easeOutCubic,
      builder: (_, x, __) => Text('$prefix${_int(x)}$suffix', style: style));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EMPTY: لسه ما لعبش
  // ═════════════════════════════════════════════════════════════════════════
  Widget _emptyHero() => _panel(strong: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(height: 130, width: double.infinity, child: AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => CustomPaint(painter: _GhostPathPainter(_pulse.value, rtl: ar)))),
    const SizedBox(height: 14),
    Text(t('Your story starts here', 'قصتك لسه هتبدأ'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    Text(t('Build your team for the next round. This page will show how you climb, your best scores, and how close you are to #1 in your area.',
           'ابني فريقك في الجولة الجاية، وهنا هتشوف ترتيبك بيطلع إزاي، أعلى نقط جبتها، وقد إيه انت قريب من الأول في منطقتك.'),
      style: const TextStyle(color: Colors.white60, fontSize: 13.5, height: 1.55)),
    const SizedBox(height: 16),
    Wrap(spacing: 8, runSpacing: 8, children: [
      _ghostChip(Icons.show_chart_rounded, t('Your climb', 'طريقك للقمة')),
      _ghostChip(Icons.flag_rounded, t('Distance to #1', 'المسافة للأول')),
      _ghostChip(Icons.lightbulb_outline_rounded, t('Tips for you', 'نصايح ليك')),
    ]),
    const SizedBox(height: 18),
    SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Text(t('Build my team', 'يلا أبني فريقي'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)))),
  ]));

  Widget _ghostChip(IconData i, String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: _msHair)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, color: Colors.white54, size: 15), const SizedBox(width: 6),
      Text(s, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
    ]));

  int? get _bestRankRound {
    final s = _scored.where((r) => r['rank'] != null).toList();
    if (s.isEmpty) return null;
    s.sort((a, b) => _pct(a).compareTo(_pct(b)));
    return (s.first['round_no'] as num?)?.toInt();
  }

  /// ترتيبه كنسبة (أقل = أحسن) علشان الجولات اللي فيها عدد مختلف تتقارن صح
  double _pct(Map<String, dynamic> r) {
    final rank = _n(r['rank']) ?? 1, total = _n(r['total']) ?? 1;
    return total <= 1 ? 0 : (rank - 1) / (total - 1);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // مستني أول نتيجة
  // ═════════════════════════════════════════════════════════════════════════
  Widget _waitingCard() {
    final r = _rounds.lastWhere((x) => x['played'] == true, orElse: () => <String, dynamic>{});
    return _panel(glow: _msUp, child: Row(children: [
      AnimatedBuilder(animation: _pulse, builder: (_, __) => Container(width: 44, height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _msUp.withOpacity(0.10 + 0.08 * (1 - _pulse.value)),
          border: Border.all(color: _msUp.withOpacity(0.5))),
        child: const Icon(Icons.check_rounded, color: _msUp, size: 22))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Your team is in for ${_rLabel(r['round_no'])}', 'فريقك متسجل في ${_rLabel(r['round_no'])}'),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(t('Your first numbers show up Thursday at 9 PM, when results are out.',
               'أول أرقامك هتظهر هنا الخميس الساعة 9 بالليل لما النتايج تطلع.'),
          style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.5)),
      ])),
    ]));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // جولة واحدة: مقارنة بالمتوسط وأعلى نقط
  // ═════════════════════════════════════════════════════════════════════════
  Widget _firstRoundCard() {
    final r = _scored.first;
    final pts = _n(r['points']) ?? 0, avg = _n(r['avg']) ?? 0, top = _n(r['top']) ?? 1;
    final beat = ((1 - _pct(r)) * 100).round();
    final diff = pts - avg;
    return _panel(glow: diff >= 0 ? _msUp : brandRed, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(t('Your first round · ${_rLabel(r['round_no'])}', 'أول جولة ليك · ${_rLabel(r['round_no'])}')),
      const SizedBox(height: 8),
      Text(t('Better than $beat% of players', 'أحسن من $beat% من اللاعيبة'),
        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      _gauge(pts, avg, top),
      const SizedBox(height: 14),
      Text(t('One more round and we will draw your climb here.', 'جولة كمان وهنرسملك هنا طريقك للقمة.'),
        style: const TextStyle(color: Colors.white38, fontSize: 12)),
    ]));
  }

  /// خط من صفر لأعلى نقط في الجولة، عليه المتوسط وانت
  Widget _gauge(num me, num avg, num top) {
    final maxV = math.max(top.toDouble(), math.max(me.toDouble(), 1.0));
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      double x(num v) => (w * (v / maxV)).clamp(0.0, w);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1200), curve: Curves.easeOutCubic,
        builder: (_, k, __) => SizedBox(height: 62, child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, right: 0, top: 26, child: Container(height: 8,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)))),
          PositionedDirectional(start: 0, top: 26, child: Container(height: 8, width: x(me) * k,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [Color(0xFF8A1010), brandRed])))),
          PositionedDirectional(start: x(avg) - 1, top: 20, child: Container(width: 2, height: 20, color: Colors.white70)),
          PositionedDirectional(start: (x(avg) - 40).clamp(0.0, w - 80), top: 44, child: SizedBox(width: 80, child: Text(
            t('Average ${_pts(avg)}', 'المتوسط ${_pts(avg)}'), textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w700)))),
          PositionedDirectional(start: (x(me) * k - 36).clamp(0.0, w - 72), top: 0, child: SizedBox(width: 72, child: Text(
            t('You ${_pts(me)}', 'انت ${_pts(me)}'), textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)))),
          PositionedDirectional(end: 0, top: 44, child: Text(t('Top ${_pts(top)}', 'الأعلى ${_pts(top)}'),
            style: const TextStyle(color: _gold, fontSize: 10.5, fontWeight: FontWeight.w800))),
        ])));
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // طريقك للقمة (التشارت)
  // ═════════════════════════════════════════════════════════════════════════
  static const _mShortAr = ['ينا','فبر','مارس','أبر','مايو','يون','يول','أغس','سبت','أكت','نوف','ديس'];
  static const _mShortEn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  /// الشهور بنفس شكل الجولات علشان نفس الرسمة تشتغل عليها
  List<Map<String, dynamic>> get _monthPoints {
    final ms = _monthsCache[_type] ?? const [];
    return [
      for (var i = 0; i < ms.length; i++) {
        'round_no': 1000 + i,
        'label': () { final m = int.tryParse('${ms[i]['month']}'.split('-').last) ?? 1; return ar ? _mShortAr[m - 1] : _mShortEn[m - 1]; }(),
        'points': ms[i]['points'], 'rank': ms[i]['rank'], 'total': ms[i]['total'], 'avg': ms[i]['avg'],
        'played': ms[i]['rank'] != null, 'eligible': true, 'phase': 'finished',
      },
    ];
  }

  Widget _chartCard() {
    final all = _byMonth ? _monthPoints : _rounds;
    final enoughMonths = _monthPoints.where((m) => m['rank'] != null).length >= 2;
    final int end = (_winEnd ?? all.length).clamp(math.min(_win, all.length), all.length).toInt();
    final int start = math.max(0, end - _win);
    final rs = all.sublist(start, end);
    final int sel = _byMonth ? rs.length - 1 : _sel - start;
    final scored = rs.where((r) => r['points'] != null && r['rank'] != null).toList()..sort((a, b) => _pct(a).compareTo(_pct(b)));
    final best = scored.isEmpty ? null : (scored.first['round_no'] as num?)?.toInt();
    final unit = _byMonth ? t('month', 'شهر') : t('round', 'جولة');
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(_chartPoints ? t('Your points', 'نقطك') : t('Your climb', 'طريقك للقمة'),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
        _seg([t('Rank', 'الترتيب'), t('Points', 'النقط')], _chartPoints ? 1 : 0,
          (i) { HapticFeedback.selectionClick(); setState(() => _chartPoints = i == 1); }),
      ]),
      const SizedBox(height: 10),
      _seg([t('Rounds', 'الجولات'), t('Months', 'الشهور')], _byMonth ? 1 : 0,
        (i) { HapticFeedback.selectionClick(); setState(() { _byMonth = i == 1; _winEnd = null; }); }),
      const SizedBox(height: 14),
      if (_byMonth && !enoughMonths)
        SizedBox(height: 150, child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.white24, size: 34),
          const SizedBox(height: 10),
          Text(t('Not enough months yet to show your monthly trend. Check back after next month.',
                 'لسه مفيش شهور كفاية نعرضلك تحليل بالشهر. ارجع هنا بعد الشهر الجاي.'),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
        ]))))
      else
        SizedBox(height: 190, child: LayoutBuilder(builder: (_, c) {
          final step = c.maxWidth / math.max(rs.length, 1);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (rs.isEmpty || _byMonth) return;
              var i = (d.localPosition.dx / step).floor().clamp(0, rs.length - 1).toInt();
              if (ar) i = rs.length - 1 - i;
              _selectRound(start + i);
            },
            // سحب يمين/شمال: يرجع لجولات أقدم أو يقدّم
            onHorizontalDragStart: all.length > _win ? (_) => _dragAcc = 0 : null,
            onHorizontalDragUpdate: all.length > _win ? (d) {
              _dragAcc += ar ? -d.delta.dx : d.delta.dx;
              final shift = (_dragAcc / step).truncate();
              if (shift != 0) {
                _dragAcc -= shift * step;
                setState(() => _winEnd = (end - shift).clamp(_win, all.length).toInt());
              }
            } : null,
            child: AnimatedBuilder(animation: _intro, builder: (_, __) {
              final k = Curves.easeInOutCubic.transform(((_intro.value - 0.1) / 0.75).clamp(0.0, 1.0));
              return CustomPaint(size: Size(c.maxWidth, 190), painter: _chartPoints
                ? _PointsBarsPainter(rounds: rs, sel: sel, k: k, rtl: ar, avgLabel: t('avg', 'متوسط'))
                : _ClimbPainter(rounds: rs, sel: sel, k: k, rtl: ar, bestRound: best,
                    pct: _pct, topLabel: t('#1', 'الأول'), labelOf: (r) => '#${_int(_n(r['rank']))}'));
            }),
          );
        })),
      const SizedBox(height: 10),
      Row(children: [
        Icon(_chartPoints ? Icons.horizontal_rule_rounded : Icons.trending_up_rounded, color: Colors.white38, size: 15),
        const SizedBox(width: 6),
        Expanded(child: Text(
          (_chartPoints
            ? t('White line = average of all players.', 'الشرطة البيضا = متوسط كل اللاعيبة.')
            : t('Line going up = your rank is getting better.', 'كل ما الخط يطلع لفوق، ترتيبك بيتحسن.'))
          + (_byMonth ? '' : t(' Tap a $unit to open it.', ' دوس على أي $unit تفتحها.'))
          + (all.length > _win ? t(' Swipe to see older ${unit}s.', ' اسحب تشوف اللي قبل كده.') : ''),
          style: const TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.4))),
      ]),
    ]));
  }

  Widget _seg(List<String> items, int on, ValueChanged<int> onTap) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(20), border: Border.all(color: _msHair)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < items.length; i++) GestureDetector(
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: i == on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Text(items[i], style: TextStyle(color: i == on ? Colors.black : Colors.white60, fontSize: 12, fontWeight: FontWeight.w800)))),
    ]));

  // ── الأرقام القياسية ────────────────────────────────────────────────────
  Widget _recordsStrip() {
    final s = _scored;
    final byRank = [...s.where((r) => r['rank'] != null)]..sort((a, b) => _pct(a).compareTo(_pct(b)));
    final byPts = [...s]..sort((a, b) => (_n(b['points']) ?? 0).compareTo(_n(a['points']) ?? 0));
    final avg = s.isEmpty ? null : s.fold<num>(0, (m, r) => m + (_n(r['points']) ?? 0)) / s.length;
    final above = s.where((r) => (_n(r['points']) ?? 0) > (_n(r['avg']) ?? 0)).length;
    Widget cell(String k, String v, String sub, Color c) => Expanded(child: Column(children: [
      Text(k, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(v, style: TextStyle(color: c, fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white30, fontSize: 10.5, fontWeight: FontWeight.w600)),
    ]));
    Widget div() => Container(width: 1, height: 44, color: _msHair);
    return _panel(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6), child: Row(children: [
      cell(t('Best rank', 'أعلى ترتيب'), byRank.isEmpty ? '—' : '#${_int(_n(byRank.first['rank']))}',
        byRank.isEmpty ? '' : _rLabel(byRank.first['round_no']), _gold),
      div(),
      cell(t('Best score', 'أعلى نقط'), byPts.isEmpty ? '—' : _pts(_n(byPts.first['points'])),
        byPts.isEmpty ? '' : _rLabel(byPts.first['round_no']), Colors.white),
      div(),
      cell(t('Your average', 'متوسطك'), _pts(avg == null ? null : (avg * 10).round() / 10),
        t('Above avg $above/${s.length}', 'فوق المتوسط $above/${s.length}'), Colors.white),
    ]));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // نصايح
  // ═════════════════════════════════════════════════════════════════════════
  List<(String, String)> _insights() {
    final out = <(String, String)>[];
    final s = _scored;
    // 1) أقرب فرصة للمركز الأول
    final chance = _closestChance();
    if (chance != null) {
      final gap = chance.$2, where = chance.$1, month = chance.$3;
      out.add(('🎯', t('You are $gap pts behind #1 in $where ${month ? 'this month' : 'this season'}. One good round and you are on top.',
                       'انت على بعد $gap نقطة بس من الأول في $where ${month ? 'الشهر ده' : 'الموسم ده'}. جولة حلوة وتبقى فوق.')));
    }
    // 2) جولات فاتته
    final missed = _rounds.where((r) => r['eligible'] == true && r['played'] != true && r['phase'] != 'open').length;
    if (missed > 0) {
      out.add(('⏰', t('You missed $missed ${missed == 1 ? 'round' : 'rounds'}. Every missed round costs you month and season points. Deadline is 3 hours before the first match.',
                       'فاتتك $missed ${missed == 1 ? 'جولة' : 'جولات'}. كل جولة بتفوتك بتخسر فيها نقط الشهر والموسم. الديدلاين قبل أول ماتش بـ 3 ساعات.')));
    }
    // 3) الاتجاه
    if (s.length >= 3) {
      num avgOf(Iterable<Map<String, dynamic>> l) => l.isEmpty ? 0 : l.fold<num>(0, (m, r) => m + (_n(r['points']) ?? 0)) / l.length;
      final last2 = avgOf(s.sublist(s.length - 2)), before = avgOf(s.sublist(0, s.length - 2));
      final d = (last2 - before).round();
      if (d >= 5) {
        out.add(('🔥', t('You are on the rise: your last two rounds beat your earlier average by $d pts.',
                         'انت في الطالع: آخر جولتين أحسن من متوسطك اللي قبلهم بـ $d نقطة.')));
      } else if (d <= -5) {
        out.add(('🔎', t('Your last two rounds dipped a bit. Check the top scorers in All players before you pick.',
                         'آخر جولتين نزلوا شوية. بص على أكتر لاعيبة جابوا نقط في شاشة "كل اللاعيبة" قبل ما تختار.')));
      }
    }
    // 4) الكابتن
    if (s.length >= 2) {
      final tot = s.fold<num>(0, (m, r) => m + (_n(r['points']) ?? 0));
      final cap = s.fold<num>(0, (m, r) => m + (_n(r['captain_points']) ?? 0));
      if (tot > 0) {
        final p = (100 * cap / tot).round();
        if (p < 18) {
          out.add(('©️', t('Your captain brought only $p% of your points. Pick a captain with an easier match — his points are doubled.',
                           'الكابتن جاب $p% بس من نقطك. اختار كابتن عنده ماتش أسهل، نقطه بتتضاعف.')));
        } else if (p >= 35) {
          out.add(('👏', t('Great captain picks: they brought $p% of your points.', 'اختيارك للكابتن شغال صح: جاب $p% من نقطك.')));
        }
      }
    }
    // 5) أول جولة
    if (s.length == 1) {
      out.add(('🌱', t('Strong start. Keep playing every week — month prizes go to whoever stays consistent.',
                       'بداية حلوة. كمّل كل أسبوع، جوايز الشهر بتروح للي بيلعب على طول.')));
    }
    // 6) مفيش محافظة
    if (_d?['governorate'] == null) {
      out.add(('📍', t('Tap "Use my location" below to compete for the #1 prize in your governorate.',
                       'دوس "استخدم موقعي" تحت علشان تنافس على جايزة الأول في محافظتك.')));
    }
    return out.take(3).toList();
  }

  /// (المكان، الفرق للأول، شهر؟) لأقرب فرصة يبقى فيها الأول
  (String, int, bool)? _closestChance() {
    (String, int, bool)? best;
    for (final month in [true, false]) {
      for (final sc in ['city', 'governorate', 'all']) {
        final s = _stand('${month ? 'month' : 'season'}_$sc');
        if (s == null || (_n(s['rank']) ?? 1) <= 1) continue;
        final gap = ((_n(s['leader']) ?? 0) - (_n(s['points']) ?? 0)).round();
        if (gap > 30) continue;
        final where = sc == 'city' ? (_cityName ?? '') : sc == 'governorate' ? (_govName ?? '') : _allName;
        if (best == null || gap < best.$2) best = (where, gap, month);
      }
    }
    return best;
  }

  Widget _insightsCard(List<(String, String)> items) => _panel(glow: _gold, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Icon(Icons.auto_awesome_rounded, color: _gold, size: 17), const SizedBox(width: 8),
      Text(t('For you', 'نصايح ليك'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
    ]),
    const SizedBox(height: 12),
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
          child: Text(items[i].$1, style: const TextStyle(fontSize: 15))),
        const SizedBox(width: 12),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 5),
          child: Text(items[i].$2, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.55)))),
      ]),
    ],
  ]));

  // ═════════════════════════════════════════════════════════════════════════
  // المسافة للأول
  // ═════════════════════════════════════════════════════════════════════════
  Widget _standingCard() {
    final per = _month ? 'month' : 'season';
    final rows = <Widget>[];
    final chance = _closestChance();
    void add(String sc, IconData icon, String name) {
      final s = _stand('${per}_$sc');
      if (s == null) return;
      final hl = chance != null && chance.$3 == _month && chance.$1 == name;
      rows.add(_standRow(icon, name, s, hl));
    }
    add('all', Icons.public_rounded, _allName);
    if (_govName != null) add('governorate', Icons.location_city_rounded, _govName!);
    if (_cityName != null) add('city', Icons.place_rounded, _cityName!);
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(t('Distance to #1', 'المسافة للأول'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
        _seg([t('Month', 'الشهر'), t('Season', 'الموسم')], _month ? 0 : 1,
          (i) { HapticFeedback.selectionClick(); setState(() => _month = i == 0); }),
      ]),
      const SizedBox(height: 14),
      if (rows.isEmpty)
        Text(t('No finished rounds in this period yet.', 'لسه مفيش جولات خلصت في الفترة دي.'),
          style: const TextStyle(color: Colors.white38, fontSize: 12.5))
      else
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 10), rows[i]],
      if (_govName == null) ...[
        const SizedBox(height: 10),
        LocationNeededCard(isArabic: ar, compact: true, onDone: () { _cache.remove(_type); _cache.remove(_type == 'LOCAL' ? 'WORLD' : 'LOCAL'); _load(); }),
      ],
    ]));
  }

  Widget _standRow(IconData icon, String name, Map<String, dynamic> s, bool highlight) {
    final rank = (_n(s['rank']) ?? 0).toInt(), total = _n(s['total']);
    final pts = _n(s['points']) ?? 0, leader = _n(s['leader']) ?? 0, ahead = _n(s['ahead']);
    final first = rank == 1;
    final frac = leader <= 0 ? 0.0 : (pts / leader).clamp(0.0, 1.0).toDouble();
    final gap = (leader - pts).round();
    final aheadGap = ahead == null ? null : (ahead - pts).round();
    final c = first ? _gold : (highlight ? Colors.white : Colors.white70);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: highlight || first ? (first ? _gold : brandRed).withOpacity(0.07) : Colors.white.withOpacity(0.025),
        border: Border.all(color: highlight || first ? (first ? _gold : brandRed).withOpacity(0.35) : _msHair)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: Colors.white54, size: 16), const SizedBox(width: 8),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
          if (highlight && !first) Container(
            margin: const EdgeInsetsDirectional.only(end: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(10)),
            child: Text(t('Closest chance', 'أقرب فرصة'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
          Text('#${_int(rank)}', style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w900)),
          if (total != null) Text(t(' / ${_int(total)}', ' / ${_int(total)}'), style: const TextStyle(color: Colors.white30, fontSize: 11.5)),
        ]),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: frac), duration: const Duration(milliseconds: 1100), curve: Curves.easeOutCubic,
          builder: (_, v, __) => Stack(children: [
            Container(height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6))),
            FractionallySizedBox(widthFactor: v, child: Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(colors: first ? [const Color(0xFFB8860B), _gold] : [const Color(0xFF7A1212), brandRed])))),
          ])),
        const SizedBox(height: 8),
        Text(
          first ? t("You're #1 here 👑 Keep it up.", 'انت الأول هنا 👑 حافظ عليها.')
                : aheadGap != null && aheadGap > 0 && aheadGap < gap
                    ? t('$gap pts to #1 · $aheadGap to pass the next one', 'محتاج $gap نقطة للأول · و$aheadGap بس تعدّي اللي قدامك')
                    : t('$gap pts to #1', 'محتاج $gap نقطة للأول'),
          style: TextStyle(color: first ? _gold : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // جولاتك (أسهم يمين وشمال)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _roundsSection() {
    final rs = _rounds;
    if (rs.isEmpty || _sel < 0) return const SizedBox.shrink();
    final r = rs[_sel];
    Widget arrow(bool back) {
      final i = back ? _sel - 1 : _sel + 1;
      final ok = i >= 0 && i < rs.length;
      return GestureDetector(
        onTap: ok ? () => _selectRound(i) : null,
        child: Container(width: 34, height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? Colors.white.withOpacity(0.06) : Colors.transparent,
            border: Border.all(color: ok ? _msHair : Colors.transparent)),
          child: Icon(back ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
            color: ok ? Colors.white70 : Colors.white12, size: 14)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [
        Text(t('Your rounds', 'جولاتك'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        const Spacer(),
        arrow(true),
        SizedBox(width: 92, child: AnimatedSwitcher(duration: const Duration(milliseconds: 200),
          child: Text(_rLabel(r['round_no']), key: ValueKey(_sel), textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)))),
        arrow(false),
      ])),
      const SizedBox(height: 10),
      GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 200) return;
          final forward = ar ? v > 0 : v < 0;
          _selectRound(forward ? _sel + 1 : _sel - 1);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: c)),
          child: KeyedSubtree(key: ValueKey('round_$_sel'), child: _roundCard(r)),
        ),
      ),
    ]);
  }

  Widget _roundCard(Map<String, dynamic> r) {
    final played = r['played'] == true, phase = '${r['phase']}', elig = r['eligible'] == true;
    if (!played) {
      final (emoji, title, body) = phase == 'open'
        ? ('⚡', t('This round is open', 'الجولة دي مفتوحة'), t('You still have time to build your team.', 'لسه تلحق تبني فريقك.'))
        : !elig
          ? ('🕰️', t('Before you joined', 'قبل ما تدخل الفانتازي'), t('This round was played before you joined.', 'الجولة دي اتلعبت قبل ما تشترك.'))
          : ('😶', t('You missed this one', 'الجولة دي فاتتك'),
              r['top'] != null ? t('The winner scored ${_pts(_n(r['top']))} pts. Next round you are in.', 'الأول فيها جاب ${_pts(_n(r['top']))} نقطة. الجولة الجاية متفوتكش.')
                               : t('Next round, do not miss it.', 'الجولة الجاية متفوتكش.'));
      return _panel(glow: Colors.white, child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(body, style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.45)),
        ])),
        if (phase == 'open') TextButton(onPressed: () => Navigator.pop(context),
          child: Text(t('Build', 'ابني'), style: const TextStyle(color: brandRed, fontWeight: FontWeight.w900))),
      ]));
    }
    final pts = _n(r['points']), avg = _n(r['avg']);
    final diff = pts == null || avg == null ? null : (pts - avg).round();
    final ev = '${r['event_id']}';
    return _panel(glow: diff != null && diff >= 0 ? _msUp : brandRed, padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (pts == null)
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: _msUp, size: 18), const SizedBox(width: 8),
            Expanded(child: Text(phase == 'open'
                ? t('Team saved. You can still edit it before the deadline.', 'فريقك متسجل. لسه تقدر تعدّله قبل الديدلاين.')
                : t('Matches are on. Points are calculated after the round.', 'الماتشات شغالة. النقط بتتحسب بعد الجولة.'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700))),
          ])
        else
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label(t('Points', 'النقط')),
              const SizedBox(height: 2),
              _countUp(pts, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
            ]),
            const SizedBox(width: 22),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label(t('Rank', 'الترتيب')),
              const SizedBox(height: 4),
              Text('#${_int(_n(r['rank']))}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (diff != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: (diff >= 0 ? _msUp : _msDown).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(diff >= 0 ? t('+$diff vs avg', '+$diff عن المتوسط') : t('$diff vs avg', '$diff عن المتوسط'),
                  style: TextStyle(color: diff >= 0 ? _msUp : _msDown, fontSize: 11.5, fontWeight: FontWeight.w900))),
              if (r['gov_rank'] != null && _govName != null) Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(t('#${r['gov_rank']} in $_govName', '#${r['gov_rank']} في $_govName'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w700))),
            ]),
          ]),
        const SizedBox(height: 14),
        if (phase != 'open')
          _squads.containsKey(ev)
            ? (_squads[ev] == null ? const SizedBox.shrink() : _lineup(_squads[ev]!))
            : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 2))),
      ]));
  }

  /// التشكيلة على ملعب صغير هادي + نقط كل لاعب
  Widget _lineup(Map<String, dynamic> sq) {
    final slots = ((sq['slots'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final cap = sq['captain_player_id']?.toString();
    final by = <String, List<Map<String, dynamic>>>{'GK': [], 'DEF': [], 'MID': [], 'FWD': []};
    for (final s in slots) { by['${s['position']}']?.add(s); }
    for (final l in by.values) { l.sort((a, b) => ((a['slot_index'] as num?) ?? 0).compareTo((b['slot_index'] as num?) ?? 0)); }
    Widget player(Map<String, dynamic> p) {
      final isCap = cap != null && '${p['player_id']}' == cap;
      final name = '${(ar ? p['name_ar'] : p['name_en']) ?? ''}';
      final short = name.split(' ').last;
      final photo = p['photo_url'] as String?;
      final pts = p['points'];
      return SizedBox(width: 62, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE8E8E8),
              border: Border.all(color: isCap ? captainColor : Colors.white70, width: isCap ? 2 : 1.2)),
            child: ClipOval(child: photo != null
              ? _netImage(photo, width: 38, height: 38, fit: BoxFit.cover, fallback: const Icon(Icons.person, color: Color(0xFF333333), size: 22))
              : const Icon(Icons.person, color: Color(0xFF333333), size: 22))),
          if (isCap) Positioned(top: -3, right: -3, child: Container(width: 15, height: 15,
            decoration: const BoxDecoration(color: captainColor, shape: BoxShape.circle),
            child: const Center(child: Text('C', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, height: 1))))),
        ]),
        const SizedBox(height: 3),
        Text(short, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: isCap ? captainColor : Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
          child: Text('${pts ?? '—'}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, height: 1.35))),
      ]));
    }
    Widget row(String pos) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final p in by[pos]!) player(p)]));
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF123526), Color(0xFF0C2219)]),
        border: Border.all(color: const Color(0x2270A988))),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _MiniPitchPainter())),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: 340,
          child: Column(children: [row('FWD'), row('MID'), row('DEF'), row('GK')])))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Painters
// ═══════════════════════════════════════════════════════════════════════════

/// خط الترتيب: فوق = أحسن. الجولات اللي فاتته بتقطع الخط
class _ClimbPainter extends CustomPainter {
  final List<Map<String, dynamic>> rounds;
  final int sel;
  final double k;
  final bool rtl;
  final int? bestRound;
  final double Function(Map<String, dynamic>) pct;
  final String topLabel;
  final String Function(Map<String, dynamic>) labelOf;
  _ClimbPainter({required this.rounds, required this.sel, required this.k, required this.rtl, required this.bestRound,
    required this.pct, required this.topLabel, required this.labelOf});

  @override
  void paint(Canvas canvas, Size size) {
    final n = rounds.length;
    if (n == 0) return;
    const top = 30.0, bottom = 24.0;
    final h = size.height - top - bottom;
    final step = size.width / n;
    double xOf(int i) { final x = step * (i + 0.5); return rtl ? size.width - x : x; }
    double yOf(Map<String, dynamic> r) => top + h * pct(r);

    // خط الأول (فوق) متقطع + الكاس
    final dash = Paint()..color = const Color(0x40FFB300)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) { canvas.drawLine(Offset(x, top), Offset(x + 4, top), dash); }
    final tp = TextPainter(text: TextSpan(text: '🏆 $topLabel', style: const TextStyle(color: Color(0xCCFFB300), fontSize: 10.5, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(rtl ? 2 : size.width - tp.width - 2, top - tp.height - 4));
    // خط القاع
    canvas.drawLine(Offset(0, top + h), Offset(size.width, top + h), Paint()..color = const Color(0x14FFFFFF)..strokeWidth = 1);

    // تقسيم الخط لقطع (الجولات اللي فاتته بتقطعه)
    final segs = <List<Offset>>[];
    var cur = <Offset>[];
    for (var i = 0; i < n; i++) {
      final r = rounds[i];
      if (r['points'] != null && r['rank'] != null) { cur.add(Offset(xOf(i), yOf(r))); }
      else if (cur.isNotEmpty) { segs.add(cur); cur = <Offset>[]; }
    }
    if (cur.isNotEmpty) segs.add(cur);

    // ظهور تدريجي من البداية للنهاية
    final reveal = rtl ? Rect.fromLTWH(size.width * (1 - k), 0, size.width * k, size.height)
                       : Rect.fromLTWH(0, 0, size.width * k, size.height);
    canvas.save();
    canvas.clipRect(reveal);
    for (final s in segs) {
      final path = _smooth(s);
      if (s.length > 1) {
        final area = Path.from(path)..lineTo(s.last.dx, top + h)..lineTo(s.first.dx, top + h)..close();
        canvas.drawPath(area, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x55FF1A1A), Color(0x00FF1A1A)]).createShader(Rect.fromLTWH(0, top, size.width, h)));
        canvas.drawPath(path, Paint()..color = const Color(0x55FF1A1A)..style = PaintingStyle.stroke..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawPath(path, Paint()..color = const Color(0xFFFF3B30)..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round);
      }
    }
    canvas.restore();

    // النقط والعلامات
    for (var i = 0; i < n; i++) {
      final r = rounds[i];
      final x = xOf(i);
      final visible = rtl ? x >= size.width * (1 - k) - 1 : x <= size.width * k + 1;
      final isSel = i == sel;
      if (isSel) {
        canvas.drawLine(Offset(x, top - 2), Offset(x, top + h), Paint()..color = const Color(0x22FFFFFF)..strokeWidth = 1);
      }
      if (r['points'] == null || r['rank'] == null) {
        if (r['played'] != true && r['eligible'] == true && r['phase'] != 'open') {
          canvas.drawCircle(Offset(x, top + h), 4, Paint()..color = const Color(0x55FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.4);
        }
      } else if (visible) {
        final p = Offset(x, yOf(r));
        final best = bestRound != null && r['round_no'] == bestRound;
        if (best) canvas.drawCircle(p, 11, Paint()..color = const Color(0x44FFB300)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(p, isSel ? 6 : 4.2, Paint()..color = best ? const Color(0xFFFFB300) : Colors.white);
        canvas.drawCircle(p, isSel ? 6 : 4.2, Paint()..color = const Color(0xFF151518)..style = PaintingStyle.stroke..strokeWidth = 1.6);
        if (isSel) _bubble(canvas, size, p, labelOf(r));
      }
      // رقم الجولة تحت
      final lp = TextPainter(text: TextSpan(text: '${r['label'] ?? r['round_no']}', style: TextStyle(
          color: isSel ? Colors.white : const Color(0x55FFFFFF), fontSize: 10.5, fontWeight: isSel ? FontWeight.w900 : FontWeight.w600)),
        textDirection: TextDirection.ltr)..layout();
      lp.paint(canvas, Offset(x - lp.width / 2, size.height - lp.height));
    }
  }

  void _bubble(Canvas canvas, Size size, Offset p, String s) {
    final tp = TextPainter(text: TextSpan(text: s, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr)..layout();
    final w = tp.width + 14, hh = tp.height + 6;
    var left = (p.dx - w / 2).clamp(0.0, size.width - w);
    var topY = p.dy - hh - 10;
    if (topY < 0) topY = p.dy + 10;
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(left, topY, w, hh), const Radius.circular(8));
    canvas.drawRRect(rr, Paint()..color = Colors.white);
    tp.paint(canvas, Offset(left + 7, topY + 3));
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _ClimbPainter o) => o.k != k || o.sel != sel || o.rounds != rounds;
}

/// عواميد نقطه + شرطة بيضا للمتوسط
class _PointsBarsPainter extends CustomPainter {
  final List<Map<String, dynamic>> rounds;
  final int sel;
  final double k;
  final bool rtl;
  final String avgLabel;
  _PointsBarsPainter({required this.rounds, required this.sel, required this.k, required this.rtl, required this.avgLabel});

  @override
  void paint(Canvas canvas, Size size) {
    final n = rounds.length;
    if (n == 0) return;
    const top = 22.0, bottom = 24.0;
    final h = size.height - top - bottom;
    final step = size.width / n;
    num maxV = 1;
    for (final r in rounds) {
      final p = r['points'] as num?, a = r['avg'] as num?;
      if (p != null && p > maxV) maxV = p;
      if (a != null && a > maxV) maxV = a;
    }
    final bw = (step * 0.46).clamp(8.0, 26.0);
    canvas.drawLine(Offset(0, top + h), Offset(size.width, top + h), Paint()..color = const Color(0x14FFFFFF));
    for (var i = 0; i < n; i++) {
      final r = rounds[i];
      final cx0 = step * (i + 0.5);
      final cx = rtl ? size.width - cx0 : cx0;
      final isSel = i == sel;
      final p = r['points'] as num?, a = r['avg'] as num?;
      if (p != null) {
        final bh = h * (math.max(p, 0) / maxV) * k;
        final rect = RRect.fromRectAndCorners(Rect.fromLTWH(cx - bw / 2, top + h - bh, bw, bh),
          topLeft: const Radius.circular(7), topRight: const Radius.circular(7));
        canvas.drawRRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: isSel ? const [Color(0xFFFF4D40), Color(0xFF8A1010)] : const [Color(0x99FF3B30), Color(0x338A1010)])
          .createShader(rect.outerRect));
        final tp = TextPainter(text: TextSpan(text: _MyStatsState._pts(p), style: TextStyle(
            color: isSel ? Colors.white : const Color(0x99FFFFFF), fontSize: 10.5, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, top + h - bh - tp.height - 3));
      } else {
        canvas.drawCircle(Offset(cx, top + h - 3), 2.2, Paint()..color = const Color(0x33FFFFFF));
      }
      if (a != null && k > 0.6) {
        final y = top + h - h * (a / maxV);
        canvas.drawLine(Offset(cx - bw / 2 - 4, y), Offset(cx + bw / 2 + 4, y),
          Paint()..color = Colors.white.withOpacity(0.8 * ((k - 0.6) / 0.4))..strokeWidth = 2..strokeCap = StrokeCap.round);
      }
      final lp = TextPainter(text: TextSpan(text: '${r['label'] ?? r['round_no']}', style: TextStyle(
          color: isSel ? Colors.white : const Color(0x55FFFFFF), fontSize: 10.5, fontWeight: isSel ? FontWeight.w900 : FontWeight.w600)),
        textDirection: TextDirection.ltr)..layout();
      lp.paint(canvas, Offset(cx - lp.width / 2, size.height - lp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _PointsBarsPainter o) => o.k != k || o.sel != sel || o.rounds != rounds;
}

/// خط وهمي بيطلع ونقطة منوّرة ماشية عليه (للي لسه ما لعبش)
class _GhostPathPainter extends CustomPainter {
  final double t;
  final bool rtl;
  _GhostPathPainter(this.t, {required this.rtl});

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[
      Offset(0.04, 0.86), Offset(0.22, 0.70), Offset(0.38, 0.78), Offset(0.56, 0.48), Offset(0.74, 0.36), Offset(0.94, 0.12),
    ].map((o) => Offset((rtl ? 1 - o.dx : o.dx) * size.width, o.dy * size.height)).toList();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final metric = path.computeMetrics().first;
    for (double d = 0; d < metric.length; d += 9) {
      canvas.drawPath(metric.extractPath(d, d + 4.5), Paint()..color = const Color(0x40FFFFFF)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }
    for (final p in pts) { canvas.drawCircle(p, 3, Paint()..color = const Color(0x30FFFFFF)); }
    final pos = metric.getTangentForOffset(metric.length * Curves.easeInOut.transform(t))!.position;
    canvas.drawCircle(pos, 14, Paint()..color = const Color(0x55FF1A1A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(pos, 5.5, Paint()..color = brandRed);
    canvas.drawCircle(pos, 5.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final tp = TextPainter(text: const TextSpan(text: '🏆', style: TextStyle(fontSize: 18)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(pts.last.dx - tp.width / 2, pts.last.dy - tp.height - 4));
  }

  @override
  bool shouldRepaint(covariant _GhostPathPainter o) => o.t != t;
}

class _MiniPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x1A9FD8B8)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.13, p);
    final bw = size.width * 0.42, bh = size.height * 0.12;
    canvas.drawRect(Rect.fromLTWH((size.width - bw) / 2, size.height - bh, bw, bh), p);
    canvas.drawRect(Rect.fromLTWH((size.width - bw) / 2, 0, bw, bh), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
