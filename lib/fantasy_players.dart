part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// كل اللاعيبة: بحث + فلاتر + ترتيب + بطاقة اللاعب
// بتتفتح من: زرار "كل اللاعيبة" في بناء الفريق، الدوسة على مكان في الملعب
// (مفلترة على المركز ده)، وزرار "اللاعيبة" في صفحة الجولة (تصفح بس)
// ═══════════════════════════════════════════════════════════════════════════

const _posList = ['GK', 'DEF', 'MID', 'FWD'];

class _PlayersPage extends StatefulWidget {
  final _FancyPageState host;
  final String? lockPos;
  final int? slotIndex;
  final bool browse;
  const _PlayersPage({required this.host, this.lockPos, this.slotIndex, this.browse = false});
  @override
  State<_PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<_PlayersPage> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  late String? _pos = widget.lockPos;
  String? _team;
  String _sort = 'price';

  _FancyPageState get h => widget.host;
  bool get ar => h.isArabic;
  String t(String en, String ar_) => ar ? ar_ : en;
  bool get _slotMode => widget.slotIndex != null && widget.lockPos != null;
  FancyPlayer? get _slotCurrent => _slotMode ? h.squad[widget.lockPos!]![widget.slotIndex!] : null;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  String _posLabel(String p) => switch (p) {
    'GK' => t('GK', 'حارس'), 'DEF' => t('DEF', 'دفاع'), 'MID' => t('MID', 'وسط'), _ => t('FWD', 'هجوم'),
  };

  Map<String, String> get _sorts => {
    'price':     t('Price: high → low', 'السعر: الأغلى الأول'),
    'price_asc': t('Price: low → high', 'السعر: الأرخص الأول'),
    'last':      t('Last round points', 'نقط آخر جولة'),
    'total':     t('Total points', 'مجموع النقط'),
    'owned':     t('Most selected', 'الأكتر اختيارًا'),
    'value':     t('Best value (pts per 1M)', 'أحسن قيمة (نقط لكل مليون)'),
  };

  List<FancyPlayer> _filtered() {
    final q = _q.trim().toLowerCase();
    final l = h.players.where((p) =>
      (_pos == null || p.position == _pos) &&
      (_team == null || p.teamId == _team) &&
      (q.isEmpty || p.nameEn.toLowerCase().contains(q) || p.nameAr.contains(q) ||
        p.teamNameEn.toLowerCase().contains(q) || p.teamNameAr.contains(q))).toList();
    int cmp(FancyPlayer a, FancyPlayer b) => switch (_sort) {
      'price_asc' => a.price.compareTo(b.price),
      'last'      => b.lastPts.compareTo(a.lastPts),
      'total'     => b.totalPts.compareTo(a.totalPts),
      'owned'     => (b.ownership ?? 0).compareTo(a.ownership ?? 0),
      'value'     => b.value.compareTo(a.value),
      _           => b.price.compareTo(a.price),
    };
    l.sort((a, b) { final c = cmp(a, b); return c != 0 ? c : b.price.compareTo(a.price); });
    return l;
  }

  /// null = ينفع يتضاف، غير كده سبب المنع (علشان نطفّي الصف)
  String? _blockReason(FancyPlayer p) {
    if (widget.browse || h.inSquad(p)) return null;
    final cur = _slotCurrent;
    if (p.price > h.remaining + (cur?.price ?? 0) + 1e-9) return t('Not enough budget', 'الميزانية مش مكفية');
    final lim = h.maxPerTeam;
    if (lim != null && p.teamId != null && h.teamCount(p.teamId) - (cur?.teamId == p.teamId ? 1 : 0) >= lim) {
      return t('Max $lim from this team', 'أقصى $lim من الفريق ده');
    }
    return null;
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  void _add(FancyPlayer p) {
    final err = h.placePlayer(p, pos: _slotMode ? widget.lockPos : null, index: _slotMode ? widget.slotIndex : null);
    if (err != null) { _snack(err); return; }
    if (_slotMode) { Navigator.pop(context); return; }
    HapticFeedback.selectionClick();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(bottom: false, child: ValueListenableBuilder<int>(
        valueListenable: h.squadTick,
        builder: (_, __, ___) {
          final list = _filtered();
          return Column(children: [
            _header(),
            // مش وقت اختيار لاعب (من غير إعلانات جوه بناء الفريق) — بس في "كل اللاعيبة"
            if (!_slotMode) const AdSlot('fantasy_players', center: true, padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                prefixEn: 'Powered by', prefixAr: 'مقدّم من'),
            if (h._playersLoading && h.players.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator(color: brandRed)))
            else if (h.players.isEmpty)
              Expanded(child: Center(child: Text(t('Failed to load players.', 'مقدرناش نحمّل اللاعيبة.'), style: const TextStyle(color: muted))))
            else if (list.isEmpty)
              Expanded(child: Center(child: Text(t('No players match.', 'مفيش لاعيبة بالفلتر ده.'), style: const TextStyle(color: muted))))
            else
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _row(list[i]),
              )),
          ]);
        })),
    );
  }

  Widget _header() {
    final title = _slotMode
        ? (_slotCurrent == null ? t('Pick a ${widget.lockPos}', 'اختار ${_posLabel(widget.lockPos!)}')
                                : t('Swap ${_slotCurrent!.nameEn}', 'بدّل ${_slotCurrent!.nameAr}'))
        : t('All players', 'كل اللاعيبة');
    final budget = h.remaining + (_slotCurrent?.price ?? 0);
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => Navigator.pop(context),
            icon: Icon(ar ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, color: Colors.white)),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
          if (!widget.browse) ...[
            _pill('💰 ${_fmtBudget(budget)}', budget < 0 ? Colors.redAccent : Colors.white),
            const SizedBox(width: 6),
            _pill('${h.selectedCount}/${h.squadSize}', h.selectedCount == h.squadSize ? const Color(0xFF4CD964) : Colors.white),
          ],
        ]),
        const SizedBox(height: 6),
        Padding(padding: const EdgeInsets.only(left: 4), child: SizedBox(height: 42, child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _q = v),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: t('Search player or team', 'دوّر على لاعب أو فريق'),
            hintStyle: const TextStyle(color: muted, fontSize: 13.5),
            prefixIcon: const Icon(Icons.search_rounded, color: muted, size: 20),
            suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded, color: muted, size: 18),
              onPressed: () { _searchCtrl.clear(); setState(() => _q = ''); }),
            filled: true, fillColor: cardBg, contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white38)),
          ),
        ))),
        const SizedBox(height: 8),
        // 3 قوايم بنفس العرض: النادي · المركز · الترتيب
        Padding(padding: const EdgeInsets.only(left: 4), child: Row(children: [
          Expanded(child: Builder(builder: (bc) => _dropBtn(
            leading: _team == null ? const Icon(Icons.shield_outlined, color: Colors.white70, size: 16)
                                   : SizedBox(width: 18, height: 18, child: _teamLogo(h.teamLogos[_team], _teamName(_team!), 18)),
            label: _team == null ? t('All clubs', 'كل الأندية') : _teamName(_team!),
            on: _team != null, onTap: () => _clubMenu(bc)))),
          const SizedBox(width: 8),
          Expanded(child: Builder(builder: (bc) => _dropBtn(
            leading: Icon(_slotMode ? Icons.lock_outline_rounded : Icons.grid_view_rounded, color: Colors.white70, size: 15),
            label: _pos == null ? t('All positions', 'كل المراكز') : _posLabel(_pos!),
            on: _pos != null && !_slotMode, onTap: _slotMode ? null : () => _posMenu(bc)))),
          const SizedBox(width: 8),
          Expanded(child: Builder(builder: (bc) => _dropBtn(
            leading: const Icon(Icons.sort_rounded, color: Colors.white70, size: 16),
            label: _sortShort(), on: false, onTap: () => _sortMenu(bc)))),
        ])),
      ]),
    );
  }

  String _teamName(String id) {
    final p = h.players.firstWhere((x) => x.teamId == id, orElse: () => h.players.first);
    return ar ? p.teamNameAr : p.teamNameEn;
  }

  Widget _dropBtn({required Widget leading, required String label, required bool on, VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: on ? Colors.white : surface2, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? Colors.white : line)),
      child: Row(children: [
        IconTheme(data: IconThemeData(color: on ? Colors.black54 : Colors.white70), child: leading),
        const SizedBox(width: 6),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: on ? Colors.black : (onTap == null ? Colors.white54 : Colors.white), fontSize: 12.5, fontWeight: FontWeight.w800))),
        if (onTap != null) Icon(Icons.keyboard_arrow_down_rounded, color: on ? Colors.black54 : Colors.white60, size: 18),
      ])),
  );

  /// قايمة منسدلة تحت الزرار مباشرة
  Future<String?> _menu(BuildContext bc, List<(String, String, Widget?)> items, String selected) {
    final box = bc.findRenderObject() as RenderBox;
    final overlay = Overlay.of(bc).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 6), ancestor: overlay);
    return showMenu<String>(
      context: bc, color: cardBg, elevation: 8,
      constraints: BoxConstraints(minWidth: box.size.width, maxWidth: math.max(box.size.width, 230), maxHeight: 380),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: line)),
      position: RelativeRect.fromLTRB(topLeft.dx, topLeft.dy, overlay.size.width - topLeft.dx - box.size.width, 0),
      items: [
        for (final it in items) PopupMenuItem<String>(
          value: it.$1, height: 42,
          child: Row(children: [
            if (it.$3 != null) ...[SizedBox(width: 20, height: 20, child: it.$3), const SizedBox(width: 10)],
            Expanded(child: Text(it.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white,
              fontSize: 13.5, fontWeight: it.$1 == selected ? FontWeight.w900 : FontWeight.w500))),
            if (it.$1 == selected) const Icon(Icons.check_rounded, color: brandRed, size: 18),
          ])),
      ],
    );
  }

  Future<void> _clubMenu(BuildContext bc) async {
    final logos = h.teamLogos;
    final ids = <String>{for (final p in h.players) if (p.teamId != null) p.teamId!}.toList()
      ..sort((a, b) => _teamName(a).compareTo(_teamName(b)));
    final v = await _menu(bc, [
      ('', t('All clubs', 'كل الأندية'), const Icon(Icons.shield_outlined, color: Colors.white54, size: 18)),
      for (final id in ids) (id, _teamName(id), _teamLogo(logos[id], _teamName(id), 20)),
    ], _team ?? '');
    if (v != null && mounted) setState(() => _team = v.isEmpty ? null : v);
  }

  Future<void> _posMenu(BuildContext bc) async {
    final v = await _menu(bc, [
      ('', t('All positions', 'كل المراكز'), null),
      for (final p in _posList) (p, _posLabel(p), null),
    ], _pos ?? '');
    if (v != null && mounted) setState(() => _pos = v.isEmpty ? null : v);
  }

  Future<void> _sortMenu(BuildContext bc) async {
    final v = await _menu(bc, [for (final e in _sorts.entries) (e.key, e.value, null)], _sort);
    if (v != null && mounted) setState(() => _sort = v);
  }


  String _sortShort() => switch (_sort) {
    'price_asc' => t('Cheapest', 'الأرخص'), 'last' => t('Last round', 'آخر جولة'),
    'total' => t('Points', 'النقط'), 'owned' => t('Selected', 'الأكتر اختيارًا'),
    'value' => t('Value', 'أحسن قيمة'), _ => t('Price', 'السعر'),
  };

  Widget _pill(String s, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
    child: Text(s, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w900)));

  Widget _teamLogo(String? url, String name, double size) {
    final fb = Center(child: Text(name.isEmpty ? '?' : name.characters.first,
      style: TextStyle(color: Colors.white70, fontSize: size * 0.5, fontWeight: FontWeight.w900)));
    if (url == null || url.isEmpty) return fb;
    return _netImage(url, width: size, height: size, fit: BoxFit.contain, fallback: fb);
  }

  Widget _row(FancyPlayer p) {
    final picked = h.inSquad(p);
    final block  = _blockReason(p);
    final dim    = block != null;
    final fg     = dim ? const Color(0xFF666666) : Colors.white;
    final logo   = h.teamLogos[p.teamId];
    return GestureDetector(
      onTap: () => _openCard(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
        decoration: BoxDecoration(
          color: picked ? const Color(0xFF14261A) : (dim ? const Color(0xFF141414) : cardBg),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: picked ? const Color(0x664CD964) : line)),
        child: Row(children: [
          Opacity(opacity: dim ? 0.45 : 1, child: Container(width: 46, height: 46,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8E8E8)),
            child: ClipOval(child: p.photoUrl != null
              ? _netImage(p.photoUrl!, width: 46, height: 46, fit: BoxFit.cover,
                  fallback: const Icon(Icons.person, color: Color(0xFF333333)))
              : const Icon(Icons.person, color: Color(0xFF333333))))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? p.nameAr : p.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(children: [
              SizedBox(width: 15, height: 15, child: _teamLogo(logo, ar ? p.teamNameAr : p.teamNameEn, 15)),
              const SizedBox(width: 5),
              Flexible(child: Text('${ar ? p.teamNameAr : p.teamNameEn} · ${_posLabel(p.position)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11.5))),
            ]),
            const SizedBox(height: 4),
            Text(dim ? block : t('Last ${_n(p.lastPts)} · Total ${_n(p.totalPts)} · ${_n(p.ownership ?? 0)}% picked',
                                 'آخر جولة ${_n(p.lastPts)} · المجموع ${_n(p.totalPts)} · ${_n(p.ownership ?? 0)}% اختاروه'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: dim ? const Color(0xFFB0605A) : Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(width: 6),
          Text(_fmtVal(p.price), style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w900)),
          if (widget.browse)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.chevron_right_rounded, color: muted))
          else
            IconButton(
              onPressed: picked ? (_slotMode ? null : () => h.removePlayer(p)) : () => _add(p),
              icon: Icon(picked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                color: picked ? const Color(0xFF4CD964) : (dim ? const Color(0xFF555555) : brandRed), size: 26)),
        ]),
      ),
    );
  }

  static String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _openCard(FancyPlayer p) {
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _PlayerCard(page: this, player: p),
    );
  }
}

// ── بطاقة اللاعب ────────────────────────────────────────────────────────────
class _PlayerCard extends StatefulWidget {
  final _PlayersPageState page;
  final FancyPlayer player;
  const _PlayerCard({required this.page, required this.player});
  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  _PlayersPageState get pg => widget.page;
  FancyPlayer get p => widget.player;
  String t(String en, String a) => pg.t(en, a);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _sb.rpc('fantasy_player_detail',
        params: {'p_player_id': p.id, 'p_event_id': pg.h.currentEvent!.eventId});
      if (mounted) setState(() { _d = Map<String, dynamic>.from(r as Map); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = pg.ar;
    final img = p.fullImageUrl ?? p.photoUrl;
    final picked = pg.h.inSquad(p);
    final block = pg._blockReason(p);
    return SafeArea(child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── الصورة والاسم ──
        SizedBox(height: 190, child: Stack(fit: StackFit.expand, children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(color: const Color(0xFF202020), child: img != null
              ? _netImage(img, fit: BoxFit.contain, fallback: Align(alignment: const Alignment(0, -0.4), child: SizedBox(height: 130, child: _playerShirtHero(p, shirtW: 96, bg: Colors.transparent))))
              : Align(alignment: const Alignment(0, -0.4), child: SizedBox(height: 130, child: _playerShirtHero(p, shirtW: 96, bg: Colors.transparent))))),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xF00D0D0D)], stops: [0.45, 1]))),
          Positioned(left: 16, right: 16, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? p.nameAr : p.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Row(children: [
              SizedBox(width: 16, height: 16, child: pg._teamLogo(pg.h.teamLogos[p.teamId], ar ? p.teamNameAr : p.teamNameEn, 16)),
              const SizedBox(width: 6),
              Text('${ar ? p.teamNameAr : p.teamNameEn} · ${pg._posLabel(p.position)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ])),
          Positioned(top: 4, right: 4, child: IconButton(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _box(t('Price', 'السعر'), _fmtVal(p.price)),
            _box(t('Picked', 'اختاروه'), '${_PlayersPageState._n(p.ownership ?? 0)}%'),
            _box(_lastLabel, _PlayersPageState._n(p.lastPts)),
            _box(t('Season', 'الموسم'), _PlayersPageState._n(p.totalPts)),
          ]),
          const SizedBox(height: 16),
          Text(t('POINTS IN EACH ROUND', 'نقطه في كل جولة'),
            style: const TextStyle(color: muted, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _chart(),
          const SizedBox(height: 14),
          if (_d != null) ...[
            Row(children: [
              Text(t('SEASON STATS', 'إحصائيات الموسم'),
                style: const TextStyle(color: muted, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text(_rangeLabel, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _statsFor(p.position)),
          ],
          if (!pg.widget.browse) ...[
            const SizedBox(height: 16),
            if (block != null && !picked) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text(block, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE0827A), fontSize: 12.5, fontWeight: FontWeight.w700))),
            SizedBox(height: 50, child: ElevatedButton(
              onPressed: picked
                ? (pg._slotMode ? null : () { pg.h.removePlayer(p); Navigator.pop(context); })
                : (block != null ? null : () { Navigator.pop(context); pg._add(p); }),
              style: ElevatedButton.styleFrom(
                backgroundColor: picked ? surface2 : brandRed, foregroundColor: Colors.white, elevation: 0,
                disabledBackgroundColor: surface2, disabledForegroundColor: muted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(picked ? t('Remove from my team', 'شيله من فريقي') : t('Add to my team', 'ضيفه لفريقي'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))),
          ],
        ])),
      ])),
    ));
  }

  String get _lastLabel {
    final r = _d?['last_round'];
    return r == null ? t('Last round', 'آخر جولة') : t('Round $r', 'الجولة $r');
  }

  /// "من الجولة 1 لـ 6" علشان يبقى واضح إن الأرقام دي للموسم كله لحد دلوقتي
  String get _rangeLabel {
    final a = _d?['first_round'], b = _d?['last_round'];
    if (a == null || b == null) return '';
    return a == b ? t('Round $a', 'الجولة $a') : t('Rounds $a–$b', 'من الجولة $a لـ $b');
  }

  /// الإحصائيات اللي تهم كل مركز بس
  List<Widget> _statsFor(String pos) {
    final d = _d!;
    num v(String k) => (d[k] as num?) ?? 0;
    final goals = _stat('⚽', t('Goals', 'أهداف'), v('goals'));
    final ast = _stat('🅰️', t('Assists', 'أسيست'), v('assists'));
    final cs = _stat('🧤', t('Clean sheets', 'شباك نضيفة'), v('clean_sheets'));
    final ps = _stat('🥅', t('Penalties saved', 'جزاء صدّها'), v('pen_saved'));
    final pm = _stat('❌', t('Penalties missed', 'جزاء ضيّعها'), v('pen_missed'));
    final y = _stat('🟨', t('Yellow', 'صفرا'), v('yellow'));
    final r = _stat('🟥', t('Red', 'حمرا'), v('red'));
    final pl = _stat('🏟️', t('Matches', 'ماتشات'), v('played'));
    final out = switch (pos) {
      'GK'  => [cs, ps, pl, y, r, if (v('goals') > 0) goals, if (v('assists') > 0) ast],
      'DEF' => [cs, goals, ast, pl, y, r],
      'MID' => [goals, ast, cs, pl, y, r],
      _     => [goals, ast, pl, if (v('pen_missed') > 0) pm, y, r],
    };
    if (v('own_goals') > 0) out.add(_stat('🙈', t('Own goals', 'في نفسه'), v('own_goals')));
    return out;
  }

  Widget _box(String k, String v) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
    child: Column(children: [
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(k, style: const TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
    ])));

  Widget _stat(String e, String k, dynamic v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
    child: Text('$e  $k  ${v ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)));

  Widget _chart() {
    if (_loading) return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 2)));
    final hist = ((_d?['history'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (hist.isEmpty) {
      return SizedBox(height: 60, child: Center(child: Text(t('No finished rounds yet.', 'لسه مفيش جولات خلصت.'),
        style: const TextStyle(color: muted, fontSize: 12))));
    }
    final vals = hist.map((x) => (x['points'] as num?)).toList();
    final maxV = vals.fold<num>(1, (m, v) => v != null && v > m ? v : m);
    return SizedBox(height: 96, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < hist.length; i++) Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(vals[i] == null ? '–' : _PlayersPageState._n(vals[i]!),
            style: TextStyle(color: vals[i] == null ? muted : Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Container(
            height: vals[i] == null || vals[i]! <= 0 ? 3 : 56 * (vals[i]! / maxV).toDouble(),
            decoration: BoxDecoration(
              color: vals[i] == null ? surface2 : (vals[i]! < 0 ? const Color(0xFFB0605A) : brandRed),
              borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 4),
          Text(t('R${hist[i]['round_no']}', 'ج${hist[i]['round_no']}'), style: const TextStyle(color: muted, fontSize: 9.5)),
        ]))),
    ]));
  }
}
