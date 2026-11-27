part of 'fantasy.dart';

// ─────────────────────────────────────────────────────────────────────────────
// v2 team builder (branch fantasy-v2, owner 24–25 Nov).
// ONE fixed shape, 3 midfield layouts (4-1-4-1 / 4-2-3-1 / 4-3-3). For the server every layout is
// formation '4-5-1' (4 DEF + 5 MID + 1 FWD: wingers are MID in players.position) → no rule change.
// Slots (squad[pos][index]):
//   GK0 · DEF0 = RB, DEF1 = CB, DEF2 = CB, DEF3 = LB · MID0..2 = the 3 central slots (per layout)
//   MID3 = right wing · MID4 = left wing · FWD0 = striker.
// Pick order: layout → GK → RB → CB → CB → LB → MID0..2 → RW → CF → LW → captain → save.
// Each slot shows only players whose exact position (players.exact_position, Transfermarkt) fits it,
// sorted by market value (€, + EGP at the DB rate), ties → total points → name.
// Card picture = the player's full image when app_settings.fantasy_card_image = 'photo', else / without
// an image → the team shirt. Pitch spots always show the shirt. Phones with "remove animations" get no flight.
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kV2Layouts = ['4-1-4-1', '4-2-3-1', '4-3-3'];

// ── DRAFT 7 (owner 25 Nov, event mode 'draft7', server formation '2-3-1') ──
// GK0 · DEF0 = full back (RB/LB) · DEF1 = CB · MID0 = midfielder (DM/CM/AM) · MID1 = RW (RW/RM) · MID2 = LW (LW/LM)
// · FWD0 = striker (CF/SS). No captain. A "surprise" player (players.fantasy_surprise) scores × surpriseMult.
const List<(String, int)> _kD7Order = [
  ('GK', 0), ('DEF', 0), ('DEF', 1), ('MID', 0), ('MID', 1), ('MID', 2), ('FWD', 0),
];

// ── DRAFT 4 / 5 / 6 (owner 26 Nov): any defender, any midfielder, wingers count as attackers ──
// server keys D / M / F; the size comes per round (fantasy_event_config.draft_size, default 7)
const Map<int, List<(String, int)>> _kDSmallOrder = {
  4: [('GK', 0), ('DEF', 0), ('MID', 0), ('FWD', 0)],
  5: [('GK', 0), ('DEF', 0), ('MID', 0), ('MID', 1), ('FWD', 0)],
  6: [('GK', 0), ('DEF', 0), ('DEF', 1), ('MID', 0), ('MID', 1), ('FWD', 0)],
};

/// one line for the start screen / help: what a draft of this size asks for
String draftShapeText(int size, bool ar) {
  switch (size) {
    case 4: return ar ? '4 اختيارات: حارس، مدافع، لاعب وسط، ومهاجم.' : '4 picks: goalkeeper, defender, midfielder and an attacker.';
    case 5: return ar ? '5 اختيارات: حارس، مدافع، 2 وسط، ومهاجم.' : '5 picks: goalkeeper, defender, two midfielders and an attacker.';
    case 6: return ar ? '6 اختيارات: حارس، 2 مدافعين، 2 وسط، ومهاجم.' : '6 picks: goalkeeper, two defenders, two midfielders and an attacker.';
  }
  return ar ? '7 اختيارات: حارس، ظهير، قلب دفاع، نص ملعب، جناحين، ومهاجم.'
            : '7 picks: goalkeeper, full back, centre back, midfielder, two wingers and a striker.';
}

/// pick order: (squad position, index)
const List<(String, int)> _kV2Order = [
  ('GK', 0), ('DEF', 0), ('DEF', 1), ('DEF', 2), ('DEF', 3),
  ('MID', 0), ('MID', 1), ('MID', 2), ('MID', 3), ('FWD', 0), ('MID', 4),
];

extension _BuilderV2 on _FancyPageState {
  // ── slot rules ──────────────────────────────────────────────────────────────
  /// exact positions a slot takes (depends on the midfield layout for MID0..2)
  Set<String> _v2Accepts(String pos, int idx) {
    if (isDraft && draftSize < 7) {
      switch (pos) {
        case 'GK': return const {'GK'};
        case 'DEF': return const {'RB', 'LB', 'CB'};
        case 'MID': return const {'DM', 'CM', 'AM'};
      }
      return const {'CF', 'SS', 'RW', 'RM', 'LW', 'LM'};   // attacker = striker or winger
    }
    if (isDraft) {
      switch (pos) {
        case 'GK': return const {'GK'};
        case 'DEF': return idx == 0 ? const {'RB', 'LB'} : const {'CB'};
        case 'FWD': return const {'CF', 'SS'};
      }
      return idx == 0 ? const {'DM', 'CM', 'AM'} : idx == 1 ? const {'RW', 'RM'} : const {'LW', 'LM'};
    }
    switch (pos) {
      case 'GK': return const {'GK'};
      case 'DEF': return idx == 0 ? const {'RB'} : idx == 3 ? const {'LB'} : const {'CB'};
      case 'FWD': return const {'CF', 'SS'};
    }
    if (idx == 3) return const {'RW', 'RM'};
    if (idx == 4) return const {'LW', 'LM'};
    final dm = (_layout == '4-1-4-1' && idx == 0) || (_layout == '4-2-3-1' && idx <= 1);
    if (dm) return const {'DM'};
    if (_layout == '4-3-3') return const {'DM', 'CM', 'AM'};
    return const {'CM', 'AM'};
  }

  bool _v2Fits(FancyPlayer p, String pos, int idx) {
    if (isDraft && draftSize < 7) {
      // small drafts: a winger (MID in players.position) can stand in the attacker spot
      final xp = p.exactPos;
      return xp == null ? p.position == pos : _v2Accepts(pos, idx).contains(xp);
    }
    if (p.position != pos) return false;            // the server checks the broad position
    final xp = p.exactPos;
    return xp == null || _v2Accepts(pos, idx).contains(xp);
  }

  /// short code shown on an empty pitch spot
  String _v2SlotCode(String pos, int idx) {
    if (isDraft && draftSize < 7) return pos == 'GK' ? 'GK' : pos == 'DEF' ? 'DEF' : pos == 'MID' ? 'MID' : 'ATT';
    if (isDraft) {
      switch (pos) {
        case 'GK': return 'GK';
        case 'DEF': return idx == 0 ? 'FB' : 'CB';
        case 'FWD': return 'CF';
      }
      return idx == 0 ? 'MID' : idx == 1 ? 'RW' : 'LW';
    }
    final a = _v2Accepts(pos, idx);
    if (pos == 'GK') return 'GK';
    if (pos == 'FWD') return 'CF';
    if (pos == 'DEF') return idx == 0 ? 'RB' : idx == 3 ? 'LB' : 'CB';
    if (idx == 3) return 'RW';
    if (idx == 4) return 'LW';
    if (a.length == 1) return 'DM';
    return a.contains('DM') ? 'MID' : 'CM';
  }

  /// what the user picks now ("pick the right back" …)
  String _v2SlotTitle(String pos, int idx) {
    if (isDraft && draftSize < 7) {
      switch (pos) {
        case 'GK': return t('Pick your goalkeeper', 'اختار الحارس');
        case 'DEF': return idx == 0 ? t('Pick a defender', 'اختار مدافع') : t('Pick your second defender', 'اختار المدافع التاني');
        case 'MID': return idx == 0 ? t('Pick a midfielder', 'اختار لاعب وسط') : t('Pick your second midfielder', 'اختار لاعب الوسط التاني');
      }
      return t('Pick an attacker (striker or winger)', 'اختار مهاجم (رأس حربة أو جناح)');
    }
    if (isDraft) {
      switch (pos) {
        case 'GK': return t('Pick your goalkeeper', 'اختار الحارس');
        case 'DEF': return idx == 0 ? t('Pick a full back (right or left)', 'اختار الظهير (يمين أو شمال)') : t('Pick your centre back', 'اختار قلب الدفاع');
        case 'FWD': return t('Pick your striker', 'اختار المهاجم');
      }
      return idx == 0 ? t('Pick your midfielder', 'اختار لاعب نص الملعب')
        : idx == 1 ? t('Pick your right winger', 'اختار الجناح اليمين') : t('Pick your left winger', 'اختار الجناح الشمال');
    }
    switch (pos) {
      case 'GK': return t('Pick your goalkeeper', 'اختار الحارس');
      case 'FWD': return t('Pick your striker', 'اختار رأس الحربة');
      case 'DEF':
        if (idx == 0) return t('Pick your right back', 'اختار الباك اليمين');
        if (idx == 3) return t('Pick your left back', 'اختار الباك الشمال');
        return idx == 1 ? t('Pick your first centre back', 'اختار قلب الدفاع الأول') : t('Pick your second centre back', 'اختار قلب الدفاع التاني');
    }
    if (idx == 3) return t('Pick your right winger', 'اختار الجناح اليمين');
    if (idx == 4) return t('Pick your left winger', 'اختار الجناح الشمال');
    final a = _v2Accepts(pos, idx);
    if (a.length == 1) return t('Pick a defensive midfielder', 'اختار ارتكاز');
    if (a.contains('DM')) return t('Pick a midfielder', 'اختار لاعب نص ملعب');
    return t('Pick a central / attacking midfielder', 'اختار وسط أو وسط مهاجم');
  }

  /// next empty slot in pick order; null = 11 picked
  List<(String, int)> get _v2Order => isDraft ? (_kDSmallOrder[draftSize] ?? _kD7Order) : _kV2Order;

  (String, int)? get _v2NextSlot {
    for (final s in _v2Order) {
      if (squad[s.$1]![s.$2] == null) return s;
    }
    return null;
  }

  int get _v2Stage => selectedCount == squadSize ? 2 : selectedCount > 0 ? 1 : _gStage;

  /// pitch rows, far (top) → near (bottom); each row left → right on screen
  List<List<(String, int)>> get _v2Rows {
    if (isDraft && draftSize < 7) {
      final o = _kDSmallOrder[draftSize]!;
      List<(String, int)> line(String pos) => [for (final s in o.reversed) if (s.$1 == pos) s];   // index 0 on the right
      return [line('FWD'), line('MID'), line('DEF'), line('GK')];
    }
    if (isDraft) {
      // the full back stands on his own side (a left back on the left), the CB next to him
      final lb = squad['DEF']![0]?.exactPos == 'LB';
      return [
        [('FWD', 0)],
        [('MID', 2), ('MID', 0), ('MID', 1)],
        lb ? [('DEF', 0), ('DEF', 1)] : [('DEF', 1), ('DEF', 0)],
        [('GK', 0)],
      ];
    }
    const def = [('DEF', 3), ('DEF', 2), ('DEF', 1), ('DEF', 0)];
    const gk = [('GK', 0)];
    switch (_layout) {
      case '4-1-4-1':
        return const [[('FWD', 0)], [('MID', 4), ('MID', 2), ('MID', 1), ('MID', 3)], [('MID', 0)], def, gk];
      case '4-2-3-1':
        return const [[('FWD', 0)], [('MID', 4), ('MID', 2), ('MID', 3)], [('MID', 1), ('MID', 0)], def, gk];
      default:
        return const [[('MID', 4), ('FWD', 0), ('MID', 3)], [('MID', 2), ('MID', 1), ('MID', 0)], def, gk];
    }
  }

  // ── layout memory (the server only knows '4-5-1') ───────────────────────────
  Future<void> _v2RestoreLayout(String eventId) async {
    String? l;
    try { l = await LocalStore.getStr('v2_layout_$eventId'); } catch (_) {}
    if (l == null || !_kV2Layouts.contains(l)) {
      // guess from the 3 central players (DM count in MID0..2)
      bool dm(int i) => squad['MID']![i]?.exactPos == 'DM';
      l = (dm(0) && dm(1) && !dm(2)) ? '4-2-3-1' : (dm(0) && !dm(1) && !dm(2)) ? '4-1-4-1' : '4-3-3';
    }
    if (mounted) _v2Set(() => _layout = l!);
  }

  // ── screen ──────────────────────────────────────────────────────────────────
  Widget buildSquadScreenV2() {
    // an old squad (another formation) can't be shown in the fixed shape → start over
    if (formation != v2Formation && selectedCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || formation == v2Formation) return;
        _v2Set(() { clearSquad(); formation = v2Formation; _gStage = -1; _flown.clear(); _landedId = null; });
        squadTick.value++;
      });
    }
    final stage = _v2Stage;
    final next = stage == 1 ? _v2NextSlot : null;
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
            buildPitchV2(empty: stage == -1, target: next),
            if (stage == -1) _v2StartOverlay(),
          ]))),
        AnimatedSize(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: stage == -1 ? const SizedBox(width: double.infinity, height: 12) : _v2Panel(stage, next)),
      ]);
    });
  }

  // ── the pitch (builder + my-squad view) ─────────────────────────────────────
  Widget buildPitchV2({bool readOnly = false, bool empty = false, (String, int)? target}) {
    final rows = empty ? <List<(String, int)>>[] : _v2Rows;
    return ValueListenableBuilder<int>(valueListenable: Ads.version, builder: (context, _, __) {
      final ads = Ads.candidates('fantasy_pitch_board', eventId: currentEvent?.eventId);
      return StadiumPitch(
        rowCount: rows.length,
        board: ads.isEmpty ? null : LedBoard(
          key: ValueKey(ads.map((a) => a.id).join('|')),
          count: ads.length,
          secondsOf: (i) => ads[i].boardS ?? 8,
          itemBuilder: (c, i) => _boardItem(ads[i])),
        rowBuilder: (i, w, h) {
          // bigger when the row has room (my-squad view got the space above the pitch, owner 27 Nov)
          final shirt = (h - 36).clamp(28.0, 64.0).toDouble();
          final cardW = (w / 5 - 4).clamp(52.0, 78.0).toDouble();
          final start = rows.take(i).fold<int>(0, (a, r) => a + r.length);
          // left/right are pitch sides: never flipped by the Arabic (RTL) layout
          return Center(child: FittedBox(fit: BoxFit.scaleDown,
            child: SizedBox(width: w - 8, child: Directionality(textDirection: TextDirection.ltr,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (var k = 0; k < rows[i].length; k++)
                  _v2Cell(rows[i][k].$1, rows[i][k].$2, cardW, shirt, start + k,
                    readOnly: readOnly, isTarget: target == rows[i][k], dim: target != null),
              ])))));
        });
    });
  }

  Widget _v2Cell(String pos, int idx, double cardW, double shirt, int gi,
      {required bool readOnly, required bool isTarget, required bool dim}) {
    final player = squad[pos]![idx];
    final base = _pitchCard(player, _v2SlotCode(pos, idx), cardW, shirt, gi);
    final pct = (isDraft && player != null && deadlinePassed) ? player.draftPct : null;
    final card = (!isDraft || player == null || (!player.surprise && pct == null)) ? base
      : Stack(clipBehavior: Clip.none, children: [
          base,
          if (player.surprise) Positioned(right: -2, top: -4, child: _surpriseBadge()),
          if (pct != null) Positioned(left: -2, top: -4, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
            decoration: BoxDecoration(color: const Color(0xE6000000), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 0.8)),
            child: Text('${pct.round()}%', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, height: 1.1)))),
        ]);
    final slot = readOnly ? card : KeyedSubtree(key: _slotKeys.putIfAbsent('${pos}_$idx', () => GlobalKey()),
      child: player == null
        ? (isTarget ? _TargetPulse(child: card) : Opacity(opacity: dim ? 0.55 : 1, child: card))
        : (player.id == _landedId ? _LandingRing(key: ValueKey('land_${player.id}'), child: card) : card));
    return Expanded(child: Center(child: DropIn(
      key: ValueKey('drop_${pos}_${idx}_${player?.id}'),
      enabled: player != null && !_flown.contains(player.id),
      delay: Duration(milliseconds: 60 * (gi % 6)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: player == null ? null
          : readOnly ? () => _openPlayerInfoDialog(player) : () => _openPlayerDialog(pos, idx),
        child: slot))));
  }

  // ── top line: deadline · picked · layout (tap = start over) ─────────────────
  Widget _v2InfoRow(int stage) => Row(children: [
    Expanded(child: _v2Pill(Icons.timer_outlined, countdownText, alert: deadlinePassed)),
    const SizedBox(width: 8),
    _v2Pill(Icons.people_alt_outlined, '$selectedCount / $squadSize'),
    if (stage >= 1) ...[
      const SizedBox(width: 8),
      GestureDetector(onTap: _v2Restart,
        child: _v2Pill(Icons.grid_view_rounded, isDraft ? t('$draftSize players', '$draftSize لاعيبة') : _layout, trailing: Icons.refresh_rounded)),
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
      content: Text(isDraft
          ? t('Your picks will be cleared so you can pick again.', 'هنشيل اللعيبة اللي اخترتهم علشان تختار من الأول.')
          : t('Your picks will be cleared so you can choose a new shape.', 'هنشيل اللعيبة اللي اخترتهم علشان تختار شكل جديد.'),
        style: const TextStyle(color: muted, fontSize: 13.5, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false),
          child: Text(t('No', 'لا'), style: const TextStyle(color: muted, fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => Navigator.pop(d, true),
          child: Text(t('Start over', 'ابدأ من الأول'), style: const TextStyle(color: brandRed, fontWeight: FontWeight.w900))),
      ])).then((ok) {
      if (ok != true || !mounted) return;
      _v2Set(() { clearSquad(); _flown.clear(); _landedId = null; _duelKey = null; _gStage = isDraft ? 1 : 0; saved = false; formation = v2Formation; });
      squadTick.value++;
    });
  }

  // ── empty pitch: one START button ───────────────────────────────────────────
  Widget _v2StartOverlay() => Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(t('Build your team, spot by spot', 'ابني فريقك مكان مكان'), textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
      const SizedBox(height: 6),
      Text(isDraft
          ? draftShapeText(draftSize, isArabic)
          : t('Shape, then goalkeeper, defence, midfield and attack.',
              'الشكل، وبعدين الحارس، الدفاع، الوسط، الهجوم.'), textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFDADADA), fontSize: 12.5, height: 1.4,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
      if (isDraft && _FancyPageState._limitPills) ...[const SizedBox(height: 14), _v2LimitPills()],
      const SizedBox(height: 22),
      _StartButton(label: t('START', 'ابدأ'), onTap: () => _v2Set(() { _gStage = isDraft ? 1 : 0; formation = v2Formation; })),
    ])));

  /// club limits (owner 27 Nov): shown on the START screen and above the bench — calm glass pills, no popup
  Widget _v2LimitPills({bool benchOnly = false}) {
    Widget pill(IconData ic, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 14, color: brandRed), const SizedBox(width: 6),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
      ]));
    final lim = maxPerTeam ?? 4, sub = _FancyPageState._subsMax;
    return Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
      if (!benchOnly) pill(Icons.shield_outlined, t('Team: max $lim from one club', 'الأساسيين: أقصى $lim من نفس النادي')),
      if (this._benchOn) pill(Icons.event_seat_outlined, t('Bench: max $sub from one club', 'الاحتياطي: أقصى $sub من نفس النادي')),
    ]);
  }

  // ── bottom panel ────────────────────────────────────────────────────────────
  Widget _v2Panel(int stage, (String, int)? next) {
    String title; String? sub; Widget body; Widget? action;
    if (stage == 0) {
      title = t('Pick your shape', 'اختار الشكل');
      body = _v2Layouts();
      action = _v2Button(t('Next: goalkeeper', 'يلا نختار الحارس'), () => _v2Set(() { _gStage = 1; formation = '4-5-1'; }));
    } else if (stage == 2 && isDraft) {
      // launch (owner 26 Nov): save first; the score predictions are asked in a sheet right after the save
      title = t('Your team is ready', 'فريقك جاهز');
      // WORLD: the optional bench before saving
      body = this._benchOn
        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 13), child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_FancyPageState._limitPills) ...[_v2LimitPills(benchOnly: true), const SizedBox(height: 10)],
            this._benchRow(editable: !deadlinePassed)]))
        : _v2CaptainCards(pickOnly: true);
      action = _v2Button(
        deadlinePassed ? t('DEADLINE PASSED', 'انتهى الديدلاين') : t('SAVE TEAM', 'حفظ الفريق'),
        canSaveV2 && !_saving ? _v2Save : null, busy: _saving);
    } else if (stage == 2) {
      title = t('Pick your captain', 'اختار الكابتن');
      sub = t('double points', 'نقطه × 2');
      body = _v2CaptainCards();
      action = _v2Button(
        deadlinePassed ? t('DEADLINE PASSED', 'انتهى الديدلاين')
          : captain == null ? t('Pick a captain first', 'اختار الكابتن الأول') : t('SAVE TEAM', 'حفظ الفريق'),
        canSaveV2 && !_saving ? _v2Save : null, busy: _saving);
    } else {
      final s = next ?? ('GK', 0);
      title = _v2SlotTitle(s.$1, s.$2);
      sub = '${selectedCount + 1} / $squadSize';
      body = isDraft ? (this._pickByCards ? this._cardsWithList(s.$1, s.$2) : _d7Duel(s.$1, s.$2)) : _v2PlayerCards(s.$1, s.$2);
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
          child: KeyedSubtree(key: ValueKey('body_${stage}_${next?.$1}_${next?.$2}'), child: body)),
        if (action != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: action),
      ]));
  }

  Future<void> _v2Save() async {
    final ev = currentEvent;
    await saveSquad(noBudget: true);
    if (saved && ev != null) {
      try { await LocalStore.setStr('v2_layout_${ev.eventId}', _layout); } catch (_) {}
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

  // ── the 3 shapes: small pitch with dots in the real places ──────────────────
  Widget _v2Layouts() => SizedBox(height: 112, child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: _kV2Layouts.length,
    separatorBuilder: (_, __) => const SizedBox(width: 10),
    itemBuilder: (_, i) {
      final l = _kV2Layouts[i];
      final on = l == _layout;
      // dots per row, top → bottom (same rows as the big pitch)
      final rows = l == '4-1-4-1' ? [1, 4, 1, 4, 1] : l == '4-2-3-1' ? [1, 3, 2, 4, 1] : [3, 3, 4, 1];
      Widget dots(int n) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(n, (_) => Container(width: 6, height: 6,
          decoration: BoxDecoration(color: on ? Colors.white : Colors.white60, shape: BoxShape.circle))));
      return GestureDetector(onTap: () => _v2Set(() => _layout = l), child: AnimatedContainer(
        duration: const Duration(milliseconds: 180), width: 92,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(color: on ? const Color(0x26FF1A1A) : cardBg,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? brandRed : line, width: on ? 1.6 : 1)),
        child: Column(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            decoration: BoxDecoration(color: on ? const Color(0xFF1E5B2C) : const Color(0xFF1A3A22),
              borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final n in rows) dots(n)]))),
          const SizedBox(height: 5),
          Text(l, style: TextStyle(color: on ? Colors.white : muted, fontSize: 12.5, fontWeight: FontWeight.w900)),
        ])));
    }));

  // ── player cards for the current slot ───────────────────────────────────────
  Widget _v2PlayerCards(String pos, int idx) {
    if (_playersLoading) {
      return const SizedBox(height: 176, child: Center(child: CircularProgressIndicator(color: muted, strokeWidth: 2)));
    }
    if (_playersError != null && players.isEmpty) {
      return SizedBox(height: 176, child: Center(child: TextButton.icon(
        onPressed: currentEvent == null ? null : () => _loadPlayers(currentEvent!.eventId),
        icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
        label: Text(t('Could not load players. Retry', 'اللعيبة ما اتحمّلوش. جرّب تاني'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))));
    }
    final list = players.where((p) => _v2Fits(p, pos, idx) && !inSquad(p) && !this._inBench(p)).toList()
      ..sort((a, b) {
        // market value high → low (no value last), then total points, then name
        final av = a.marketValue, bv = b.marketValue;
        if (av != bv) {
          if (av == null) return 1;
          if (bv == null) return -1;
          return bv.compareTo(av);
        }
        final c = b.totalPts.compareTo(a.totalPts);
        return c != 0 ? c : (isArabic ? a.nameAr : a.nameEn).compareTo(isArabic ? b.nameAr : b.nameEn);
      });
    if (list.isEmpty) {
      return SizedBox(height: 176, child: Center(child: Text(t('No players for this spot.', 'مفيش لعيبة للمكان ده.'),
        style: const TextStyle(color: muted, fontSize: 13))));
    }
    final lim = maxPerTeam;
    return SizedBox(height: 176, child: ListView.separated(
      key: PageStorageKey('v2_cards_${pos}_$idx'),
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
            : () => _v2Fly(cctx, p, pos, idx),
          child: Opacity(opacity: full ? 0.35 : 1, child: _v2CardFace(p))));
      }));
  }

  Widget _v2CaptainCards({bool pickOnly = false}) {
    final picked = [for (final s in _v2Order) if (squad[s.$1]![s.$2] != null) squad[s.$1]![s.$2]!];
    return SizedBox(height: 176, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: picked.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final p = picked[i];
        if (pickOnly) return _v2CardFace(p);
        return GestureDetector(
          onTap: () => _v2Set(() { captain = p; saved = false; }),
          child: _v2CardFace(p, captainOn: captain?.id == p.id));
      }));
  }

  /// "€110M" / "€500K"
  String _v2Eur(double v) {
    if (v >= 1e6) {
      final m = v / 1e6;
      return '€${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
    }
    return '€${(v / 1e3).round()}K';
  }

  /// the same value in EGP at the DB rate: "6.05 مليار ج" / "27.5 مليون ج"
  String _v2Egp(double eur) {
    final v = eur * _FancyPageState._eurEgp;
    String n(double x) => x >= 100 ? x.toStringAsFixed(0) : x >= 10 ? x.toStringAsFixed(1) : x.toStringAsFixed(2);
    String clean(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
    if (v >= 1e9) return '${clean(n(v / 1e9))} ${t('bn EGP', 'مليار ج')}';
    if (v >= 1e6) return '${clean(n(v / 1e6))} ${t('m EGP', 'مليون ج')}';
    return '${clean(n(v / 1e3))} ${t('k EGP', 'ألف ج')}';
  }

  /// one card: picture (player photo or team shirt) + crest, full name (2 lines), club, market value
  Widget _v2CardFace(FancyPlayer p, {bool captainOn = false}) {
    final kit = _FancyPageState._kits[p.teamId];
    final logo = p.teamId == null ? null : teamLogos[p.teamId];
    final shirt = _playerShirtHero(p, shirtW: 64, bg: Colors.transparent);
    final img = _FancyPageState._cardImage == 'photo' ? p.imageUrl : null;
    final mv = p.marketValue;
    return Container(
      width: 112, height: 176,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: captainOn ? captainColor : line, width: captainOn ? 2 : 1)),
      child: Column(children: [
        SizedBox(height: 96, width: 112, child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [(kit?.c1 ?? const Color(0xFF8A8F98)).withOpacity(0.38), cardBg]))),
          if (img != null && !img.toLowerCase().contains('.svg'))
            // small decode (phones crash on many full-size photos); shirt while loading / on error
            Image(image: ResizeImage(MediaCache.image(img), width: 300, allowUpscaling: false),
              fit: BoxFit.cover, alignment: Alignment.topCenter, gaplessPlayback: true,
              loadingBuilder: (_, child, pr) => pr == null ? child : shirt,
              errorBuilder: (_, __, ___) => shirt)
          else shirt,
          if (logo != null) Positioned(left: 6, bottom: 5, child: Container(width: 22, height: 22,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 3)]),
            child: ClipOval(child: _SafeCrest(logo, size: 18)))),
          if (isDraft && p.surprise) Positioned(right: 6, top: 6, child: _surpriseBadge(big: true)),
          if (captainOn) Positioned(right: 6, top: 6, child: Container(width: 22, height: 22,
            decoration: BoxDecoration(color: captainColor, shape: BoxShape.circle, border: Border.all(color: Colors.black)),
            child: const Center(child: Text('C', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, height: 1))))),
        ])),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // full name: up to 2 lines, a very long one shrinks a little
            SizedBox(height: 28, width: double.infinity, child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 96),
                child: Text(isArabic ? p.nameAr : p.nameEn, maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, height: 1.15))))),
            const SizedBox(height: 1),
            Text(isArabic ? p.teamNameAr : p.teamNameEn, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 10.5, height: 1.2)),
            const Spacer(),
            Text(mv == null ? '—' : _v2Eur(mv), maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, height: 1.1)),
            if (mv != null) Text(_v2Egp(mv), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w600, height: 1.2)),
          ]))),
      ]));
  }

  /// exact position label (falls back to the broad one)
  String _v2PosLabel(FancyPlayer p) {
    switch (p.exactPos) {
      case 'GK': return t('Goalkeeper', 'حارس');
      case 'CB': return t('Centre-Back', 'قلب دفاع');
      case 'LB': return t('Left-Back', 'باك شمال');
      case 'RB': return t('Right-Back', 'باك يمين');
      case 'DM': return t('Def. Midfield', 'ارتكاز');
      case 'CM': return t('Central Midfield', 'وسط');
      case 'AM': return t('Att. Midfield', 'وسط مهاجم');
      case 'LM': return t('Left Midfield', 'وسط شمال');
      case 'RM': return t('Right Midfield', 'وسط يمين');
      case 'LW': return t('Left Winger', 'جناح شمال');
      case 'RW': return t('Right Winger', 'جناح يمين');
      case 'SS': return t('Second Striker', 'مهاجم ثاني');
      case 'CF': return t('Centre-Forward', 'رأس حربة');
    }
    switch (p.position) {
      case 'GK':  return t('Goalkeeper', 'حارس');
      case 'DEF': return t('Defender', 'مدافع');
      case 'MID': return t('Midfielder', 'وسط');
      default:    return t('Forward', 'مهاجم');
    }
  }

  // ── NORMAL 11 / DRAFT 7 switch (only when the draft is open in this round) ──
  Widget draftModeSwitch({void Function(bool draft)? onPick}) {
    Widget seg(bool draft, String label) {
      final on = _draftView == draft;
      return Expanded(child: GestureDetector(
        onTap: on ? null : () => (onPick ?? _setDraftView)(draft),
        child: AnimatedContainer(duration: const Duration(milliseconds: 180), height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? brandRed : Colors.transparent, borderRadius: BorderRadius.circular(9)),
          child: Text(label, maxLines: 1, style: TextStyle(color: on ? Colors.white : muted, fontSize: 13, fontWeight: FontWeight.w900)))));
    }
    return Container(padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Row(children: [seg(false, t('⚽ 11 players', '⚽ 11 لاعب')), seg(true, t('🎯 $draftSize players', '🎯 $draftSize لاعيبة'))]));
  }

  /// switch between the normal squad and the draft squad of this round (each saved on its own)
  void _setDraftView(bool draft) {
    final ev = currentEvent;
    if (ev == null || _flying) return;
    _v2Set(() {
      _draftView = draft;
      clearSquad();
      saved = false; step = 2; _gStage = -1;
      _flown.clear(); _landedId = null; _duelKey = null;
      formation = v2Formation;
    });
    squadTick.value++;
    _loadSavedSquad(ev.eventId);
  }

  // ── DRAFT duel picker: holder vs rival, tap the one you want, the winner stays ──
  // Rivals come in random order; "that's him" locks the holder early. The last one standing flies to the pitch.
  Widget _d7Duel(String pos, int idx) {
    if (_playersLoading) {
      return const SizedBox(height: 236, child: Center(child: CircularProgressIndicator(color: muted, strokeWidth: 2)));
    }
    if (_playersError != null && players.isEmpty) return _v2PlayerCards(pos, idx);   // same retry UI
    final key = '${currentEvent?.eventId}_${pos}_$idx';
    if (_duelKey != key) {
      final lim = maxPerTeam;
      final list = players.where((p) => _v2Fits(p, pos, idx) && !inSquad(p) && !this._inBench(p)
          && !(lim != null && p.teamId != null && teamCount(p.teamId) >= lim)).toList()..shuffle();
      _duelKey = key;
      _duelTotal = list.length;
      _duelHold = list.isEmpty ? null : list[0];
      _duelRival = list.length > 1 ? list[1] : null;
      _duelQueue = list.length > 2 ? list.sublist(2) : [];
      _duelHoldLeft = true;
      _duelPicked = false;
      _duelHist.clear();
    }
    final hold = _duelHold;
    if (hold == null) {
      return SizedBox(height: 236, child: Center(child: Text(t('No players for this spot.', 'مفيش لعيبة للمكان ده.'),
        style: const TextStyle(color: muted, fontSize: 13))));
    }
    final rival = _duelRival;
    final left = _duelQueue.length + (rival == null ? 0 : 1);
    final chosen = _duelPicked || rival == null;
    Widget swap(Widget child, String id) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack, switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: c)),
      child: KeyedSubtree(key: ValueKey(id), child: child));
    // the kept card never moves: tap a card = keep it, the other side gets a new player
    final holdCard = swap(Builder(builder: (cctx) {
      _duelHoldCtx = cctx;
      return GestureDetector(
        onTap: () => rival == null ? _v2Fly(cctx, hold, pos, idx) : _duelNext(keepHold: true),
        child: AnimatedContainer(duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15),
            border: Border.all(color: chosen ? brandRed : Colors.transparent, width: 2)),
          child: _v2CardFace(hold)));
    }), 'h_${hold.id}');
    final rivalCard = rival == null ? null : swap(GestureDetector(onTap: () => _duelNext(keepHold: false),
      child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.transparent, width: 2)),
        child: _v2CardFace(rival))), 'r_${rival.id}');
    final vs = Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 70), child: Container(width: 34, height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
      child: const Text('VS', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900))));
    return SizedBox(height: 236, child: Column(children: [
      Expanded(child: Directionality(textDirection: TextDirection.ltr, child: Row(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (rivalCard == null) holdCard
          else ...(_duelHoldLeft ? [holdCard, vs, rivalCard] : [rivalCard, vs, holdCard]),
        ]))),
      const SizedBox(height: 8),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        Expanded(child: Text(
          rival == null ? t('Last one left', 'ده آخر واحد فضل')
            : t('$left left · tap who you want', 'باقي $left · دوس على اللي عايزه'),
          maxLines: 2, style: const TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w700))),
        TextButton(
          onPressed: _flying ? null : () => this._seeAllFor(pos, idx),
          style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 36)),
          child: Text(t('All players', 'كل اللعيبة'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, decoration: TextDecoration.underline))),
        if (_duelHist.isNotEmpty) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: OutlinedButton(
          onPressed: _flying ? null : _duelUndo,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(t('↶', '↶'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))),
        TextButton(
          onPressed: _flying || !chosen ? null : () => _duelLock(pos, idx),
          style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: chosen ? brandRed : surface2,
            disabledForegroundColor: muted, disabledBackgroundColor: surface2,
            padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(rival == null ? t('Pick him ✓', 'اختاره ✓') : t('That\'s him ✓', 'هو ده ✓'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5))),
      ])),
    ]));
  }

  /// keepHold = the kept card was tapped again (the other side gets the next player);
  /// else the other card is kept now (it stays on its side) and the old one is replaced
  void _duelNext({required bool keepHold}) {
    if (_flying) return;
    HapticFeedback.selectionClick();
    _v2Set(() {
      _duelHist.add([_duelHold, _duelRival, List<FancyPlayer>.of(_duelQueue), _duelHoldLeft, _duelPicked]);
      if (!keepHold && _duelRival != null) {
        _duelHold = _duelRival;
        _duelHoldLeft = !_duelHoldLeft;
      }
      _duelPicked = true;
      _duelRival = _duelQueue.isEmpty ? null : _duelQueue.removeAt(0);
    });
  }

  /// undo the last tap: the same two cards come back, on the same sides
  void _duelUndo() {
    if (_flying || _duelHist.isEmpty) return;
    HapticFeedback.selectionClick();
    _v2Set(() {
      final h = _duelHist.removeLast();
      _duelHold = h[0] as FancyPlayer?;
      _duelRival = h[1] as FancyPlayer?;
      _duelQueue = h[2] as List<FancyPlayer>;
      _duelHoldLeft = h[3] as bool;
      _duelPicked = h[4] as bool;
    });
  }

  /// lock the kept card → it flies to its spot (from the card on screen)
  void _duelLock(String pos, int idx) {
    final hold = _duelHold;
    if (hold == null) return;
    final ctx = _duelHoldCtx;
    if (ctx != null && ctx.mounted) { _v2Fly(ctx, hold, pos, idx); return; }
    final err = placePlayer(hold, pos: pos, index: idx, noBudget: true);
    if (err != null) { _showSnack(err); return; }
    _v2Set(() { _flown.add(hold.id); _landedId = hold.id; });
  }

  // ── draft score predictions (tie-break only) ────────────────────────────────
  /// one row per chosen match: home crest+name · ▲N▼ - ▲N▼ · away name+crest (empty = "؟")
  Widget _d7PredEditor(Map<String, List<int?>> vals, void Function(VoidCallback) set) {
    Widget arrow(IconData i, VoidCallback f) => GestureDetector(behavior: HitTestBehavior.opaque,
      onTap: () { HapticFeedback.selectionClick(); set(f); },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), child: Icon(i, color: Colors.white70, size: 22)));
    Widget box(List<int?> v, int side) => Column(mainAxisSize: MainAxisSize.min, children: [
      arrow(Icons.keyboard_arrow_up_rounded, () => v[side] = ((v[side] ?? -1) + 1).clamp(0, 15).toInt()),
      Container(width: 40, height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(color: v[side] == null ? surface2 : const Color(0x26FF1A1A), borderRadius: BorderRadius.circular(9),
          border: Border.all(color: v[side] == null ? line : brandRed, width: 1.4)),
        child: Text(v[side]?.toString() ?? '؟', style: TextStyle(color: v[side] == null ? muted : Colors.white,
          fontSize: 18, fontWeight: FontWeight.w900))),
      arrow(Icons.keyboard_arrow_down_rounded, () => v[side] = ((v[side] ?? 1) - 1).clamp(0, 15).toInt()),
    ]);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final m in _predMatches) Builder(builder: (_) {
        final v = vals.putIfAbsent(m.matchId, () => [null, null]);
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(isArabic ? m.homeNameAr : m.homeNameEn, maxLines: 2, textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
            const SizedBox(width: 6), predCrest(m.homeLogoUrl, m.homeNameEn, 26),
          ])),
          const SizedBox(width: 8), box(v, 0),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('-', style: TextStyle(color: muted, fontSize: 18, fontWeight: FontWeight.w900))),
          box(v, 1), const SizedBox(width: 8),
          Expanded(child: Row(children: [
            predCrest(m.awayLogoUrl, m.awayNameEn, 26), const SizedBox(width: 6),
            Flexible(child: Text(isArabic ? m.awayNameAr : m.awayNameEn, maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
          ])),
        ]));
      }),
    ]);
  }

  /// "🎯 my predictions" under the my-squad header; before the deadline a tap edits them (saved_at stays the same)
  Widget d7MyPredStrip() {
    final rows = [for (final m in _predMatches) PredRow(
      homeEn: m.homeNameEn, homeAr: m.homeNameAr, homeLogo: m.homeLogoUrl,
      awayEn: m.awayNameEn, awayAr: m.awayNameAr, awayLogo: m.awayLogoUrl,
      ph: _preds[m.matchId]?[0], pa: _preds[m.matchId]?[1],
      hs: m.finished ? m.homeScore : null, as: m.finished ? m.awayScore : null)];
    return DraftPredictStrip(rows: rows, isArabic: isArabic, mine: true,
      onEdit: phaseOf(currentEvent) == 'open' ? _d7EditPreds : null);
  }

  Future<void> _d7EditPreds({bool afterSave = false}) async {
    final ev = currentEvent;
    if (ev == null) return;
    final vals = {for (final m in _predMatches) m.matchId: List<int?>.of(_preds[m.matchId] ?? [null, null])};
    var busy = false;
    final ok = await showModalBottomSheet<bool>(
      context: context, useRootNavigator: true, useSafeArea: true, isScrollControlled: true, backgroundColor: const Color(0xFF111114),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final done = vals.values.every((v) => v[0] != null && v[1] != null);
        return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          if (afterSave) ...[
            Text(t('✓ Your team is saved', '✓ تشكيلتك اتحفظت'), style: const TextStyle(color: Color(0xFF4CD964), fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
          ],
          Text(t('🎯 Your score predictions', '🎯 توقعاتك للنتيجة'), style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(afterSave
              ? t('If you tie on points, the better predictions win. You can change them until the deadline.',
                  'لو اتعادلت في النقط، اللي توقعاته أصح يكسب. تقدر تعدّلها لحد الديدلاين.')
              : t('Tie-break only. Changing them does not change when you saved.', 'لفك التعادل بس. تعديلها مش بيغيّر وقت حفظ تشكيلتك.'),
            textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          _d7PredEditor(vals, ss),
          const SizedBox(height: 12),
          _v2Button(done ? t('SAVE', 'حفظ') : t('Predict the score first', 'توقّع النتيجة الأول'),
            !done || busy ? null : () async {
              ss(() => busy = true);
              try {
                await _sb.rpc('save_draft_predictions', params: {'p_event_id': ev.eventId,
                  'p_preds': [for (final e in vals.entries) {'match_id': e.key, 'home': e.value[0], 'away': e.value[1]}]});
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                ss(() => busy = false);
                _showSnack(_saveErrorText(e.toString()));
              }
            }, busy: busy),
          if (afterSave) TextButton(onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
            child: Text(t('Later', 'بعدين'), style: const TextStyle(color: muted, fontWeight: FontWeight.w700))),
        ]));
      }));
    if (ok == true && mounted) {
      _v2Set(() { _preds..clear()..addAll(vals); });
      _showSnack(t('Predictions saved ✓', 'التوقعات اتحفظت ✓'));
    }
  }

  /// "2" / "1.5" (the surprise multiplier from the DB)
  String _multText() {
    final m = currentEvent?.surpriseMult ?? 2;
    return m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toString();
  }

  /// red "🎲 ×2" pill on surprise players (draft rounds)
  Widget _surpriseBadge({bool big = false}) => Container(
    padding: EdgeInsets.symmetric(horizontal: big ? 7 : 4, vertical: big ? 3 : 1.5),
    decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white, width: big ? 1.2 : 0.8),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)]),
    child: Text('${big ? '🎲 ' : ''}×${_multText()}',
      style: TextStyle(color: Colors.white, fontSize: big ? 11 : 8.5, fontWeight: FontWeight.w900, height: 1.1)));

  // ── the flight: card → its spot on the pitch ────────────────────────────────
  void _v2Fly(BuildContext cardCtx, FancyPlayer p, String pos, int idx) {
    if (_flying || squad[pos]![idx] != null) return;
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


// ── draft score predictions: shared by my squad + another user's draft squad ──
Widget predCrest(String? url, String nameEn, double size) {
  final fb = TeamInitialsCrest(name: nameEn, size: size);
  if (url == null || url.isEmpty) return SizedBox(width: size, height: size, child: fb);
  return SizedBox(width: size, height: size, child: _netImage(url, width: size, height: size, fit: BoxFit.contain, fallback: fb));
}

class PredRow {
  final String homeEn, homeAr, awayEn, awayAr;
  final String? homeLogo, awayLogo;
  final int? ph, pa, hs, as;   // predicted / real (real = null until the result)
  const PredRow({required this.homeEn, required this.homeAr, this.homeLogo, required this.awayEn, required this.awayAr,
    this.awayLogo, this.ph, this.pa, this.hs, this.as});
  factory PredRow.fromPublic(Map<String, dynamic> j) {
    final h = Map<String, dynamic>.from((j['home_team'] as Map?) ?? const {});
    final a = Map<String, dynamic>.from((j['away_team'] as Map?) ?? const {});
    return PredRow(homeEn: '${h['name_en'] ?? ''}', homeAr: '${h['name_ar'] ?? h['name_en'] ?? ''}', homeLogo: h['logo'] as String?,
      awayEn: '${a['name_en'] ?? ''}', awayAr: '${a['name_ar'] ?? a['name_en'] ?? ''}', awayLogo: a['logo'] as String?,
      ph: (j['home'] as num?)?.toInt(), pa: (j['away'] as num?)?.toInt(),
      hs: (j['home_score'] as num?)?.toInt(), as: (j['away_score'] as num?)?.toInt());
  }
  /// 2 = exact, 1 = right winner/draw, 0 = wrong, null = no result yet / no prediction
  int? get grade {
    if (hs == null || as == null || ph == null || pa == null) return null;
    if (ph == hs && pa == as) return 2;
    return (ph! - pa!).sign == (hs! - as!).sign ? 1 : 0;
  }
}

class DraftPredictStrip extends StatelessWidget {
  final List<PredRow> rows;
  final bool isArabic, mine;
  final VoidCallback? onEdit;
  const DraftPredictStrip({super.key, required this.rows, required this.isArabic, required this.mine, this.onEdit});
  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    Widget mark(int? g) => g == null ? const SizedBox(width: 18)
      : SizedBox(width: 18, child: Text(g == 2 ? '🎯' : g == 1 ? '✅' : '✖️', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)));
    return GestureDetector(onTap: onEdit, child: Container(
      width: double.infinity, padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(mine ? t('🎯 My score predictions · tie-break', '🎯 توقعاتي · لفك التعادل')
                                    : t('🎯 Score predictions · tie-break', '🎯 توقعاته · لفك التعادل'),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800))),
          if (onEdit != null) Text(t('Edit', 'تعديل'), style: const TextStyle(color: brandRed, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ]),
        for (final r in rows) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(isArabic ? r.homeAr : r.homeEn, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(width: 5), predCrest(r.homeLogo, r.homeEn, 18),
          ])),
          Container(margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(7)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // home number sits on the home side (right in Arabic), like the names
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final x in ['${r.ph ?? '؟'}', ' - ', '${r.pa ?? '؟'}'])
                  Text(x, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              ]),
              if (r.hs != null && r.as != null) Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t('FT ', 'النتيجة '), style: const TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
                for (final x in ['${r.hs}', '-', '${r.as}'])
                  Text(x, style: const TextStyle(color: muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ]),
            ])),
          Expanded(child: Row(children: [
            predCrest(r.awayLogo, r.awayEn, 18), const SizedBox(width: 5),
            Flexible(child: Text(isArabic ? r.awayAr : r.awayEn, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ])),
          mark(r.grade),
        ])),
      ])));
  }
}
