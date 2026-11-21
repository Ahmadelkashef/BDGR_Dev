part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// الهايلايتس: صور الكسبانين وهما بيستلموا الجوايز (بترفع من الداشبورد)
// - دايرة لكل فترة (الجولة 6، الجولة 5، أكتوبر…) زي هايلايتس إنستجرام، آخر 8 فترات بس
// - الحلقة دهبي لو فيها جديد ما اتشافش، رمادي لو اتشافت
// - جوه: ستوري بيمشي لوحده (4 ثواني)، دوسة على الجنب ترجع، دوسة طويلة توقف
// - أول مرة اليوزر يدخل الفانتازي والصور موجودة ← بيفتح لوحده مرة واحدة
// ═══════════════════════════════════════════════════════════════════════════

const _hlMonthsAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
const _hlMonthsEn = ['January','February','March','April','May','June','July','August','September','October','November','December'];

class _HlGroup {
  final String period, key;
  String? month;              // للأسابيع: الشهر اللي الجولة فيه
  bool lastWeek = false;      // أحدث جولة: بتتكتب "آخر أسبوع"
  final List<Map<String, dynamic>> items = [];
  _HlGroup(this.period, this.key);
  String get id => '$period|$key';
}

/// الترتيب: الموسم (لو فيه) ← آخر شهر ← آخر أسبوع ← باقي الجولات من الأحدث للأقدم،
/// ولما جولات شهر تخلص يدخل الشهر اللي قبله وجولاته… وهكذا
List<_HlGroup> _groupHighlights(List<Map<String, dynamic>> items, {int max = 8}) {
  final byId = <String, _HlGroup>{};
  for (final h in items) {
    final g = byId.putIfAbsent('${h['period']}|${h['key']}', () => _HlGroup('${h['period']}', '${h['key']}'));
    g.month ??= h['month']?.toString();
    g.items.add(h);
  }
  final seasons = byId.values.where((g) => g.period == 'season').toList();
  final months = byId.values.where((g) => g.period == 'month').toList()..sort((a, b) => b.key.compareTo(a.key));
  final weeks = byId.values.where((g) => g.period == 'week').toList()
    ..sort((a, b) => (int.tryParse(b.key) ?? 0).compareTo(int.tryParse(a.key) ?? 0));
  final out = <_HlGroup>[...seasons];
  final added = <String>{};
  void addMonth(_HlGroup m) { if (added.add(m.key)) out.add(m); }
  if (months.isNotEmpty) addMonth(months.first);
  for (var i = 0; i < weeks.length; i++) {
    final w = weeks[i];
    if (i == 0) {
      w.lastWeek = true;
    } else {
      // أول ما ندخل في جولات شهر أقدم من اللي اتعرض: نحط الشهر ده قبل جولاته
      final m = months.where((x) => x.key == w.month).firstOrNull;
      if (m != null) addMonth(m);
    }
    out.add(w);
  }
  for (final m in months) { addMonth(m); }
  return out.take(max).toList();
}

String _hlGroupLabel(_HlGroup g, bool ar) {
  switch (g.period) {
    case 'week':  return g.lastWeek ? (ar ? 'آخر أسبوع' : 'Last week') : (ar ? 'الجولة ${g.key}' : 'Round ${g.key}');
    case 'month':
      final m = int.tryParse(g.key.split('-').last) ?? 1;
      return ar ? _hlMonthsAr[m - 1] : _hlMonthsEn[m - 1];
    default:      return ar ? 'الموسم' : 'Season';
  }
}

class FantasyHighlightsStrip extends StatefulWidget {
  final bool isArabic;
  const FantasyHighlightsStrip({super.key, required this.isArabic});
  @override
  State<FantasyHighlightsStrip> createState() => _FantasyHighlightsStripState();
}

class _FantasyHighlightsStripState extends State<FantasyHighlightsStrip> {
  List<Map<String, dynamic>> _items = [];
  List<_HlGroup> _groups = [];
  final Set<String> _seen = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _sb.rpc('fantasy_highlights_feed', params: {'p_limit': 60});
      final items = ((r as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final groups = _groupHighlights(items);
      for (final g in groups) {
        for (final h in g.items) {
          if (await LocalStore.getFlag('hl_seen_${h['id']}_${h['created_at']}')) _seen.add('${h['id']}');
        }
      }
      if (!mounted) return;
      setState(() { _items = items; _groups = groups; });
      // أول مرة: نوريه الكسبانين علشان يتحمّس
      if (groups.isNotEmpty && !(await LocalStore.getFlag('fantasy_highlights_seen'))) {
        await LocalStore.setFlag('fantasy_highlights_seen');
        if (mounted) _open(0);
      }
    } catch (_) {}
  }

  bool _groupSeen(_HlGroup g) => g.items.every((h) => _seen.contains('${h['id']}'));

  Future<void> _open(int groupIndex) async {
    // الستوريز بتمشي على كل الفترات اللي في الشريط بالترتيب، من الفترة اللي اتداست
    final flat = <Map<String, dynamic>>[for (final g in _groups) ...g.items];
    final start = _groups.take(groupIndex).fold<int>(0, (n, g) => n + g.items.length);
    await showHighlightsGallery(context, flat, widget.isArabic, start: start, onSeen: (h) {
      _seen.add('${h['id']}');
      LocalStore.setFlag('hl_seen_${h['id']}_${h['created_at']}');
    }, onProfile: (h) {
      // بيتفتح جوه تاب الفانتازي (البار اللي تحت يفضل)، والرجوع بيرجّعك هنا
      _openVisitorProfile(context, userId: '${h['user_id']}', username: '${h['username'] ?? ''}', displayName: '${h['name'] ?? ''}');
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(height: 86, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final g = _groups[i];
          final cover = g.items.firstWhere((h) => (h['rank'] as num?)?.toInt() == 1, orElse: () => g.items.first);
          final seen = _groupSeen(g);
          return GestureDetector(
            onTap: () => _open(i),
            child: SizedBox(width: 64, child: Column(children: [
              Container(
                width: 62, height: 62, padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: seen ? null : const LinearGradient(colors: [_gold, Color(0xFFFF8A00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: seen ? Border.all(color: Colors.white24, width: 1.5) : null),
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
                  child: ClipOval(child: _netImage('${cover['photo_url']}', fit: BoxFit.cover, fallback: Container(color: surface2))))),
              const SizedBox(height: 5),
              Text(_hlGroupLabel(g, widget.isArabic), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: seen ? Colors.white54 : Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
          );
        },
      )),
    );
  }
}

Future<void> showHighlightsGallery(BuildContext context, List<Map<String, dynamic>> items, bool isArabic,
    {int start = 0, void Function(Map<String, dynamic>)? onSeen, void Function(Map<String, dynamic>)? onProfile}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black87,
    pageBuilder: (_, __, ___) => WebStage(background: Colors.transparent, child: _HighlightsGallery(items: items, isArabic: isArabic, start: start, onSeen: onSeen, onProfile: onProfile)),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _HighlightsGallery extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool isArabic;
  final int start;
  final void Function(Map<String, dynamic>)? onSeen;
  final void Function(Map<String, dynamic>)? onProfile;
  const _HighlightsGallery({required this.items, required this.isArabic, required this.start, this.onSeen, this.onProfile});
  @override
  State<_HighlightsGallery> createState() => _HighlightsGalleryState();
}

class _HighlightsGalleryState extends State<_HighlightsGallery> with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 4);
  late final PageController _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;
  late final AnimationController _timer = AnimationController(vsync: this, duration: _storyDuration)
    ..addStatusListener((s) { if (s == AnimationStatus.completed) _next(); });
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _startStory();
  }

  @override
  void dispose() { _timer.dispose(); _pc.dispose(); super.dispose(); }

  void _startStory() {
    widget.onSeen?.call(widget.items[_i]);
    _timer.forward(from: 0);
  }

  void _next() {
    if (_i >= widget.items.length - 1) { if (mounted) Navigator.pop(context); return; }
    _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _prev() {
    if (_i == 0) { _timer.forward(from: 0); return; }
    _pc.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  /// الشرط فوق بتبقى للفترة الحالية بس (زي الستوريز)
  (int, int) get _groupRange {
    final h = widget.items[_i];
    bool same(Map<String, dynamic> x) => x['period'] == h['period'] && x['key'] == h['key'];
    var a = _i, b = _i;
    while (a > 0 && same(widget.items[a - 1])) { a--; }
    while (b < widget.items.length - 1 && same(widget.items[b + 1])) { b++; }
    return (a, b);
  }

  String _title(Map<String, dynamic> h) {
    final p = h['period']?.toString(), k = '${h['key'] ?? ''}';
    final type = h['type'] == 'WORLD' ? t('World', 'عالمي') : t('Egypt', 'مصر');
    switch (p) {
      case 'week':  return t('BDGR of the week · Round $k · $type', 'بادجر الأسبوع · الجولة $k · $type');
      case 'month':
        final m = int.tryParse(k.split('-').last) ?? 1;
        return t('BDGR of the month · ${_hlMonthsEn[m - 1]} · $type', 'بادجر الشهر · ${_hlMonthsAr[m - 1]} · $type');
      default:      return t('BDGR of the season · $type', 'بادجر الموسم · $type');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (ga, gb) = _groupRange;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => _timer.stop(),
        onLongPressEnd: (_) => _timer.forward(),
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          final x = d.globalPosition.dx;
          final backSide = rtl ? x > w * 0.7 : x < w * 0.3;
          backSide ? _prev() : _next();
        },
        child: Stack(children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.items.length,
            onPageChanged: (i) { setState(() => _i = i); _startStory(); },
            itemBuilder: (_, i) {
              final h = widget.items[i];
              final rank = (h['rank'] as num?)?.toInt() ?? 0;
              return Stack(fit: StackFit.expand, children: [
                _netImage('${h['photo_url']}', fit: BoxFit.cover, fallback: Container(color: surface2)),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Colors.transparent, Colors.transparent, Color(0xEE000000)],
                  stops: [0, 0.2, 0.55, 1]))),
                Positioned(left: 20, right: 20, bottom: 40, child: SafeArea(top: false, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(_title(h), style: const TextStyle(color: _gold, fontSize: 13.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    // الاسم: دوسة عليه تقفل الستوري وتفتح بروفايله
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onProfile == null ? null : () {
                        _timer.stop();
                        Navigator.pop(context);
                        widget.onProfile!(h);
                      },
                      child: Row(children: [
                        Text(rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉', style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: 10),
                        Flexible(child: Text('${h['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
                        if (widget.onProfile != null) ...[
                          const SizedBox(width: 6),
                          Icon(widget.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: Colors.white70, size: 26),
                        ],
                      ])),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if ((h['prize'] ?? '').toString().isNotEmpty) _pill('🏆 ${h['prize']}', _gold),
                      if (h['points'] != null) _pill(t('${h['points']} pts', '${h['points']} نقطة'), Colors.white),
                    ]),
                  ]))),
              ]);
            },
          ),
          // فوق: شرط بتتملي + إغلاق
          SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Column(children: [
            AnimatedBuilder(animation: _timer, builder: (_, __) => Row(children: [
              for (var j = ga; j <= gb; j++)
                Expanded(child: Container(
                  height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: j < _i ? 1 : j > _i ? 0 : _timer.value,
                    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))))),
            ])),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.emoji_events_rounded, color: _gold, size: 20), const SizedBox(width: 6),
              Text(t('Winners', 'الكسبانين'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ]),
          ]))),
        ]),
      ),
    );
  }

  Widget _pill(String s, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.6))),
    child: Text(s, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 13)),
  );
}
