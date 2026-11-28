import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ads/ad_widgets.dart';
import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../local_store.dart';
import 'login_config.dart';
import 'login_screen.dart';
import 'provider_login_screen.dart';
import 'video_preloader.dart';
import '../web/web_layout.dart';

/// أول شاشة في التطبيق. بتفضل ظاهرة لحد ما اليوزر يدوس Login،
/// وفي نفس الوقت فيديوهات صفحة اللوجن بتتحمّل في الخلفية.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String _lang = 'en';

  bool get _ar => _lang == 'ar';

  @override
  void initState() {
    super.initState();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final lang = await LocalStore.getLang();

    if (mounted) {
      setState(() => _lang = lang);
    }
  }

  Future<void> _toggleLang() async {
    final next = _ar ? 'en' : 'ar';
    setState(() => _lang = next);
    AppLang.set(next);
    await LocalStore.setLang(next);
  }

  bool _opening = false;

  /// الداتابيز بتقرر: صفحة الـ OTP أو صفحة الحسابات (app_settings.login_method)
  Future<void> _openLogin() async {
    if (_opening) return;
    _opening = true;
    try {
      await LoginConfig.ensureLoaded();
    } catch (_) {}
    _opening = false;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginConfig.useSocial
            ? ProviderLoginScreen(lang: _lang)
            : LoginScreen(lang: _lang),
      ),
    );
  }

  /// الويب على شاشة كبيرة: البادجر على جنب والكلام وزرار الدخول على الجنب التاني
  Widget _buildDesktop(BuildContext context) {
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          Row(children: [
            const Expanded(flex: 11, child: _Hero()),
            Expanded(
              flex: 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E1E22), Color(0xFF0E0E10)],
                  ),
                  border: BorderDirectional(start: BorderSide(color: Colors.white.withOpacity(0.06))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 64),
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConfig.appName,
                          style: const TextStyle(color: Colors.white, fontSize: 84, fontWeight: FontWeight.w900, letterSpacing: 3, height: 1)),
                      const SizedBox(height: 22),
                      Text(
                        _ar
                            ? 'اعرض مهارتك، ادخل التحديات، وابدأ رحلتك من مجهول لبطل. ساحتك بتبدأ من هنا.'
                            : 'Show your skills, take on challenges, and go from unknown to unstoppable. Your arena starts here.',
                        style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 19, height: 1.6),
                      ),
                      AdSlot('login_partner', key: ValueKey('lp-$_lang'), padding: const EdgeInsets.only(top: 18),
                          prefixEn: 'Official partner', prefixAr: 'الشريك الرسمي'),
                      const SizedBox(height: 40),
                      _LoginButton(label: _ar ? 'تسجيل الدخول' : 'Login', onPressed: _openLogin),
                    ],
                  ),
                ),
              ),
            ),
          ]),
          PositionedDirectional(
            top: 20,
            end: 24,
            child: _LangButton(label: _ar ? 'English' : 'عربي', onTap: _toggleLang),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (WebLayout.isDesktop(context)) return _buildDesktop(context);
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // الجزء اللي فوق: البادجر
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.58,
              child: const _Hero(),
            ),

            // الكارت المايل اللي تحت
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.5,
              child: ClipPath(
                clipper: _SlantClipper(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2A2A2E), Color(0xFF141416)],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    size.height * 0.5 * 0.17,
                    24,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _ar
                            ? 'اعرض مهارتك، ادخل التحديات، وابدأ رحلتك من مجهول لبطل. ساحتك بتبدأ من هنا.'
                            : 'Show your skills, take on challenges, and go from unknown to unstoppable. Your arena starts here.',
                        style: const TextStyle(
                          color: Color(0xFFDDDDDD),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      // شريك/راعي (لو فيه): سطر صغير هادي
                      AdSlot('login_partner', key: ValueKey('lp-$_lang'), padding: const EdgeInsets.only(top: 14),
                          prefixEn: 'Official partner', prefixAr: 'الشريك الرسمي'),
                      const Spacer(),
                      Row(
                        children: [
                          if (AppConfig.devMode && !kIsWeb) const _PreloadStatus(),
                          const Spacer(),
                          _LoginButton(
                            label: _ar ? 'تسجيل الدخول' : 'Login',
                            onPressed: _openLogin,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // زرار اللغة
            PositionedDirectional(
              top: MediaQuery.of(context).padding.top + 12,
              end: 16,
              child: _LangButton(
                label: _ar ? 'English' : 'عربي',
                onTap: _toggleLang,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // توهج أخضر خفيف ورا البادجر
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0.05),
              radius: 0.75,
              colors: [Color(0x3300FF87), Color(0x00000000)],
            ),
          ),
        ),
        CustomPaint(painter: _RaysPainter()),
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.78,
            child: Image.asset(Brand.badger, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
}

/// خطوط مايلة خفيفة في الخلفية (إحساس بالحركة)
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final rays = <List<Offset>>[
      [Offset(w * 0.55, 0), Offset(w * 0.70, 0), Offset(w * 0.20, h)],
      [Offset(w * 0.85, 0), Offset(w * 0.95, 0), Offset(w * 0.45, h)],
      [Offset(w, h * 0.10), Offset(w, h * 0.22), Offset(w * 0.60, h)],
    ];

    for (final r in rays) {
      final path = Path()
        ..moveTo(r[0].dx, r[0].dy)
        ..lineTo(r[1].dx, r[1].dy)
        ..lineTo(r[2].dx, r[2].dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// الحافة اللي فوق في الكارت مايلة
class _SlantClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height * 0.14)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Brand.green,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          // السهم بيتقلب لوحده في العربي
          const Icon(Icons.arrow_forward, size: 22),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x26FFFFFF),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.language, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// وضع التجربة بس: عدد الفيديوهات اللي اتحمّلت
class _PreloadStatus extends StatelessWidget {
  const _PreloadStatus();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: VideoPreloader.readyVideos,
      builder: (context, ready, _) {
        final total = VideoPreloader.totalVideos;
        final done = total > 0 && ready >= total;

        return Text(
          'videos $ready/$total',
          style: TextStyle(
            color: done ? Brand.green : Colors.white54,
            fontSize: 12,
          ),
        );
      },
    );
  }
}
