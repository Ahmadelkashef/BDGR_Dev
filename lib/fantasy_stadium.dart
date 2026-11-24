// Stadium look for the fantasy pitch (animation branch, phase 1).
// Everything is drawn in code: no files, no downloads, zero egress.
// - StadiumPitch: a tilted (2.5D) pitch inside a stadium, crowd + camera flashes + floodlights.
// - DropIn: a player card falls onto its spot when picked.
// - CaptainShine: a turning gold ring around the captain.
// - showStadiumConfetti: confetti over the screen after saving the team.
// Phones with "remove animations" on (accessibility) get the still version.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'diag.dart';

bool _calm(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

// ── geometry shared by the painters and the player rows ─────────────────────
class _Geo {
  final double w, h, top, topW, botW;
  _Geo(this.w, this.h, [double topFrac = 0.085])
      : top = h * topFrac,
        topW = w * 0.70,
        botW = w * 1.02;
  double get cx => w / 2;
  double get pitchH => h - top;
  // depth t (0 = far end, 1 = near end) → screen y. Far stripes look thinner.
  double y(double t) => top + pitchH * (0.62 * t + 0.38 * t * t);
  double widthAtY(double yy) => topW + (botW - topW) * ((yy - top) / pitchH).clamp(0.0, 1.0);
  Offset p(double u, double t) {
    final yy = y(t);
    return Offset(cx + u * widthAtY(yy) / 2, yy);
  }
}

/// [rows] go from the far line (attack) to the near line (GK).
/// [rowBuilder] gets the row width/height in the row's own (unscaled) units.
class StadiumPitch extends StatefulWidget {
  final int rowCount;
  final Widget Function(int row, double width, double height) rowBuilder;
  /// LED ad board on the far edge of the pitch (null = no board)
  final Widget? board;
  const StadiumPitch({super.key, required this.rowCount, required this.rowBuilder, this.board});
  @override
  State<StadiumPitch> createState() => _StadiumPitchState();
}

class _StadiumPitchState extends State<StadiumPitch> with SingleTickerProviderStateMixin {
  late final AnimationController _amb =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_calm(context)) {
      _amb.stop();
    } else if (!_amb.isAnimating) {
      _amb.repeat();
    }
  }

  @override
  void dispose() { _amb.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(builder: (context, cons) {
        final tf = widget.board != null ? 0.115 : 0.085;
        final g = _Geo(cons.maxWidth, cons.maxHeight, tf);
        Diag.step('StadiumPitch ${cons.maxWidth.toStringAsFixed(0)}x${cons.maxHeight.toStringAsFixed(0)} rows=${widget.rowCount} board=${widget.board != null}');
        final n = widget.rowCount;
        final boardH = math.min(26.0, g.top - 10);
        // row centres in depth: a bit of room at the far end for the halfway line
        final ts = List<double>.generate(n, (i) => n == 1 ? 0.6 : 0.14 + 0.76 * i / (n - 1));
        final baseH = g.pitchH / n;
        return Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: CustomPaint(painter: _StandsPainter(_amb, tf))),
          RepaintBoundary(child: CustomPaint(painter: _GrassPainter(tf))),
          if (widget.board != null && boardH >= 14)
            Positioned(left: g.cx - g.topW * 0.53, width: g.topW * 1.06, top: g.top - boardH - 3, height: boardH,
              child: widget.board!),
          for (var i = 0; i < n; i++)
            _row(g, i, ts[i], baseH),
        ]);
      }),
    );
  }

  Widget _row(_Geo g, int i, double t, double baseH) {
    final yy = g.y(t);
    final rowW = g.widthAtY(yy) * 0.96;
    final scale = 0.80 + 0.20 * t;                // far players look smaller
    final h = baseH * 1.05;
    return Positioned(
      left: g.cx - rowW / 2, top: yy - h / 2, width: rowW, height: h,
      child: Center(child: Transform.scale(scale: scale,
        child: SizedBox(width: rowW / scale, height: h,
          child: widget.rowBuilder(i, rowW / scale, h)))),
    );
  }
}

// ── stands: dark tiers, crowd dots, camera flashes, two floodlights ─────────
class _StandsPainter extends CustomPainter {
  final Animation<double> a;
  final double tf;
  _StandsPainter(this.a, this.tf) : super(repaint: a);
  static final _dots = <_Dot>[];
  static double _tf = 0;

  void _seed(Size s) {
    if (_dots.isNotEmpty && _dots.first.w == s.width && _dots.first.h == s.height && _tf == tf) return;
    _dots.clear();
    _tf = tf;
    final r = math.Random(7);
    final g = _Geo(s.width, s.height, tf);
    for (var k = 0; k < 420; k++) {
      final x = r.nextDouble() * s.width;
      final y = r.nextDouble() * s.height;
      // only outside the grass
      final inside = y > g.top && (x - g.cx).abs() < g.widthAtY(y) / 2;
      if (inside) continue;
      _dots.add(_Dot(s.width, s.height, Offset(x, y), r.nextDouble(), r.nextInt(_crowd.length)));
    }
  }

  static const _crowd = [
    Color(0xFF3A2A2A), Color(0xFF2A2F3A), Color(0xFF3A3A3A), Color(0xFF5A1A1A),
    Color(0xFF2E3A2E), Color(0xFF444444),
  ];

  @override
  void paint(Canvas canvas, Size s) {
    _seed(s);
    final g = _Geo(s.width, s.height, tf);
    canvas.drawRect(Offset.zero & s, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF050505), Color(0xFF101418), Color(0xFF0B0E10)]).createShader(Offset.zero & s));
    // tier lines in the top stand
    final tier = Paint()..color = const Color(0x14FFFFFF)..strokeWidth = 1;
    for (var k = 1; k < 4; k++) {
      final yy = g.top * k / 4;
      canvas.drawLine(Offset(0, yy), Offset(s.width, yy), tier);
    }
    final v = a.value;
    final dot = Paint();
    for (final d in _dots) {
      // a tiny sway so the crowd feels alive
      final sway = math.sin((v * 2 * math.pi * 3) + d.phase * 20) * 0.6;
      dot.color = _crowd[d.c];
      canvas.drawCircle(d.o.translate(0, sway), 1.6, dot);
      // camera flash: each dot flashes once per loop at its own moment
      final f = ((v + d.phase) % 1.0);
      if (d.phase > 0.82 && f < 0.025) {
        final k = 1 - f / 0.025;
        canvas.drawCircle(d.o, 3.2 * k + 1, Paint()
          ..color = Colors.white.withOpacity(0.9 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }
    // floodlights at the far corners
    final pulse = 0.22 + 0.06 * math.sin(v * 2 * math.pi);
    for (final x in [s.width * 0.08, s.width * 0.92]) {
      final c = Offset(x, g.top * 0.35);
      canvas.drawCircle(c, s.width * 0.45, Paint()
        ..shader = RadialGradient(colors: [Colors.white.withOpacity(pulse), Colors.transparent])
            .createShader(Rect.fromCircle(center: c, radius: s.width * 0.45)));
      canvas.drawCircle(c, 3, Paint()..color = Colors.white.withOpacity(0.95));
    }
  }

  @override
  bool shouldRepaint(_StandsPainter o) => false;
}

class _Dot {
  final double w, h, phase;
  final Offset o;
  final int c;
  _Dot(this.w, this.h, this.o, this.phase, this.c);
}

// ── the grass: tilted trapezoid, mowing stripes, white lines ───────────────
class _GrassPainter extends CustomPainter {
  final double tf;
  _GrassPainter(this.tf);
  @override
  void paint(Canvas canvas, Size s) {
    final g = _Geo(s.width, s.height, tf);
    Path quad(double t0, double t1) => Path()
      ..moveTo(g.p(-1, t0).dx, g.p(-1, t0).dy)
      ..lineTo(g.p(1, t0).dx, g.p(1, t0).dy)
      ..lineTo(g.p(1, t1).dx, g.p(1, t1).dy)
      ..lineTo(g.p(-1, t1).dx, g.p(-1, t1).dy)
      ..close();
    // shadow under the pitch edge
    canvas.drawPath(quad(0, 1), Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    const stripes = 10;
    for (var k = 0; k < stripes; k++) {
      canvas.drawPath(quad(k / stripes, (k + 1) / stripes),
          Paint()..color = k.isEven ? const Color(0xFF1F6B47) : const Color(0xFF1A5C3D));
    }
    // light from the floodlights: brighter far end, darker near
    canvas.drawPath(quad(0, 1), Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.10), Colors.transparent, Colors.black.withOpacity(0.18)])
          .createShader(Rect.fromLTWH(0, g.top, s.width, g.pitchH)));

    final line = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(quad(0, 1), line);
    // centre circle (half of it, at the far end = halfway line)
    final c = g.p(0, 0);
    final rx = g.widthAtY(c.dy) * 0.17;
    canvas.save();
    canvas.clipPath(quad(0, 1));
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: rx * 0.9), line);
    canvas.restore();
    canvas.drawCircle(c.translate(0, 1), 2, Paint()..color = Colors.white.withOpacity(0.7));
    // penalty box + goal box at the near end
    void box(double u, double t0) {
      final a = g.p(-u, t0), b = g.p(u, t0), cc = g.p(u, 1), d = g.p(-u, 1);
      canvas.drawPath(Path()..moveTo(d.dx, d.dy)..lineTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(cc.dx, cc.dy), line);
    }
    box(0.56, 0.80);
    box(0.26, 0.93);
    // penalty arc + spot
    final spot = g.p(0, 0.86);
    canvas.drawCircle(spot, 1.8, Paint()..color = Colors.white.withOpacity(0.7));
    final arcTop = g.p(0, 0.80);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, s.width, arcTop.dy));
    canvas.drawOval(Rect.fromCenter(center: spot, width: g.widthAtY(spot.dy) * 0.30,
        height: (spot.dy - arcTop.dy) * 2.6), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GrassPainter o) => false;
}

// ── a picked player falls onto the pitch ────────────────────────────────────
class DropIn extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Duration delay;
  const DropIn({super.key, required this.child, this.enabled = true, this.delay = Duration.zero});
  @override
  State<DropIn> createState() => _DropInState();
}

class _DropInState extends State<DropIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled || _calm(context)) { _c.value = 1; return; }
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      final v = Curves.easeOutBack.transform(_c.value);
      final o = Curves.easeOut.transform((_c.value * 2).clamp(0.0, 1.0));
      return Opacity(opacity: o,
        child: Transform.translate(offset: Offset(0, -46 * (1 - v)),
          child: Transform.scale(scale: 1.35 - 0.35 * v, child: child)));
    });
}

// ── turning gold ring around the captain (circle, or a rounded card when [radius] is set) ──
class CaptainShine extends StatefulWidget {
  final double size;
  final double? height, radius;
  final Color color;
  final Widget child;
  const CaptainShine({super.key, required this.size, required this.color, required this.child, this.height, this.radius});
  @override
  State<CaptainShine> createState() => _CaptainShineState();
}

class _CaptainShineState extends State<CaptainShine> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_calm(context)) { _c.stop(); } else if (!_c.isAnimating) { _c.repeat(); }
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w = widget.size, h = widget.height ?? widget.size;
    final r = widget.radius;
    return SizedBox(width: w, height: h, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Positioned(left: -3, top: -3, right: -3, bottom: -3,
        child: IgnorePointer(child: AnimatedBuilder(animation: _c, builder: (_, __) {
          final glow = 0.35 + 0.25 * math.sin(_c.value * 2 * math.pi);
          return Container(
            decoration: BoxDecoration(
              shape: r == null ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: r == null ? null : BorderRadius.circular(r + 3),
              gradient: SweepGradient(
                transform: GradientRotation(_c.value * 2 * math.pi),
                colors: [widget.color.withOpacity(0.15), widget.color, Colors.white, widget.color, widget.color.withOpacity(0.15)],
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0]),
              boxShadow: [BoxShadow(color: widget.color.withOpacity(glow), blurRadius: 12, spreadRadius: 1)]));
        }))),
      widget.child,
    ]));
  }
}

// ── team shirt drawn in code (zero files): colours + pattern from `fantasy_team_kits` ──
class KitShirt extends StatelessWidget {
  final Color c1, c2;
  final String pattern;   // plain | stripes | hoops | halves | sash | sleeves | ghost
  final double width;
  const KitShirt({super.key, required this.c1, required this.c2, this.pattern = 'plain', required this.width});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * 0.96), painter: _ShirtPainter(c1, c2, pattern));
}

class _ShirtPainter extends CustomPainter {
  final Color c1, c2;
  final String pattern;
  _ShirtPainter(this.c1, this.c2, this.pattern);

  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 100;
    Offset o(double x, double y) => Offset(x * k, y * k);
    final body = Path()
      ..moveTo(36 * k, 6 * k)
      ..quadraticBezierTo(50 * k, 18 * k, 64 * k, 6 * k)
      ..lineTo(84 * k, 13 * k)
      ..lineTo(100 * k, 33 * k)
      ..lineTo(88 * k, 45 * k)
      ..lineTo(79 * k, 38 * k)
      ..lineTo(79 * k, 94 * k)
      ..quadraticBezierTo(50 * k, 97 * k, 21 * k, 94 * k)
      ..lineTo(21 * k, 38 * k)
      ..lineTo(12 * k, 45 * k)
      ..lineTo(0, 33 * k)
      ..lineTo(16 * k, 13 * k)
      ..close();
    final ghost = pattern == 'ghost';
    canvas.drawShadow(body, Colors.black, 3, false);
    canvas.drawPath(body, Paint()..color = c1);
    final p2 = Paint()..color = c2;
    if (pattern == 'sleeves') {
      // Sleeves are drawn OUTSIDE the clip, as convex shapes that sit exactly on the shirt outline.
      // The old version (a concave shape drawn inside clipPath) crashed the Samsung Vulkan GPU driver
      // on the WORLD pitch (diag-3, 24 Nov: crash exactly when Arsenal's shirt was drawn).
      canvas.drawPath(Path()..moveTo(12 * k, 45 * k)..lineTo(0, 33 * k)..lineTo(16 * k, 13 * k)..lineTo(23 * k, 10.55 * k)..lineTo(21 * k, 38 * k)..close(), p2);
      canvas.drawPath(Path()..moveTo(88 * k, 45 * k)..lineTo(100 * k, 33 * k)..lineTo(84 * k, 13 * k)..lineTo(77 * k, 10.55 * k)..lineTo(79 * k, 38 * k)..close(), p2);
    }
    canvas.save();
    canvas.clipPath(body);
    switch (pattern) {
      case 'stripes':
        for (var x = 27.0; x < 79; x += 13) { canvas.drawRect(Rect.fromLTWH(x * k, 0, 6.5 * k, s.height), p2); }
        break;
      case 'hoops':
        for (var y = 30.0; y < 96; y += 18) { canvas.drawRect(Rect.fromLTWH(0, y * k, s.width, 8 * k), p2); }
        break;
      case 'halves':
        canvas.drawRect(Rect.fromLTWH(50 * k, 0, 50 * k, s.height), p2);
        break;
      case 'sash':
        canvas.drawPath(Path()..moveTo(18 * k, 18 * k)..lineTo(34 * k, 14 * k)..lineTo(82 * k, 92 * k)..lineTo(66 * k, 96 * k)..close(), p2);
        break;
    }
    // cloth light: lighter on the left, darker on the right
    canvas.drawRect(Offset.zero & s, Paint()
      ..shader = LinearGradient(colors: [Colors.white.withOpacity(0.18), Colors.transparent, Colors.black.withOpacity(0.22)],
          stops: const [0.0, 0.45, 1.0]).createShader(Offset.zero & s));
    canvas.restore();
    final trim = Paint()..color = (ghost ? Colors.white54 : c2)..style = PaintingStyle.stroke..strokeWidth = 2.2 * k;
    // collar + cuffs
    canvas.drawPath(Path()..moveTo(36 * k, 6 * k)..quadraticBezierTo(50 * k, 18 * k, 64 * k, 6 * k), trim..strokeWidth = 3.2 * k);
    canvas.drawLine(o(0.8, 34), o(12.5, 45.5), trim..strokeWidth = 2.4 * k);
    canvas.drawLine(o(99.2, 34), o(87.5, 45.5), trim);
    canvas.drawPath(body, Paint()
      ..color = ghost ? Colors.white38 : Colors.black.withOpacity(0.28)
      ..style = PaintingStyle.stroke..strokeWidth = (ghost ? 1.4 : 1) * k);
  }

  @override
  bool shouldRepaint(_ShirtPainter o) => o.c1 != c1 || o.c2 != c2 || o.pattern != pattern;
}

// ── LED board: shows [count] items one after another, each for its own seconds ──
class LedBoard extends StatefulWidget {
  final int count;
  final Widget Function(BuildContext context, int i) itemBuilder;
  final int Function(int i) secondsOf;
  const LedBoard({super.key, required this.count, required this.itemBuilder, required this.secondsOf});
  @override
  State<LedBoard> createState() => _LedBoardState();
}

class _LedBoardState extends State<LedBoard> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() { super.initState(); _schedule(); }

  @override
  void didUpdateWidget(LedBoard old) {
    super.didUpdateWidget(old);
    if (_i >= widget.count) _i = 0;
    if (old.count != widget.count) _schedule();
  }

  void _schedule() {
    _t?.cancel();
    if (widget.count < 2) return;
    _t = Timer(Duration(seconds: widget.secondsOf(_i).clamp(3, 600).toInt()), () {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % widget.count);
      _schedule();
    });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 3))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(3), child: Stack(fit: StackFit.expand, children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: _calm(context) ? 0 : 650),
          switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, a) => ClipRect(child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a),
            child: FadeTransition(opacity: a, child: child))),
          child: KeyedSubtree(key: ValueKey(_i), child: widget.itemBuilder(context, _i))),
        // LED dot grid on top: looks like a stadium screen
        const IgnorePointer(child: CustomPaint(painter: _LedGridPainter())),
      ])),
    );
  }
}

class _LedGridPainter extends CustomPainter {
  const _LedGridPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.black.withOpacity(0.28);
    for (var y = 0.0; y < s.height; y += 2.5) { canvas.drawRect(Rect.fromLTWH(0, y, s.width, 0.8), p); }
    canvas.drawRect(Offset.zero & s, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.10), Colors.transparent]).createShader(Offset.zero & s));
  }
  @override
  bool shouldRepaint(_LedGridPainter o) => false;
}

// ── confetti after the team is saved ───────────────────────────────────────
void showStadiumConfetti(BuildContext context) {
  HapticFeedback.mediumImpact();
  if (_calm(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry e;
  e = OverlayEntry(builder: (_) => _Confetti(onDone: () => e.remove()));
  overlay.insert(e);
}

class _Confetti extends StatefulWidget {
  final VoidCallback onDone;
  const _Confetti({required this.onDone});
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _bits = <_Bit>[];

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    const colors = [Color(0xFFFF0000), Colors.white, Color(0xFFE0B84A), Color(0xFF00FF87)];
    for (var k = 0; k < 110; k++) {
      _bits.add(_Bit(
        x: r.nextDouble(), delay: r.nextDouble() * 0.35, speed: 0.7 + r.nextDouble() * 0.6,
        drift: (r.nextDouble() - 0.5) * 0.25, spin: (r.nextDouble() - 0.5) * 14,
        w: 5 + r.nextDouble() * 5, color: colors[r.nextInt(colors.length)]));
    }
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_c, _bits)));
}

class _Bit {
  final double x, delay, speed, drift, spin, w;
  final Color color;
  _Bit({required this.x, required this.delay, required this.speed, required this.drift,
        required this.spin, required this.w, required this.color});
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> a;
  final List<_Bit> bits;
  _ConfettiPainter(this.a, this.bits) : super(repaint: a);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();
    for (final b in bits) {
      final t = ((a.value - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -20 + (s.height + 40) * t * b.speed;
      final x = s.width * (b.x + b.drift * t) + math.sin(t * 12 + b.x * 9) * 12;
      p.color = b.color.withOpacity((1 - t).clamp(0.0, 1.0) * 0.95 + 0.05);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * t);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.w, height: b.w * 0.45), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => false;
}
