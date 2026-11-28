import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_lang.dart';
import '../brand.dart';
import '../media_cache.dart';
import '../local_store.dart';
import '../motion_kit.dart';
import 'profile_trophies.dart';
import 'trophy_cabinet.dart' show ArenaLevel, levelName;

// ═════════════════════════════════════════════════════════════════════════
// Profile looks per LEVEL (owner, 28 Nov): every level adds something to the profile itself,
// so a visitor sees the difference at once. Profile level = the higher of Egypt / World.
// 0 Rookie   plain (red glow, white frame, no sparks)
// 1 Amateur  bronze frame + bronze light + a few sparks
// 2 Semi-Pro + level chip next to the name + shine on the card
// 3 Pro      silver frame + silver light + more sparks
// 4 Elite    + a light edge running around the card + shining name
// 5 Master   gold frame + gold light + gold sparks
// 6 Legend   + crown over the card + slow light rays behind it
// 7 Icon     red × gold ring turning around the card, red + gold light, ICON chip, flash when the profile opens
// All code (no files, no egress). Phones with "remove animations" get the still version.
// Switch: `profile_level_looks` = show | hide (hide = everyone plain).
// ═════════════════════════════════════════════════════════════════════════

class LevelLook {
  const LevelLook._(this.level);
  final int level;


  static LevelLook of(ProfileTrophies? t) {
    if (t == null || !ProfileUi.levelLooks) return const LevelLook._(0);
    final lv = math.max(ArenaLevel.of(t, 'LOCAL').level, ArenaLevel.of(t, 'WORLD').level);
    return LevelLook._(lv.clamp(0, 7).toInt());
  }

  /// level names are always English (owner 28 Nov)
  String get en => levelName(level);
  String get name => levelName(level);

  static const _bronze = [Color(0xFFE3A06B), Color(0xFF8C4F24), Color(0xFFD08A55)];
  static const _silver = [Color(0xFFF4F6F8), Color(0xFF8E979F), Color(0xFFD9DEE2)];
  static const _gold = [Color(0xFFFFE9A8), Color(0xFFA8771F), Color(0xFFE6B649)];
  static const _icon = [Color(0xFFFF5A5A), Color(0xFF8A0E14), Color(0xFFFFD76A)];
  static const _white = [Color(0xFFFFFFFF), Color(0xFF8C8C8C), Color(0xFFE6E6E6)];

  /// BADGER card frame
  List<Color> get frame => switch (level) { 1 || 2 => _bronze, 3 || 4 => _silver, 5 || 6 => _gold, 7 => _icon, _ => _white };
  /// main colour (light, sparks, chip)
  Color get accent => switch (level) {
        1 || 2 => const Color(0xFFC97B45),
        3 || 4 => const Color(0xFFCFD6DD),
        5 || 6 => const Color(0xFFE6B649),
        7 => const Color(0xFFFF3B3B),
        _ => const Color(0xFFC81E28),
      };
  /// background light colour
  Color get glow => switch (level) {
        1 || 2 => const Color(0xFFBE6E3C),
        3 || 4 => const Color(0xFFAAB4C8),
        5 || 6 => const Color(0xFFE6B43C),
        7 => const Color(0xFFFF3C3C),
        _ => const Color(0xFFC81E28),
      };
  Color? get glow2 => level == 7 ? const Color(0xFFFFC85A) : null;
  int get sparks => const [0, 10, 16, 22, 28, 32, 40, 55][level];
  bool get shine => level >= 2;
  bool get chip => level >= 2;
  bool get ring => level >= 4;
  bool get nameShine => level >= 4;
  bool get crown => level >= 6;
  bool get rays => level >= 6;
  bool get flash => level == 7;
}

/// Ring / crown / rays around the BADGER card (they move with the card).
class LevelDecor extends StatefulWidget {
  const LevelDecor({super.key, required this.look, required this.width, required this.child});
  final LevelLook look;
  final double width;
  final Widget child;
  @override
  State<LevelDecor> createState() => _LevelDecorState();
}

class _LevelDecorState extends State<LevelDecor> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moving = (widget.look.ring || widget.look.rays) && !calmMotion(context);
    if (moving && !_c.isAnimating) _c.repeat();
    if (!moving && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    if (!look.ring && !look.rays && !look.crown) return widget.child;
    final w = widget.width;
    final h = w * FantasyProfileCard.ratio;
    final r = w * 0.12;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      if (look.rays)
        Positioned(left: -w * 0.6, right: -w * 0.6, top: h / 2 - w * 1.1, height: w * 2.2,
          child: IgnorePointer(child: AnimatedBuilder(animation: _c,
              builder: (_, __) => CustomPaint(painter: _RaysPainter(_c.value * 2 * math.pi, look))))),
      widget.child,
      if (look.ring)
        Positioned(left: -4, right: -4, top: -4, bottom: -4,
          child: IgnorePointer(child: AnimatedBuilder(animation: _c,
              builder: (_, __) => CustomPaint(painter: _RingPainter(_c.value * 2 * math.pi * 5, look, r + 4))))),
      if (look.crown)
        Positioned(top: -w * 0.24, left: 0, right: 0,
          child: IgnorePointer(child: AnimatedBuilder(animation: _c,
              builder: (_, child) => Transform.translate(offset: Offset(0, -2 * math.sin(_c.value * 2 * math.pi * 6)), child: child),
              child: Center(child: Text('👑', style: TextStyle(fontSize: w * 0.17)))))),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.angle, this.look, this.radius);
  final double angle;
  final LevelLook look;
  final double radius;

  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect.deflate(2), Radius.circular(radius));
    final icon = look.level == 7;
    final colors = icon
        ? const [Color(0xFFFF2B2B), Color(0xFFFFD76A), Color(0xFFFF2B2B), Color(0xFFFFD76A), Color(0xFFFF2B2B)]
        : [look.accent.withOpacity(0), look.accent.withOpacity(0), Colors.white, look.accent.withOpacity(0)];
    final stops = icon ? const [0.0, 0.25, 0.5, 0.75, 1.0] : const [0.0, 0.62, 0.8, 1.0];
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = icon ? 4 : 3
      ..shader = SweepGradient(colors: colors, stops: stops, transform: GradientRotation(angle)).createShader(rect);
    if (icon) {
      c.drawRRect(rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0x55FF3B3B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    c.drawRRect(rr, p);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.angle != angle || o.look.level != look.level;
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.angle, this.look);
  final double angle;
  final LevelLook look;

  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    final a = look.level == 7 ? const Color(0x33FF3C3C) : const Color(0x26FFD76A);
    final b = look.level == 7 ? const Color(0x22FFC85A) : const Color(0x1AFFD76A);
    c.save();
    c.translate(ctr.dx, ctr.dy);
    c.rotate(angle);
    const n = 16;
    for (var i = 0; i < n; i++) {
      final t0 = i * 2 * math.pi / n;
      final t1 = t0 + 0.14;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(r * math.cos(t0), r * math.sin(t0))
        ..lineTo(r * math.cos(t1), r * math.sin(t1))
        ..close();
      c.drawPath(path, Paint()..shader = RadialGradient(colors: [i.isEven ? a : b, const Color(0x00000000)], stops: const [0.15, 1.0])
          .createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter o) => o.angle != angle;
}

/// Level chip next to the name (Semi-Pro and up).
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.look});
  final LevelLook look;
  @override
  Widget build(BuildContext context) {
    final icon = look.level == 7;
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: icon ? null : Border.all(color: look.accent),
        gradient: icon ? const LinearGradient(colors: [Color(0xFFFF2B2B), Color(0xFFFFD76A)]) : null,
      ),
      child: Text(look.en.toUpperCase(), style: TextStyle(color: icon ? Colors.black : look.accent,
          fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}

/// Shining name (Elite and up): a light band moves across the letters.
class LevelNameShine extends StatefulWidget {
  const LevelNameShine({super.key, required this.look, required this.child});
  final LevelLook look;
  final Widget child;
  @override
  State<LevelNameShine> createState() => _LevelNameShineState();
}

class _LevelNameShineState extends State<LevelNameShine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!calmMotion(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.look.accent;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(
          colors: [Colors.white, a, Colors.white],
          stops: const [0.3, 0.5, 0.7],
          transform: _Slide(_c.value * 2 - 1),
        ).createShader(r),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.t);
  final double t;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * t, 0, 0);
}

/// Owner only, once per new level: the big "level up" moment.
/// [card] draws the BADGER card in a given look; [onSeeProfile] (optional) jumps to the profile tab.
Future<bool> maybeShowLevelUp(BuildContext context, ProfileTrophies t, Widget Function(LevelLook l, double w) card,
    {VoidCallback? onSeeProfile}) async {
  final look = LevelLook.of(t);
  final seen = await LocalStore.getStr('profile_level_seen');
  await LocalStore.setStr('profile_level_seen', '${look.level}');
  if (seen == null || !context.mounted) return false; // first time: just remember
  final old = int.tryParse(seen) ?? 0;
  if (look.level <= old) return false;
  await showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'level',
    barrierColor: Colors.black.withOpacity(0.9),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, __, ___) => _LevelUpView(look: look, old: LevelLook._(old.clamp(0, 7).toInt()), card: card,
        onSeeProfile: onSeeProfile),
  );
  return true;
}

/// After a squad save (fantasy): the 2 "round played" points count at save, so the level can change right here.
/// Returns true when the celebration was shown (the save flow then shows nothing else that time).
Future<bool> maybeLevelUpAfterSave(BuildContext context, {VoidCallback? onSeeProfile}) async {
  try {
    final sb = Supabase.instance.client;
    final id = await sb.rpc('get_my_iplay_user_id');
    final uid = id is num ? id.toInt() : int.tryParse('$id');
    if (uid == null) return false;
    final t = await ProfileTrophies.load(uid);
    if (t == null || !ProfileUi.levelLooks || !context.mounted) return false;
    ImageProvider? photo;
    try {
      final row = await sb.from('user_profile').select('avatar_url').eq('user_id', uid).maybeSingle();
      final url = row?['avatar_url']?.toString();
      if (url != null && url.isNotEmpty) photo = MediaCache.image(url);
    } catch (_) {}
    if (!context.mounted) return false;
    return await maybeShowLevelUp(context, t, (l, w) => LevelDecor(look: l, width: w,
        child: badgerProfileCard(w, t, photo: photo, frame: l.frame)), onSeeProfile: onSeeProfile);
  } catch (_) {
    return false;
  }
}

class _LevelUpView extends StatefulWidget {
  const _LevelUpView({required this.look, required this.old, required this.card, this.onSeeProfile});
  final LevelLook look, old;
  final Widget Function(LevelLook l, double w) card;
  final VoidCallback? onSeeProfile;
  @override
  State<_LevelUpView> createState() => _LevelUpViewState();
}

class _LevelUpViewState extends State<_LevelUpView> with SingleTickerProviderStateMixin {
  // 0 → 0.45: the old card spins in · 0.45: flash, it becomes the new card · then confetti + text
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _shareKey = GlobalKey();
  final _rnd = math.Random();
  late final List<ConfettiBit> _bits = List.generate(80, (_) => ConfettiBit(_rnd));
  bool _buzzed = false, _sharing = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_buzzed && _c.value > 0.45) {
        _buzzed = true;
        Buzz.medium();
        Future.delayed(const Duration(milliseconds: 140), Buzz.medium);
        Future.delayed(const Duration(milliseconds: 280), Buzz.medium);
      }
    });
    Future.delayed(const Duration(milliseconds: 200), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final rb = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (rb == null) return;
      final img = await rb.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final n = widget.look.en;
      await Share.shareXFiles(
        [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'bdgr_level.png')],
        text: AppLang.t("I'm now $n on BDGR 🦡 ${Brand.shareLinkBase}", 'بقيت $n على BDGR 🦡 ${Brand.shareLinkBase}'),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width * 0.48).clamp(160.0, 210.0).toDouble();
    final look = widget.look;
    final calm = calmMotion(context);
    final today = DateTime.now();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        // confetti in the level colours
        if (!calm) Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _c,
            builder: (_, __) => CustomPaint(painter: ConfettiPainter(_bits, ((_c.value - 0.45) / 0.55).clamp(0.0, 1.0).toDouble(),
                [look.accent, look.frame.first, Colors.white, const Color(0xFFFFD27A)]))))),
        Center(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final v = calm ? 1.0 : _c.value;
              final spin = Curves.easeOutCubic.transform((v / 0.45).clamp(0.0, 1.0).toDouble());
              final isNew = calm || v >= 0.45;
              final flash = calm ? 0.0 : (v < 0.45 ? 0.0 : math.max(0.0, 1 - (v - 0.45) / 0.18));
              final glow = calm ? 0.7 : (v < 0.45 ? 0.2 : 0.7);
              return Stack(alignment: Alignment.center, children: [
                Container(width: w * 2.2, height: w * 2.2, decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [look.accent.withOpacity(0.55 * glow), look.accent.withOpacity(0)]))),
                RepaintBoundary(key: _shareKey, child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 16),
                  color: Colors.transparent,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..setEntry(3, 2, 0.0015)..rotateY(isNew ? 0 : (1 - spin) * math.pi * 3),
                      child: Transform.scale(scale: 0.7 + 0.3 * spin,
                          child: widget.card(isNew ? look : widget.old, w)),
                    ),
                    const SizedBox(height: 14),
                    Text(look.en.toUpperCase(), style: TextStyle(color: look.accent, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    Text('${months[today.month - 1]} ${today.day}, ${today.year} · BDGR',
                        style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
                  ]),
                )),
                if (flash > 0) IgnorePointer(child: Container(width: w * 1.6, height: w * 1.6,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [
                      Colors.white.withOpacity(0.85 * flash), Colors.white.withOpacity(0)])))),
              ]);
            },
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Opacity(opacity: calm ? 1 : ((_c.value - 0.55) / 0.25).clamp(0.0, 1.0).toDouble(), child: child),
            child: Column(children: [
              const SizedBox(height: 10),
              Text(AppLang.t('LEVEL UP', 'مستوى جديد'), style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 3)),
              const SizedBox(height: 6),
              Text(AppLang.t('Congrats! You\'re now ${look.en} 🎉', 'مبروك! بقيت ${look.en} 🎉'), textAlign: TextAlign.center,
                  style: TextStyle(color: look.accent, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text(
                  AppLang.t('${widget.old.en} → ${look.en}. Your profile has a new frame and a new light, everyone who visits sees it.',
                      '${widget.old.en} ← ${look.en}. بروفايلك بقى ليه إطار جديد ونور جديد، وكل اللي يزوره هيشوفه.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4))),
              const SizedBox(height: 18),
              Row(mainAxisSize: MainAxisSize.min, children: [
                FilledButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(AppLang.t('Share my card', 'شير كارتي'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF0000), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                if (widget.onSeeProfile != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () { Navigator.of(context).pop(); widget.onSeeProfile!(); },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(AppLang.t('See my profile', 'شوف بروفايلك'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              TextButton(onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLang.t('Close', 'قفل'), style: const TextStyle(color: Colors.white54))),
            ]),
          ),
        ]))),
      ]),
    );
  }
}

class ConfettiBit {
  ConfettiBit(math.Random r)
      : x = r.nextDouble(), speed = 0.5 + r.nextDouble() * 0.7, drift = (r.nextDouble() - 0.5) * 0.25,
        size = 4 + r.nextDouble() * 5, spin = r.nextDouble() * 6, color = r.nextInt(4), delay = r.nextDouble() * 0.25;
  final double x, speed, drift, size, spin, delay;
  final int color;
}

class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.bits, this.t, this.colors);
  final List<ConfettiBit> bits;
  final double t;
  final List<Color> colors;
  @override
  void paint(Canvas c, Size s) {
    if (t <= 0) return;
    for (final b in bits) {
      final p = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0).toDouble();
      if (p <= 0) continue;
      final y = -20 + p * b.speed * s.height * 1.2;
      final x = (b.x + b.drift * p) * s.width;
      final paint = Paint()..color = colors[b.color].withOpacity((1 - p * 0.7).clamp(0.0, 1.0).toDouble());
      c.save();
      c.translate(x, y);
      c.rotate(b.spin + p * 8);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.55), paint);
      c.restore();
    }
  }
  @override
  bool shouldRepaint(ConfettiPainter o) => o.t != t;
}
