part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// المباريات والنتايج (زي البريمير ليج): صفحة الجولة ← شيت الماتش (الأحداث + التشكيلة)
// ← دوسة على لاعب = تفاصيل نقطه. كله من السيرفر (fantasy_fixtures / fantasy_match_detail /
// fantasy_player_points)، والنتايج الحقيقية بس (اللي اتدخلت من الداشبورد).
// ═══════════════════════════════════════════════════════════════════════════

bool get _mAr => AppLang.isArabic;
String _mt(String en, String ar) => _mAr ? ar : en;

String _teamName(dynamic t) {
  if (t is! Map) return '';
  return '${_mAr ? (t['name_ar'] ?? t['name_en']) : (t['name_en'] ?? t['name_ar'])}';
}

Widget _crest(dynamic t, {double size = 30}) {
  final logo = t is Map ? t['logo'] as String? : null;
  final en = t is Map ? (t['name_en'] ?? t['name_ar']) as String? : null;
  final fb = TeamInitialsCrest(name: en, size: size);
  return SizedBox(width: size, height: size, child: logo != null && logo.isNotEmpty
      ? _netImage(logo, fit: BoxFit.contain, fallback: fb)
      : fb);
}

String _dayTitle(DateTime d) {
  const ar = ['الاتنين', 'التلات', 'الأربع', 'الخميس', 'الجمعة', 'السبت', 'الحد'];
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  const mEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return _mAr ? '${ar[d.weekday - 1]} ${d.day} ${mAr[d.month - 1]}' : '${en[d.weekday - 1]} ${d.day} ${mEn[d.month - 1]}';
}

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ─── صفحة المباريات والنتايج ──────────────────────────────────────────────
Future<void> openFixturesPage(BuildContext context, {String type = 'WORLD'}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => _FixturesPage(type: type)));

class _FixturesPage extends StatefulWidget {
  final String type;
  const _FixturesPage({required this.type});
  @override
  State<_FixturesPage> createState() => _FixturesPageState();
}

class _FixturesPageState extends State<_FixturesPage> {
  late String _type = widget.type == 'LOCAL' ? 'LOCAL' : 'WORLD';
  int? _round;
  Map<String, dynamic>? _d;
  bool _loading = true, _error = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('fantasy_fixtures', params: {'p': {
        'type': _type, if (_round != null) 'round_no': _round,
      }}) as Map);
      if (!mounted) return;
      setState(() { _d = r; _round = (r['round_no'] as num?)?.toInt(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  List<int> get _rounds => ((_d?['rounds'] as List?) ?? []).map((e) => (e as num).toInt()).toList();

  void _step(int dir) {
    final rs = _rounds;
    final i = rs.indexOf(_round ?? -1);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= rs.length) return;
    _round = rs[j];
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final matches = ((_d?['matches'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final m in matches) {
      final at = DateTime.parse('${m['at']}').toLocal();
      (byDay[_dayTitle(at)] ??= []).add(m);
    }
    final rs = _rounds;
    final idx = rs.indexOf(_round ?? -1);
    return Directionality(
      textDirection: _mAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 16, 0), child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(backgroundColor: cardBg, side: const BorderSide(color: line)),
              icon: const Icon(Icons.arrow_back, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(child: Text(_mt('Fixtures & Results', 'المباريات والنتايج'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
            _FilterMenu(value: _type, items: [('WORLD', _mt('🌍 World', '🌍 العالمي')), ('LOCAL', _mt('🇪🇬 Local', '🇪🇬 المحلي'))],
              onChanged: (v) { setState(() { _type = v; _round = null; }); _load(); }),
          ])),
          const SizedBox(height: 10),
          // ◀ الجولة N ▶
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: idx > 0 ? () => _step(-1) : null,
              icon: Icon(_mAr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, color: idx > 0 ? Colors.white : Colors.white24)),
            SizedBox(width: 130, child: Text(_round == null ? '—' : _mt('Round $_round', 'الجولة $_round'), textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
            IconButton(onPressed: idx >= 0 && idx < rs.length - 1 ? () => _step(1) : null,
              icon: Icon(_mAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: idx >= 0 && idx < rs.length - 1 ? Colors.white : Colors.white24)),
          ]),
          if (_d?['deadline_at'] != null)
            Text(_mt('Deadline: ', 'الديدلاين: ') +
                '${_dayTitle(DateTime.parse('${_d!['deadline_at']}').toLocal())} · ${_hhmm(DateTime.parse('${_d!['deadline_at']}').toLocal())}',
              style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : _error
              ? Center(child: TextButton(onPressed: _load,
                  child: Text(_mt('Could not load. Tap to retry.', 'مش قادرين نحمّل. دوس وجرّب تاني.'), style: const TextStyle(color: muted))))
              : matches.isEmpty
                ? Center(child: Text(_mt('No matches in this round.', 'مفيش ماتشات في الجولة دي.'), style: const TextStyle(color: muted)))
                : BadgerRefresh( onRefresh: _load, child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final e in byDay.entries)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                              child: Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                            for (var i = 0; i < e.value.length; i++) ...[
                              if (i > 0) const Divider(color: line, height: 1),
                              _FixtureRow(m: e.value[i]),
                            ],
                          ]),
                        ),
                    ],
                  ))),
        ])),
      ),
    );
  }
}

class _FixtureRow extends StatelessWidget {
  final Map<String, dynamic> m;
  const _FixtureRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final at = DateTime.parse('${m['at']}').toLocal();
    final finished = m['finished'] == true;
    final started = DateTime.now().isAfter(at);
    return InkWell(
      onTap: started ? () => openMatchSheet(context, '${m['id']}') : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(_teamName(m['home']), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            _crest(m['home'], size: 26),
          ])),
          Container(
            width: 70, margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: finished ? surface2 : Colors.transparent, borderRadius: BorderRadius.circular(8),
              border: finished ? null : Border.all(color: line)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(finished ? '${m['home_score']} - ${m['away_score']}' : _hhmm(at), textDirection: TextDirection.ltr,
                style: TextStyle(color: Colors.white, fontSize: finished ? 16 : 13.5, fontWeight: FontWeight.w900)),
              if (finished || started)
                Text(finished ? _mt('FT', 'انتهت') : _mt('Soon', 'قريب'),
                  style: TextStyle(color: finished ? muted : sage, fontSize: 9.5, fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(child: Row(children: [
            _crest(m['away'], size: 26),
            const SizedBox(width: 8),
            Flexible(child: Text(_teamName(m['away']), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
          ])),
        ]),
      ),
    );
  }
}

// ─── شيت الماتش: النتيجة + الأحداث + التشكيلة ─────────────────────────────
Future<void> openMatchSheet(BuildContext context, String matchId) => showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useRootNavigator: true, useSafeArea: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: _MatchSheet(matchId: matchId)),
    );

class _MatchSheet extends StatefulWidget {
  final String matchId;
  const _MatchSheet({required this.matchId});
  @override
  State<_MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<_MatchSheet> {
  Map<String, dynamic>? _d;
  bool _error = false;
  int _tab = 0;        // 0 الأحداث · 1 التشكيلة
  int _team = 0;       // أنهي فريق في التشكيلة

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = Map<String, dynamic>.from(await _sb.rpc('fantasy_match_detail', params: {'p_match_id': widget.matchId}) as Map);
      if (mounted) setState(() => _d = r);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Directionality(
      textDirection: _mAr ? TextDirection.rtl : TextDirection.ltr,
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Align(alignment: AlignmentDirectional.centerEnd, child: IconButton(onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white70))),
        if (d == null)
          Expanded(child: Center(child: _error
            ? Text(_mt('Could not load the match.', 'مش قادرين نحمّل الماتش.'), style: const TextStyle(color: muted))
            : const CircularProgressIndicator(color: brandRed)))
        else ...[
          _header(d),
          const SizedBox(height: 14),
          if (d['finished'] != true)
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
              _mt('The result is not in yet. Check back soon.', 'النتيجة لسه ما نزلتش. ارجع بعد شوية.'),
              textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 14)))))
          else ...[
            _tabs(),
            const SizedBox(height: 10),
            Expanded(child: _tab == 0 ? _events(d) : _lineups(d)),
          ],
        ],
      ]),
    );
  }

  Widget _header(Map<String, dynamic> d) {
    final at = DateTime.parse('${d['at']}').toLocal();
    final fin = d['finished'] == true;
    Widget side(dynamic t) => Expanded(child: Column(children: [
      _crest(t, size: 54),
      const SizedBox(height: 8),
      Text(_teamName(t), maxLines: 2, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
    ]));
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      side(d['home']),
      Padding(padding: const EdgeInsets.only(top: 6), child: Column(children: [
        Text(_dayTitle(at), style: const TextStyle(color: muted, fontSize: 11.5)),
        const SizedBox(height: 4),
        Text(fin ? '${d['home_score']} - ${d['away_score']}' : _hhmm(at), textDirection: TextDirection.ltr,
          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
        Text(fin ? _mt('Full time', 'انتهت') : _mt('Not in yet', 'لسه'), style: const TextStyle(color: muted, fontSize: 12)),
      ])),
      side(d['away']),
    ]));
  }

  Widget _tabs() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      height: 38, padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(11), border: Border.all(color: line)),
      child: Row(children: [
        for (final (i, label) in [(0, _mt('Match events', 'الأحداث')), (1, _mt('Lineups', 'التشكيلة'))])
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _tab = i),
            child: AnimatedContainer(duration: const Duration(milliseconds: 160), alignment: Alignment.center,
              decoration: BoxDecoration(color: _tab == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(color: _tab == i ? Colors.black : Colors.white70, fontWeight: FontWeight.w900, fontSize: 13))),
          )),
      ]),
    ),
  );

  // ── الأحداث اللي ليها نقط بس: أجوان (+ الأسيست)، ضربات جزاء، كروت ──
  Widget _events(Map<String, dynamic> d) {
    final ev = ((d['events'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (ev.isEmpty) {
      return Center(child: Text(_mt('No goals or cards.', 'مفيش أجوان ولا كروت.'), style: const TextStyle(color: muted)));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
            child: Text('${_mt('Full time', 'نهاية الماتش')}  ${d['home_score']} - ${d['away_score']}',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          for (final e in ev.reversed) _eventRow(e),
        ]),
      ),
    ]);
  }

  Widget _eventRow(Map<String, dynamic> e) {
    final home = e['side'] == 'home';
    final kind = '${e['kind']}';
    final name = '${_mAr ? e['name_ar'] : e['name_en']}';
    final other = (_mAr ? e['other_ar'] : e['other_en']) as String?;
    final minute = '${e['minute']}${e['added'] != null ? '+${e['added']}' : ''}\'';
    final (Widget icon, String? sub) = switch (kind) {
      'goal' => (const Text('⚽', style: TextStyle(fontSize: 18)), other != null ? _mt('Assist: $other', 'أسيست: $other') : null),
      'pen_goal' => (const Text('⚽', style: TextStyle(fontSize: 18)), _mt('Penalty', 'ضربة جزاء')),
      'own_goal' => (const Text('⚽', style: TextStyle(fontSize: 18, color: brandRed)), _mt('Own goal', 'جون في نفسه')),
      'pen_miss' => (const Icon(Icons.close_rounded, color: brandRed, size: 20), _mt('Missed penalty', 'ضيّع ضربة جزاء')),
      'pen_saved' => (const Text('🧤', style: TextStyle(fontSize: 18)), _mt('Saved a penalty', 'صد ضربة جزاء')),
      'yellow' => (Container(width: 12, height: 17, decoration: BoxDecoration(color: const Color(0xFFFFC400), borderRadius: BorderRadius.circular(2))), null),
      _ => (Container(width: 12, height: 17, decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(2))), null),
    };
    final text = Column(crossAxisAlignment: home ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Text(name, textAlign: home ? TextAlign.end : TextAlign.start,
        style: TextStyle(color: e['in_pool'] == true ? Colors.white : Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w800)),
      if (sub != null) Text(sub, style: const TextStyle(color: muted, fontSize: 11.5)),
    ]);
    // الفريق الأول على ناحية، والتاني على الناحية التانية، والدقيقة في النص
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(children: [
        Expanded(child: home ? Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: text), const SizedBox(width: 8), icon]) : const SizedBox()),
        SizedBox(width: 52, child: Text(minute, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
        Expanded(child: home ? const SizedBox() : Row(children: [icon, const SizedBox(width: 8), Flexible(child: text)])),
      ]),
    );
  }

  // ── التشكيلة: الملعب زي 365 + البدلا تحت. الفرق اللي في البول بس ──
  Widget _lineups(Map<String, dynamic> d) {
    final lus = ((d['lineups'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (lus.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(
        _mt('The lineup is not in yet.', 'التشكيلة لسه ما نزلتش.'), textAlign: TextAlign.center, style: const TextStyle(color: muted))));
    }
    final team = _team.clamp(0, lus.length - 1).toInt();
    final lu = lus[team];
    final teamJson = lu['side'] == 'home' ? d['home'] : d['away'];
    final rows = ((lu['rows'] as List?) ?? []).map((r) => (r as List).map((x) => Map<String, dynamic>.from(x as Map)).toList()).toList();
    final subs = ((lu['subs'] as List?) ?? []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
    final eventId = '${d['event_id']}';
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      if (lus.length > 1)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          for (var i = 0; i < lus.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _team = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: _team == i ? Colors.white : cardBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _team == i ? Colors.white : line)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _crest(lus[i]['side'] == 'home' ? d['home'] : d['away'], size: 20),
                  const SizedBox(width: 6),
                  Flexible(child: Text(_teamName(lus[i]['side'] == 'home' ? d['home'] : d['away']), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _team == i ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
                ]),
              ),
            )),
          ],
        ]))
      else
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          _crest(teamJson, size: 22), const SizedBox(width: 8),
          Text(_teamName(teamJson), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        ])),
      // الملعب: الهجوم فوق والحارس تحت
      Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
        ),
        child: Column(children: [
          for (final row in rows.reversed)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Directionality(
              textDirection: TextDirection.ltr,   // نفس أماكن اللاعيبة زي التلفزيون
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final p in row) _PitchPlayer(p: p, eventId: eventId),
              ]),
            )),
          if (lu['formation'] != null)
            Align(alignment: AlignmentDirectional.centerStart, child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
              child: Text('${lu['formation']}', textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)))),
        ]),
      ),
      if (subs.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(_mt('Substitutes', 'البدلا'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final s in subs)
          InkWell(
            onTap: () => showPlayerMatchPoints(context, eventId, s, matchId: widget.matchId),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
              child: Row(children: [
                Text("${s['minute']}'", style: const TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_upward_rounded, color: Color(0xFF4CAF50), size: 16),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_mAr ? s['name_ar'] : s['name_en']}', style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  if (s['off_en'] != null)
                    Text(_mt('For ${s['off_en']}', 'بدل ${s['off_ar']}'), style: const TextStyle(color: muted, fontSize: 11.5)),
                ])),
                _PointsBadge(points: s['points']),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 8),
      Text(_mt('Tap a player to see how he got his points.', 'دوس على أي لاعب تشوف جاب نقطه إزاي.'),
        textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 11.5)),
    ]);
  }
}

class _PointsBadge extends StatelessWidget {
  final dynamic points;
  const _PointsBadge({required this.points});
  @override
  Widget build(BuildContext context) {
    final n = (points as num?) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: n > 0 ? const Color(0xFF00C853) : (n < 0 ? brandRed : const Color(0xFF616161)),
        borderRadius: BorderRadius.circular(8)),
      child: Text(_mt('${n.toStringAsFixed(0)} pts', '${n.toStringAsFixed(0)} ن'),
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _PitchPlayer extends StatelessWidget {
  final Map<String, dynamic> p;
  final String eventId;
  const _PitchPlayer({required this.p, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final goals = (p['g'] as num?)?.toInt() ?? 0;
    final yellow = (p['y'] as num?)?.toInt() ?? 0;
    final red = p['r'] == true;
    final name = '${_mAr ? p['name_ar'] : p['name_en']}';
    final short = name.contains(' ') && !_mAr ? name.split(' ').last : name.split(' ').last;
    return GestureDetector(
      onTap: () => showPlayerMatchPoints(context, eventId, p),
      child: SizedBox(width: 72, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 44, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black26, width: 2)),
            child: Text('${p['number'] ?? ''}', style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          Positioned(bottom: -6, left: -8, child: _PointsBadge(points: p['points'])),
          if (goals > 0)
            Positioned(top: -6, right: -8, child: Container(
              padding: const EdgeInsets.all(1),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Text(goals > 1 ? '⚽$goals' : '⚽', style: const TextStyle(fontSize: 11)))),
          if (yellow > 0 || red)
            Positioned(top: -4, left: -6, child: Container(width: 9, height: 12,
              decoration: BoxDecoration(color: red ? brandRed : const Color(0xFFFFC400), borderRadius: BorderRadius.circular(2)))),
        ]),
        const SizedBox(height: 9),
        Text(short, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
      ])),
    );
  }
}

// ─── بوب أب: اللاعب جاب نقطه إزاي في الماتش ده ───────────────────────────
Future<void> showPlayerMatchPoints(BuildContext context, String eventId, Map<String, dynamic> p, {String? matchId}) =>
    showDialog<void>(context: context, builder: (_) => _PlayerPointsDialog(eventId: eventId, player: p, matchId: matchId));

class _PlayerPointsDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> player;
  final String? matchId;
  const _PlayerPointsDialog({required this.eventId, required this.player, this.matchId});
  @override
  State<_PlayerPointsDialog> createState() => _PlayerPointsDialogState();
}

class _PlayerPointsDialogState extends State<_PlayerPointsDialog> {
  Map<String, dynamic>? _d;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _sb.rpc('fantasy_player_points', params: {'p_event_id': widget.eventId, 'p_player_id': widget.player['player_id']})
        .then((r) { if (mounted) setState(() => _d = Map<String, dynamic>.from(r as Map)); })
        .catchError((_) { if (mounted) setState(() => _error = true); });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final matches = ((_d?['matches'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pos = '${_d?['position'] ?? p['position'] ?? ''}';
    final posLabel = switch (pos) {
      'GK' => _mt('Goalkeeper', 'حارس مرمى'), 'DEF' => _mt('Defender', 'مدافع'),
      'MID' => _mt('Midfielder', 'وسط'), 'FWD' => _mt('Forward', 'مهاجم'), _ => pos };
    return Directionality(
      textDirection: _mAr ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(posLabel, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${_mAr ? p['name_ar'] : p['name_en']}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
            ]),
            const SizedBox(height: 8),
            if (_d == null)
              Padding(padding: const EdgeInsets.all(24), child: Center(child: _error
                ? Text(_mt('Could not load.', 'مش قادرين نحمّل.'), style: const TextStyle(color: muted))
                : const CircularProgressIndicator(color: brandRed)))
            else if (matches.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Text(_mt('No points in this round yet.', 'لسه مفيش نقط في الجولة دي.'),
                textAlign: TextAlign.center, style: const TextStyle(color: muted)))
            else
              for (final m in matches.where((m) => widget.matchId == null || m['match_id'] == widget.matchId || matches.length == 1)) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Text(_teamName(m['home']), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 6), _crest(m['home'], size: 18), const SizedBox(width: 8),
                    Text('${m['home_score']} - ${m['away_score']}', textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8), _crest(m['away'], size: 18), const SizedBox(width: 6),
                    Flexible(child: Text(_teamName(m['away']), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
                  ]),
                ),
                const SizedBox(height: 10),
                _row(_mt('Type', 'النوع'), _mt('Value', 'العدد'), _mt('Points', 'النقط'), head: true),
                const Divider(color: line, height: 1),
                for (final l in ((m['lines'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map))) ...[
                  _row('${_mAr ? l['ar'] : l['en']}', '${l['value']}', '${l['points']}'),
                  const Divider(color: line, height: 1),
                ],
                if (((m['lines'] as List?) ?? []).isEmpty) ...[
                  _row(_mt('Did not play', 'ما لعبش'), '—', '0'),
                  const Divider(color: line, height: 1),
                ],
                _row(_mt('Total points', 'المجموع'), '', '${(m['total'] as num?)?.toStringAsFixed(0) ?? 0}', total: true),
                const SizedBox(height: 6),
              ],
          ]),
        ),
      ),
    );
  }

  Widget _row(String a, String b, String c, {bool head = false, bool total = false}) {
    final st = TextStyle(color: head ? muted : Colors.white, fontSize: head ? 12 : 13.5,
      fontWeight: total || head ? FontWeight.w900 : FontWeight.w600);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
      Expanded(flex: 5, child: Text(a, style: st)),
      Expanded(flex: 2, child: Text(b, textAlign: TextAlign.center, style: st)),
      Expanded(flex: 3, child: Text(c, textAlign: TextAlign.end, style: st.copyWith(color: total ? const Color(0xFF00C853) : st.color))),
    ]));
  }
}
