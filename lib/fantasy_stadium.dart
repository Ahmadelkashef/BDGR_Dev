// Stadium look for the fantasy pitch (animation branch, phase 1).
// Everything is drawn in code: no files, no downloads, zero egress.
// - StadiumPitch: a tilted (2.5D) pitch inside a stadium, crowd + camera flashes + floodlights.
// - DropIn: a player card falls onto its spot when picked.
// - CaptainShine: a turning gold ring around the captain.
// - showStadiumConfetti: confetti over the screen after saving the team.
// Phones with "remove animations" on (accessibility) get the still version.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _calm(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

// ── geometry shared by the painters and the player rows ─────────────────────
class _Geo {
  final double w, h, top, topW, botW;
  _Geo(this.w, this.h)
      : top = h * 0.085,
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
  const StadiumPitch({super.key, required this.rowCount, required this.rowBuilder});
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
        final g = _Geo(cons.maxWidth, cons.maxHeight);
        final n = widget.rowCount;
        // row centres in depth: a bit of room at the far end for the halfway line
        final ts = List<double>.generate(n, (i) => n == 1 ? 0.6 : 0.14 + 0.76 * i / (n - 1));
        final baseH = g.pitchH / n;
        return Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: CustomPaint(painter: _StandsPainter(_amb))),
          RepaintBoundary(child: CustomPaint(painter: _GrassPainter())),
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
  _StandsPainter(this.a) : super(repaint: a);
  static final _dots = <_Dot>[];

  void _seed(Size s) {
    if (_dots.isNotEmpty && _dots.first.w == s.width && _dots.first.h == s.height) return;
    _dots.clear();
    final r = math.Random(7);
    final g = _Geo(s.width, s.height);
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
    final g = _Geo(s.width, s.height);
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
  @override
  void paint(Canvas canvas, Size s) {
    final g = _Geo(s.width, s.height);
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

// ── turning gold ring around the captain ────────────────────────────────────
class CaptainShine extends StatefulWidget {
  final double size;
  final Color color;
  final Widget child;
  const CaptainShine({super.key, required this.size, required this.color, required this.child});
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
    final s = widget.size;
    return SizedBox(width: s, height: s, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Positioned(left: -4, top: -4, right: -4, bottom: -4,
        child: IgnorePointer(child: AnimatedBuilder(animation: _c, builder: (_, __) {
          final glow = 0.35 + 0.25 * math.sin(_c.value * 2 * math.pi);
          return Transform.rotate(angle: _c.value * 2 * math.pi, child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: SweepGradient(colors: [
                widget.color.withOpacity(0), widget.color, Colors.white, widget.color, widget.color.withOpacity(0),
              ], stops: const [0.0, 0.35, 0.5, 0.65, 1.0]),
              boxShadow: [BoxShadow(color: widget.color.withOpacity(glow), blurRadius: 12, spreadRadius: 1)])));
        }))),
      widget.child,
    ]));
  }
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
