part of 'profile_page.dart';

extension _ProfileMomentsTab on _ProfilePageState {
  // -------------------------------------------------------------------------
  // MOMENTS
  // -------------------------------------------------------------------------

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String text,
    Widget? button,
  }) {
    return CustomPaint(
      painter: const _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 18, color: _kGray400),
            ),
            Text(
              title,
              style: _s(12, FontWeight.w700, _kGray200, height: 1.33),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: _s(10, FontWeight.w400, _kGray500, height: 1.625),
              ),
            ),
            if (button != null) button,
          ],
        ),
      ),
    );
  }

  Widget _addFirstButton() {
    return _PrimaryButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onTap: _openAddMoment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 10, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Add First Moment',
            style: _s(10, FontWeight.w700, Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMoments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelHeader(
          _visitorMode ? 'Moments' : 'My Moments',
          _visitorMode
              ? 'A sports story, one moment at a time.'
              : 'Your sports story, one moment at a time.',
          bottom: 16,
          alignment: CrossAxisAlignment.center,
          action: _visitorMode
              ? null
              : _PrimaryButton(
                  onTap: _openAddMoment,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 11, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Add Moment',
                        style: _s(10, FontWeight.w700, Colors.white,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
        ),
        ..._momentsHeader('MOMENTS', _moments.length),
        if (_moments.isEmpty)
          _emptyState(
            icon: Icons.photo_library_outlined,
            title: 'No Moments Yet',
            text: _visitorMode
                ? 'No moments to show yet.'
                : 'Your story starts here. Upload your first photo or video to share a moment.',
            button: _visitorMode ? null : _addFirstButton(),
          )
        else
          ..._momentRows(),
      ],
    );
  }

  List<Widget> _momentsHeader(String label, int count) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: _s(10, FontWeight.w600, _kGray500, height: 1.5),
            ),
            Text(
              _countText(count),
              style: _s(10, FontWeight.w400, _kGray500, height: 1.5),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _momentRows() {
    final rows = <Widget>[];
    for (var i = 0; i < _moments.length; i += 2) {
      if (i > 0) {
        rows.add(const SizedBox(height: 12));
      }
      rows.add(
        Row(
          children: [
            Expanded(child: _buildMomentCard(_moments[i])),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < _moments.length
                  ? _buildMomentCard(_moments[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return rows;
  }

  Widget _momentEditButton(_Moment moment) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _changeMomentMedia(moment),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: const Icon(Icons.photo_camera, size: 12, color: Colors.white),
      ),
    );
  }

  Widget _buildMomentCard(_Moment moment) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openMoment(moment),
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Container(
          decoration: BoxDecoration(
            color: _kSecondaryBg,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // الصورة أو الفيديو (صامت وبيلف في الكارت)
              _MomentMediaView(moment: moment, withSound: false),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (moment.isVideo)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.70),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (!_visitorMode)
                Positioned(top: 10, right: 10, child: _momentEditButton(moment)),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (moment.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          moment.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _s(12, FontWeight.w700, Colors.white,
                              height: 1.33),
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.favorite_border,
                            size: 10, color: _kGray300),
                        const SizedBox(width: 4),
                        Text('0',
                            style: _s(10, FontWeight.w400, _kGray300,
                                height: 1.5)),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_outline,
                            size: 10, color: _kGray300),
                        const SizedBox(width: 4),
                        Text('0',
                            style: _s(10, FontWeight.w400, _kGray300,
                                height: 1.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
