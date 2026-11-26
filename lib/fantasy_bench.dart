part of 'fantasy.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BENCH + PLAYERS SHEET (launch, owner 26 Nov 2026)
// · WORLD bench (per round `draft_subs`): optional 1 GK sub (only for the GK) + up to 3 outfield subs,
//   one DEF, one MID, one ATT (wingers = ATT), in order 1 → 3. A starter who did not play at all is replaced
//   by the next outfield sub in order (any position) who played; the GK only by the GK sub. Server:
//   save_fantasy_draft_subs (saved after the 7, or at once from my squad page), scoring in _draft_calc_event.
// · Players sheet: every eligible player as swipeable cards, or as a list (photo + info) with club /
//   position filters. Used by "See all players" in the duel, by the WORLD picker and by the bench.
// ═══════════════════════════════════════════════════════════════════════════

/// bench line of an exact position (same rule as the server's _draft_line)
String? _benchLine(FancyPlayer p) {
  final xp = p.exactPos;
  if (xp == null) return p.position == 'GK' ? 'GK' : p.position == 'DEF' ? 'DEF' : p.position == 'MID' ? 'MID' : 'ATT';
  if (xp == 'GK') return 'GK';
  if (const {'RB', 'LB', 'CB'}.contains(xp)) return 'DEF';
  if (const {'DM', 'CM', 'AM'}.contains(xp)) return 'MID';
  if (const {'RW', 'RM', 'LW', 'LM', 'CF', 'SS'}.contains(xp)) return 'ATT';
  return null;
}

extension _Bench on _FancyPageState {
  bool get _benchOn => isDraft && (currentEvent?.draftSubs ?? false);
  /// WORLD has many players → swipe cards + a list instead of the 1-v-1 duel
  bool get _pickByCards => arena != 'EGYPT';

  bool _inBench(FancyPlayer p) => _benchGk?.id == p.id || _benchOut.any((b) => b?.id == p.id);

  List<Map<String, dynamic>> get _benchPayload {
    final out = <Map<String, dynamic>>[];
    if (_benchGk != null) out.add({'player_id': _benchGk!.id, 'kind': 'GK'});
    var o = 0;
    for (final b in _benchOut) {
      if (b != null) out.add({'player_id': b.id, 'kind': 'OUT', 'order': ++o});
    }
    return out;
  }

  void _benchLoad(dynamic subs) {
    _benchGk = null;
    for (var i = 0; i < _benchOut.length; i++) _benchOut[i] = null;
    if (subs is! List) return;
    for (final x in subs) {
      final m = Map<String, dynamic>.from(x as Map);
      final f = players.where((p) => p.id == '${m['player_id']}');
      if (f.isEmpty) continue;
      if (m['kind'] == 'GK') {
        _benchGk = f.first;
      } else {
        final o = ((m['order'] as num?)?.toInt() ?? 1) - 1;
        if (o >= 0 && o < _benchOut.length) _benchOut[o] = f.first;
      }
    }
  }

  /// keep outfield orders contiguous (1, 2, 3) after a removal
  void _benchCompact() {
    final l = _benchOut.whereType<FancyPlayer>().toList();
    for (var i = 0; i < _benchOut.length; i++) _benchOut[i] = i < l.length ? l[i] : null;
  }

  Future<void> _benchSave() async {
    final ev = currentEvent;
    if (ev == null || !(_hasSquad || saved)) return;
    try {
      await _sb.rpc('save_fantasy_draft_subs', params: {'p_event_id': ev.eventId, 'p_subs': _benchPayload});   // quiet on success
    } catch (e) {
      final s = e.toString();
      _showSnack(s.contains('team_limit') ? t('Max ${maxPerTeam ?? 4} players from the same club (bench included).', 'أقصى ${maxPerTeam ?? 4} من نفس النادي (مع الاحتياطي).')
        : s.contains('event_closed') ? t('The deadline has passed.', 'الديدلاين عدّى.')
        : t('Could not save the bench. Try again.', 'الاحتياطي ما اتحفظش. جرّب تاني.'));
    }
  }

  /// the bench row: [GK] [1] [2] [3] — photo, name, position; drag 1/2/3 onto each other to change the order
  Widget _benchRow({required bool editable, bool autoSave = false}) {
    Widget face(FancyPlayer? p, String code, {bool hot = false, bool ghost = false}) {
      final empty = p == null;
      return AnimatedContainer(duration: const Duration(milliseconds: 150),
        height: 96, margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(color: empty ? Colors.transparent : cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hot ? brandRed : empty ? Colors.white24 : line, width: hot ? 1.6 : 1)),
        child: Opacity(opacity: ghost ? 0.35 : 1, child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (empty)
              Icon(Icons.add_rounded, color: editable ? Colors.white54 : Colors.white12, size: 26)
            else ...[
              this._sheetAvatar(p, 40),
              const SizedBox(height: 4),
              Text(isArabic ? p.nameAr : p.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.1)),
              Text(_benchLineLabel(_benchLine(p)), maxLines: 1, textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 9.5, height: 1.2)),
            ],
          ])),
          PositionedDirectional(start: 0, top: 0, child: Container(width: 18, height: 18, alignment: Alignment.center,
            decoration: BoxDecoration(color: code == 'GK' ? const Color(0xFF2E7D32) : surface2, shape: BoxShape.circle),
            child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)))),
        ])));
    }
    void act(int i) {
      final p = i == 0 ? _benchGk : _benchOut[i - 1];
      if (!editable) { if (p != null) _openPlayerInfoDialog(p); return; }
      if (p == null) { _benchPick(i, autoSave: autoSave); } else { _benchMenu(i, autoSave: autoSave); }
    }
    Future<void> swap(int a, int b) async {   // outfield indexes 0..2
      if (a == b) return;
      HapticFeedback.selectionClick();
      _v2Set(() {
        final x = _benchOut[a]; _benchOut[a] = _benchOut[b]; _benchOut[b] = x;
        _benchCompact();
        if (!autoSave) saved = false;
      });
      if (autoSave) await _benchSave();
    }
    Widget outChip(int k) {
      final p = _benchOut[k];
      final tile = GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => act(k + 1), child: face(p, '${k + 1}'));
      if (!editable || p == null) return Expanded(child: tile);
      return Expanded(child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != k,
        onAcceptWithDetails: (d) => swap(d.data, k),
        builder: (_, cand, __) {
          final hot = cand.isNotEmpty;
          return LayoutBuilder(builder: (_, cons) => LongPressDraggable<int>(
            data: k,
            delay: const Duration(milliseconds: 180),
            hapticFeedbackOnStart: true,
            feedback: Material(color: Colors.transparent, child: SizedBox(width: cons.maxWidth, child: face(p, '${k + 1}', hot: true))),
            childWhenDragging: face(p, '${k + 1}', ghost: true),
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => act(k + 1), child: face(p, '${k + 1}', hot: hot))));
        }));
    }
    final filled = _benchOut.whereType<FancyPlayer>().length;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(t('BENCH', 'الاحتياطي'), style: const TextStyle(color: muted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Expanded(child: Text(
          editable && filled > 1
            ? t('hold & drag to change the order', 'دوس مطوّل واسحب علشان تغيّر الترتيب')
            : t('optional · comes in if a starter does not play', 'اختياري · بينزل لو لاعب أساسي مالعبش'),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 10.5))),
        GestureDetector(onTap: _benchHelp, child: const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => act(0), child: face(_benchGk, 'GK'))),
        for (var k = 0; k < 3; k++) outChip(k),
      ]),
    ]);
  }

  String _benchLineLabel(String? l) => switch (l) {
    'GK' => t('Goalkeeper', 'حارس'),
    'DEF' => t('Defender', 'مدافع'),
    'MID' => t('Midfielder', 'وسط'),
    _ => t('Attacker', 'مهاجم'),
  };

  void _benchHelp() => showModalBottomSheet<void>(
    context: context, useRootNavigator: true, useSafeArea: true, backgroundColor: bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 22), child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('How the bench works', 'الاحتياطي بيشتغل إزاي'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final l in [
          t('Optional: a goalkeeper + up to 3 players, one defender, one midfielder, one attacker.',
            'اختياري: حارس + لحد 3 لاعيبة، مدافع ووسط ومهاجم (واحد من كل خط).'),
          t('If one of your 7 does not play at all, sub 1 comes in, then 2, then 3 — whatever the position.',
            'لو حد من الـ7 مالعبش خالص، يدخل احتياطي 1، بعده 2، بعده 3، أيًا كان المركز.'),
          t('The bench goalkeeper only replaces your goalkeeper.', 'الحارس الاحتياطي بيدخل مكان الحارس بس.'),
          t('A sub who did not play either is skipped.', 'الاحتياطي اللي مالعبش هو كمان بيتخطى.'),
        ]) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $l',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
      ])));

  /// pick a bench player for spot i (0 = GK, 1..3 = outfield order)
  Future<void> _benchPick(int i, {bool autoSave = false}) async {
    final used = <String?>{for (var k = 0; k < 3; k++) if (k != i - 1 && _benchOut[k] != null) _benchLine(_benchOut[k]!)};
    final p = await _openPlayersSheet(
      title: i == 0 ? t('Bench goalkeeper', 'الحارس الاحتياطي') : t('Sub $i', 'احتياطي $i'),
      filter: (p) {
        final l = _benchLine(p);
        if (l == null || inSquad(p) || _inBench(p)) return false;
        return i == 0 ? l == 'GK' : (l != 'GK' && !used.contains(l));
      },
      countBench: true);
    if (p == null || !mounted) return;
    _v2Set(() {
      if (i == 0) { _benchGk = p; } else { _benchOut[i - 1] = p; _benchCompact(); }
      if (!autoSave) saved = false;
    });
    if (autoSave) await _benchSave();
  }

  void _benchMenu(int i, {bool autoSave = false}) {
    final p = i == 0 ? _benchGk : _benchOut[i - 1];
    if (p == null) return;
    showModalBottomSheet<String>(
      context: context, useRootNavigator: true, useSafeArea: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 14), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isArabic ? p.nameAr : p.nameEn, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.swap_horiz_rounded, color: Colors.white), title: Text(t('Change', 'غيّره'), style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(ctx, 'change')),
        if (i > 0) for (var k = 1; k <= 3; k++)
          if (k != i && _benchOut[k - 1] != null) ListTile(leading: const Icon(Icons.swap_vert_rounded, color: Colors.white),
            title: Text(t('Swap with sub $k', 'بدّله مع احتياطي $k'), style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, 'swap$k')),
        ListTile(leading: const Icon(Icons.info_outline_rounded, color: Colors.white), title: Text(t('Player info', 'معلومات اللاعب'), style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(ctx, 'info')),
        ListTile(leading: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF5C5C)),
          title: Text(t('Remove', 'شيله'), style: const TextStyle(color: Color(0xFFFF5C5C))),
          onTap: () => Navigator.pop(ctx, 'remove')),
      ]))).then((a) async {
      if (!mounted || a == null) return;
      if (a == 'info') { _openPlayerInfoDialog(p); return; }
      if (a == 'change') {
        _v2Set(() { if (i == 0) { _benchGk = null; } else { _benchOut[i - 1] = null; } });
        await _benchPick(i, autoSave: autoSave);
        return;
      }
      _v2Set(() {
        if (a == 'remove') {
          if (i == 0) { _benchGk = null; } else { _benchOut[i - 1] = null; _benchCompact(); }
        } else if (a.startsWith('swap') && i > 0) {
          final k = int.parse(a.substring(4)) - 1;
          final x = _benchOut[k];
          _benchOut[k] = _benchOut[i - 1];
          _benchOut[i - 1] = x;
        }
        if (!autoSave) saved = false;
      });
      if (autoSave) await _benchSave();
    });
  }

  /// small circle picture: player photo, else the team shirt
  Widget _sheetAvatar(FancyPlayer p, double size) {
    final shirt = SizedBox(width: size, height: size, child: _playerShirtHero(p, shirtW: size * 0.8, bg: Colors.transparent));
    final img = p.imageUrl;
    return Container(width: size, height: size, clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: surface2, shape: BoxShape.circle),
      child: (img == null || img.toLowerCase().contains('.svg')) ? shirt
        : Image(image: ResizeImage(MediaCache.image(img), width: (size * 3).round(), allowUpscaling: false),
            fit: BoxFit.cover, alignment: Alignment.topCenter,
            loadingBuilder: (_, child, pr) => pr == null ? child : shirt, errorBuilder: (_, __, ___) => shirt));
  }

  /// every eligible player: swipe cards, or a list (photo + info) with club / position filters → the chosen one
  Future<FancyPlayer?> _openPlayersSheet({required String title, required bool Function(FancyPlayer) filter,
      bool listFirst = false, bool countBench = false}) {
    final all = players.where(filter).toList()
      ..sort((a, b) {
        final av = a.marketValue, bv = b.marketValue;
        if (av != bv) { if (av == null) return 1; if (bv == null) return -1; return bv.compareTo(av); }
        final c = b.totalPts.compareTo(a.totalPts);
        return c != 0 ? c : (isArabic ? a.nameAr : a.nameEn).compareTo(isArabic ? b.nameAr : b.nameEn);
      });
    final lim = maxPerTeam;
    int clubCount(String? team) => team == null ? 0
      : teamCount(team) + (countBench ? [_benchGk, ..._benchOut].where((b) => b?.teamId == team).length : 0);
    var asList = listFirst;
    var club = '', pos = '';
    final clubs = <String, String>{for (final p in all) if (p.teamId != null) p.teamId!: isArabic ? p.teamNameAr : p.teamNameEn};
    final poss = <String>{for (final p in all) if (p.exactPos != null) p.exactPos!}.toList()..sort();
    return showModalBottomSheet<FancyPlayer>(
      context: context, useRootNavigator: true, useSafeArea: true, isScrollControlled: true, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final list = all.where((p) => (club.isEmpty || p.teamId == club) && (pos.isEmpty || p.exactPos == pos)).toList();
        bool full(FancyPlayer p) => lim != null && p.teamId != null && clubCount(p.teamId) >= lim;
        void pick(FancyPlayer p) {
          if (full(p)) { _showSnack(t('Max $lim players from the same club.', 'أقصى $lim لاعيبة من نفس النادي.')); return; }
          HapticFeedback.selectionClick();
          Navigator.pop(ctx, p);
        }
        Widget seg(bool l, IconData ic, String label) => Expanded(child: GestureDetector(
          onTap: () => ss(() => asList = l),
          child: AnimatedContainer(duration: const Duration(milliseconds: 160), height: 34, alignment: Alignment.center,
            decoration: BoxDecoration(color: asList == l ? brandRed : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, size: 16, color: asList == l ? Colors.white : muted), const SizedBox(width: 6),
              Text(label, style: TextStyle(color: asList == l ? Colors.white : muted, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ]))));
        return FractionallySizedBox(heightFactor: asList ? 0.9 : 0.52, child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
            Text('${list.length}', style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800)),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
            child: Row(children: [
              seg(false, Icons.view_carousel_outlined, t('Cards', 'كروت')),
              seg(true, Icons.view_list_rounded, t('List', 'ليستة')),
            ]))),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            Expanded(child: _FilterMenu(value: club, expand: true,
              items: [('', t('All clubs', 'كل الأندية')), for (final e in clubs.entries) (e.key, e.value)],
              onChanged: (v) => ss(() => club = v))),
            if (poss.length > 1) ...[
              const SizedBox(width: 8),
              Expanded(child: _FilterMenu(value: pos, expand: true,
                items: [('', t('All positions', 'كل المراكز')), for (final x in poss) (x, x)],
                onChanged: (v) => ss(() => pos = v))),
            ],
          ])),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Expanded(child: Center(child: Text(t('No players.', 'مفيش لعيبة.'), style: const TextStyle(color: muted))))
          else if (!asList)
            SizedBox(height: 176, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => GestureDetector(onTap: () => pick(list[i]),
                child: Opacity(opacity: full(list[i]) ? 0.35 : 1, child: _v2CardFace(list[i])))))
          else
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = list[i];
                final mv = p.marketValue;
                return Opacity(opacity: full(p) ? 0.35 : 1, child: Material(color: cardBg, borderRadius: BorderRadius.circular(12),
                  child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => pick(p),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Row(children: [
                      _sheetAvatar(p, 46),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isArabic ? p.nameAr : p.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('${isArabic ? p.teamNameAr : p.teamNameEn} · ${_v2PosLabel(p)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 12)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(mv == null ? '—' : _v2Eur(mv), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                        Text('${p.totalPts.toStringAsFixed(0)} ${t('pts', 'نقطة')}', style: const TextStyle(color: muted, fontSize: 11)),
                      ]),
                    ])))));
              })),
          if (!asList) const Spacer(),
        ]));
      }));
  }

  /// put a player chosen from the sheet straight in his spot (no flight)
  void _placeFromSheet(FancyPlayer p, String pos, int idx) {
    final err = placePlayer(p, pos: pos, index: idx, noBudget: true);
    if (err != null) { _showSnack(err); return; }
    HapticFeedback.lightImpact();
    _v2Set(() { _landedId = p.id; _duelKey = null; });
  }

  Future<void> _seeAllFor(String pos, int idx, {bool listFirst = false}) async {
    final p = await _openPlayersSheet(
      title: this._v2SlotTitle(pos, idx), listFirst: listFirst,
      filter: (p) => this._v2Fits(p, pos, idx) && !inSquad(p) && !_inBench(p));
    if (p != null && mounted) _placeFromSheet(p, pos, idx);
  }

  /// WORLD picker: swipe cards + "List" for the whole list with filters
  Widget _cardsWithList(String pos, int idx) => Column(mainAxisSize: MainAxisSize.min, children: [
    this._v2PlayerCards(pos, idx),
    const SizedBox(height: 8),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
      Expanded(child: Text(t('Swipe to see more', 'اسحب تشوف أكتر'), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700))),
      OutlinedButton.icon(
        onPressed: _flying ? null : () => _seeAllFor(pos, idx, listFirst: true),
        icon: const Icon(Icons.view_list_rounded, size: 17),
        label: Text(t('List', 'ليستة'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38),
          padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ])),
  ]);
}
