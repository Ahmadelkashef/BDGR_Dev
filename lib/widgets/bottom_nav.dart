import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand.dart';

// ============================================================
// NavItem — بيانات تاب واحد
// ============================================================

class NavItem {
  const NavItem({required this.label, required this.svgInner});
  final String label;
  final String svgInner;
}

// ============================================================
// BottomNav — الويدجت الرئيسي
// ============================================================

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<NavItem>     items;
  final int               selectedIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 60;
  static const double _overflow  = 30;
  static const double _circle    = 50;
  static const double _maxWidth  = 520;
  static const double _sidePad   = 4;

  @override
  Widget build(BuildContext context) {
    final inset       = MediaQuery.of(context).padding.bottom;
    final totalHeight = _overflow + _barHeight + inset;

    return SizedBox(
      height: totalHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SizedBox(
            width: double.infinity,
            height: totalHeight,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w       = constraints.maxWidth;
                final itemW   = (w - _sidePad * 2) / items.length;
                final targetX = _sidePad + itemW * (selectedIndex + 0.5);

                final buttonsRow = Positioned(
                  left: _sidePad, right: _sidePad,
                  top: _overflow,  height: _barHeight,
                  child: Row(
                    children: List.generate(
                      items.length,
                      (i) => Expanded(
                        child: _NavButton(
                          item:   items[i],
                          active: i == selectedIndex,
                          onTap:  () => onTap(i),
                        ),
                      ),
                    ),
                  ),
                );

                return TweenAnimationBuilder<double>(
                  tween:    Tween<double>(end: targetX),
                  duration: const Duration(milliseconds: 320),
                  curve:    Curves.easeOutCubic,
                  child:    buttonsRow,
                  builder:  (_, center, child) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _NavBarPainter(
                            centerX:     center * 520 / w,
                            barTop:      _overflow,
                            barHeight:   _barHeight,
                            extraBottom: inset,
                          ),
                        ),
                      ),
                      child!,
                      // الدايرة النشطة
                      Positioned(
                        left:   center - _circle / 2,
                        top:    _overflow - 22,
                        width:  _circle,
                        height: _circle,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              shape:  BoxShape.circle,
                              color:  Brand.navAccent,
                              border: Border.all(color: Brand.navBg, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color:      Brand.navGlow,
                                  offset:     const Offset(0, 6),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.string(
                              navSvg(items[selectedIndex].svgInner,
                                  stroke: '#FFFFFF', opacity: 1.0),
                              width: 18, height: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// زرار تاب واحد
// ============================================================

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem      item;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!active) ...[
              SizedBox(
                width: 32, height: 32,
                child: Center(
                  child: SvgPicture.string(
                    navSvg(item.svgInner, stroke: '#FFFFFF', opacity: 0.45),
                    width: 18, height: 18,
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve:    Curves.easeInOut,
              transform: Matrix4.translationValues(0, active ? -6 : 0, 0),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve:    Curves.easeInOut,
                style: TextStyle(
                  fontSize:   9.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Brand.navAccent : Brand.navInactive,
                ),
                child: Text(item.label,
                    maxLines: 1, softWrap: false,
                    overflow: TextOverflow.visible),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// helper: بيبني SVG string
// ============================================================

String navSvg(String inner,
    {required String stroke, required double opacity}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'fill="none" stroke="$stroke" stroke-opacity="$opacity" '
    'stroke-linecap="round" stroke-linejoin="round" '
    'stroke-width="1.8">$inner</svg>';

// ============================================================
// القوس المتحرك
// ============================================================

class _NavBarPainter extends CustomPainter {
  const _NavBarPainter({
    required this.centerX,
    required this.barTop,
    required this.barHeight,
    required this.extraBottom,
  });

  final double centerX;
  final double barTop;
  final double barHeight;
  final double extraBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = centerX;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(c - 70, 0)
      ..cubicTo(c - 44, 0,  c - 50, 8,  c - 44, 18)
      ..cubicTo(c - 36, 30, c - 23, 34, c,       34)
      ..cubicTo(c + 23, 34, c + 36, 30, c + 44,  18)
      ..cubicTo(c + 50, 8,  c + 44, 0,  c + 70,  0)
      ..lineTo(520, 0)
      ..lineTo(520, 75)
      ..lineTo(0,   75)
      ..close();

    final paint = Paint()
      ..color = Brand.navBg
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(0, barTop);
    canvas.scale(w / 520, barHeight / 75);
    canvas.drawPath(path, paint);
    canvas.restore();

    if (extraBottom > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, barTop + barHeight, w, extraBottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter old) =>
      old.centerX     != centerX     ||
      old.barTop      != barTop      ||
      old.barHeight   != barHeight   ||
      old.extraBottom != extraBottom;
}
