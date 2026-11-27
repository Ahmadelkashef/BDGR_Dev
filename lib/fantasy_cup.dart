part of 'fantasy.dart';

/// 🏆 كاس بادجر: خروج المغلوب بالمجموعات على تشكيلة الدرافت.
/// السيرفر: badger_cup_for_event / badger_cup_get (القرعة والتأهيل بيتعملوا لوحدهم).
const Color _cupGold = Color(0xFFFFB300);

/// شريط صغير في صفحة الجولة. بيظهر بس لو الجولة دي جزء من كاس.
class BadgerCupBanner extends StatefulWidget {
  const BadgerCupBanner({super.key, required this.eventId, required this.isArabic});
  final String eventId;
  final bool isArabic;
  @override
  State<BadgerCupBanner> createState() => _BadgerCupBannerState();
}

class _BadgerCupBannerState extends State<BadgerCupBanner> {
  Map<String, dynamic>? _c;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _sb.rpc('badger_cup_for_event', params: {'p_event': widget.eventId});
      if (mounted && r != null) setState(() => _c = Map<String, dynamic>.from(r as Map));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    final name = widget.isArabic ? '${c['name_ar']}' : '${c['name_en']}';
    final status = c['status'] as String? ?? 'scheduled';
    final stage = (c['stage'] as num?)?.toInt() ?? 0;
    final myStage = (c['my_stage'] as num?)?.toInt();
    final alive = c['alive'] == true;
    final line = status == 'scheduled'
        ? t('Save a draft squad to enter. Groups are drawn at the deadline.', 'اعمل تشكيلة درافت وتدخل. القرعة بعد الديدلاين.')
        : status == 'finished'
            ? t('The cup is over. See the champion.', 'الكاس خلص. شوف البطل.')
            : myStage == null
                ? t('Stage ${_stageName(stage, false)} is on.', 'شغّال: ${_stageName(stage, true)}')
                : alive
                    ? t('You are still in · ${_stageName(stage, false)}', 'إنت لسه في الكاس · ${_stageName(stage, true)}')
                    : t('You are out. Follow the cup.', 'خرجت من الكاس. تابع اللي فاضلين.');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openBadgerCupPage(context, '${c['id']}', isArabic: widget.isArabic),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: [_cupGold.withOpacity(0.16), cardBg]),
            border: Border.all(color: _cupGold.withOpacity(0.55))),
          child: Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _cupGold, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(line, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3)),
            ])),
            Icon(widget.isArabic ? Icons.chevron_left : Icons.chevron_right, color: _cupGold),
          ]),
        ),
      )),
    );
  }
}

String _stageName(int s, bool ar) => s >= 4
    ? (ar ? 'النهائي' : 'Final')
    : (ar ? 'الدور $s' : 'Stage $s');

Future<void> openBadgerCupPage(BuildContext context, String cupId, {required bool isArabic}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => Directionality(textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: _BadgerCupPage(cupId: cupId, isArabic: isArabic))));

class _BadgerCupPage extends StatefulWidget {
  const _BadgerCupPage({required this.cupId, required this.isArabic});
  final String cupId;
  final bool isArabic;
  @override
  State<_BadgerCupPage> createState() => _BadgerCupPageState();
}

class _BadgerCupPageState extends State<_BadgerCupPage> {
  Map<String, dynamic>? _d;
  bool _loading = true, _failed = false;
  int? _stage;
  bool get ar => widget.isArabic;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final r = await _sb.rpc('badger_cup_get', params: {'p_cup': widget.cupId, 'p_stage': _stage});
      if (!mounted) return;
      setState(() { _d = Map<String, dynamic>.from(r as Map); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  Map get _cup => (_d?['cup'] as Map?) ?? const {};
  Map get _me => (_d?['me'] as Map?) ?? const {};
  Map get _view => (_d?['view'] as Map?) ?? const {};
  List get _stages => (_d?['stages'] as List?) ?? const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: _loading && _d == null
          ? const Center(child: CircularProgressIndicator(color: _cupGold))
          : _failed && _d == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(t('Failed to load.', 'فشل التحميل.'), style: const TextStyle(color: muted)),
                  const SizedBox(height: 10),
                  TextButton(onPressed: _load, child: Text(t('Retry', 'إعادة'), style: const TextStyle(color: _cupGold))),
                ]))
              : BadgerRefresh( onRefresh: _load, child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Row(children: [
                      IconButton(onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(backgroundColor: cardBg, side: BorderSide(color: line)),
                          icon: const Icon(Icons.arrow_back, color: Colors.white)),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
                          child: Text(_cup['arena'] == 'LOCAL' ? t('🇪🇬 Local', '🇪🇬 محلي') : t('🌍 World', '🌍 عالمي'),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 10),
                    _hero(),
                    const SizedBox(height: 14),
                    _stepper(),
                    const SizedBox(height: 14),
                    if (_d?['champion'] != null) ...[_championCard(), const SizedBox(height: 14)],
                    _groupCard(),
                    const SizedBox(height: 14),
                    _rules(),
                  ],
                ))),
    );
  }

  // ── my status at the top ──
  Widget _hero() {
    final name = ar ? '${_cup['name_ar']}' : '${_cup['name_en']}';
    final prize = ar ? _cup['prize_ar'] : _cup['prize_en'];
    final status = _cup['status'] as String? ?? 'scheduled';
    final stage = (_cup['stage'] as num?)?.toInt() ?? 0;
    final inCup = _me['in'] == true;
    final outStage = (_me['out_stage'] as num?)?.toInt();
    final myStage = (_me['stage'] as num?)?.toInt();
    final champ = (_d?['champion'] as Map?)?['user_id'] == _sb.auth.currentUser?.id;
    final first = _stages.isNotEmpty ? _stages.first as Map : const {};
    final firstName = ar ? (first['event_name_ar'] ?? '') : (first['event_name_en'] ?? '');
    String msg; Color c = Colors.white;
    if (champ) { msg = t('🏆 You are the champion!', '🏆 إنت البطل!'); c = _cupGold; }
    else if (status == 'scheduled') {
      msg = _me['has_draft'] == true
          ? t("✅ You're in! Groups are drawn after the $firstName deadline.", '✅ إنت داخل! القرعة بعد ديدلاين $firstName.')
          : t('Save a draft squad in $firstName to enter the cup.', 'اعمل تشكيلة درافت في $firstName عشان تدخل الكاس.');
    } else if (!inCup) { msg = t("You're not in this cup. The next one is yours!", 'إنت مش في الكاس ده. الكاس الجاي ليك!'); c = muted; }
    else if (outStage != null) { msg = t('❌ Out at ${_stageName(outStage, false)}', '❌ خرجت في ${_stageName(outStage, true)}'); c = muted; }
    else if (status == 'finished') { msg = t('The cup is over.', 'الكاس خلص.'); }
    else { msg = t('✅ Still in · ${_stageName(myStage ?? stage, false)}', '✅ إنت لسه في الكاس · ${_stageName(myStage ?? stage, true)}'); c = const Color(0xFF39D98A); }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_cupGold.withOpacity(0.22), cardBg]),
        border: Border.all(color: _cupGold.withOpacity(0.6))),
      child: Column(children: [
        const Text('🏆', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 4),
        Text(name, textAlign: TextAlign.center, style: const TextStyle(color: _cupGold, fontSize: 20, fontWeight: FontWeight.w900)),
        if (prize != null && '$prize'.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('🎁 $prize', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 10),
        Text(msg, textAlign: TextAlign.center, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w800, height: 1.35)),
        if (inCup && status != 'scheduled') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _share,
            style: OutlinedButton.styleFrom(foregroundColor: _cupGold, side: const BorderSide(color: _cupGold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.ios_share, size: 17),
            label: Text(t('Share', 'شيّر'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ]),
    );
  }

  void _share() {
    final name = ar ? '${_cup['name_ar']}' : '${_cup['name_en']}';
    final outStage = (_me['out_stage'] as num?)?.toInt();
    final myStage = (_me['stage'] as num?)?.toInt() ?? 1;
    final champ = (_d?['champion'] as Map?)?['user_id'] == _sb.auth.currentUser?.id;
    final text = champ
        ? t('🏆 I won the $name on BDGR!', '🏆 كسبت $name على BDGR!')
        : outStage != null
            ? t('I reached ${_stageName(outStage, false)} of the $name on BDGR. Next cup is mine 💪', 'وصلت ${_stageName(outStage, true)} في $name على BDGR. الكاس الجاي بتاعي 💪')
            : t("🔥 I'm in ${_stageName(myStage, false)} of the $name on BDGR!", '🔥 أنا في ${_stageName(myStage, true)} في $name على BDGR!');
    Share.share('$text\n${Brand.shareLinkBase}');
  }

  // ── 4 steps: stage 1 → 2 → 3 → final ──
  Widget _stepper() {
    final now = (_cup['stage'] as num?)?.toInt() ?? 0;
    final view = (_view['stage'] as num?)?.toInt();
    final status = _cup['status'];
    final starters = (_d?['starters'] as num?)?.toInt();
    return Row(children: [
      for (final s in _stages) ...[
        Expanded(child: Builder(builder: (_) {
          final m = s as Map;
          final st = (m['stage'] as num).toInt();
          final players = (m['players'] as num?)?.toInt() ?? 0;
          final done = m['finished'] == true && players > 0 && (st < now || status == 'finished');
          final cur = st == now && status == 'running';
          final sel = st == view;
          final canView = players > 0;
          return GestureDetector(
            onTap: canView && !sel ? () { _stage = st; _load(); } : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              decoration: BoxDecoration(
                color: sel ? _cupGold.withOpacity(0.14) : cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cur || sel ? _cupGold : line, width: cur ? 1.4 : 1)),
              child: Column(children: [
                Text(done ? '✓' : cur ? '●' : '○',
                    style: TextStyle(color: done ? const Color(0xFF39D98A) : cur ? _cupGold : muted, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(_stageName(st, ar), maxLines: 1,
                    style: TextStyle(color: cur || sel ? Colors.white : muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(players > 0 ? _fmt(players) : (st == 1 && starters != null ? '~${_fmt(starters)}' : '—'),
                    style: const TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
          );
        })),
        if (s != _stages.last) const SizedBox(width: 6),
      ],
    ]);
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K' : '$n';

  Widget _championCard() {
    final c = Map<String, dynamic>.from(_d!['champion'] as Map);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cupGold)),
      child: Row(children: [
        _avatar(c['avatar'] as String?, '${c['name'] ?? ''}', 44),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('🏆 CHAMPION', '🏆 البطل'), style: const TextStyle(color: _cupGold, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text('${c['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          if ((c['username'] ?? '').toString().isNotEmpty)
            Text('@${c['username']}', style: const TextStyle(color: muted, fontSize: 12)),
        ])),
      ]),
    );
  }

  // ── my group ──
  Widget _groupCard() {
    final rows = (_view['rows'] as List?) ?? const [];
    final grp = _view['group_no'];
    final st = (_view['stage'] as num?)?.toInt();
    final settled = _view['settled'] == true;
    if (grp == null || rows.isEmpty) {
      final status = _cup['status'];
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
        child: Text(status == 'scheduled'
              ? t('Your group shows here once the groups are drawn.', 'مجموعتك هتظهر هنا أول ما القرعة تتعمل.')
              : t("You don't have a group in this stage.", 'مالكش مجموعة في الدور ده.'),
            textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13, height: 1.4)),
      );
    }
    final evId = _view['event_id'] as String?;
    final stMap = _stages.cast<Map>().firstWhere((m) => (m['stage'] as num).toInt() == st, orElse: () => const {});
    final evName = ar ? (stMap['event_name_ar'] ?? '') : (stMap['event_name_en'] ?? '');
    final deadline = DateTime.tryParse('${stMap['deadline_at'] ?? ''}');
    final open = deadline != null && deadline.isAfter(DateTime.now());
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Your group #$grp · ${rows.length} players', 'مجموعتك #$grp · ${rows.length} لاعيبة'),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(settled
                  ? t('Final · only #1 went on', 'النتيجة النهائية · الأول بس كمّل')
                  : evId == null
                      ? t('Round not set yet', 'الجولة لسه ماتحددتش')
                      : open
                          ? t('$evName · squads lock at the deadline', '$evName · التشكيلات بتتقفل في الديدلاين')
                          : t('$evName · live, updates with every match', '$evName · لايف، بتتحدّث مع كل ماتش'),
                style: const TextStyle(color: muted, fontSize: 11.5)),
          ])),
          if (!settled) Text(t('#1 goes on', 'الأول يكمل'),
              style: const TextStyle(color: _cupGold, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ])),
        Divider(height: 1, color: line),
        for (final r in rows) _groupRow(Map<String, dynamic>.from(r as Map), evId, settled, open),
      ]),
    );
  }

  Widget _groupRow(Map<String, dynamic> r, String? evId, bool settled, bool open) {
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final me = r['me'] == true;
    final first = rank == 1;
    final adv = r['advanced'] == true;
    final pts = r['points'];
    final ptsTxt = pts is num ? (pts == pts.roundToDouble() ? '${pts.toInt()}' : pts.toStringAsFixed(1)) : '0';
    final name = '${r['name'] ?? ''}';
    return InkWell(
      onTap: evId == null || open ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _UserSquadPage(
          userId: '${r['user_id']}', userName: name, eventId: evId, roundName: ar ? '${_cup['name_ar']}' : '${_cup['name_en']}',
          username: r['username'] as String?, avatarUrl: r['avatar'] as String?, rank: rank, points: pts, isArabic: ar, draft: true))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        color: me ? brandRed.withOpacity(0.10) : first ? _cupGold.withOpacity(0.07) : null,
        child: Row(children: [
          SizedBox(width: 24, child: Text('$rank', style: TextStyle(color: first ? _cupGold : muted, fontSize: 14, fontWeight: FontWeight.w900))),
          _avatar(r['avatar'] as String?, name, 34),
          const SizedBox(width: 10),
          Expanded(child: Row(children: [
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: me ? FontWeight.w900 : FontWeight.w700))),
            if (me) ...[const SizedBox(width: 6), Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(8)),
                child: Text(t('You', 'إنت'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)))],
          ])),
          if (settled && adv) const Padding(padding: EdgeInsetsDirectional.only(end: 8), child: Text('✅', style: TextStyle(fontSize: 13))),
          Text(ptsTxt, style: TextStyle(color: first ? _cupGold : Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Widget _avatar(String? url, String name, double size) {
    final letter = Center(child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4)));
    return Container(width: size, height: size,
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(size * 0.3)),
      child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.3),
        child: (url != null && url.isNotEmpty) ? _netImage(url, width: size, height: size, fit: BoxFit.cover, fallback: letter) : letter));
  }

  Widget _rules() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('How it works', 'الكاس ماشي إزاي'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      for (final l in [
        t('Played with your 🎯 draft 7 squad.', 'بيتلعب بتشكيلة 🎯 الدرافت 7 بتاعتك.'),
        t('Random groups after the first deadline. Only #1 of each group goes on.', 'قرعة عشوائية بعد أول ديدلاين. الأول في كل مجموعة بس اللي يكمل.'),
        t('4 stages: stage 1 → stage 2 → stage 3 → final.', '4 أدوار: الدور 1 ← 2 ← 3 ← النهائي.'),
        t('No squad in a stage = 0 points.', 'مفيش تشكيلة في دور = صفر نقط.'),
        t('Tied? Score predictions, then who saved first.', 'تعادل؟ توقعات النتيجة، وبعدها اللي حفظ الأول.'),
        t('The champion gets the prize + a 🏆 badge on the profile.', 'البطل ياخد الجايزة + بادج 🏆 في البروفايل.'),
      ]) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('•  ', style: TextStyle(color: _cupGold)),
        Expanded(child: Text(l, style: const TextStyle(color: muted, fontSize: 12.5, height: 1.4))),
      ])),
    ]),
  );
}
