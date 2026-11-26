// Fantasy motion (branch `launch`, 26 Nov 2026): everything drawn / moved in code.
// No files, no downloads, zero egress, no extra package.
// - FantasyIntro: the night stadium seen from above, floodlights switch on one by one,
//   the camera dives down into the pitch, "FANTASY" appears, then the page shows.
//   Once per app run, the first time the Fantasy tab opens. "Skip" + tap anywhere.
// - StaggerIn: a widget slides up + fades in, one after the other (waits for the intro).
// - Pressable: presses in a little when touched (+ a light tick).
// - RollingText: each changed character rolls in (countdown).
// - CountUp: a number counts up to its value.
// - PopIn: pops in with a small bounce (saved chip, sheet icons).
// - ShineSweep: a soft light passes over a button every few seconds.
// Phones with "remove animations" (accessibility) get everything still and no intro.
// Painter rules (Samsung Vulkan lesson): only convex shapes, every gradient has 2+ colours,
// no clipPath, no blur filters.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'brand.dart';

bool motionCalm(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

class FantasyMotion {
  /// set by MainShell: true while the Fantasy tab is the visible tab
  static final ValueNotifier<bool> tabActive = ValueNotifier<bool>(false);
  /// page entrances wait for this: false until the Fantasy tab is first opened (the tab is built
  /// hidden at app start) and while the intro covers the screen
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  /// the intro plays once per app run
  static bool introPlayed = false;
}

// ═══════════════════════════════════════════════════════════════════════════
// INTRO
// ═══════════════════════════════════════════════════════════════════════════
class FantasyIntro extends StatefulWidget {
  const FantasyIntro({super.key, required this.isArabic, required this.onDone});
  final bool isArabic;
  final VoidCallback onDone;
  @override
  State<FantasyIntro> createState() => _FantasyIntroState();
}

class _FantasyIntroState extends State<FantasyIntro> with SingleTickerProviderStateMixin {
  static const _len = Duration(milliseconds: 2900);
  late final AnimationController _c = AnimationController(vsync: this, duration: _len);
  bool _done = false, _revealed = false, _tick1 = false, _tick2 = false;

  @override
  void initState() {
    super.initState();
    FantasyMotion.ready.value = false;
    _c.addListener(_onTick);
    _c.addStatusListener((s) { if (s == AnimationStatus.completed) _finish(); });
    _c.forward();
  }

  void _onTick() {
    final t = _c.value;
    if (!_tick1 && t >= 0.40) { _tick1 = true; HapticFeedback.selectionClick(); }
    if (!_tick2 && t >= 0.66) { _tick2 = true; HapticFeedback.lightImpact(); }
    if (!_revealed && t >= 0.86) { _revealed = true; FantasyMotion.ready.value = true; }
  }

  void _skip() {
    if (_done || _c.value >= 0.86) return;
    _c.animateTo(1.0, duration: const Duration(milliseconds: 320), curve: Curves.easeIn);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    FantasyMotion.ready.value = true;
    widget.onDone();
  }

  @override
  void dispose() {
    if (!_done) FantasyMotion.ready.value = true;
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnimatedBuilder(animation: _c, builder: (context, _) {
      final t = _c.value;
      final lights = _seg(t, 0.04, 0.40);
      final dive = _seg(t, 0.28, 0.84, Curves.easeInOutCubic);
      final word = _seg(t, 0.60, 0.78, Curves.easeOutCubic);
      final out = _seg(t, 0.86, 1.0, Curves.easeInCubic);
      // camera: tilt (perspective, kept mild) inside + zoom (flat) outside → no point ever goes behind the camera
      final tilt = Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..rotateX(-1.15 * dive);
      final zoom = 0.66 + 2.5 * dive;
      return IgnorePointer(ignoring: out > 0.5, child: Opacity(opacity: (1 - out).clamp(0.0, 1.0), child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Container(color: const Color(0xFF04060A), child: Stack(fit: StackFit.expand, children: [
          Transform.scale(scale: zoom, alignment: const Alignment(0, 0.18),
            child: Transform(transform: tilt, alignment: Alignment.center,
              child: CustomPaint(painter: _StadiumIntroPainter(t: t, lights: lights)))),
          // FANTASY wordmark on a dark veil (the green pitch is bright)
          if (word > 0) Container(decoration: BoxDecoration(gradient: RadialGradient(radius: 0.9, colors: [
              Colors.black.withOpacity(0.70 * word), Colors.black.withOpacity(0.35 * word)]))),
          if (word > 0) Center(child: Opacity(opacity: word, child: Transform.translate(
            offset: Offset(0, 14 * (1 - word)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset(Brand.badger, width: 46, height: 46, fit: BoxFit.contain),
              const SizedBox(height: 10),
              Text('FANTASY', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900,
                  letterSpacing: 4 + 12 * (1 - word), height: 1,
                  shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 18)])),
              const SizedBox(height: 10),
              Container(width: 90 * word, height: 3,
                decoration: BoxDecoration(color: Brand.navAccent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              const Text('B D G R', style: TextStyle(color: Color(0xFFB8BCC4), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3)),
            ])))),
          PositionedDirectional(top: top + 10, end: 14, child: GestureDetector(
            onTap: _skip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x55FFFFFF))),
              child: Text(widget.isArabic ? 'تخطي' : 'Skip',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))))),
        ])),
      )));
    });
  }
}

/// the stadium from above: stands + crowd, pitch with lines, 6 floodlights on the rim
class _StadiumIntroPainter extends CustomPainter {
  _StadiumIntroPainter({required this.t, required this.lights});
  final double t, lights;

  static final List<_Fan> _fans = _makeFans();
  static List<_Fan> _makeFans() {
    final r = math.Random(7);
    return List.generate(900, (_) => _Fan(r.nextDouble() * math.pi * 2, r.nextDouble(), r.nextInt(5), r.nextDouble() * math.pi * 2));
  }
  static const _fanColors = [Color(0xFFE8E8E8), Color(0xFFD32F2F), Color(0xFF1E88E5), Color(0xFFFFC107), Color(0xFF9E9E9E)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);
    // stadium bowl (portrait oval, wider than the screen)
    final outerRx = w * 0.70, outerRy = h * 0.47;
    final innerRx = w * 0.40, innerRy = h * 0.33;
    final lit = lights;

    // glow of the lights in the night sky
    final glow = Paint()..shader = RadialGradient(colors: [
      Color.lerp(const Color(0xFF0A0F18), const Color(0xFF26344A), lit)!, const Color(0xFF04060A)])
        .createShader(Rect.fromCenter(center: c, width: w * 1.8, height: h * 1.2));
    canvas.drawRect(Offset.zero & size, glow);

    // stands: 3 rings, outside → inside
    for (var i = 0; i < 3; i++) {
      final f = i / 3;
      final rx = outerRx - (outerRx - innerRx) * f, ry = outerRy - (outerRy - innerRy) * f;
      final shade = Color.lerp(const Color(0xFF15181E), const Color(0xFF2A2F38), lit * (0.5 + 0.2 * i))!;
      canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), Paint()..color = shade);
    }

    // crowd: points between the inner and outer oval, a slow shimmer
    final buckets = List.generate(_fanColors.length, (_) => <Offset>[]);
    for (final f in _fans) {
      final rf = 0.06 + f.rf * 0.90;
      final rx = innerRx + (outerRx - innerRx) * rf, ry = innerRy + (outerRy - innerRy) * rf;
      buckets[f.col].add(Offset(c.dx + math.cos(f.a) * rx, c.dy + math.sin(f.a) * ry));
    }
    final crowdAlpha = 0.25 + 0.6 * lit;
    for (var i = 0; i < buckets.length; i++) {
      final a = (crowdAlpha * (0.85 + 0.15 * math.sin(t * 40 + i))).clamp(0.0, 1.0);
      canvas.drawPoints(PointMode.points, buckets[i], Paint()
        ..color = _fanColors[i].withOpacity(a)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round);
    }
    // camera flashes in the crowd
    if (lit > 0.3) {
      final flash = Paint()..color = Colors.white;
      for (var k = 0; k < 40; k++) {
        final f = _fans[(k * 37) % _fans.length];
        final s = math.sin(t * 60 + f.ph * 3);
        if (s > 0.985) {
          final rf = 0.06 + f.rf * 0.90;
          final p = Offset(c.dx + math.cos(f.a) * (innerRx + (outerRx - innerRx) * rf), c.dy + math.sin(f.a) * (innerRy + (outerRy - innerRy) * rf));
          canvas.drawCircle(p, 3.2, flash);
        }
      }
    }

    // pitch (rectangle inside the inner oval), mowing stripes, white lines
    final pw = innerRx * 1.18, ph = innerRy * 1.55;
    final pitch = Rect.fromCenter(center: c, width: pw, height: ph);
    final dark = Color.lerp(const Color(0xFF0A2410), const Color(0xFF1C6B30), lit)!;
    final light = Color.lerp(const Color(0xFF0D2C14), const Color(0xFF238038), lit)!;
    canvas.drawRect(pitch.inflate(10), Paint()..color = dark);
    const stripes = 10;
    for (var i = 0; i < stripes; i++) {
      if (i.isOdd) continue;
      canvas.drawRect(Rect.fromLTWH(pitch.left, pitch.top + ph * i / stripes, pw, ph / stripes), Paint()..color = light);
    }
    final ln = Paint()
      ..color = Colors.white.withOpacity(0.18 + 0.62 * lit)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(pitch, ln);
    canvas.drawLine(Offset(pitch.left, c.dy), Offset(pitch.right, c.dy), ln);
    canvas.drawCircle(c, pw * 0.15, ln);
    canvas.drawCircle(c, 2.5, Paint()..color = ln.color);
    final boxW = pw * 0.56, boxH = ph * 0.15, sixW = pw * 0.26, sixH = ph * 0.055;
    canvas.drawRect(Rect.fromLTWH(c.dx - boxW / 2, pitch.top, boxW, boxH), ln);
    canvas.drawRect(Rect.fromLTWH(c.dx - boxW / 2, pitch.bottom - boxH, boxW, boxH), ln);
    canvas.drawRect(Rect.fromLTWH(c.dx - sixW / 2, pitch.top, sixW, sixH), ln);
    canvas.drawRect(Rect.fromLTWH(c.dx - sixW / 2, pitch.bottom - sixH, sixW, sixH), ln);

    // 6 floodlights on the rim, switching on one by one; each throws a soft cone on the pitch
    const angles = [-2.35, -1.57, -0.79, 0.79, 1.57, 2.35];
    for (var i = 0; i < angles.length; i++) {
      final on = ((lights * angles.length) - i).clamp(0.0, 1.0);
      if (on <= 0) continue;
      final p = Offset(c.dx + math.cos(angles[i]) * outerRx * 0.93, c.dy + math.sin(angles[i]) * outerRy * 0.93);
      // cone: a simple triangle (convex) from the light to the pitch centre
      final dir = (c - p);
      final n = Offset(-dir.dy, dir.dx) / dir.distance;
      final cone = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(c.dx + n.dx * pw * 0.35, c.dy + n.dy * pw * 0.35)
        ..lineTo(c.dx - n.dx * pw * 0.35, c.dy - n.dy * pw * 0.35)
        ..close();
      canvas.drawPath(cone, Paint()..color = Colors.white.withOpacity(0.022 * on));
      final r = 34.0 * on;
      canvas.drawCircle(p, r, Paint()..shader = RadialGradient(colors: [
        Colors.white.withOpacity(0.85 * on), Colors.white.withOpacity(0)]).createShader(Rect.fromCircle(center: p, radius: r)));
      canvas.drawCircle(p, 4.5, Paint()..color = Colors.white.withOpacity(on));
    }
  }

  @override
  bool shouldRepaint(_StadiumIntroPainter old) => old.t != t || old.lights != lights;
}

class _Fan {
  final double a, rf, ph;
  final int col;
  const _Fan(this.a, this.rf, this.col, this.ph);
}

// ═══════════════════════════════════════════════════════════════════════════
// SMALL MOTION WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// slides up + fades in, [index] × [stepMs] after the page is ready (after the intro)
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.child, this.index = 0, this.dy = 18, this.stepMs = 70,
      this.delayMs = 0, this.durationMs = 460});
  final Widget child;
  final int index, stepMs, delayMs, durationMs;
  final double dy;
  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.durationMs));
  Timer? _timer;
  bool _first = true;

  @override
  void initState() {
    super.initState();
    FantasyMotion.ready.addListener(_kick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_first) { _first = false; _kick(); }
  }

  void _kick() {
    if (!mounted || _timer != null || _c.value > 0 || _c.isAnimating) return;
    if (motionCalm(context)) { _c.value = 1; return; }
    if (!FantasyMotion.ready.value) return;
    final idx = widget.index.clamp(0, 12);
    _timer = Timer(Duration(milliseconds: widget.delayMs + idx * widget.stepMs), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() {
    FantasyMotion.ready.removeListener(_kick);
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c, child: widget.child,
    builder: (_, child) {
      final v = Curves.easeOutCubic.transform(_c.value);
      if (v >= 1) return child!;
      return Opacity(opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, widget.dy * (1 - v)), child: child));
    });
}

/// presses in a little when touched; never takes the tap from the child
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.965, this.haptic = true, this.enabled = true});
  final Widget child;
  final double scale;
  final bool haptic, enabled;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) { if (mounted && _down != v) setState(() => _down = v); }
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || motionCalm(context)) return widget.child;
    return Listener(
      onPointerDown: (_) { _set(true); if (widget.haptic) HapticFeedback.selectionClick(); },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child));
  }
}

/// every character that changes rolls in from above (countdown digits)
class RollingText extends StatelessWidget {
  const RollingText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    if (motionCalm(context)) return Text(text, style: style);
    final chars = text.characters.toList();
    return Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < chars.length; i++)
        ClipRect(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) {
            final incoming = child.key == ValueKey('$i${chars[i]}');
            return SlideTransition(
              position: Tween<Offset>(begin: Offset(0, incoming ? -0.8 : 0.8), end: Offset.zero).animate(anim),
              child: FadeTransition(opacity: anim, child: child));
          },
          child: Text(chars[i], key: ValueKey('$i${chars[i]}'), style: style),
        )),
    ]));
  }
}

/// a number that counts up to [value]
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style, this.format, this.ms = 900});
  final num value;
  final TextStyle style;
  final String Function(int v)? format;
  final int ms;
  @override
  Widget build(BuildContext context) {
    String f(int v) => format?.call(v) ?? '$v';
    if (motionCalm(context)) return Text(f(value.round()), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: Duration(milliseconds: ms), curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(f(v.round()), style: style));
  }
}

/// pops in with a small bounce, [delayMs] after it first shows
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delayMs = 0, this.from = 0.5});
  final Widget child;
  final int delayMs;
  final double from;
  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  Timer? _timer;
  bool _first = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_first) return;
    _first = false;
    if (motionCalm(context)) { _c.value = 1; return; }
    _timer = Timer(Duration(milliseconds: widget.delayMs), () { if (mounted) _c.forward(); });
  }
  @override
  void dispose() { _timer?.cancel(); _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, child: widget.child, builder: (_, child) {
    if (_c.value >= 1) return child!;
    final s = widget.from + (1 - widget.from) * Curves.elasticOut.transform(_c.value);
    return Opacity(opacity: Curves.easeOut.transform((_c.value * 2.5).clamp(0.0, 1.0)),
      child: Transform.scale(scale: s, child: child));
  });
}

/// a soft light passes over the child every [everyMs]
class ShineSweep extends StatefulWidget {
  const ShineSweep({super.key, required this.child, this.radius = 14, this.everyMs = 3400});
  final Widget child;
  final double radius;
  final int everyMs;
  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.everyMs));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionCalm(context)) { _c.stop(); } else if (!_c.isAnimating) { _c.repeat(); }
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Stack(children: [
    widget.child,
    Positioned.fill(child: IgnorePointer(child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: AnimatedBuilder(animation: _c, builder: (_, __) {
        // the light crosses during the first 30% of each cycle, then rests
        final p = (_c.value / 0.30);
        if (p >= 1) return const SizedBox.shrink();
        return FractionalTranslation(
          translation: Offset(-1.2 + 2.4 * Curves.easeInOut.transform(p), 0),
          child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment(-1, -0.4), end: Alignment(1, 0.4),
            colors: [Color(0x00FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
            stops: [0.30, 0.5, 0.70]))));
      })))),
  ]);
}
