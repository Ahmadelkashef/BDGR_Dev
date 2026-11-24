part of 'fantasy.dart';

// ─────────────────────────────────────────────────────────────────────────────
// v2 team builder (branch fantasy-v2, owner 24 Nov) — LOOK ONLY, no database change.
// Empty pitch + START → pick a formation → pick the team line by line from cards
// (goalkeeper, defenders, midfielders, forwards). A picked card flies onto its spot.
// No prices / budget on screen. Then pick the captain and save.
// Positions stay GK / DEF / MID / FWD for now (exact positions later).
// Phones with "remove animations" get no flight (the player is placed at once).
// ─────────────────────────────────────────────────────────────────────────────

extension _BuilderV2 on _FancyPageState {
  /// first line that still has an empty spot (GK → DEF → MID → FWD); null = 11 picked
  String? get _v2Target {
    for (final pos in _FancyPageState.posOrder) {
      if (_v2FreeIndex(pos) != null) return pos;
    }
    return null;
  }

  int? _v2FreeIndex(String pos) {
    for (var i = 0; i < slotCount(pos); i++) {
      if (squad[pos]![i] == null) return i;
    }
    return null;
  }

  /// -1 start · 0 formation · 1 picking · 2 captain + save
  int get _v2Stage => selectedCount == 11 ? 2 : selectedCount > 0 ? 1 : _gStage;

  Widget buildSquadScreenV2() {
    final stage = _v2Stage;
    final target = stage == 1 ? _v2Target : null;
    return LayoutBuilder(key: const ValueKey('squad'), builder: (context, cons) {
      return Column(children: [
        Container(color: bg, padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: Column(children: [
          backHeader(
            label: isArabic ? currentEvent?.nameAr ?? '' : currentEvent?.nameEn ?? '',
            onBack: () => _v2Set(() { step = 1; saved = false; _gStage = -1; })),
          const SizedBox(height: 8),
          _v2InfoRow(stage),
        ])),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(fit: StackFit.expand, children: [
            buildPitch(empty: stage == -1, target: target),
            if (stage == -1) _v2StartOverlay(),
          ]))),
        AnimatedSize(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: stage == -1 ? const SizedBox(width: double.infinity, height: 12) : _v2Panel(stage, target)),
      ]);
    });
  }

  // ── top line: deadline · picked · formation (tap = start over) ───────────────
  Widget _v2InfoRow(int stage) => Row(children: [
    Expanded(child: _v2Pill(Icons.timer_outlined, countdownText, alert: deadlinePassed)),
    const SizedBox(width: 8),
    _v2Pill(Icons.people_alt_outlined, '$selectedCount / 11'),
    if (stage >= 1) ...[
      const SizedBox(width: 8),
      GestureDetector(onTap: _v2Restart,
        child: _v2Pill(Icons.grid_view_rounded, formation, trailing: Icons.refresh_rounded)),
    ],
  ]);

  Widget _v2Pill(IconData icon, String text, {bool alert = false, IconData? trailing}) => Container(
    height: 36, padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: alert ? Colors.red.withOpacity(0.5) : line)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: alert ? Colors.red : muted),
      const SizedBox(width: 6),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: alert ? Colors.red : Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
      if (trailing != null) ...[const SizedBox(width: 5), Icon(trailing, size: 14, color: muted)],
    ]));

  void _v2Restart() {
    if (selectedCount == 0) { _v2Set(() => _gStage = 0); return; }
    showDialog<bool>(context: context, barrierColor: Colors.black.withOpacity(0.7), builder: (d) => AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: line)),
      title: Text(t('Start over?', 'تبدأ من الأول؟'),
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
      content: Text(t('Your picks will be cleared so you can choose a new formation.',
                      'هنشيل اللعيبة اللي اخترتهم علشان تختار تشكيلة جديدة.'),
        style: const TextStyle(color: muted, fontSize: 13.5, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false),
          child: Text(t('No', 'لا'), style: const TextStyle(color: muted, fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => Navigator.pop(d, true),
          child: Text(t('Start over', 'ابدأ من الأول'), style: const TextStyle(color: brandRed, fontWeight: FontWeight.w900))),
      ])).then((ok) {
      if (ok != true || !mounted) return;
      _v2Set(() { clearSquad(); _flown.clear(); _landedId = null; _gStage = 0; saved = false; });
      squadTick.value++;
    });
  }

  // ── empty pitch: one START button ───────────────────────────────────────────
  Widget _v2StartOverlay() => Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(t('Build your team, line by line', 'ابني فريقك خط بخط'), textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
      const SizedBox(height: 6),
      Text(t('Formation, then goalkeeper, defence, midfield and attack.',
             'التشكيلة، وبعدين الحارس، الدفاع، الوسط، الهجوم.'), textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFDADADA), fontSize: 12.5, height: 1.4,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
      const SizedBox(height: 22),
      _StartButton(label: t('START', 'ابدأ'), onTap: () => _v2Set(() => _gStage = 0)),
    ])));

  // ── bottom panel ────────────────────────────────────────────────────────────
  Widget _v2Panel(int stage, String? target) {
    String title; String? sub; Widget body; Widget? action;
    if (stage == 0) {
      title = t('Pick your formation', 'اختار التشكيلة');
      body = _v2Formations();
      action = _v2Button(t('Next: goalkeeper', 'يلا نختار الحارس'), () => _v2Set(() => _gStage = 1));
    } else if (stage == 2) {
      title = t('Pick your captain', 'اختار الكابتن');
      sub = t('double points', 'نقطه × 2');
      body = _v2CaptainCards();
      action = _v2Button(
        deadlinePassed ? t('DEADLINE PASSED', 'انتهى الديدلاين')
          : captain == null ? t('Pick a captain first', 'اختار الكابتن الأول') : t('SAVE TEAM', 'حفظ الفريق'),
        canSaveV2 && !_saving ? () => saveSquad(noBudget: true) : null, busy: _saving);
    } else {
      final pos = target ?? 'GK';
      final need = slotCount(pos);
      final have = squad[pos]!.take(need).where((p) => p != null).length;
      title = _v2LineTitle(pos, need);
      sub = need > 1 ? '$have / $need' : null;
      body = _v2PlayerCards(pos);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: const BoxDecoration(color: Color(0xFF111114),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: line))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220),
            child: Text(title, key: ValueKey(title), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)))),
          if (sub != null) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: stage == 2 ? captainColor.withOpacity(0.15) : surface2,
              borderRadius: BorderRadius.circular(20)),
            child: Text(sub, style: TextStyle(color: stage == 2 ? captainColor : Colors.white,
              fontSize: 11.5, fontWeight: FontWeight.w800))),
        ])),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) => FadeTransition(opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0.18, 0), end: Offset.zero).animate(a), child: child)),
          child: KeyedSubtree(key: ValueKey('body_${stage}_$target'), child: body)),
        if (action != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: action),
      ]));
  }

  String _v2LineTitle(String pos, int n) {
    switch (pos) {
      case 'GK':  return t('Pick your goalkeeper', 'اختار الحارس');
      case 'DEF': return n == 1 ? t('Pick a defender', 'اختار مدافع') : t('Pick $n defenders', 'اختار $n مدافعين');
      case 'MID': return n == 1 ? t('Pick a midfielder', 'اختار لاعب وسط') : t('Pick $n midfielders', 'اختار $n لاعيبة وسط');
      default:    return n == 1 ? t('Pick a forward', 'اختار مهاجم') : t('Pick $n forwards', 'اختار $n مهاجمين');
    }
  }

  Widget _v2Button(String label, VoidCallback? onTap, {bool busy = false}) => SizedBox(height: 48,
    child: ElevatedButton(onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap != null ? brandRed : surface2,
        foregroundColor: onTap != null ? Colors.white : muted,
        disabledBackgroundColor: surface2, disabledForegroundColor: muted,
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5))));

  // ── formations: small pitch with dots ───────────────────────────────────────
  Widget _v2Formations() => SizedBox(height: 96, child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: _FancyPageState.formations.length,
    separatorBuilder: (_, __) => const SizedBox(width: 10),
    itemBuilder: (_, i) {
      final f = _FancyPageState.formations[i];
      final on = f == formation;
      final c = f.split('-').map(int.parse).toList();
      Widget dots(int n) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(n, (_) => Container(width: 6, height: 6,
          decoration: BoxDecoration(color: on ? Colors.white : Colors.white60, shape: BoxShape.circle))));
      return GestureDetector(onTap: () => changeFormation(f), child: AnimatedContainer(
        duration: const Duration(milliseconds: 180), width: 78,
        padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
        decoration: BoxDecoration(color: on ? const Color(0x26FF1A1A) : cardBg,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? brandRed : line, width: on ? 1.6 : 1)),
        child: Column(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
            decoration: BoxDecoration(color: on ? const Color(0xFF1E5B2C) : const Color(0xFF1A3A22),
              borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [dots(c[2]), dots(c[1]), dots(c[0]), dots(1)]))),
          const SizedBox(height: 5),
          Text(f, style: TextStyle(color: on ? Colors.white : muted, fontSize: 12.5, fontWeight: FontWeight.w900)),
        ])));
    }));

  // ── player cards for the current line ───────────────────────────────────────
  Widget _v2PlayerCards(String pos) {
    if (_playersLoading) {
      return const SizedBox(height: 168, child: Center(child: CircularProgressIndicator(color: muted, strokeWidth: 2)));
    }
    if (_playersError != null && players.isEmpty) {
      return SizedBox(height: 168, child: Center(child: TextButton.icon(
        onPressed: currentEvent == null ? null : () => _loadPlayers(currentEvent!.eventId),
        icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
        label: Text(t('Could not load players. Retry', 'اللعيبة ما اتحمّلوش. جرّب تاني'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))));
    }
    final list = players.where((p) => p.position == pos && !inSquad(p)).toList()
      ..sort((a, b) {
        final c = b.totalPts.compareTo(a.totalPts);
        return c != 0 ? c : (isArabic ? a.nameAr : a.nameEn).compareTo(isArabic ? b.nameAr : b.nameEn);
      });
    if (list.isEmpty) {
      return SizedBox(height: 168, child: Center(child: Text(t('No players for this spot.', 'مفيش لعيبة للمكان ده.'),
        style: const TextStyle(color: muted, fontSize: 13))));
    }
    final lim = maxPerTeam;
    return SizedBox(height: 168, child: ListView.separated(
      key: PageStorageKey('v2_cards_$pos'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final p = list[i];
        final full = lim != null && p.teamId != null && teamCount(p.teamId) >= lim;
        return Builder(builder: (cctx) => GestureDetector(
          onTap: full
            ? () => _showSnack(t('Max $lim players from the same team.', 'أقصى $lim لاعيبة من نفس الفريق.'))
            : () => _v2Fly(cctx, p, pos),
          child: Opacity(opacity: full ? 0.35 : 1, child: _v2CardFace(p))));
      }));
  }

  Widget _v2CaptainCards() {
    final picked = pickedPlayers;
    return SizedBox(height: 168, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: picked.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final p = picked[i];
        return GestureDetector(
          onTap: () => _v2Set(() { captain = p; saved = false; }),
          child: _v2CardFace(p, captainOn: captain?.id == p.id));
      }));
  }

  /// one card: photo (or the team shirt) + crest, name, club, position. Same size for everyone.
  Widget _v2CardFace(FancyPlayer p, {bool captainOn = false}) {
    final kit = _FancyPageState._kits[p.teamId];
    final logo = p.teamId == null ? null : teamLogos[p.teamId];
    final shirt = _playerShirtHero(p, shirtW: 66, bg: Colors.transparent);
    final photo = p.photoUrl;
    return Container(
      width: 112, height: 168,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: captainOn ? captainColor : line, width: captainOn ? 2 : 1)),
      child: Column(children: [
        SizedBox(height: 100, width: 112, child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [(kit?.c1 ?? const Color(0xFF8A8F98)).withOpacity(0.38), cardBg]))),
          if (photo != null && !photo.toLowerCase().contains('.svg'))
            // small decode (phones crash on many full-size photos)
            Image(image: ResizeImage(MediaCache.image(photo), width: 300, allowUpscaling: false),
              fit: BoxFit.cover, alignment: Alignment.topCenter, gaplessPlayback: true,
              loadingBuilder: (_, child, pr) => pr == null ? child : shirt,
              errorBuilder: (_, __, ___) => shirt)
          else shirt,
          if (logo != null) Positioned(left: 6, bottom: 5, child: Container(width: 22, height: 22,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 3)]),
            child: ClipOval(child: _SafeCrest(logo, size: 18)))),
          if (captainOn) Positioned(right: 6, top: 6, child: Container(width: 22, height: 22,
            decoration: BoxDecoration(color: captainColor, shape: BoxShape.circle, border: Border.all(color: Colors.black)),
            child: const Center(child: Text('C', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, height: 1))))),
        ])),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isArabic ? p.nameAr : p.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 2),
            Text(isArabic ? p.teamNameAr : p.teamNameEn, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 10.5, height: 1.2)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(6)),
              child: Text(_v2PosLabel(p.position),
                style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800))),
          ]))),
      ]));
  }

  String _v2PosLabel(String pos) {
    switch (pos) {
      case 'GK':  return t('Goalkeeper', 'حارس');
      case 'DEF': return t('Defender', 'مدافع');
      case 'MID': return t('Midfielder', 'وسط');
      default:    return t('Forward', 'مهاجم');
    }
  }

  // ── the flight: card → its spot on the pitch ────────────────────────────────
  void _v2Fly(BuildContext cardCtx, FancyPlayer p, String pos) {
    if (_flying) return;
    final idx = _v2FreeIndex(pos);
    if (idx == null) return;
    void land() {
      final err = placePlayer(p, pos: pos, index: idx, noBudget: true);
      if (err != null) { _showSnack(err); return; }
      _v2Set(() { _flown.add(p.id); _landedId = p.id; });
      HapticFeedback.lightImpact();
    }
    final src = _v2RectOf(cardCtx);
    final slotCtx = _slotKeys['${pos}_$idx']?.currentContext;
    final dst = slotCtx == null ? null : _v2RectOf(slotCtx);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (src == null || dst == null || overlay == null || calm) { land(); return; }
    _flying = true;
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _FlyingCard(
      from: src, to: dst,
      card: _v2CardFace(p),
      shirt: SizedBox(width: 64, height: 64, child: _playerShirtHero(p, shirtW: 58, bg: Colors.transparent)),
      onDone: () {
        entry.remove();
        _flying = false;
        if (mounted) land();
      }));
    overlay.insert(entry);
  }

  Rect? _v2RectOf(BuildContext c) {
    final ro = c.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
  }
}

// ── START: red circle with a soft pulse ring ─────────────────────────────────
class _StartButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _StartButton({required this.label, required this.onTap});
  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (calm) { _c.stop(); } else if (!_c.isAnimating) { _c.repeat(); }
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: widget.onTap, child: SizedBox(width: 132, height: 132,
    child: AnimatedBuilder(animation: _c, builder: (_, __) {
      final v = Curves.easeOut.transform(_c.value);
      return Stack(alignment: Alignment.center, children: [
        Transform.scale(scale: 0.72 + 0.28 * v, child: Opacity(opacity: (1 - v) * 0.7,
          child: Container(width: 132, height: 132,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: brandRed, width: 2.5))))),
        Container(width: 92, height: 92,
          decoration: BoxDecoration(color: brandRed, shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 14, offset: Offset(0, 6))]),
          child: Center(child: Text(widget.label,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)))),
      ]);
    })));
}

// ── the next empty spots: a soft red pulse ───────────────────────────────────
class _TargetPulse extends StatefulWidget {
  final Widget child;
  const _TargetPulse({required this.child});
  @override
  State<_TargetPulse> createState() => _TargetPulseState();
}

class _TargetPulseState extends State<_TargetPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (calm) { _c.value = 0.5; _c.stop(); } else if (!_c.isAnimating) { _c.repeat(reverse: true); }
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, child: widget.child, builder: (_, child) {
    final v = Curves.easeInOut.transform(_c.value);
    return Transform.scale(scale: 1 + 0.06 * v, child: Stack(clipBehavior: Clip.none, children: [
      child!,
      Positioned.fill(child: IgnorePointer(child: Opacity(opacity: 0.35 + 0.65 * v, child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(7),
          border: Border.all(color: brandRed, width: 1.8)))))),
    ]));
  });
}

// ── landing: a small pop + a white ring that grows and fades (once) ──────────
class _LandingRing extends StatefulWidget {
  final Widget child;
  const _LandingRing({super.key, required this.child});
  @override
  State<_LandingRing> createState() => _LandingRingState();
}

class _LandingRingState extends State<_LandingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (calm) { _c.value = 1; } else if (!_c.isAnimating && _c.value == 0) { _c.forward(); }
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, child: widget.child, builder: (_, child) {
    final v = _c.value;
    final pop = 1 + 0.16 * math.sin(math.pi * v);
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      if (v < 1) Positioned.fill(child: IgnorePointer(child: Transform.scale(scale: 0.6 + 0.9 * v,
        child: Opacity(opacity: (1 - v) * 0.9, child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))))))),
      Transform.scale(scale: pop, child: child),
    ]);
  });
}

// ── the flying card (in the root overlay, screen coordinates) ────────────────
class _FlyingCard extends StatefulWidget {
  final Rect from, to;
  final Widget card, shirt;
  final VoidCallback onDone;
  const _FlyingCard({required this.from, required this.to, required this.card, required this.shirt, required this.onDone});
  @override
  State<_FlyingCard> createState() => _FlyingCardState();
}

class _FlyingCardState extends State<_FlyingCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 640))
    ..addStatusListener((s) { if (s == AnimationStatus.completed) widget.onDone(); })
    ..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(child: Material(type: MaterialType.transparency,
    child: AnimatedBuilder(animation: _c, builder: (_, __) {
      final raw = _c.value;
      final t = Curves.easeInOutCubic.transform(raw);
      final r = Rect.lerp(widget.from, widget.to, t)!;
      final lift = -64 * math.sin(math.pi * t);                    // arc up, then down onto the spot
      final morph = ((raw - 0.4) / 0.4).clamp(0.0, 1.0).toDouble(); // card → shirt
      final dir = widget.to.center.dx < widget.from.center.dx ? -1.0 : 1.0;
      final rot = 0.10 * math.sin(math.pi * t) * dir;
      return Stack(children: [
        Positioned.fromRect(rect: r.shift(Offset(0, lift)), child: Transform.rotate(angle: rot,
          child: Stack(fit: StackFit.expand, children: [
            if (morph < 1) Opacity(opacity: 1 - morph, child: FittedBox(fit: BoxFit.contain, child: widget.card)),
            if (morph > 0) Opacity(opacity: morph, child: FittedBox(fit: BoxFit.contain, child: widget.shirt)),
          ]))),
      ]);
    })));
}
