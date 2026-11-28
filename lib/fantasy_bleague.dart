part of 'fantasy.dart';

/// 🥇 دوري بادجر: فرق صحاب (من 1 لـ 5) بيجمعوا نقط الدرافت بتاعتهم على الشهر.
/// السيرفر: badger_league_home / _team / _board / _create / _update / _preview / _join.
const Color _blGold = Color(0xFFFFB300);
const List<String> _kBLIcons = ['🦅','🦁','🐺','🦈','🐉','🦂','🐍','🐆','🦬','🦡','⚡','🔥','👑','⭐','💎','🚀','⚔️','🛡️'];
const List<String> _kBLColors = ['#E53935','#FFB300','#1E88E5','#43A047','#8E24AA','#00ACC1','#F4511E','#3949AB','#6D4C41','#546E7A'];

Color _blColor(String? hex) {
  final h = (hex ?? '').replaceAll('#', '');
  return h.length == 6 ? Color(int.parse('FF$h', radix: 16)) : const Color(0xFF546E7A);
}

String _blMonthName(String? m, bool ar) {
  final p = (m ?? '').split('-');
  if (p.length != 2) return '';
  final i = (int.tryParse(p[1]) ?? 1) - 1;
  const arM = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  const enM = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  return '${ar ? arM[i.clamp(0, 11).toInt()] : enM[i.clamp(0, 11).toInt()]} ${p[0]}';
}

String _blPts(dynamic v) {
  final n = v is num ? v : num.tryParse('$v') ?? 0;
  return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);
}

String _blErr(Object e, bool ar) {
  final s = e.toString();
  String t(String en, String a) => ar ? a : en;
  if (s.contains('already_in_team')) return t("You're already in a team in this arena this month.", 'إنت في فريق خلاص في الأرينا دي الشهر ده.');
  if (s.contains('league_off')) return t('The Badger League is not open yet.', 'دوري بادجر لسه ما فتحش.');
  if (s.contains('bad_arena')) return t('Pick Egypt or World.', 'اختار مصر أو العالم.');
  if (s.contains('reserved_name')) return t('This name is not allowed.', 'الاسم ده مش مسموح.');
  if (s.contains('bad_name')) return t('Name must be 2–24 characters.', 'الاسم لازم يبقى من 2 لـ 24 حرف.');
  if (s.contains('name_taken')) return t('This name is taken this month.', 'الاسم ده متاخد الشهر ده.');
  if (s.contains('team_full')) return t('The team is full (5/5).', 'الفريق كامل (5/5).');
  if (s.contains('code_not_found')) return t('Wrong code.', 'الكود غلط.');
  if (s.contains('too_many_tries')) return t('Too many tries. Try again in an hour.', 'جربت كتير. جرّب تاني بعد ساعة.');
  if (s.contains('not_allowed')) return t('Only the captain can do this.', 'الكابتن بس اللي يقدر.');
  return t('Something went wrong.', 'حصلت مشكلة، جرّب تاني.');
}

/// درع الفريق: شكل محدّب + لون + رمز
class LeagueShield extends StatelessWidget {
  const LeagueShield({super.key, required this.icon, required this.color, this.size = 40});
  final String icon;
  final String color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = _blColor(color);
    return SizedBox(width: size, height: size * 1.12, child: ClipPath(
      clipper: _ShieldClipper(),
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [c, Color.lerp(c, Colors.black, 0.55)!])),
        alignment: const Alignment(0, -0.1),
        child: Text(icon, style: TextStyle(fontSize: size * 0.46)),
      ),
    ));
  }
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width / 2, 0)
    ..lineTo(s.width, s.height * 0.14)
    ..lineTo(s.width, s.height * 0.58)
    ..lineTo(s.width / 2, s.height)
    ..lineTo(0, s.height * 0.58)
    ..lineTo(0, s.height * 0.14)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// شريط في صفحة الجولة
class BadgerLeagueBanner extends StatefulWidget {
  const BadgerLeagueBanner({super.key, required this.isArabic});
  final bool isArabic;
  @override
  State<BadgerLeagueBanner> createState() => _BadgerLeagueBannerState();
}

class _BadgerLeagueBannerState extends State<BadgerLeagueBanner> {
  Map<String, dynamic>? _d;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _sb.rpc('badger_league_home');
      if (mounted && r != null) setState(() => _d = Map<String, dynamic>.from(r as Map));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final team = d['team'] as Map?;
    final total = (d['teams'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => badgerLeaguePage()));
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
          child: Row(children: [
            team != null
                ? LeagueShield(icon: '${team['icon']}', color: '${team['color']}', size: 30)
                : const Text('🥇', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Badger League · ${_blMonthName(d['month'] as String?, false)}', 'دوري بادجر · ${_blMonthName(d['month'] as String?, true)}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(team != null
                    ? t('${team['name']} · #${team['rank'] ?? '-'} of $total · ${_blPts(team['points'])} pts',
                        '${team['name']} · المركز ${team['rank'] ?? '-'} من $total · ${_blPts(team['points'])} نقطة')
                    : t('Make a team of up to 5 friends and win together.', 'اعمل فريق لحد 5 صحاب واكسبوا مع بعض.'),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12, height: 1.3)),
            ])),
            Icon(widget.isArabic ? Icons.chevron_left : Icons.chevron_right, color: muted),
          ]),
        ),
      )),
    );
  }
}

/// صفحة الدوري (من صفحة الجولة أو من لينك الدعوة ?b=CODE)
/// owner 28 Nov: one league per arena → [arena] = 'LOCAL' | 'WORLD' (null = the last one opened, else Egypt)
Widget badgerLeaguePage({String? joinCode, String? arena}) {
  final ar = AppLang.isArabic;
  return Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: _BLeaguePage(isArabic: ar, joinCode: joinCode, arena: arena));
}

/// opens the league page on the root navigator (used by the announcement from the feed / home too)
Future<void> openBadgerLeague(BuildContext context, {String? arena}) async {
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => badgerLeaguePage(arena: arena)));
  BLeagueInfo.clear();
}

class _BLeaguePage extends StatefulWidget {
  const _BLeaguePage({required this.isArabic, this.joinCode, this.arena});
  final bool isArabic;
  final String? joinCode;
  final String? arena;
  @override
  State<_BLeaguePage> createState() => _BLeaguePageState();
}

/// table first page kept on the phone (it only changes when a round is closed) → no DB call on every open
class _BLBoardCache {
  static String? month;
  static String? arena;
  static String lastArena = 'LOCAL';
  static DateTime? at;
  static List<Map<String, dynamic>> items = [];
  static bool more = false;
  static int total = 0;
  static Map<String, dynamic>? mine;
  static bool get fresh => at != null && DateTime.now().difference(at!) < const Duration(minutes: 10);
  static void clear() { at = null; }
}

class _BLeaguePageState extends State<_BLeaguePage> {
  Map<String, dynamic>? _home;
  BLeagueInfo? _info;
  late String _arena = widget.arena ?? _BLBoardCache.lastArena;
  Map<String, dynamic>? _mine;            // my team's row in the table (rank null = not in the table yet)
  int _minMembers = 2;
  final Set<int> _animated = {};          // table rows that already played their entrance
  int _animFrom = 0;
  bool _loading = true, _failed = false;
  int _tab = 0; // 0 فريقي · 1 الترتيب
  final List<Map<String, dynamic>> _board = [];
  bool _boardMore = false, _boardBusy = false;
  int _boardTotal = 0;
  bool get ar => widget.isArabic;
  String t(String en, String a) => ar ? a : en;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.joinCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinFlow(widget.joinCode!));
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final info = await BLeagueInfo.load(force: true);
      if (info == null) throw 'no_info';
      if (!mounted) return;
      setState(() { _info = info; _home = _homeOf(info, _arena); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  static const _page = 20;

  /// the old one-league shape, built for one arena
  Map<String, dynamic> _homeOf(BLeagueInfo info, String a) {
    final x = info.arena(a);
    final prize = Map<String, dynamic>.from(x['prize'] as Map? ?? const {});
    return {
      'month': info.month, 'arena': a, 'started': info.started, 'state': info.state,
      'icons': info.raw['icons'], 'colors': info.raw['colors'],
      'team': x['team'], 'per_member': prize['per_member_egp'],
      'prize_ar': prize['prize_ar'], 'prize_en': prize['prize_en'],
    };
  }

  void _setArena(String a) {
    if (a == _arena || _info == null) return;
    HapticFeedback.selectionClick();
    _BLBoardCache.lastArena = a;
    setState(() {
      _arena = a; _home = _homeOf(_info!, a);
      _board.clear(); _animated.clear(); _mine = null; _boardTotal = 0; _boardMore = false;
    });
    if (_tab == 1) _loadBoard();
  }

  Future<void> _loadBoard({bool reset = false}) async {
    if (_boardBusy) return;
    final month = _home?['month'] as String?;
    // first open of the tab: use the copy on the phone when it is fresh
    if (!reset && _board.isEmpty && _BLBoardCache.fresh && _BLBoardCache.month == month && _BLBoardCache.arena == _arena) {
      setState(() {
        _board.addAll(_BLBoardCache.items);
        _boardMore = _BLBoardCache.more; _boardTotal = _BLBoardCache.total; _mine = _BLBoardCache.mine;
        _animFrom = 0; _animated.clear();
      });
      return;
    }
    _boardBusy = true;
    if (reset) { _board.clear(); _animated.clear(); }
    setState(() {});
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('badger_league_board', params: {'p': {'offset': _board.length, 'limit': _page, 'arena': _arena}}) as Map);
      if (!mounted) return;
      setState(() {
        _animFrom = _board.length;
        _board.addAll(((r['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
        _boardMore = r['has_more'] == true;
        _boardTotal = (r['total'] as num?)?.toInt() ?? 0;
        _mine = r['mine'] is Map ? Map<String, dynamic>.from(r['mine'] as Map) : null;
        _minMembers = (r['min_members'] as num?)?.toInt() ?? _minMembers;
      });
      _BLBoardCache.month = r['month'] as String?;
      _BLBoardCache.arena = _arena;
      _BLBoardCache.at = DateTime.now();
      _BLBoardCache.items = List.of(_board);
      _BLBoardCache.more = _boardMore;
      _BLBoardCache.total = _boardTotal;
      _BLBoardCache.mine = _mine;
    } catch (_) {} finally { _boardBusy = false; if (mounted) setState(() {}); }
  }

  /// my place in the table: one small call for the 11 rows around my rank
  Future<void> _showAround() async {
    final m = _mine;
    final rank = (m?['rank'] as num?)?.toInt();
    if (m == null || rank == null) { setState(() => _tab = 0); return; }
    List<Map<String, dynamic>> rows = [];
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('badger_league_board',
          params: {'p': {'offset': math.max(0, rank - 6), 'limit': 11, 'arena': _arena}}) as Map);
      rows = ((r['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (!mounted || rows.isEmpty) return;
    showModalBottomSheet<void>(
      context: context, useRootNavigator: true, useSafeArea: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text(t('Your place in the table', 'مكانك في الترتيب'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            StaggerIn(index: i, gate: false, dy: 14, stepMs: 45, child: _boardRow(rows[i], rows[i]['id'] == m['id'])),
        ]),
      )),
    );
  }

  Map? get _team => _home?['team'] as Map?;
  int get _min => (_team?['min_members'] as num?)?.toInt() ?? _minMembers;
  List<String> get _icons => ((_home?['icons'] as List?)?.map((e) => '$e').toList()) ?? _kBLIcons;
  List<String> get _colors => ((_home?['colors'] as List?)?.map((e) => '$e').toList()) ?? _kBLColors;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ── إنشاء / تعديل ──
  Future<void> _editTeam({Map? team}) async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, useRootNavigator: true, useSafeArea: true,
      backgroundColor: const Color(0xFF121317),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
          child: _BLTeamForm(isArabic: ar, icons: _icons, colors: _colors, team: team, arena: _arena)),
    );
    if (res != null && mounted) {
      setState(() { _home = {...?_home, 'team': res}; _tab = 0; });
      _BLBoardCache.clear(); _board.clear(); _lsAt = null; BLeagueInfo.clear();
      if (team == null) _invite(res);
      BLeagueInfo.load(force: true).then((i) { if (i != null && mounted) _info = i; });
    }
  }

  // ── انضمام بالكود ──
  Future<void> _askCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      backgroundColor: cardBg,
      title: Text(t('Join with a code', 'انضم بكود'), style: const TextStyle(color: Colors.white, fontSize: 17)),
      content: TextField(controller: ctrl, autofocus: true, maxLength: 6, textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w900),
          decoration: InputDecoration(hintText: 'ABC123', hintStyle: const TextStyle(color: muted), counterText: '',
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: line)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _blGold)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('Cancel', 'إلغاء'), style: const TextStyle(color: muted))),
        TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim().toUpperCase()),
            child: Text(t('Next', 'التالي'), style: const TextStyle(color: _blGold, fontWeight: FontWeight.w800))),
      ],
    ));
    if (code != null && code.length == 6) _joinFlow(code);
  }

  Future<void> _joinFlow(String code) async {
    try {
      final p = Map<String, dynamic>.from(await _sb.rpc('badger_league_preview', params: {'p_code': code}) as Map);
      if (!mounted) return;
      if (p['error'] != null) { _snack(_blErr(p['error'] as Object, ar)); return; }
      if (p['my_team'] != null) {
        _snack(p['my_team'] == p['id'] ? t("You're already in this team.", 'إنت في الفريق ده أصلًا.') : _blErr('already_in_team', ar));
        return;
      }
      final n = (p['members'] as num?)?.toInt() ?? 0;
      if (n >= 5) { _snack(_blErr('team_full', ar)); return; }
      final cap = (p['captain'] as Map?)?['name'] ?? '';
      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        backgroundColor: cardBg,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          LeagueShield(icon: '${p['icon']}', color: '${p['color']}', size: 56),
          const SizedBox(height: 10),
          Text('${p['name']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(t('Captain: $cap · $n/5', 'الكابتن: $cap · $n/5'), style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(p['arena'] == 'WORLD' ? t('🌍 World league', '🌍 دوري العالم') : t('🇪🇬 Egypt league', '🇪🇬 دوري مصر'),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(t('Once you join you stay in this team all month (this arena).', 'أول ما تنضم هتفضل في الفريق ده الشهر كله (في الأرينا دي).'),
              textAlign: TextAlign.center, style: const TextStyle(color: _blGold, fontSize: 12.5, height: 1.4)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel', 'إلغاء'), style: const TextStyle(color: muted))),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: Text(t('Join ✓', 'انضم ✓'), style: const TextStyle(color: _blGold, fontWeight: FontWeight.w900))),
        ],
      ));
      if (ok != true || !mounted) return;
      final r = Map<String, dynamic>.from(await _sb.rpc('badger_league_join', params: {'p_code': code}) as Map);
      if (!mounted) return;
      if (r['error'] != null) { _snack(_blErr(r['error'] as Object, ar)); return; }
      HapticFeedback.mediumImpact();
      final ja = '${r['arena'] ?? _arena}';
      _BLBoardCache.lastArena = ja;
      setState(() { _arena = ja; _home = {...?_home, 'arena': ja, 'team': r}; _tab = 0; });
      _BLBoardCache.clear(); _board.clear(); _lsAt = null; BLeagueInfo.clear();
      BLeagueInfo.load(force: true).then((i) { if (i != null && mounted) _info = i; });
      _snack(t('Welcome to ${r['name']}! 🥇', 'أهلًا بيك في ${r['name']}! 🥇'));
    } catch (e) {
      if (mounted) _snack(_blErr(e, ar));
    }
  }

  void _invite(Map team) {
    final code = team['code'];
    if (code == null) return;
    final name = team['name'];
    final w = team['arena'] == 'WORLD';
    Share.share(t('Join my team "$name" in the Badger League ${w ? '🌍 World' : '🇪🇬 Egypt'} 🥇\nCode: $code\n${Brand.shareLinkBase}?b=$code',
        'انضم لفريقي "$name" في دوري بادجر ${w ? '🌍 العالم' : '🇪🇬 مصر'} 🥇\nالكود: $code\n${Brand.shareLinkBase}?b=$code'));
  }

  @override
  Widget build(BuildContext context) {
    final per = (_home?['per_member'] as num?)?.toInt();
    final prize = per != null
        ? t('${blMoney(per)} EGP for every member of the #1 team', '${blMoney(per)} جنيه لكل عضو في الفريق الأول')
        : (ar ? (_home?['prize_ar']) : (_home?['prize_en']));
    final started = _home?['started'] != false;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: _loading && _home == null
          ? const Center(child: CircularProgressIndicator(color: _blGold))
          : _failed && _home == null
              ? Center(child: TextButton(onPressed: _load, child: Text(t('Retry', 'إعادة'), style: const TextStyle(color: _blGold))))
              : Column(children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [
                    IconButton(onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(backgroundColor: cardBg, side: BorderSide(color: line)),
                        icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t('🥇 Badger League', '🥇 دوري بادجر'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                      Text(started ? _blMonthName(_home?['month'] as String?, ar)
                              : '${_blMonthName(_home?['month'] as String?, ar)} · ${_info != null ? blStartLine(_info!) : ''}',
                          style: TextStyle(color: started ? muted : _blGold, fontSize: 12, fontWeight: started ? FontWeight.w400 : FontWeight.w800)),
                    ])),
                    if (_info != null) GestureDetector(
                      onTap: () => showBLAnnouncement(context, onOpen: (a) async => _setArena(a)),
                      child: Container(width: 40, height: 40, alignment: Alignment.center,
                        decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle, border: Border.all(color: line)),
                        child: const Text('?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)))),
                  ])),
                  Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [
                    for (final (a, f, l) in [('LOCAL', '🇪🇬', t('Egypt', 'مصر')), ('WORLD', '🌍', t('World', 'العالم'))]) ...[
                      if (a == 'WORLD') const SizedBox(width: 8),
                      Expanded(child: GestureDetector(onTap: () => _setArena(a), child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _arena == a ? _blGold.withValues(alpha: 0.14) : cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _arena == a ? _blGold : line)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(f, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(l, style: TextStyle(color: _arena == a ? Colors.white : muted, fontWeight: FontWeight.w900, fontSize: 13.5)),
                          if (_info?.team(a) != null) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 15),
                          ],
                        ]),
                      ))),
                    ],
                  ])),
                  if (prize != null && '$prize'.isNotEmpty)
                    Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: _blGold.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _blGold.withValues(alpha: 0.5))),
                      child: Text('🎁 $prize',
                          style: const TextStyle(color: _blGold, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.35)),
                    )),
                  Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
                    child: Stack(children: [
                      // the selected pill slides between the tabs
                      Positioned.fill(child: AnimatedAlign(
                        duration: const Duration(milliseconds: 320), curve: Curves.easeOutBack,
                        alignment: _tab == 0 ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                        child: FractionallySizedBox(widthFactor: 0.5, heightFactor: 1, child: Container(
                          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _blGold.withValues(alpha: 0.35))))))),
                      Row(children: [
                        for (final (i, l) in [(0, t('My team', 'فريقي')), (1, t('Table', 'الترتيب'))])
                          Expanded(child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_tab == i) return;
                              HapticFeedback.selectionClick();
                              setState(() => _tab = i);
                              if (i == 1 && _board.isEmpty) _loadBoard();
                            },
                            child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Center(child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(color: _tab == i ? Colors.white : muted, fontWeight: FontWeight.w800, fontSize: 13.5),
                              child: Text(l)))),
                          )),
                      ]),
                    ]),
                  )),
                  Expanded(child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 340),
                    switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      // My team comes from the start side, Table from the end side
                      final fromStart = child.key == const ValueKey('bl_team');
                      final dir = (fromStart ? -1.0 : 1.0) * (ar ? -1 : 1);
                      return FadeTransition(opacity: anim, child: SlideTransition(
                        position: Tween<Offset>(begin: Offset(0.12 * dir, 0), end: Offset.zero).animate(anim), child: child));
                    },
                    child: KeyedSubtree(key: ValueKey(_tab == 0 ? 'bl_team' : 'bl_board'),
                        child: _tab == 0 ? _myTeamTab() : _boardTab()),
                  )),
                ])),
    );
  }

  // ── تاب فريقي ──
  Widget _myTeamTab() {
    final team = _team;
    if (team == null) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
          child: Column(children: [
            const PopIn(from: 0.3, child: Text('🥇', style: TextStyle(fontSize: 44))),
            const SizedBox(height: 6),
            Text(t('Play with your friends', 'العب مع صحابك'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(_arena == 'WORLD'
                    ? t('Your WORLD team: $_min to 5 friends. Your World draft points add up all month. The #1 team wins — all of you get the prize.',
                        'فريقك في العالم: من $_min لـ 5 صحاب. نقط درافت العالم بتاعتكم بتتجمع على الشهر كله، والفريق الأول يكسب وكلكم تاخدوا الجايزة.')
                    : t('Your EGYPT team: $_min to 5 friends. Your Egypt draft points add up all month. The #1 team wins — all of you get the prize.',
                        'فريقك في مصر: من $_min لـ 5 صحاب. نقط درافت مصر بتاعتكم بتتجمع على الشهر كله، والفريق الأول يكسب وكلكم تاخدوا الجايزة.'),
                textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13, height: 1.45)),
            const SizedBox(height: 16),
            Pressable(child: ShineSweep(radius: 12, child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
              onPressed: () => _editTeam(),
              style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(t('➕ Make a team', '➕ اعمل فريق'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 46, child: OutlinedButton(
              onPressed: _askCode,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(t('🔑 Join with a code', '🔑 انضم بكود'), style: const TextStyle(fontWeight: FontWeight.w800)))),
          ]),
        ),
        const SizedBox(height: 14),
        _rules(),
      ]);
    }
    return BadgerRefresh( onRefresh: _load,
        child: _BLTeamView(team: Map<String, dynamic>.from(team), isArabic: ar,
            onEdit: team['is_captain'] == true ? () => _editTeam(team: team) : null,
            onInvite: () => _invite(team), footer: _rules(), animate: true));
  }

  // ── تاب الترتيب ──
  Widget _boardTab() {
    final myId = _team?['id'];
    if (_board.isEmpty && _boardBusy) return const Center(child: CircularProgressIndicator(color: _blGold));
    final mine = _mine;
    final mineShown = mine != null && _board.any((r) => r['id'] == mine['id']);
    return Column(children: [
      Expanded(child: BadgerRefresh( onRefresh: () => _loadBoard(reset: true), child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        itemCount: _board.length + 2,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(
                t('$_boardTotal teams · a team enters with $_min players · points update when a round is closed',
                  '$_boardTotal فريق · الفريق بيدخل الترتيب من $_min لاعيبة · النقط بتتحدّث لما الجولة تتقفل'),
                style: const TextStyle(color: muted, fontSize: 12, height: 1.35)));
          }
          if (i == _board.length + 1) {
            if (!_boardMore) return const SizedBox(height: 8);
            return Padding(padding: const EdgeInsets.only(top: 12), child: Center(child: Pressable(child: OutlinedButton(
                onPressed: _boardBusy ? null : _loadBoard,
                style: OutlinedButton.styleFrom(foregroundColor: _blGold, side: BorderSide(color: _blGold.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: _boardBusy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _blGold))
                    : Text(t('Show more', 'اعرض أكتر'), style: const TextStyle(fontWeight: FontWeight.w800))))));
          }
          final idx = i - 1;
          final row = _boardRow(_board[idx], _board[idx]['id'] == myId);
          // each row plays its entrance once (first page, then each "show more" page)
          if (_animated.contains(idx)) return row;
          _animated.add(idx);
          return StaggerIn(index: (idx - _animFrom).clamp(0, 12).toInt(), gate: false, dy: 16, stepMs: 45, child: row);
        },
      ))),
      // my team, pinned under the table when it is not in the rows on screen
      if (mine != null && !mineShown)
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: StaggerIn(gate: false, delayMs: 300, dy: 30,
          child: Pressable(child: GestureDetector(onTap: _showAround, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFF1E1214), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: brandRed),
                boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 14, offset: Offset(0, -4))]),
            child: Row(children: [
              SizedBox(width: 44, child: Text(mine['rank'] != null ? '#${mine['rank']}' : '—', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5))),
              LeagueShield(icon: '${mine['icon']}', color: '${mine['color']}', size: 28),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${mine['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                Text(mine['rank'] != null ? t('Your team · tap to see your place', 'فريقك · دوس تشوف مكانك')
                        : t('Not in the table yet · invite a friend', 'لسه مش في الترتيب · اعزم صاحب'),
                    style: TextStyle(color: mine['rank'] != null ? muted : _blGold, fontSize: 11)),
              ])),
              Text(_blPts(mine['points']), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            ]),
          ))))),
    ]);
  }

  Widget _boardRow(Map<String, dynamic> r, bool mine) {
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    const medals = [Color(0xFFFFB300), Color(0xFFC0C6CF), Color(0xFFCD7F32)];
    final medal = rank >= 1 && rank <= 3 ? medals[rank - 1] : null;
    final rankBox = medal == null
        ? Text('$rank', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontWeight: FontWeight.w900, fontSize: 13.5))
        : ShineSweep(radius: 9, everyMs: 2800 + rank * 500, child: Container(
            width: 26, height: 26, alignment: Alignment.center,
            decoration: BoxDecoration(color: medal.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9), border: Border.all(color: medal)),
            child: Text('$rank', style: TextStyle(color: medal, fontWeight: FontWeight.w900, fontSize: 13))));
    return Padding(padding: const EdgeInsets.only(top: 6), child: Material(
      color: mine ? brandRed.withValues(alpha: 0.10) : cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Directionality(
            textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
            child: _BLTeamPage(teamId: '${r['id']}', isArabic: ar)))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mine ? brandRed : (medal?.withValues(alpha: 0.45) ?? line))),
          child: Row(children: [
            SizedBox(width: 34, child: Center(child: rankBox)),
            const SizedBox(width: 4),
            LeagueShield(icon: '${r['icon']}', color: '${r['color']}', size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
            Text('${r['members']}/5', style: const TextStyle(color: muted, fontSize: 11.5)),
            const SizedBox(width: 10),
            SizedBox(width: 48, child: Text(_blPts(r['points']), textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
          ]),
        ),
      ),
    ));
  }

  Widget _rules() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('How it works', 'الدوري ماشي إزاي'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      for (final l in [
        t('Egypt and World are two separate leagues: separate table, separate prize.', 'مصر والعالم دوريين منفصلين: ترتيب لوحده وجايزة لوحدها.'),
        t('A team is $_min to 5 friends. One team per player in each arena per month.', 'الفريق من $_min لـ 5 صحاب. فريق واحد بس لكل لاعيب في كل أرينا في الشهر.'),
        t('A team enters the table once it has $_min players. Until then it can not win.', 'الفريق بيدخل الترتيب لما يبقى فيه $_min لاعيبة، وقبلها مايقدرش يكسب.'),
        t("Only this arena's draft points count, every gameweek of the month.", 'نقط درافت الأرينا دي بس هي اللي بتتحسب، في كل جولات الشهر.'),
        t('You can add members any time until 5. Nobody can be removed or swapped.', 'تقدر تزوّد أعضاء في أي وقت لحد 5. ماحدش يتشال ولا يتبدّل.'),
        t('A new member counts from the first round whose deadline is after he joined.', 'العضو الجديد بيتحسب من أول جولة ديدلاينها بعد ما دخل.'),
        t('No squad in a round = 0 points.', 'اللي ماعملش تشكيلة في جولة = صفر.'),
        t('Tied? More exact score predictions, then the older team.', 'تعادل؟ اللي توقعاته للنتيجة مظبوطة أكتر، وبعدها الفريق الأقدم.'),
        t('The #1 team of the month wins: all its players get the prize.', 'الفريق الأول في الشهر يكسب، وكل لاعيبته ياخدوا الجايزة.'),
      ]) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('•  ', style: TextStyle(color: _blGold)),
        Expanded(child: Text(l, style: const TextStyle(color: muted, fontSize: 12.5, height: 1.4))),
      ])),
    ]),
  );
}

/// فريق حد تاني (من الترتيب)
class _BLTeamPage extends StatefulWidget {
  const _BLTeamPage({required this.teamId, required this.isArabic});
  final String teamId;
  final bool isArabic;
  @override
  State<_BLTeamPage> createState() => _BLTeamPageState();
}

class _BLTeamPageState extends State<_BLTeamPage> {
  Map<String, dynamic>? _t;
  @override
  void initState() {
    super.initState();
    _sb.rpc('badger_league_team', params: {'p_team': widget.teamId}).then((r) {
      if (mounted && r != null) setState(() => _t = Map<String, dynamic>.from(r as Map));
    }).catchError((_) {});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: cardBg, side: BorderSide(color: line)),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
      ])),
      Expanded(child: _t == null
          ? const Center(child: CircularProgressIndicator(color: _blGold))
          : _BLTeamView(team: _t!, isArabic: widget.isArabic)),
    ])),
  );
}

/// شكل الفريق: الدرع والاسم والنقط، وبعدين الأعضاء كأنهم لاعيبة
class _BLTeamView extends StatelessWidget {
  const _BLTeamView({required this.team, required this.isArabic, this.onEdit, this.onInvite, this.footer, this.animate = true});
  final Map<String, dynamic> team;
  final bool isArabic;
  final bool animate;
  final VoidCallback? onEdit, onInvite;
  final Widget? footer;
  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final members = ((team['members'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final rounds = ((team['rounds'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final member = team['is_member'] == true;
    final code = team['code'] as String?;
    final c = _blColor(team['color'] as String?);
    final min = (team['min_members'] as num?)?.toInt() ?? 2;
    final inTable = team['in_table'] != false && team['rank'] != null;
    var k = 0;   // entrance order
    Widget st(Widget w, {double dy = 18}) => StaggerIn(index: k++, gate: false, dy: dy, child: w);
    const statStyle = TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      st(dy: 24, Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: 0.30), cardBg]),
          border: Border.all(color: c.withValues(alpha: 0.7))),
        child: Column(children: [
          Row(children: [
            const Spacer(),
            if (onEdit != null) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20)),
          ]),
          PopIn(delayMs: 120, from: 0.4, child: LeagueShield(icon: '${team['icon']}', color: '${team['color']}', size: 66)),
          const SizedBox(height: 8),
          Text('${team['name']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _statW(CountUp((team['points'] as num?) ?? 0, style: statStyle), t('points', 'نقطة')),
            Container(width: 1, height: 30, color: line, margin: const EdgeInsets.symmetric(horizontal: 18)),
            inTable
                ? _statW(CountUp((team['rank'] as num?) ?? 0, style: statStyle, format: (v) => '#$v'), t('of ${team['teams'] ?? '-'}', 'من ${team['teams'] ?? '-'}'))
                : _statW(const Text('—', style: statStyle), t('not ranked yet', 'لسه مش في الترتيب')),
            Container(width: 1, height: 30, color: line, margin: const EdgeInsets.symmetric(horizontal: 18)),
            // members: number + a small gold bar that fills up to 5
            _statW(Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${members.length}/5', style: statStyle),
              const SizedBox(height: 4),
              SizedBox(width: 46, height: 4, child: ClipRRect(borderRadius: BorderRadius.circular(2), child: Stack(children: [
                Container(color: const Color(0xFF33363C)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: members.length / 5), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(widthFactor: v.clamp(0.0, 1.0), heightFactor: 1,
                      alignment: AlignmentDirectional.centerStart, child: Container(color: _blGold))),
              ]))),
            ]), t('members', 'أعضاء')),
          ]),
        ]),
      )),
      // not in the table yet: tell him what to do
      if (member && !inTable) ...[
        const SizedBox(height: 12),
        st(Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _blGold.withValues(alpha: 0.7)),
              gradient: const LinearGradient(colors: [Color(0xFF2A2210), cardBg])),
          child: Row(children: [
            const Text('⚠️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(
                t('Your team is not in the table yet. Invite ${min - members.length <= 1 ? 'one friend' : '${min - members.length} friends'} so it enters the league.',
                  'فريقك لسه مش في الترتيب. اعزم ${min - members.length <= 1 ? 'صاحب واحد' : '${min - members.length} صحاب'} عشان يدخل الدوري.'),
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4, fontWeight: FontWeight.w700))),
          ]),
        )),
      ],
      if (member && code != null && members.length < 5) ...[
        const SizedBox(height: 12),
        st(Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _blGold.withValues(alpha: 0.6))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Team code', 'كود الفريق'), style: const TextStyle(color: muted, fontSize: 11.5)),
              GestureDetector(
                onTap: () { Clipboard.setData(ClipboardData(text: code)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Copied ✓', 'اتنسخ ✓')))); },
                child: Text(code, textDirection: TextDirection.ltr,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4))),
            ])),
            Pressable(child: ShineSweep(radius: 12, child: ElevatedButton.icon(
              onPressed: onInvite,
              style: ElevatedButton.styleFrom(backgroundColor: _blGold, foregroundColor: Colors.black, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.ios_share, size: 17),
              label: Text(t('Invite', 'اعزم'), style: const TextStyle(fontWeight: FontWeight.w900))))),
          ]),
        )),
      ],
      const SizedBox(height: 14),
      st(Text(t('PLAYERS', 'اللاعيبة'), style: const TextStyle(color: muted, fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w800))),
      const SizedBox(height: 6),
      for (final m in members) st(_memberRow(context, m, rounds)),
      for (var i = members.length; i < 5; i++)
        st(Padding(padding: const EdgeInsets.only(top: 6), child: GlowPulse(
          // the first free spot breathes while the team is still too small
          on: member && !inTable && i == members.length, radius: 12, child: InkWell(
          onTap: member ? onInvite : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.add, color: muted)),
              const SizedBox(width: 12),
              Text(member ? t('Invite a friend', 'اعزم صاحب') : t('Empty spot', 'مكان فاضي'),
                  style: const TextStyle(color: muted, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        )))),
      if (footer != null) ...[const SizedBox(height: 16), footer!],
    ]);
  }

  Widget _statW(Widget v, String l) => Column(children: [
    v,
    Text(l, style: const TextStyle(color: muted, fontSize: 11.5)),
  ]);

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
    Text(l, style: const TextStyle(color: muted, fontSize: 11.5)),
  ]);

  Widget _memberRow(BuildContext context, Map<String, dynamic> m, List<Map<String, dynamic>> rounds) {
    final name = '${m['name'] ?? ''}';
    final url = m['avatar'] as String?;
    final me = m['me'] == true;
    final from = m['from_event'];
    final fromRound = from == null ? null : rounds.cast<Map?>().firstWhere((r) => r?['event_id'] == from, orElse: () => null);
    final late = fromRound != null && rounds.isNotEmpty && rounds.first['event_id'] != from;
    final letter = Center(child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)));
    return Padding(padding: const EdgeInsets.only(top: 6), child: Material(
      color: me ? brandRed.withValues(alpha: 0.10) : cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _memberRounds(context, m, rounds),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: me ? brandRed : line)),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(11)),
                child: ClipRRect(borderRadius: BorderRadius.circular(11),
                    child: (url != null && url.isNotEmpty) ? _netImage(url, width: 38, height: 38, fit: BoxFit.cover, fallback: letter) : letter)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
                if (m['captain'] == true) const Padding(padding: EdgeInsetsDirectional.only(start: 6), child: Text('👑', style: TextStyle(fontSize: 13))),
                if (me) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(8)),
                    child: Text(t('You', 'إنت'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)))),
              ]),
              if (late || fromRound == null)
                Text(fromRound == null
                      ? t('Counts from next month’s rounds', 'مفيش جولات ليه الشهر ده')
                      : t('Counts from ${fromRound['name_en']}', 'بيتحسب من ${fromRound['name_ar']}'),
                    style: const TextStyle(color: muted, fontSize: 11.5)),
            ])),
            Text(_blPts(m['points']), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    ));
  }

  // جولات العضو: كل جولة بنقطها، والدوسة بتفتح تشكيلته (بعد الديدلاين)
  void _memberRounds(BuildContext context, Map<String, dynamic> m, List<Map<String, dynamic>> rounds) {
    final by = (m['by_event'] as Map?) ?? const {};
    final joined = DateTime.tryParse('${m['joined_at']}');
    showModalBottomSheet<void>(
      context: context, useRootNavigator: true, useSafeArea: true,
      backgroundColor: const Color(0xFF121317),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => Directionality(textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr, child: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${m['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(t('Draft rounds this month', 'جولات الدرافت في الشهر ده'), style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 8),
          if (rounds.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(t('No draft rounds yet.', 'مفيش جولات درافت لسه.'),
                textAlign: TextAlign.center, style: const TextStyle(color: muted))),
          for (final r in rounds) Builder(builder: (_) {
            final dl = DateTime.tryParse('${r['deadline_at']}');
            final counts = joined == null || dl == null || joined.isBefore(dl);
            final open = r['open'] == true;
            final pts = by['${r['event_id']}'];
            final arena = r['arena'] == 'LOCAL' ? t('Local', 'محلي') : t('World', 'عالمي');
            return ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: open,
              onTap: open ? () {
                Navigator.pop(sheetCtx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => _UserSquadPage(
                    userId: '${m['user_id']}', userName: '${m['name'] ?? ''}', eventId: '${r['event_id']}',
                    roundName: isArabic ? '${r['name_ar']}' : '${r['name_en']}', username: m['username'] as String?,
                    avatarUrl: m['avatar'] as String?, points: pts, isArabic: isArabic, draft: true)));
              } : null,
              title: Text('${isArabic ? r['name_ar'] : r['name_en']} · $arena',
                  style: TextStyle(color: open ? Colors.white : muted, fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(!counts
                    ? t("Before he joined (doesn't count)", 'قبل ما يدخل (مش بتتحسب)')
                    : !open ? t('Squad shows after the deadline', 'التشكيلة بتبان بعد الديدلاين')
                    : r['finished'] == true ? t('Final', 'نهائي') : t('Points come when the round is closed', 'النقط بتنزل لما الجولة تتقفل'),
                  style: const TextStyle(color: muted, fontSize: 11.5)),
              trailing: Text(counts && pts != null ? _blPts(pts) : '—',
                  style: TextStyle(color: counts ? Colors.white : muted, fontSize: 15, fontWeight: FontWeight.w900)),
            );
          }),
        ]),
      ))),
    );
  }
}

/// فورم الإنشاء / التعديل: الاسم + الرمز + اللون، ومعاينة الدرع
class _BLTeamForm extends StatefulWidget {
  const _BLTeamForm({required this.isArabic, required this.icons, required this.colors, this.team, this.arena = 'LOCAL'});
  final String arena;
  final bool isArabic;
  final List<String> icons, colors;
  final Map? team;
  @override
  State<_BLTeamForm> createState() => _BLTeamFormState();
}

class _BLTeamFormState extends State<_BLTeamForm> {
  late final TextEditingController _name = TextEditingController(text: widget.team?['name'] as String? ?? '');
  late String _icon = widget.team?['icon'] as String? ?? widget.icons.first;
  late String _color = (widget.team?['color'] as String? ?? widget.colors.first).toUpperCase();
  bool _busy = false;
  String? _err;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.length < 2) { setState(() => _err = _blErr('bad_name', widget.isArabic)); return; }
    setState(() { _busy = true; _err = null; });
    try {
      final edit = widget.team != null;
      final r = await _sb.rpc(edit ? 'badger_league_update' : 'badger_league_create', params: {'p': {
        if (edit) 'team_id': widget.team!['id'], if (!edit) 'arena': widget.arena, 'name': name, 'icon': _icon, 'color': _color}});
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) setState(() { _busy = false; _err = _blErr(e, widget.isArabic); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Text(widget.team == null ? t('New team', 'فريق جديد') : t('Edit team', 'تعديل الفريق'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Center(child: LeagueShield(icon: _icon, color: _color, size: 72)),
        const SizedBox(height: 8),
        Center(child: Text(_name.text.trim().isEmpty ? t('Team name', 'اسم الفريق') : _name.text.trim(),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
        const SizedBox(height: 14),
        TextField(
          controller: _name, maxLength: 24, onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            labelText: t('Team name', 'اسم الفريق'), labelStyle: const TextStyle(color: muted),
            counterStyle: const TextStyle(color: muted),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blGold))),
        ),
        const SizedBox(height: 6),
        Text(t('Symbol', 'الرمز'), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final i in widget.icons) GestureDetector(
            onTap: () => setState(() => _icon = i),
            child: Container(width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _icon == i ? _blGold : line, width: _icon == i ? 1.6 : 1)),
              child: Text(i, style: const TextStyle(fontSize: 21))),
          ),
        ]),
        const SizedBox(height: 14),
        Text(t('Colour', 'اللون'), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in widget.colors) GestureDetector(
            onTap: () => setState(() => _color = c.toUpperCase()),
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: _blColor(c), shape: BoxShape.circle,
                  border: Border.all(color: _color == c.toUpperCase() ? Colors.white : Colors.transparent, width: 2.5))),
          ),
        ]),
        if (_err != null) ...[const SizedBox(height: 12), Text(_err!, style: const TextStyle(color: brandRed, fontSize: 13))],
        const SizedBox(height: 16),
        SizedBox(height: 50, child: ElevatedButton(
          onPressed: _busy ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
              : Text(widget.team == null ? t('Create team', 'اعمل الفريق') : t('Save', 'حفظ'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))),
      ])),
    );
  }
}
