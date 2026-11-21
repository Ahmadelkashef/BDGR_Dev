part of 'profile_page.dart';

extension _ProfileFantasyTab on _ProfilePageState {
  // ---- Fantasy tab ----

  Widget _buildFantasy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelHeader(
          _visitorMode ? 'Fantasy' : 'My Fantasy',
          _visitorMode
              ? 'Lineup and results, round by round.'
              : 'Your lineup and results, round by round.',
          action: const Icon(Icons.sports_soccer, size: 20, color: _kRed),
        ),
        _buildFantasySportChips(),
        if (_fantasyRounds.isEmpty)
          _buildFantasyEmpty()
        else
          _buildFantasyRounds(),
      ],
    );
  }

  // ---- Sport selector (الديفولت كورة) ----

  Widget _buildFantasySportChips() {
    const sports = <(String, String, IconData, bool)>[
      ('football', 'Football', Icons.sports_soccer, true),
      ('padel', 'Padel', Icons.sports_tennis, false),
      ('basketball', 'Basketball', Icons.sports_basketball, false),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final sport in sports)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _fantasySportChip(
                  sport.$1,
                  sport.$2,
                  sport.$3,
                  sport.$4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fantasySportChip(
    String id,
    String label,
    IconData icon,
    bool available,
  ) {
    final active = _fantasySport == id;
    final color = active
        ? _kRed
        : (available ? _kGray300 : _kGray600);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectFantasySport(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kRed.withOpacity(0.10) : _kCardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? _kRed.withOpacity(0.40) : _kCardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(label, style: _s(11, FontWeight.w700, color, height: 1.4)),
            if (!available) ...[
              const SizedBox(width: 6),
              Text(
                'Soon',
                style: _s(8, FontWeight.w700, _kGray600, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Rounds navigator + round card ----

  Widget _buildFantasyRounds() {
    final total = _fantasyRounds.length;
    var index = _fantasyRoundIndex;
    if (index < 0) index = 0;
    if (index > total - 1) index = total - 1;
    final round = _fantasyRounds[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _roundArrow(
                Icons.chevron_left,
                index > 0,
                () => _stepFantasyRound(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Round ${round.number}',
                      style: _s(14, FontWeight.w900, Colors.white, height: 1.43),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (round.isCurrent)
                          _badge(
                            'CURRENT',
                            _kRed.withOpacity(0.10),
                            const Color(0xFFFF7777),
                          )
                        else
                          _badge(
                            'FINISHED',
                            const Color(0xFF10B981).withOpacity(0.10),
                            _kEmerald,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '${index + 1} / $total',
                          style: _s(10, FontWeight.w400, _kGray500, height: 1.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _roundArrow(
                Icons.chevron_right,
                index < total - 1,
                () => _stepFantasyRound(1),
              ),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 200) {
              _stepFantasyRound(-1);
            } else if (velocity < -200) {
              _stepFantasyRound(1);
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey<int>(round.number),
              child: _FantasyRoundCard(round: round),
            ),
          ),
        ),
        if (total > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'Swipe left or right to switch rounds',
                style: _s(9, FontWeight.w400, _kGray600, height: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _roundArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCardBorder),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? Colors.white : _kGray600,
        ),
      ),
    );
  }

  // ---- Empty state ----

  Widget _buildFantasyEmpty() {
    return CustomPaint(
      painter: const _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'No Fantasy team yet',
              style: _s(12, FontWeight.w700, _kGray200, height: 1.33),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                _visitorMode
                    ? 'No fantasy lineup to show yet.'
                    : 'Build your lineup and it will show up here.',
                textAlign: TextAlign.center,
                style: _s(10, FontWeight.w400, _kGray500, height: 1.5),
              ),
            ),
            if (!_visitorMode)
              _PrimaryButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () {
                final callback = widget.onBuildTeam;
                if (callback != null) {
                  callback();
                } else {
                  _showToast('Build Team will be connected soon.');
                }
              },
              child: Text(
                'Build my team',
                style: _s(10, FontWeight.w700, Colors.white, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
