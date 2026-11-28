import 'dart:ui' as ui;

import '../ads/ad_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../app_config.dart';
import '../brand.dart';
import '../media_cache.dart';
import 'competition_sports.dart';

/// كارت "WELCOME NEW BADGER": كارت دهبي على شكل درع (ستايل كروت اللاعيبة)
/// بيظهر بعد ما اليوزر يسجّل في مسابقة (أول مرة، أو لما المفضلة تتغير).
/// جواه صورة البروفايل + الاسم + اللعبة المفضلة. من غير أرقام وهمية.

const _goldLight = Color(0xFFFFE9A8);
const _gold = Color(0xFFE6B649);
const _goldDeep = Color(0xFFA8771F);
const _goldGradient = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [_goldLight, _gold, _goldDeep, _gold, _goldLight],
  stops: [0, 0.3, 0.55, 0.8, 1],
);

/// يجيب بيانات البروفايل ويفتح الكارت. مفيش حاجة بتتحفظ هنا.
/// الأونر (28 نوفمبر): زرار واحد "Edit" بس → بيرجّع 'edit' (يغيّر الرياضة الأساسية). ✕ / برّه = خلاص اتسجل (null).
/// زراير الفرق (كابتن / انضم) اتشالت من الكارت؛ الفرق نفسها مستخبية بسويتش competition_teams.
Future<String?> showBadgerWelcomeCard(BuildContext context, CompSport sport, {required bool arabic}) async {
  String name = '';
  String? avatar;
  try {
    final res = await supa.rpc('get_my_profile_info');
    if (res is List && res.isNotEmpty) {
      final d = res.first as Map<String, dynamic>;
      final n = (d['display_name'] ?? d['full_name'] ?? '').toString().trim();
      // الاسم الافتراضي "BDGR Athlete" = ملوش اسم → مش بيتكتب
      if (n.isNotEmpty && n.toLowerCase() != 'bdgr athlete') name = n;
      final a = (d['avatar_url'] ?? d['provider_avatar_url'] ?? '').toString().trim();
      if (a.isNotEmpty) avatar = a;
    }
  } catch (e) {
    debugPrint('badger card profile error: $e');
  }
  if (!context.mounted) return null;
  // نحمّل الصورة الأول عشان الكارت يظهر كامل (والشير يطلع فيه الصورة)
  if (avatar != null) {
    try {
      await precacheImage(MediaCache.image(avatar), context).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }
  if (!context.mounted) return null;
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'badger-card',
    barrierColor: Colors.black.withOpacity(0.85),
    transitionDuration: const Duration(milliseconds: 420),
    transitionBuilder: (_, anim, __, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(c), child: child));
    },
    pageBuilder: (ctx, _, __) => _BadgerCardDialog(name: name, avatar: avatar, sport: sport, arabic: arabic),
  );
}

class _BadgerCardDialog extends StatefulWidget {
  const _BadgerCardDialog({required this.name, required this.avatar, required this.sport, required this.arabic});
  final String name;
  final String? avatar;
  final CompSport sport;
  final bool arabic;

  @override
  State<_BadgerCardDialog> createState() => _BadgerCardDialogState();
}

class _BadgerCardDialogState extends State<_BadgerCardDialog> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  String t(String en, String ar) => widget.arabic ? ar : en;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await Share.shareXFiles(
        [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'bdgr_card.png')],
        text: t("I'm a new Badger for ${widget.sport.en} 🔥 ${Brand.shareLinkBase}",
            'بقيت Badger جديد في ${widget.sport.ar} 🔥 ${Brand.shareLinkBase}'),
      );
    } catch (e) {
      debugPrint('badger card share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = (size.width * 0.78).clamp(240.0, 340.0).toDouble();
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(alignment: AlignmentDirectional.centerEnd, child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54))),
                Text(t("You're in! 🎉", 'مبروك! 🎉'),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(t('Your Badger card is ready', 'كارت الـ Badger بتاعك جاهز'),
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 18),
                RepaintBoundary(
                  key: _cardKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    BadgerCard(width: cardW, name: widget.name, avatarUrl: widget.avatar, sport: widget.sport),
                    // "Powered by X" تحت الكارت (بيطلع في الصورة اللي بتتشير كمان)
                    AdSlot('badger_card', sport: widget.sport.id, center: true, boxed: true,
                        padding: const EdgeInsets.only(top: 10), prefixEn: 'Powered by', prefixAr: 'برعاية'),
                  ]),
                ),
                const SizedBox(height: 22),
                SizedBox(width: cardW, child: Text(
                    t("We'll tell you as soon as the tournament opens. Stay tuned 🔔",
                        'هنبلغك بالبطولة أول ما تتسجل، خليك متابع 🔔'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
                const SizedBox(height: 16),
                SizedBox(width: cardW * 0.62, height: 46, child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop('edit'),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(t('Edit', 'تعديل'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold, side: BorderSide(color: _gold.withOpacity(0.7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// الكارت نفسه (ينفع يتعرض في أي مكان). الاتجاه دايماً LTR زي كروت اللاعيبة.
class BadgerCard extends StatelessWidget {
  const BadgerCard({super.key, required this.width, required this.name, required this.avatarUrl, required this.sport});

  final double width;
  final String name;
  final String? avatarUrl;
  final CompSport sport;

  static const double ratio = 1.38; // الطول / العرض

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = width * ratio;
    final border = w * 0.022;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: w, height: h,
        child: Stack(children: [
          // الإطار الدهبي
          Positioned.fill(child: ClipPath(
            clipper: _ShieldClipper(),
            child: const DecoratedBox(decoration: BoxDecoration(gradient: _goldGradient)),
          )),
          // الجسم الأسود
          Positioned.fill(child: Padding(
            padding: EdgeInsets.all(border),
            child: ClipPath(
              clipper: _ShieldClipper(),
              child: Stack(fit: StackFit.expand, children: [
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF1C1912), Color(0xFF0E0D0A), Color(0xFF070706)],
                ))),
                CustomPaint(painter: _FacetsPainter()),
                // خط دهبي رفيع جوه الإطار
                CustomPaint(painter: _InnerLinePainter()),
                _content(w, h - border * 2, context),
              ]),
            ),
          )),
        ]),
      ),
    );
  }

  // الأونر (28 نوفمبر): الصورة بعرض الكارت فوق (من غير علم ولا عمود NEW/BADGER)،
  // مفيش صورة → البادجر على الأسود؛ الاسم بس لو موجود.
  Widget _content(double w, double h, BuildContext context) {
    final iw = w;
    return Stack(children: [
      Positioned(
        top: 0, left: 0, right: 0, height: h * 0.6,
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.7, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: _photo(iw),
        ),
      ),
      Positioned(
        left: iw * 0.1, right: iw * 0.1, top: h * (name.isEmpty ? 0.6 : 0.56),
        child: Column(children: [
          if (name.isNotEmpty) ...[
            FittedBox(fit: BoxFit.scaleDown, child: _goldText(name, iw * 0.095, FontWeight.w900)),
            SizedBox(height: h * 0.012),
          ],
          Container(height: 1.2, decoration: BoxDecoration(gradient: LinearGradient(colors: [
            _gold.withOpacity(0), _gold, _gold.withOpacity(0)]))),
          SizedBox(height: h * 0.028),
          FittedBox(fit: BoxFit.scaleDown, child: _goldText('WELCOME NEW BADGER', iw * 0.058, FontWeight.w900, letterSpacing: 1.2)),
          SizedBox(height: h * 0.012),
          FittedBox(fit: BoxFit.scaleDown, child: Text('FOR ${sport.en.toUpperCase()}',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: iw * 0.046,
                  fontWeight: FontWeight.w700, letterSpacing: 2.5))),
          SizedBox(height: h * 0.03),
          Text('B D G R', style: TextStyle(color: _gold.withOpacity(0.55), fontSize: iw * 0.032,
              fontWeight: FontWeight.w800, letterSpacing: 3)),
        ]),
      ),
    ]);
  }

  Widget _photo(double iw) {
    final fallback = Container(
      decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.1), radius: 0.8,
          colors: [Color(0xFF2A2A2E), Color(0xFF121214), Color(0xFF0A0A0B)])),
      alignment: const Alignment(0, 0.1),
      child: FractionallySizedBox(widthFactor: 0.45,
          child: Opacity(opacity: 0.9, child: Image.asset(Brand.badger, fit: BoxFit.contain))),
    );
    if (avatarUrl == null) return fallback;
    return Image(image: MediaCache.image(avatarUrl!), fit: BoxFit.cover, alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => fallback);
  }

  static Widget _goldText(String s, double size, FontWeight weight, {double letterSpacing = 0}) => ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_goldLight, _gold, _goldDeep],
        ).createShader(r),
        blendMode: BlendMode.srcIn,
        child: Text(s, maxLines: 1, style: TextStyle(color: Colors.white, fontSize: size, fontWeight: weight,
            letterSpacing: letterSpacing, height: 1.05)),
      );
}

/// شكل الدرع: تاج صغير فوق في النص، أكتاف مشطوفة، وسنّ تحت.
Path _shieldPath(Size s) {
  final w = s.width, h = s.height;
  return Path()
    ..moveTo(w * 0.09, h * 0.055)
    ..lineTo(w * 0.36, h * 0.055)
    ..quadraticBezierTo(w * 0.43, h * 0.05, w * 0.46, h * 0.018)
    ..lineTo(w * 0.5, 0)
    ..lineTo(w * 0.54, h * 0.018)
    ..quadraticBezierTo(w * 0.57, h * 0.05, w * 0.64, h * 0.055)
    ..lineTo(w * 0.91, h * 0.055)
    ..lineTo(w * 0.91, h * 0.1)
    ..lineTo(w, h * 0.13)
    ..lineTo(w, h * 0.8)
    ..quadraticBezierTo(w * 0.97, h * 0.86, w * 0.78, h * 0.9)
    ..quadraticBezierTo(w * 0.6, h * 0.93, w * 0.5, h)
    ..quadraticBezierTo(w * 0.4, h * 0.93, w * 0.22, h * 0.9)
    ..quadraticBezierTo(w * 0.03, h * 0.86, 0, h * 0.8)
    ..lineTo(0, h * 0.13)
    ..lineTo(w * 0.09, h * 0.1)
    ..close();
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _shieldPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _InnerLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.03;
    final inner = Size(size.width - inset * 2, size.height - inset * 2);
    canvas.save();
    canvas.translate(inset, inset);
    canvas.drawPath(_shieldPath(inner), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _gold.withOpacity(0.45));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// لمعة دهبي على شكل مثلثات في الجنب اليمين فوق
class _FacetsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    void tri(List<Offset> p, double o) {
      final path = Path()..addPolygon(p, true);
      canvas.drawPath(path, Paint()
        ..shader = LinearGradient(colors: [_goldLight.withOpacity(o), _goldDeep.withOpacity(o * 0.3)])
            .createShader(path.getBounds()));
    }
    tri([Offset(w * 0.55, 0), Offset(w, 0), Offset(w, h * 0.28)], 0.22);
    tri([Offset(w * 0.62, h * 0.08), Offset(w, h * 0.28), Offset(w * 0.78, h * 0.45)], 0.14);
    tri([Offset(w * 0.78, h * 0.45), Offset(w, h * 0.28), Offset(w, h * 0.62)], 0.1);
    tri([Offset(w * 0.4, h * 0.02), Offset(w * 0.62, h * 0.08), Offset(w * 0.55, h * 0.3)], 0.08);
    tri([Offset(0, h * 0.62), Offset(w * 0.25, h * 0.75), Offset(0, h * 0.9)], 0.06);
    final line = Paint()..color = _gold.withOpacity(0.18)..strokeWidth = 0.8;
    canvas.drawLine(Offset(w * 0.55, 0), Offset(w * 0.78, h * 0.45), line);
    canvas.drawLine(Offset(w * 0.62, h * 0.08), Offset(w, h * 0.5), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EgyptFlag extends StatelessWidget {
  const _EgyptFlag({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.64;
    return Container(
      width: width, height: h,
      decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 0.6)),
      child: Column(children: [
        Expanded(child: Container(color: const Color(0xFFCE1126))),
        Expanded(child: Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: Container(width: h * 0.22, height: h * 0.22,
              decoration: const BoxDecoration(color: Color(0xFFC09300), shape: BoxShape.circle)),
        )),
        Expanded(child: Container(color: Colors.black)),
      ]),
    );
  }
}
