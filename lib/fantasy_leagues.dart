part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// تاب الليجز: ليجزي + اعمل ليج + ادخل بكود + الوارد (دعوات/طلبات)
// صفحة الليج: الترتيب (أسبوع/شهر/موسم) + الأعضاء + إدارة صاحب الليج
// كل الصلاحيات بتتأكد في السيرفر
// ═══════════════════════════════════════════════════════════════════════════

String _leagueErr(Object e, bool ar) {
  final m = e.toString();
  String t(String en, String a) => ar ? a : en;
  if (m.contains('name_too_short') || m.contains('invalid_name')) return t('Name must be 2–40 characters.', 'الاسم لازم من 2 لـ 40 حرف.');
  if (m.contains('name_too_long')) return t('Name is too long (max 40).', 'الاسم طويل (40 حرف بالكتير).');
  if (m.contains('too_many_leagues')) return t('You can create up to 10 leagues.', 'تقدر تعمل 10 ليجز بالكتير.');
  if (m.contains('league_full')) return t('This league is full.', 'الليج دي مليانة.');
  if (m.contains('invite_limit_reached')) return t('Invite limit reached for today (50).', 'وصلت لحد الدعوات النهارده (50).');
  if (m.contains('already_member')) return t('Already a member.', 'عضو بالفعل.');
  if (m.contains('owner_must_transfer_or_delete')) return t('Transfer or delete the league first.', 'انقل الليج لحد أو امسحها الأول.');
  if (m.contains('not_league_owner')) return t('Only the league owner can do this.', 'صاحب الليج بس يقدر يعمل كده.');
  if (m.contains('invalid_visibility')) return t('Pick who can see the league.', 'اختار مين يشوف الليج.');
  if (m.contains('new_owner_has_too_many_leagues')) return t('That member already owns 10 leagues.', 'العضو ده عنده 10 ليجز بالفعل.');
  return t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.');
}

class FantasyLeaguesTab extends StatefulWidget {
  final bool isArabic;
  const FantasyLeaguesTab({super.key, required this.isArabic});
  @override
  State<FantasyLeaguesTab> createState() => _FantasyLeaguesTabState();
}

class _FantasyLeaguesTabState extends State<FantasyLeaguesTab> {
  List<Map<String, dynamic>> _leagues = [];
  Map<String, dynamic>? _inbox;
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _top = [];   // كل الليجز: أول 5 (الأكبر عدد)
  int _topTotal = 0;
  String _scope = 'all';   // all | member | following | followers
  bool _topLoading = false;
  bool _loading = true;
  String? _error;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = _leagues.isEmpty; _error = null; });
    try {
      final r = await Future.wait([
        _sb.rpc('league_my_list'),
        _sb.rpc('league_inbox'),
        _sb.rpc('league_directory', params: {'p': {'limit': 5, 'scope': _scope}}).catchError((_) => null),
        if (_cats.isEmpty) _sb.rpc('league_categories'),
      ]);
      if (!mounted) return;
      setState(() {
        _leagues = ((r[0] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _inbox = Map<String, dynamic>.from(r[1] as Map);
        if (r[2] is Map) {
          final dir = Map<String, dynamic>.from(r[2] as Map);
          _top = ((dir['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _topTotal = (dir['total'] as num?)?.toInt() ?? 0;
        }
        if (r.length > 3) _cats = ((r[3] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  int get _inboxCount =>
      ((_inbox?['invites'] as List?)?.length ?? 0) + ((_inbox?['requests'] as List?)?.length ?? 0);

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: brandRed));
    return RefreshIndicator(
      color: brandRed,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        const AdSlot('fantasy_leagues', padding: EdgeInsets.only(bottom: 12)),
        // الوارد
        if (_inboxCount > 0) ...[
          InkWell(
            onTap: _openInbox,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0F2233), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5AA9FF).withOpacity(0.5))),
              child: Row(children: [
                const Text('📥', style: TextStyle(fontSize: 22)), const SizedBox(width: 10),
                Expanded(child: Text(_inboxLine(), style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(10)),
                  child: Text('$_inboxCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // زرارين
        Row(children: [
          Expanded(child: _actionBtn('➕', t('Create league', 'اعمل ليج'), _openCreate, primary: true)),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn('🔑', t('Join with code', 'ادخل بكود'), _openJoin)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Text(t('MY LEAGUES', 'ليجزي'), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(width: 6),
          Text('${_leagues.length}', style: const TextStyle(color: muted, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(20), child: Text(t('Could not load leagues.', 'مش قادرين نحمّل الليجز.'), textAlign: TextAlign.center, style: const TextStyle(color: muted)))
        else if (_leagues.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
            child: Column(children: [
              const Text('🏟️', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 8),
              Text(t('Play with your friends', 'العب مع صحابك'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(t('Create a league and share the code, or join one with a code.', 'اعمل ليج وابعت الكود لصحابك، أو ادخل ليج بكود.'),
                textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13)),
            ]),
          )
        else
          for (final l in _leagues) _leagueCard(l),
        // كل الليجز (الأكبر عدد الأول)
        if (_top.isNotEmpty || _scope != 'all') ...[
          const SizedBox(height: 18),
          Row(children: [
            Text(t('ALL LEAGUES', 'كل الليجز'), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(width: 6),
            Text('$_topTotal', style: const TextStyle(color: muted, fontSize: 12)),
            const Spacer(),
            _FilterMenu(value: _scope, items: _scopeItems(widget.isArabic), onChanged: _setScope),
          ]),
          const SizedBox(height: 10),
          if (_topLoading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: brandRed))))
          else if (_top.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_scopeEmpty(_scope, widget.isArabic), textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13)))
          else for (final l in _top)
            _DirLeagueCard(l: l, isArabic: widget.isArabic, catName: _catName(l['category']),
              onOpen: () => _openLeague(l['league_id'] as String),
              onJoined: (id) async { await _load(); if (mounted) _openLeague(id); }),
          const SizedBox(height: 4),
          SizedBox(height: 44, child: OutlinedButton(
            onPressed: _openDirectory,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(t('See all leagues', 'شوف كل الليجز'), style: const TextStyle(fontWeight: FontWeight.w900)))),
        ],
      ]),
    );
  }

  Future<void> _openDirectory() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        _LeagueDirectoryPage(isArabic: widget.isArabic, categories: _cats, initialScope: _scope)));
    _load();
  }

  Future<void> _setScope(String v) async {
    if (v == _scope) return;
    setState(() { _scope = v; _topLoading = true; });
    try {
      final dir = Map<String, dynamic>.from(await _sb.rpc('league_directory', params: {'p': {'limit': 5, 'scope': v}}) as Map);
      if (!mounted || v != _scope) return;
      setState(() {
        _top = ((dir['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _topTotal = (dir['total'] as num?)?.toInt() ?? 0;
        _topLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _topLoading = false);
    }
  }

  String _inboxLine() {
    final inv = (_inbox?['invites'] as List?)?.length ?? 0;
    final req = (_inbox?['requests'] as List?)?.length ?? 0;
    final parts = <String>[
      if (inv > 0) t('$inv invite${inv > 1 ? 's' : ''}', inv == 1 ? 'دعوة' : '$inv دعوات'),
      if (req > 0) t('$req join request${req > 1 ? 's' : ''}', req == 1 ? 'طلب رجوع' : '$req طلبات رجوع'),
    ];
    return t('You have ', 'عندك ') + parts.join(t(' and ', ' و'));
  }

  Widget _actionBtn(String icon, String label, VoidCallback onTap, {bool primary = false}) => SizedBox(height: 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? brandRed : cardBg, foregroundColor: Colors.white, elevation: 0,
        side: primary ? null : const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5))),
      ]),
    ));

  Widget _leagueCard(Map<String, dynamic> l) {
    final owner = l['is_owner'] == true;
    final pending = (l['pending_requests'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openLeague(l['league_id'] as String),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: owner ? _gold.withOpacity(0.4) : line)),
          child: Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(13)),
              child: Text('${l['icon']}', style: const TextStyle(fontSize: 24))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('${l['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
                if (owner) const Padding(padding: EdgeInsetsDirectional.only(start: 6), child: Text('👑', style: TextStyle(fontSize: 13))),
              ]),
              const SizedBox(height: 2),
              Text('${_catName(l['category'])} · ${t('${l['members']} members', '${l['members']} عضو')}',
                style: const TextStyle(color: muted, fontSize: 12)),
            ])),
            if (pending > 0) Container(
              margin: const EdgeInsetsDirectional.only(end: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(10)),
              child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ]),
        ),
      ),
    );
  }

  String _catName(dynamic key) {
    final c = _cats.cast<Map<String, dynamic>?>().firstWhere((x) => x?['key'] == key, orElse: () => null);
    if (c == null) return t('General', 'عامة');
    return widget.isArabic ? '${c['ar']}' : '${c['en']}';
  }

  Future<void> _openLeague(String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        _LeaguePage(leagueId: id, isArabic: widget.isArabic, categories: _cats)));
    _load();
  }

  // ─── اعمل ليج ──────────────────────────────────────────────────────────
  Future<void> _openCreate() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LeagueFormSheet(isArabic: widget.isArabic, categories: _cats),
    );
    if (res == null || !mounted) return;
    await _load();
    if (!mounted) return;
    _showCode(res['name']?.toString() ?? '', res['invite_code']?.toString() ?? '', res['icon']?.toString() ?? '🏆', created: true);
  }

  void _showCode(String name, String code, String icon, {bool created = false}) {
    showModalBottomSheet<void>(
      context: context, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          Text(created ? t('League created! 🎉', 'الليج اتعملت! 🎉') : name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(t('Send this code to your friends', 'ابعت الكود ده لصحابك'), style: const TextStyle(color: muted)),
          const SizedBox(height: 14),
          _CodeBox(code: code, isArabic: widget.isArabic, leagueName: name),
        ]),
      )),
    );
  }

  // ─── ادخل بكود ─────────────────────────────────────────────────────────
  Future<void> _openJoin() async {
    final ctrl = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Join a league', 'ادخل ليج'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(t('Enter the 6-character code your friend sent you.', 'اكتب الكود (6 حروف) اللي صاحبك بعتهولك.'), style: const TextStyle(color: muted)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl, autofocus: true, maxLength: 6, textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 6),
            decoration: InputDecoration(counterText: '', filled: true, fillColor: cardBg, hintText: 'ABC123',
              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line))),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 48, child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(t('Join', 'ادخل'), style: const TextStyle(fontWeight: FontWeight.w900)))),
        ]),
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('join_fantasy_league', params: {'p_code': code.trim()}) as Map);
      final st = r['status']?.toString();
      final msg = switch (st) {
        'joined' => t('You joined the league! 🎉', 'دخلت الليج! 🎉'),
        'already_member' => t("You're already in this league.", 'إنت في الليج دي بالفعل.'),
        'requested' => t('You were removed from this league before — a request was sent to the owner.', 'إنت اتشلت من الليج دي قبل كده — اتبعت طلب لصاحبها.'),
        'pending' => t('Your request is still waiting for the owner.', 'طلبك لسه مستني رد صاحب الليج.'),
        'blocked' => t("You can't join this league.", 'مش هتقدر تدخل الليج دي.'),
        'league_full' => t('This league is full.', 'الليج دي مليانة.'),
        'too_many_attempts' => t('Too many wrong codes. Try again in an hour.', 'كودات غلط كتير. جرّب تاني بعد ساعة.'),
        _ => t('Wrong code. Check it and try again.', 'الكود غلط. اتأكد منه وجرّب تاني.'),
      };
      _snack(msg);
      if (st == 'joined') {
        await _load();
        if (r['league_id'] != null && mounted) _openLeague(r['league_id'] as String);
      }
    } catch (e) {
      _snack(_leagueErr(e, widget.isArabic));
    }
  }

  // ─── الوارد ────────────────────────────────────────────────────────────
  Future<void> _openInbox() async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InboxSheet(isArabic: widget.isArabic),
    );
    _load();
  }
}

// ─── الكود: نسخ + مشاركة ────────────────────────────────────────────────
class _CodeBox extends StatelessWidget {
  final String code, leagueName;
  final bool isArabic;
  final VoidCallback? onReset;
  const _CodeBox({required this.code, required this.isArabic, required this.leagueName, this.onReset});

  /// الدعوة: يختار لغة الرسالة الأول، والرسالة فيها لينك بيفتح التطبيق ويدخّله الليج
  Future<void> _shareInvite(BuildContext context) async {
    String t(String en, String ar) => isArabic ? ar : en;
    final lang = await showModalBottomSheet<String>(
      context: context, backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 14),
        Text(t('Send the invite in…', 'تبعت الدعوة بـ…'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Row(children: [
          for (final o in const [('ar', 'العربي', '🇪🇬'), ('en', 'English', '🌍')]) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, o.$1),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: line),
                padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Column(children: [
                Text(o.$3, style: const TextStyle(fontSize: 22)), const SizedBox(height: 4),
                Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
              ])))),
        ]),
      ]))),
    );
    if (lang == null) return;
    final link = Brand.leagueShareLink(code);
    final text = lang == 'ar'
        ? '🏆 تعالى ادخل ليج "$leagueName" بتاعتي على BDGR فانتازي!\n'
          'نلعب كل أسبوع ونشوف مين فينا الأحسن 💪\n\n'
          'ادخل من هنا: $link\n'
          'أو اكتب الكود: $code'
        : '🏆 Join my BDGR Fantasy league "$leagueName"!\n'
          "Let's play every week and see who's the best 💪\n\n"
          'Join here: $link\n'
          'Or enter the code: $code';
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String ar) => isArabic ? ar : en;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Row(children: [
        Expanded(child: SelectableText(code, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 5))),
        IconButton(
          tooltip: t('Copy', 'نسخ'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Code copied', 'الكود اتنسخ'))));
          },
          icon: const Icon(Icons.copy_rounded, color: Colors.white70)),
        IconButton(
          tooltip: t('Share', 'مشاركة'),
          onPressed: () => _shareInvite(context),
          icon: const Icon(Icons.ios_share_rounded, color: Brand.green)),
        if (onReset != null)
          IconButton(tooltip: t('New code', 'كود جديد'), onPressed: onReset, icon: const Icon(Icons.refresh_rounded, color: muted)),
      ]),
    );
  }
}

// ─── عمل / تعديل ليج: الاسم + النوع ─────────────────────────────────────
class _LeagueFormSheet extends StatefulWidget {
  final bool isArabic;
  final List<Map<String, dynamic>> categories;
  final String? leagueId, initialName, initialCategory, initialVisibility;
  const _LeagueFormSheet({required this.isArabic, required this.categories, this.leagueId, this.initialName, this.initialCategory, this.initialVisibility});
  @override
  State<_LeagueFormSheet> createState() => _LeagueFormSheetState();
}

class _LeagueFormSheetState extends State<_LeagueFormSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName ?? '');
  late String _cat = widget.initialCategory ?? 'general';
  late String _vis = widget.initialVisibility ?? 'public';   // public | followers | private
  bool _busy = false;
  String? _err;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _save() async {
    setState(() { _busy = true; _err = null; });
    try {
      final r = widget.leagueId == null
          ? await _sb.rpc('league_create', params: {'p_name': _name.text, 'p_category': _cat})
          : await _sb.rpc('league_update', params: {'p_league_id': widget.leagueId, 'p_name': _name.text, 'p_category': _cat});
      final id = widget.leagueId ?? (r as Map)['league_id']?.toString();
      final changed = widget.leagueId == null ? _vis != 'public' : _vis != (widget.initialVisibility ?? 'public');
      if (id != null && changed) {
        await _sb.rpc('league_set_visibility', params: {'p_league_id': id, 'p_visibility': _vis});
      }
      if (!mounted) return;
      Navigator.pop(context, {...Map<String, dynamic>.from(r as Map), 'name': _name.text.trim()});
    } catch (e) {
      if (mounted) setState(() { _busy = false; _err = _leagueErr(e, widget.isArabic); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories.isEmpty
        ? [{'key': 'general', 'icon': '🏆', 'ar': 'عامة', 'en': 'General'}]
        : widget.categories;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.leagueId == null ? t('Create a league', 'اعمل ليج') : t('Edit league', 'تعديل الليج'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Text(t('League name', 'اسم الليج'), style: const TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _name, maxLength: 40, autofocus: widget.leagueId == null,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          decoration: InputDecoration(filled: true, fillColor: cardBg, hintText: t('e.g. Work friends', 'مثلاً: صحاب الشغل'),
            hintStyle: const TextStyle(color: Colors.white24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line))),
        ),
        const SizedBox(height: 6),
        Text(t('Type', 'النوع'), style: const TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in cats)
            GestureDetector(
              onTap: () => setState(() => _cat = '${c['key']}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _cat == c['key'] ? Brand.green.withOpacity(0.14) : cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cat == c['key'] ? Brand.green : line)),
                child: Text('${c['icon']}  ${widget.isArabic ? c['ar'] : c['en']}',
                  style: TextStyle(color: _cat == c['key'] ? Brand.green : Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Text(t('Who can see it', 'مين يشوف الليج'), style: const TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final (key, icon, title, sub) in [
          ('public', '🌍', t('Everyone', 'الكل'), t('Shows in "All leagues". Anyone can join.', 'بتظهر في "كل الليجز"، وأي حد يقدر يدخل.')),
          ('followers', '👥', t('My followers', 'المتابعين بس'), t('Only people who follow you see it and join.', 'بس اللي متابعينك يشوفوها ويدخلوا.')),
          ('private', '🔒', t('Private', 'برايفت'), t('Hidden. Join with the code or an invite only.', 'مخفية. الدخول بالكود أو بدعوة بس.')),
        ])
          Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(
            onTap: () => setState(() => _vis = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _vis == key ? Brand.green.withOpacity(0.12) : cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _vis == key ? Brand.green : line)),
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: _vis == key ? Brand.green : Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                  Text(sub, style: const TextStyle(color: muted, fontSize: 11.5)),
                ])),
                Icon(_vis == key ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: _vis == key ? Brand.green : muted),
              ]),
            ),
          )),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: const TextStyle(color: Color(0xFFFF6B6B)))),
        const SizedBox(height: 16),
        SizedBox(height: 48, child: ElevatedButton(
          onPressed: _busy ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_busy ? t('Saving…', 'بنحفظ…') : (widget.leagueId == null ? t('Create', 'اعمل الليج') : t('Save', 'حفظ')),
            style: const TextStyle(fontWeight: FontWeight.w900)))),
      ])),
    );
  }
}

// ─── الوارد: دعوات ليا + طلبات رجوع لليجزي ──────────────────────────────
class _InboxSheet extends StatefulWidget {
  final bool isArabic;
  const _InboxSheet({required this.isArabic});
  @override
  State<_InboxSheet> createState() => _InboxSheetState();
}

class _InboxSheetState extends State<_InboxSheet> {
  Map<String, dynamic>? _d;
  String? _busy;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await _sb.rpc('league_inbox');
      if (mounted) setState(() => _d = Map<String, dynamic>.from(r as Map));
    } catch (_) {}
  }

  Future<void> _act(String id, Future<dynamic> Function() f, String done) async {
    setState(() => _busy = id);
    try {
      await f();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_leagueErr(e, widget.isArabic))));
    }
    await _load();
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final inv = ((_d?['invites'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final req = ((_d?['requests'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final mine = ((_d?['my_requests'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    Widget head(String s) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(s, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)));
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7, maxChildSize: 0.92,
      builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text(t('📥 Inbox', '📥 الوارد'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        if (_d == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: brandRed))),
        if (inv.isNotEmpty) head(t('INVITES', 'دعوات ليك')),
        for (final i in inv) _card(
          icon: '${i['icon']}',
          title: '${i['league_name']}',
          sub: t('${i['invited_by'] ?? 'Someone'} invited you · ${i['members']} members', '${i['invited_by'] ?? 'حد'} بعتلك دعوة · ${i['members']} عضو'),
          busy: _busy == i['invite_id'],
          actions: [
            _btn(t('Join', 'ادخل'), Brand.green, () => _act('${i['invite_id']}', () => _sb.rpc('league_invite_respond', params: {'p_invite_id': i['invite_id'], 'p_accept': true}), t('Joined 🎉', 'دخلت 🎉'))),
            _btn(t('Decline', 'رفض'), Colors.white54, () => _act('${i['invite_id']}', () => _sb.rpc('league_invite_respond', params: {'p_invite_id': i['invite_id'], 'p_accept': false}), t('Declined', 'اترفضت'))),
          ]),
        if (req.isNotEmpty) head(t('WANT TO COME BACK', 'عايزين يرجعوا')),
        for (final r in req) _card(
          icon: '${r['icon']}',
          title: '${r['display_name'] ?? '—'}  ·  ${r['league_name']}',
          sub: t('Removed ${r['times_removed']}× · declined ${r['times_declined']}× before',
                 'اتشال ${r['times_removed']} مرة · اترفض ${r['times_declined']} مرة قبل كده'),
          busy: _busy == r['request_id'],
          actions: [
            _btn(t('Accept', 'وافق'), Brand.green, () => _act('${r['request_id']}', () => _sb.rpc('league_decide_request', params: {'p_request_id': r['request_id'], 'p_decision': 'approve'}), t('Accepted', 'اتقبل'))),
            _btn(t('Decline', 'ارفض'), Colors.white54, () => _act('${r['request_id']}', () => _sb.rpc('league_decide_request', params: {'p_request_id': r['request_id'], 'p_decision': 'decline'}), t('Declined', 'اترفض'))),
            _btn(t('Block', 'بلوك'), const Color(0xFFFF6B6B), () => _act('${r['request_id']}', () => _sb.rpc('league_decide_request', params: {'p_request_id': r['request_id'], 'p_decision': 'block'}), t('Blocked — they can’t join again', 'اتعمله بلوك — مش هيقدر يدخل تاني'))),
          ]),
        if (mine.isNotEmpty) head(t('MY REQUESTS', 'طلباتي')),
        for (final m in mine) _card(
          icon: '${m['icon']}', title: '${m['league_name']}',
          sub: switch (m['status']) {
            'approved' => t('✅ Accepted', '✅ اتقبلت'),
            'declined' => t('❌ Declined — you can ask again', '❌ اترفضت — تقدر تطلب تاني'),
            'blocked'  => t('⛔ You can’t join this league', '⛔ مش هتقدر تدخل الليج دي'),
            _          => t('⏳ Waiting for the owner', '⏳ مستني صاحب الليج'),
          },
          actions: const []),
        if (_d != null && inv.isEmpty && req.isEmpty && mine.isEmpty)
          Padding(padding: const EdgeInsets.all(30), child: Text(t('Nothing here 👌', 'مفيش حاجة 👌'), textAlign: TextAlign.center, style: const TextStyle(color: muted))),
      ]),
    );
  }

  Widget _card({required String icon, required String title, required String sub, required List<Widget> actions, bool busy = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(icon, style: const TextStyle(fontSize: 22)), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(color: muted, fontSize: 12)),
        ])),
      ]),
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 10),
        busy ? const LinearProgressIndicator(color: brandRed, backgroundColor: line)
             : Row(children: [for (final a in actions) ...[Expanded(child: a), if (a != actions.last) const SizedBox(width: 8)]]),
      ],
    ]),
  );

  Widget _btn(String label, Color c, VoidCallback onTap) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c.withOpacity(0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

// ═══ صفحة الليج ═════════════════════════════════════════════════════════
/// صفحة ليج من برّه الفانتازي (مثلًا بعد ما اليوزر يدخل من لينك دعوة)
Widget fantasyLeaguePage(String leagueId) => _LeagueLoader(leagueId: leagueId);

class _LeagueLoader extends StatefulWidget {
  final String leagueId;
  const _LeagueLoader({required this.leagueId});
  @override
  State<_LeagueLoader> createState() => _LeagueLoaderState();
}

class _LeagueLoaderState extends State<_LeagueLoader> {
  List<Map<String, dynamic>>? _cats;
  @override
  void initState() {
    super.initState();
    _sb.rpc('league_categories').then((r) {
      if (mounted) setState(() => _cats = ((r as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    }).catchError((_) { if (mounted) setState(() => _cats = []); });
  }
  @override
  Widget build(BuildContext context) => _cats == null
      ? const Scaffold(backgroundColor: bg, body: Center(child: CircularProgressIndicator(color: brandRed)))
      : _LeaguePage(leagueId: widget.leagueId, isArabic: AppLang.isArabic, categories: _cats!);
}

class _LeaguePage extends StatefulWidget {
  final String leagueId;
  final bool isArabic;
  final List<Map<String, dynamic>> categories;
  const _LeaguePage({required this.leagueId, required this.isArabic, required this.categories});
  @override
  State<_LeaguePage> createState() => _LeaguePageState();
}

class _LeaguePageState extends State<_LeaguePage> {
  Map<String, dynamic>? _d;
  List<Map<String, dynamic>> _members = [];
  int _tab = 0;   // 0 الترتيب · 1 الأعضاء
  String? _error;
  String t(String en, String ar) => widget.isArabic ? ar : en;
  bool get _owner => _d?['is_owner'] == true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        _sb.rpc('league_detail', params: {'p_league_id': widget.leagueId}),
        _sb.rpc('get_league_members', params: {'p_league_id': widget.leagueId}),
      ]);
      if (!mounted) return;
      setState(() {
        _d = Map<String, dynamic>.from(r[0] as Map);
        _members = ((r[1] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<bool> _confirm(String title, String body, String ok, {bool danger = false}) async =>
      (await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel', 'إلغاء'), style: const TextStyle(color: muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(ok, style: TextStyle(color: danger ? const Color(0xFFFF6B6B) : Brand.green, fontWeight: FontWeight.w900))),
        ],
      ))) ?? false;

  Future<void> _run(Future<dynamic> Function() f, String done) async {
    try { await f(); _snack(done); } catch (e) { _snack(_leagueErr(e, widget.isArabic)); }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: d == null
        ? Center(child: _error != null
            ? Text(t('Could not open the league.', 'مش قادرين نفتح الليج.'), style: const TextStyle(color: muted))
            : const CircularProgressIndicator(color: brandRed))
        : Column(children: [
            // الهيدر
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: cardBg, side: const BorderSide(color: line)),
                icon: const Icon(Icons.arrow_back, color: Colors.white)),
              const SizedBox(width: 10),
              Text('${d['icon']}', style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                Text('${_visIcon(d['visibility'])} ' + t('${d['members']} members', '${d['members']} عضو') + (_owner ? t(' · you own it', ' · إنت صاحبها') : ''),
                  style: const TextStyle(color: muted, fontSize: 12)),
              ])),
              IconButton(onPressed: _menu, icon: const Icon(Icons.more_vert_rounded, color: Colors.white)),
            ])),
            // الكود
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: _CodeBox(
              code: '${d['invite_code']}', isArabic: widget.isArabic, leagueName: '${d['name']}',
              onReset: _owner ? () async {
                if (await _confirm(t('New code?', 'كود جديد؟'), t('The old code will stop working.', 'الكود القديم هيبطل يشتغل.'), t('Change', 'غيّر'))) {
                  _run(() => _sb.rpc('league_reset_code', params: {'p_league_id': widget.leagueId}), t('New code ready', 'الكود الجديد جاهز'));
                }
              } : null,
            )),
            // ترتيب | أعضاء
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Container(
              height: 38, padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(11), border: Border.all(color: line)),
              child: Row(children: [
                for (final (i, label) in [(0, t('Ranking', 'الترتيب')), (1, t('Members', 'الأعضاء'))])
                  Expanded(child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _tab = i),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 160), alignment: Alignment.center,
                      decoration: BoxDecoration(color: _tab == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Text(label, style: TextStyle(color: _tab == i ? Colors.black : Colors.white70, fontWeight: FontWeight.w900, fontSize: 13))),
                  )),
              ]),
            )),
            Expanded(child: IndexedStack(index: _tab, children: [
              FantasyRankTab(isArabic: widget.isArabic, leagueId: widget.leagueId),
              _membersList(),
            ])),
          ])),
    );
  }

  Widget _membersList() => ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
    if (_owner) Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(height: 44, child: OutlinedButton.icon(
      onPressed: _openInvite,
      style: OutlinedButton.styleFrom(foregroundColor: Brand.green, side: const BorderSide(color: Brand.green),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: Text(t('Invite people', 'ادعي ناس'), style: const TextStyle(fontWeight: FontWeight.w900))))),
    for (final m in _members) Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Row(children: [
        // الصورة والاسم: بيودّوا على البروفايل
        Expanded(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openVisitorProfile(context, userId: '${m['user_id']}', username: '${m['username'] ?? ''}',
            displayName: '${m['display_name'] ?? ''}', avatarUrl: m['avatar_url'] as String?),
          child: Row(children: [
        CircleAvatar(radius: 17, backgroundColor: surface2,
          backgroundImage: (m['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage('${m['avatar_url']}') : null,
          child: (m['avatar_url'] ?? '').toString().isNotEmpty ? null
              : Text('${m['display_name'] ?? '?'}'.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['display_name'] ?? '—'}${m['is_owner'] == true ? '  👑' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          if (m['username'] != null) Text('@${m['username']}', style: const TextStyle(color: muted, fontSize: 11.5)),
        ])),
        ]))),
        if (_owner && m['is_owner'] != true)
          PopupMenuButton<String>(
            color: cardBg, icon: const Icon(Icons.more_horiz_rounded, color: muted),
            onSelected: (v) => _memberAction(v, m),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'remove', child: Text(t('Remove from league', 'شيله من الليج'), style: const TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'block', child: Text(t('Block (can’t rejoin)', 'بلوك (مش هيرجع تاني)'), style: const TextStyle(color: Color(0xFFFF6B6B)))),
              PopupMenuItem(value: 'owner', child: Text(t('Make league owner', 'خليه صاحب الليج'), style: const TextStyle(color: Colors.white))),
            ],
          ),
      ]),
    ),
    if (_owner && ((_d?['pending_invites'] as List?)?.isNotEmpty ?? false)) ...[
      Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(t('INVITED (WAITING)', 'متدعيين (مستنيين)'), style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1))),
      for (final i in (_d!['pending_invites'] as List)) ListTile(
        dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6),
        title: Text('${i['name']}', style: const TextStyle(color: Colors.white70)),
        subtitle: Text('@${i['username'] ?? ''}', style: const TextStyle(color: muted, fontSize: 11.5)),
        trailing: TextButton(onPressed: () => _run(() => _sb.rpc('league_invite_cancel', params: {'p_invite_id': i['invite_id']}), t('Invite cancelled', 'الدعوة اتلغت')),
          child: Text(t('Cancel', 'إلغاء'), style: const TextStyle(color: muted))),
      ),
    ],
    if (_owner && ((_d?['blocked'] as List?)?.isNotEmpty ?? false)) ...[
      Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(t('BLOCKED', 'عليهم بلوك'), style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1))),
      for (final b in (_d!['blocked'] as List)) ListTile(
        dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6),
        title: Text('${b['name']}', style: const TextStyle(color: Colors.white70)),
        subtitle: Text('@${b['username'] ?? ''}', style: const TextStyle(color: muted, fontSize: 11.5)),
        trailing: TextButton(onPressed: () => _run(() => _sb.rpc('league_unblock', params: {'p_league_id': widget.leagueId, 'p_user_id': b['user_id']}), t('Unblocked', 'البلوك اتشال')),
          child: Text(t('Unblock', 'فك البلوك'), style: const TextStyle(color: Brand.green))),
      ),
    ],
  ]);

  Future<void> _memberAction(String v, Map<String, dynamic> m) async {
    final name = '${m['display_name'] ?? ''}';
    switch (v) {
      case 'remove':
        if (await _confirm(t('Remove $name?', 'تشيل $name؟'),
            t('If they use the code again, you’ll get a request to accept or decline.', 'لو دخل بالكود تاني، هيوصلك طلب توافق أو ترفض.'), t('Remove', 'شيله'), danger: true)) {
          _run(() => _sb.rpc('league_remove_member', params: {'p_league_id': widget.leagueId, 'p_user_id': m['user_id']}), t('Removed', 'اتشال'));
        }
      case 'block':
        if (await _confirm(t('Block $name?', 'بلوك لـ $name؟'),
            t('They’ll be removed and can never join this league with the code.', 'هيتشال ومش هيقدر يدخل الليج دي بالكود تاني خالص.'), t('Block', 'بلوك'), danger: true)) {
          _run(() => _sb.rpc('league_block', params: {'p_league_id': widget.leagueId, 'p_user_id': m['user_id']}), t('Blocked', 'اتعمله بلوك'));
        }
      case 'owner':
        if (await _confirm(t('Make $name the owner?', 'تخلي $name صاحب الليج؟'),
            t('You’ll stay a member but lose owner controls.', 'هتفضل عضو بس مش هتقدر تدير الليج.'), t('Transfer', 'انقلها'))) {
          _run(() => _sb.rpc('league_transfer', params: {'p_league_id': widget.leagueId, 'p_new_owner': m['user_id']}), t('Ownership transferred', 'الملكية اتنقلت'));
        }
    }
  }

  Future<void> _menu() async {
    final v = await showModalBottomSheet<String>(
      context: context, backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        if (_owner) ...[
          ListTile(leading: const Icon(Icons.edit_rounded, color: Colors.white), title: Text(t('Edit name & type', 'تعديل الاسم والنوع'), style: const TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(leading: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white), title: Text(t('Invite people', 'ادعي ناس'), style: const TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, 'invite')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)), title: Text(t('Delete league', 'امسح الليج'), style: const TextStyle(color: Color(0xFFFF6B6B))), onTap: () => Navigator.pop(ctx, 'delete')),
        ] else
          ListTile(leading: const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)), title: Text(t('Leave league', 'اخرج من الليج'), style: const TextStyle(color: Color(0xFFFF6B6B))), onTap: () => Navigator.pop(ctx, 'leave')),
        const SizedBox(height: 8),
      ])),
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'edit':
        final r = await showModalBottomSheet<Map<String, dynamic>>(
          context: context, isScrollControlled: true, backgroundColor: bg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _LeagueFormSheet(isArabic: widget.isArabic, categories: widget.categories,
              leagueId: widget.leagueId, initialName: '${_d?['name'] ?? ''}', initialCategory: '${_d?['category'] ?? 'general'}',
              initialVisibility: '${_d?['visibility'] ?? 'public'}'));
        if (r != null) { _snack(t('Saved', 'اتحفظ')); _load(); }
      case 'invite':
        _openInvite();
      case 'delete':
        if (await _confirm(t('Delete this league?', 'تمسح الليج دي؟'), t('This can’t be undone.', 'مفيش رجوع.'), t('Delete', 'امسحها'), danger: true)) {
          try { await _sb.rpc('league_delete', params: {'p_league_id': widget.leagueId}); if (mounted) Navigator.pop(context); }
          catch (e) { _snack(_leagueErr(e, widget.isArabic)); }
        }
      case 'leave':
        if (await _confirm(t('Leave this league?', 'تخرج من الليج دي؟'), t('You can come back with the code.', 'تقدر ترجع بالكود.'), t('Leave', 'اخرج'), danger: true)) {
          try { await _sb.rpc('league_leave', params: {'p_league_id': widget.leagueId}); if (mounted) Navigator.pop(context); }
          catch (e) { _snack(_leagueErr(e, widget.isArabic)); }
        }
    }
  }

  Future<void> _openInvite() async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InviteSheet(leagueId: widget.leagueId, isArabic: widget.isArabic),
    );
    _load();
  }
}

// ─── الدعوة بالبحث: الكل / بتابعهم / بيتابعوني ─────────────────────────
class _InviteSheet extends StatefulWidget {
  final String leagueId;
  final bool isArabic;
  const _InviteSheet({required this.leagueId, required this.isArabic});
  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _q = TextEditingController();
  String _scope = 'following';
  List<Map<String, dynamic>> _res = [];
  bool _loading = false;
  Timer? _deb;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _search(); }
  @override
  void dispose() { _deb?.cancel(); _q.dispose(); super.dispose(); }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final r = await _sb.rpc('league_search_users', params: {'p_league_id': widget.leagueId, 'p_query': _q.text, 'p_scope': _scope, 'p_limit': 30});
      if (mounted) setState(() { _res = ((r as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _invite(Map<String, dynamic> u) async {
    try {
      await _sb.rpc('league_invite', params: {'p_league_id': widget.leagueId, 'p_user_id': u['user_id']});
      if (mounted) setState(() => u['state'] = 'invited');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_leagueErr(e, widget.isArabic))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.85, maxChildSize: 0.95,
      builder: (_, sc) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text(t('Invite people', 'ادعي ناس'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextField(
            controller: _q,
            onChanged: (_) { _deb?.cancel(); _deb = Timer(const Duration(milliseconds: 350), _search); },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(filled: true, fillColor: cardBg, prefixIcon: const Icon(Icons.search_rounded, color: muted),
              hintText: t('Name or @username', 'الاسم أو @اليوزرنيم'), hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line))),
          ),
          const SizedBox(height: 8),
          Row(children: [
            for (final (k, label) in [('following', t('I follow', 'بتابعهم')), ('followers', t('Follow me', 'بيتابعوني')), ('all', t('Everyone', 'الكل'))])
              Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: ChoiceChip(
                label: Text(label), selected: _scope == k,
                onSelected: (_) { setState(() => _scope = k); _search(); },
                selectedColor: Brand.green, backgroundColor: cardBg,
                labelStyle: TextStyle(color: _scope == k ? Colors.black : Colors.white, fontWeight: FontWeight.w800),
                side: const BorderSide(color: line),
              )),
          ]),
          const SizedBox(height: 8),
          if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: brandRed)))
          else if (_res.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(
            _scope == 'all' && _q.text.trim().length < 2 ? t('Type at least 2 letters', 'اكتب حرفين على الأقل') : t('No one found', 'مفيش حد'),
            textAlign: TextAlign.center, style: const TextStyle(color: muted)))
          else for (final u in _res) ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: CircleAvatar(backgroundColor: surface2,
              backgroundImage: (u['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage('${u['avatar_url']}') : null,
              child: (u['avatar_url'] ?? '').toString().isNotEmpty ? null : Text('${u['display_name'] ?? '?'}'.characters.first, style: const TextStyle(color: Colors.white))),
            title: Text('${u['display_name'] ?? '—'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(color: muted)),
            trailing: switch (u['state']) {
              'member'  => Text(t('Member', 'عضو'), style: const TextStyle(color: muted)),
              'invited' => Text(t('Invited ✓', 'اتدعى ✓'), style: const TextStyle(color: Brand.green, fontWeight: FontWeight.w800)),
              _ => OutlinedButton(onPressed: () => _invite(u),
                    style: OutlinedButton.styleFrom(foregroundColor: Brand.green, side: const BorderSide(color: Brand.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text(u['state'] == 'blocked' ? t('Unblock & invite', 'فك وادعي') : t('Invite', 'ادعي'))),
            },
          ),
        ]),
      ),
    );
  }
}

String _visIcon(dynamic v) => switch ('$v') { 'followers' => '👥', 'private' => '🔒', _ => '🌍' };

/// ادخل ليج من "كل الليجز" (من غير كود). بيرجّع league_id لو دخل.
Future<String?> _joinOpenLeague(BuildContext context, Map<String, dynamic> l, bool ar) async {
  String t(String en, String a) => ar ? a : en;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final r = Map<String, dynamic>.from(await _sb.rpc('league_join_open', params: {'p_league_id': l['league_id']}) as Map);
    final st = r['status']?.toString();
    final msg = switch (st) {
      'joined' => t('You joined the league! 🎉', 'دخلت الليج! 🎉'),
      'already_member' => t("You're already in this league.", 'إنت في الليج دي بالفعل.'),
      'requested' => t('You were removed from this league before — a request was sent to the owner.', 'إنت اتشلت من الليج دي قبل كده — اتبعت طلب لصاحبها.'),
      'pending' => t('Your request is still waiting for the owner.', 'طلبك لسه مستني رد صاحب الليج.'),
      'blocked' || 'not_allowed' => t("You can't join this league.", 'مش هتقدر تدخل الليج دي.'),
      'league_full' => t('This league is full.', 'الليج دي مليانة.'),
      _ => t('This league is not available.', 'الليج دي مش متاحة.'),
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
    return (st == 'joined' || st == 'already_member') ? l['league_id']?.toString() : null;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_leagueErr(e, ar))));
    return null;
  }
}

/// كارت ليج في "كل الليجز": الترتيب بالعدد + الاسم + صاحبها + الأعضاء + ادخل.
class _DirLeagueCard extends StatefulWidget {
  final Map<String, dynamic> l;
  final bool isArabic;
  final String catName;
  final VoidCallback onOpen;
  final ValueChanged<String> onJoined;
  const _DirLeagueCard({required this.l, required this.isArabic, required this.catName, required this.onOpen, required this.onJoined});
  @override
  State<_DirLeagueCard> createState() => _DirLeagueCardState();
}

class _DirLeagueCardState extends State<_DirLeagueCard> {
  bool _busy = false;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _join() async {
    setState(() => _busy = true);
    final id = await _joinOpenLeague(context, widget.l, widget.isArabic);
    if (!mounted) return;
    setState(() => _busy = false);
    if (id != null) {
      widget.l['is_member'] = true;
      widget.onJoined(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final rank = (l['rank'] as num?)?.toInt() ?? 0;
    final member = l['is_member'] == true;
    final owner = l['owner'] is Map ? Map<String, dynamic>.from(l['owner'] as Map) : const <String, dynamic>{};
    final by = (owner['username'] ?? '').toString().isNotEmpty ? '@${owner['username']}' : '${owner['name'] ?? ''}';
    final rankColor = switch (rank) { 1 => _gold, 2 => const Color(0xFFC9CED6), 3 => const Color(0xFFCD8B5A), _ => muted };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: member ? widget.onOpen : (_busy ? null : _join),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: l['is_owner'] == true ? _gold.withOpacity(0.4) : line)),
          child: Row(children: [
            SizedBox(width: 34, child: Text('#$rank', textAlign: TextAlign.center,
              style: TextStyle(color: rankColor, fontSize: rank <= 3 ? 15 : 13, fontWeight: FontWeight.w900))),
            Container(width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(12)),
              child: Text('${l['icon']}', style: const TextStyle(fontSize: 21))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('${l['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900))),
                if (l['visibility'] != 'public') Padding(padding: const EdgeInsetsDirectional.only(start: 5),
                  child: Text(_visIcon(l['visibility']), style: const TextStyle(fontSize: 11.5))),
              ]),
              const SizedBox(height: 2),
              Text('${t('${l['members']} members', '${l['members']} عضو')} · ${widget.catName}${by.isEmpty ? '' : ' · $by'}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11.5)),
            ])),
            const SizedBox(width: 8),
            if (l['is_owner'] == true)
              Text(t('👑 Owner', '👑 صاحبها'), style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w900))
            else if (member)
              Text(t('✓ Member', '✓ عضو'), style: TextStyle(color: Brand.green, fontSize: 12, fontWeight: FontWeight.w900))
            else
              SizedBox(height: 32, child: ElevatedButton(
                onPressed: _busy ? null : _join,
                style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text(_busy ? '…' : t('Join', 'ادخل'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)))),
          ]),
        ),
      ),
    );
  }
}

/// صفحة "كل الليجز": بحث + نوع + ترتيب بالعدد، 20 كل مرة.
class _LeagueDirectoryPage extends StatefulWidget {
  final bool isArabic;
  final List<Map<String, dynamic>> categories;
  final String initialScope;
  const _LeagueDirectoryPage({required this.isArabic, required this.categories, this.initialScope = 'all'});
  @override
  State<_LeagueDirectoryPage> createState() => _LeagueDirectoryPageState();
}

class _LeagueDirectoryPageState extends State<_LeagueDirectoryPage> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  String? _cat;
  late String _scope = widget.initialScope;
  bool _loading = true, _more = false, _loadingMore = false, _error = false;
  int _total = 0, _req = 0;
  Timer? _debounce;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_more && !_loadingMore && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _fetch(more: true);
    });
    _fetch();
  }

  @override
  void dispose() { _debounce?.cancel(); _q.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _fetch({bool more = false}) async {
    final req = ++_req;
    setState(() { if (more) { _loadingMore = true; } else { _loading = _items.isEmpty; _error = false; } });
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('league_directory', params: {'p': {
        'q': _q.text.trim(), 'scope': _scope, if (_cat != null) 'category': _cat, 'offset': more ? _items.length : 0, 'limit': 20,
      }}) as Map);
      if (!mounted || req != _req) return;
      final list = ((r['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        if (!more) _items.clear();
        _items.addAll(list);
        _total = (r['total'] as num?)?.toInt() ?? 0;
        _more = r['has_more'] == true;
        _loading = false; _loadingMore = false;
      });
    } catch (_) {
      if (mounted && req == _req) setState(() { _loading = false; _loadingMore = false; _error = !more; });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch());
  }

  String _catName(dynamic key) {
    final c = widget.categories.cast<Map<String, dynamic>?>().firstWhere((x) => x?['key'] == key, orElse: () => null);
    if (c == null) return t('General', 'عامة');
    return widget.isArabic ? '${c['ar']}' : '${c['en']}';
  }

  void _open(String id) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
      _LeaguePage(leagueId: id, isArabic: widget.isArabic, categories: widget.categories)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 16, 0), child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(backgroundColor: cardBg, side: const BorderSide(color: line)),
              icon: const Icon(Icons.arrow_back, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('All leagues', 'كل الليجز'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              Text(t('Biggest first', 'الأكبر عدد الأول'), style: const TextStyle(color: muted, fontSize: 12)),
            ])),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: TextField(
            controller: _q, onChanged: _onSearch, maxLength: 40,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(counterText: '', isDense: true, filled: true, fillColor: cardBg,
              prefixIcon: const Icon(Icons.search_rounded, color: muted, size: 20),
              hintText: t('Search by league name', 'دوّر باسم الليج'), hintStyle: const TextStyle(color: Colors.white24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line))),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Row(children: [
            Expanded(child: _FilterMenu(value: _scope, items: _scopeItems(widget.isArabic), expand: true,
              onChanged: (v) { setState(() => _scope = v); _fetch(); })),
            const SizedBox(width: 8),
            Expanded(child: _FilterMenu(value: _cat ?? '', expand: true,
              items: [
                ('', t('All types', 'كل الأنواع')),
                for (final c in widget.categories) ('${c['key']}', '${c['icon']} ${widget.isArabic ? c['ar'] : c['en']}'),
              ],
              onChanged: (v) { setState(() => _cat = v.isEmpty ? null : v); _fetch(); })),
          ])),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : _error
              ? Center(child: TextButton(onPressed: _fetch,
                  child: Text(t('Could not load. Tap to retry.', 'مش قادرين نحمّل. دوس وجرّب تاني.'), style: const TextStyle(color: muted))))
              : _items.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
                    _q.text.trim().isNotEmpty || _cat != null ? t('No leagues found.', 'مفيش ليجز بالشكل ده.') : _scopeEmpty(_scope, widget.isArabic),
                    textAlign: TextAlign.center, style: const TextStyle(color: muted))))
                : RefreshIndicator(color: brandRed, onRefresh: () => _fetch(),
                    child: ListView.builder(
                      controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length + 1,
                      itemBuilder: (_, i) {
                        if (i == _items.length) {
                          return Padding(padding: const EdgeInsets.all(12), child: Center(child: _loadingMore
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: brandRed))
                            : Text(t('$_total leagues', '$_total ليج'), style: const TextStyle(color: muted, fontSize: 12))));
                        }
                        final l = _items[i];
                        return _DirLeagueCard(l: l, isArabic: widget.isArabic, catName: _catName(l['category']),
                          onOpen: () => _open(l['league_id'] as String),
                          onJoined: (id) { setState(() {}); _open(id); });
                      },
                    ))),
        ])),
      ),
    );
  }
}

String _scopeEmpty(String scope, bool ar) {
  String t(String en, String a) => ar ? a : en;
  return switch (scope) {
    'member' => t("You're not in any league yet.", 'إنت لسه مش في أي ليج.'),
    'following' => t('People you follow have no leagues you can see.', 'اللي بتتابعهم معندهمش ليجز تقدر تشوفها.'),
    'followers' => t('Your followers have no leagues you can see.', 'متابعينك معندهمش ليجز تقدر تشوفها.'),
    _ => t('No leagues yet.', 'مفيش ليجز لسه.'),
  };
}

/// فلتر "كل الليجز": الكل · ليجزي · اللي بتابعهم · متابعيني.
List<(String, String)> _scopeItems(bool ar) {
  String t(String en, String a) => ar ? a : en;
  return [
    ('all', t('All leagues', 'كل الليجز')),
    ('member', t("Leagues I'm in", 'ليجزي')),
    ('following', t('People I follow', 'اللي بتابعهم')),
    ('followers', t('My followers', 'متابعيني')),
  ];
}

/// قايمة منسدلة صغيرة للفلاتر (زرار واحد + ▾).
class _FilterMenu extends StatelessWidget {
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;
  final bool expand;
  const _FilterMenu({required this.value, required this.items, required this.onChanged, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final current = items.firstWhere((e) => e.$1 == value, orElse: () => items.first).$2;
    final active = value != items.first.$1;
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: cardBg,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: line)),
      itemBuilder: (_) => [
        for (final (key, label) in items)
          PopupMenuItem<String>(value: key, height: 42, child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: key == value ? Colors.white : Colors.white70,
              fontSize: 13.5, fontWeight: key == value ? FontWeight.w900 : FontWeight.w600))),
            if (key == value) const Icon(Icons.check_rounded, size: 18, color: brandRed),
          ])),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? brandRed : line)),
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [
          Flexible(fit: expand ? FlexFit.tight : FlexFit.loose, child: Text(current, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: muted),
        ]),
      ),
    );
  }
}
