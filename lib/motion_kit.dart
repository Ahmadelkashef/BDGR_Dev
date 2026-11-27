// Motion kit (branch `launch`, 27 Nov 2026, owner: "motion phase 1").
// Shared moves for the whole app, drawn in code only (no files, no package, zero egress).
// Every move respects the phone's "remove animations" setting (shows the still version).
// - BadgerRefresh: pull to refresh with the badger digging instead of the spinner.
// - HoloCard: a soft holographic shine that crosses the card by itself every few seconds;
//   press and hold the card + move the finger = the card tilts and the shine follows the finger.
// - CardEntrance: the profile card rises in when the page opens.
// - Buzz: small haptics for the important moments.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool calmMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

class Buzz {
  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
}

// ── Pull to refresh with the badger ────────────────────────────────────────
class BadgerRefresh extends StatefulWidget {
  const BadgerRefresh({super.key, required this.onRefresh, required this.child, this.top = 8});
  final Future<void> Function() onRefresh;
  final Widget child;
  final double top;
  @override
  State<BadgerRefresh> createState() => _BadgerRefreshState();
}

class _BadgerRefreshState extends State<BadgerRefresh> with SingleTickerProviderStateMixin {
  RefreshIndicatorStatus? _st;
  late final AnimationController _dig =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void dispose() {
    _dig.dispose();
    super.dispose();
  }

  void _status(RefreshIndicatorStatus? s) {
    if (!mounted) return;
    if (s == RefreshIndicatorStatus.armed && _st != RefreshIndicatorStatus.armed) Buzz.light();
    if (s == RefreshIndicatorStatus.snap || s == RefreshIndicatorStatus.refresh) {
      if (!_dig.isAnimating) _dig.repeat();
    } else {
      _dig.stop();
    }
    setState(() => _st = s);
  }

  @override
  Widget build(BuildContext context) {
    final show = _st != null && _st != RefreshIndicatorStatus.done && _st != RefreshIndicatorStatus.canceled;
    final armed = _st == RefreshIndicatorStatus.armed || _st == RefreshIndicatorStatus.snap ||
        _st == RefreshIndicatorStatus.refresh;
    return Stack(children: [
      RefreshIndicator.noSpinner(onRefresh: widget.onRefresh, onStatusChange: _status, child: widget.child),
      Positioned(
        top: widget.top, left: 0, right: 0,
        child: IgnorePointer(child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Center(child: AnimatedScale(
            scale: armed ? 1 : 0.7,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                shape: BoxShape.circle,
                border: Border.all(color: armed ? const Color(0xFFFF2B2B) : Colors.white24, width: 1.4),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
              ),
              child: AnimatedBuilder(
                animation: _dig,
                builder: (_, child) {
                  // digging: the badger dips and tilts left/right, small dirt dots fly up
                  final v = _dig.value;
                  final dip = math.sin(v * math.pi * 2);
                  return Stack(alignment: Alignment.center, children: [
                    if (_dig.isAnimating)
                      for (var i = 0; i < 3; i++)
                        Positioned(
                          left: 10.0 + i * 10,
                          bottom: 6 + ((v + i / 3) % 1) * 18,
                          child: Opacity(
                            opacity: (1 - ((v + i / 3) % 1)).clamp(0.0, 1.0).toDouble(),
                            child: Container(width: 3, height: 3,
                                decoration: const BoxDecoration(color: Color(0xFFB0805A), shape: BoxShape.circle)),
                          ),
                        ),
                    Transform.translate(
                      offset: Offset(0, _dig.isAnimating ? dip * 3 : 0),
                      child: Transform.rotate(angle: _dig.isAnimating ? dip * 0.18 : 0, child: child),
                    ),
                  ]);
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/badger_white.png',
                      color: armed ? Colors.white : Colors.white54, fit: BoxFit.contain),
                ),
              ),
            ),
          )),
        )),
      ),
    ]);
  }
}

// ── Holographic shine + press-and-hold tilt ────────────────────────────────
class HoloCard extends StatefulWidget {
  const HoloCard({super.key, required this.child, this.radius = 12, this.enabled = true, this.strength = 1});
  final Widget child;
  final double radius;
  final bool enabled;
  final double strength; // 1 = normal, bigger for gold
  @override
  State<HoloCard> createState() => _HoloCardState();
}

class _HoloCardState extends State<HoloCard> with SingleTickerProviderStateMixin {
  // the shine crosses the card in 1.4 s, then waits ~4 s
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 5400));
  Offset? _touch; // 0..1 inside the card while holding
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled && !calmMotion(context)) _sweep.repeat();
    });
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _move(Offset local) {
    if (_size.isEmpty) return;
    setState(() => _touch = Offset((local.dx / _size.width).clamp(0.0, 1.0).toDouble(),
        (local.dy / _size.height).clamp(0.0, 1.0).toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || calmMotion(context)) return widget.child;
    final t = _touch;
    final tilt = t == null
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX((t.dy - 0.5) * -0.35)
          ..rotateY((t.dx - 0.5) * 0.35));
    return GestureDetector(
      onLongPressStart: (d) { Buzz.light(); _move(d.localPosition); },
      onLongPressMoveUpdate: (d) => _move(d.localPosition),
      onLongPressEnd: (_) => setState(() => _touch = null),
      onLongPressCancel: () => setState(() => _touch = null),
      child: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth.isFinite ? c.maxWidth : 0, c.maxHeight.isFinite ? c.maxHeight : 0);
        return AnimatedContainer(
          duration: Duration(milliseconds: t == null ? 260 : 60),
          curve: Curves.easeOut,
          transform: tilt,
          transformAlignment: Alignment.center,
          child: Stack(children: [
            widget.child,
            Positioned.fill(child: IgnorePointer(child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (_, __) {
                  // position of the shine band: the finger while holding, else the timed sweep
                  double pos;
                  double alpha;
                  if (t != null) {
                    pos = (t.dx + t.dy) / 2;
                    alpha = 0.55;
                  } else {
                    final v = _sweep.value * 5400 / 1400; // 0..1 during the first 1.4 s
                    if (v > 1) return const SizedBox.shrink();
                    pos = -0.3 + v * 1.6;
                    alpha = 0.42 * math.sin(v * math.pi);
                  }
                  final a = (alpha * widget.strength).clamp(0.0, 0.8).toDouble();
                  return DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF7FE7FF).withOpacity(a * 0.35),
                      Colors.white.withOpacity(a),
                      const Color(0xFFFFB3F2).withOpacity(a * 0.35),
                      Colors.transparent,
                    ],
                    stops: [
                      (pos - 0.22).clamp(0.0, 1.0).toDouble(),
                      (pos - 0.08).clamp(0.0, 1.0).toDouble(),
                      pos.clamp(0.0, 1.0).toDouble(),
                      (pos + 0.08).clamp(0.0, 1.0).toDouble(),
                      (pos + 0.22).clamp(0.0, 1.0).toDouble(),
                    ],
                  )));
                },
              ),
            ))),
          ]),
        );
      }),
    );
  }
}

// ── The profile card rises in when the page opens ──────────────────────────
class CardEntrance extends StatefulWidget {
  const CardEntrance({super.key, required this.child, this.delayMs = 0, this.fromSide = 0});
  final Widget child;
  final int delayMs;
  final double fromSide; // -1 from the left, 1 from the right, 0 from below
  @override
  State<CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<CardEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (calmMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeOutBack.transform(_c.value);
        final o = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: o.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(widget.fromSide * (1 - v) * 40, widget.fromSide == 0 ? (1 - v) * 34 : 0),
            child: Transform.scale(scale: 0.82 + 0.18 * v, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// a number that counts from [from] to [to]
class CountBetween extends StatelessWidget {
  const CountBetween({super.key, required this.from, required this.to, required this.style, this.format, this.ms = 1100});
  final num from, to;
  final TextStyle style;
  final String Function(int v)? format;
  final int ms;
  @override
  Widget build(BuildContext context) {
    String f(int v) => format?.call(v) ?? '$v';
    if (calmMotion(context)) return Text(f(to.round()), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from.toDouble(), end: to.toDouble()),
      duration: Duration(milliseconds: ms), curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(f(v.round()), style: style));
  }
}
