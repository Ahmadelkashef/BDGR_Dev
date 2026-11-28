import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Which bottom tab is showing, and which tab a widget lives in.
/// The tabs sit in an IndexedStack, so a hidden tab keeps ticking unless the widget checks this.
class ShellTab {
  ShellTab._();
  static final ValueNotifier<int> current = ValueNotifier<int>(0);
  /// colour for the 30 px above the bottom bar (behind the raised Profile circle). null = the app's normal black.
  /// Set only while a profile page with the moving background is the page on screen.
  static final ValueNotifier<Color?> navFill = ValueNotifier<Color?>(null);
  static Object? _fillOwner;
  static void setFill(Object who, Color? c) {
    if (c != null) {
      _fillOwner = who;
      if (navFill.value != c) navFill.value = c;
    } else if (_fillOwner == who) {
      _fillOwner = null;
      navFill.value = null;
    }
  }
}

class ShellTabScope extends InheritedWidget {
  const ShellTabScope({super.key, required this.index, required super.child});
  final int index;
  static int? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellTabScope>()?.index;
  @override
  bool updateShouldNotify(ShellTabScope old) => old.index != index;
}

/// Profile background (owner 27 Nov, idea 4 = "1 + 3"): two soft lights drifting slowly
/// + small sparks rising, all drawn in code (no files, no egress). Colour follows the card tier.
/// Still picture when the phone has "remove animations", when its tab is hidden or the app is in the background.
class ProfileAmbient extends StatefulWidget {
  const ProfileAmbient({super.key, required this.tier, required this.base, this.fillNav = false});
  final String tier; // new | bronze | silver | gold
  final Color base;
  /// `profile_nav_fill` = show: paint the strip above the bottom bar in [base] while this page is on screen
  final bool fillNav;

  static Color tierColor(String tier) => switch (tier) {
        'bronze' => const Color(0xFFBE6E3C),
        'silver' => const Color(0xFFAAB4C8),
        'gold' => const Color(0xFFE6B43C),
        _ => const Color(0xFFC81E28),
      };

  @override
  State<ProfileAmbient> createState() => _ProfileAmbientState();
}

class _Spark {
  _Spark(math.Random r) { reset(r, true); }
  double x = 0, y = 0, r = 1, v = 0.3, p = 0;
  void reset(math.Random rnd, bool anywhere) {
    x = rnd.nextDouble();
    y = anywhere ? rnd.nextDouble() : 1.02;
    r = 0.6 + rnd.nextDouble() * 1.6;
    v = 0.012 + rnd.nextDouble() * 0.03; // screen heights per second
    p = rnd.nextDouble() * 6.28;
  }
}

class _ProfileAmbientState extends State<ProfileAmbient> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier<double>(0);
  final _rnd = math.Random();
  late final List<_Spark> _sparks = List.generate(34, (_) => _Spark(_rnd));
  Duration _last = Duration.zero;
  bool _appOpen = true;
  int? _myTab;
  bool _routeOn = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addObserver(this);
    ShellTab.current.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _myTab = ShellTabScope.of(context);
    _routeOn = ModalRoute.of(context)?.isCurrent ?? true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _appOpen = s == AppLifecycleState.resumed;
    _sync();
  }

  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _sync() {
    if (!mounted) return;
    final shown = _routeOn && (_myTab == null || _myTab == ShellTab.current.value);
    // after the frame: never change the shell while it is building
    final fill = shown && widget.fillNav ? widget.base : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => ShellTab.setFill(this, fill));
    final run = _appOpen && !_still && shown;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration d) {
    final dt = _last == Duration.zero ? 0.0 : (d - _last).inMicroseconds / 1e6;
    _last = d;
    for (final s in _sparks) {
      s.y -= s.v * dt;
      if (s.y < -0.02) s.reset(_rnd, false);
    }
    _t.value += dt;
  }

  @override
  void didUpdateWidget(ProfileAmbient old) {
    super.didUpdateWidget(old);
    if (old.fillNav != widget.fillNav || old.base != widget.base) _sync();
  }

  @override
  void dispose() {
    ShellTab.setFill(this, null);
    ShellTab.current.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AmbientPainter(_t, _sparks, ProfileAmbient.tierColor(widget.tier), widget.base, _still),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.t, this.sparks, this.c, this.base, this.still) : super(repaint: t);
  final ValueNotifier<double> t;
  final List<_Spark> sparks;
  final Color c;
  final Color base;
  final bool still;

  void _blob(Canvas cv, Size sz, Offset o, double r, Color col, double a) {
    final rect = Rect.fromCircle(center: o, radius: r);
    cv.drawRect(Offset.zero & sz, Paint()
      ..shader = RadialGradient(colors: [col.withOpacity(a), col.withOpacity(0)]).createShader(rect));
  }

  @override
  void paint(Canvas cv, Size sz) {
    cv.drawRect(Offset.zero & sz, Paint()..color = base);
    final s = t.value * 1000; // ms, same speeds as the approved mockup
    final w = sz.width, h = sz.height;
    // light 1 = tier colour, high up behind the cards; light 2 = cool grey lower down
    _blob(cv, sz, Offset(w / 2 + w * 0.26 * math.sin(s * 0.00025), h * 0.2 + h * 0.09 * math.cos(s * 0.0002)),
        w * 0.85, c, 0.38);
    _blob(cv, sz, Offset(w / 2 + w * 0.3 * math.cos(s * 0.00018), h * 0.59 + h * 0.12 * math.sin(s * 0.00022)),
        w * 0.78, const Color(0xFF787D8C), 0.16);
    if (still) return;
    final sc = Color.lerp(c, Colors.white, 0.45)!;
    final p = Paint();
    for (final d in sparks) {
      final a = 0.25 + 0.35 * math.sin(s * 0.002 + d.p);
      p.color = sc.withOpacity(a.clamp(0.0, 1.0).toDouble());
      cv.drawCircle(Offset(d.x * w, d.y * h), d.r, p);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter o) => o.c != c || o.base != base || o.still != still;
}
