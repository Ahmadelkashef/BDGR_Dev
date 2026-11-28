import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../brand.dart';
import '../main_shell.dart';
import '../app_lang.dart';
import 'login_screen.dart';
import 'provider_login_screen.dart';
import 'session_processor.dart';
import 'welcome_screen.dart';

/// شاشة "جاري تسجيل الدخول..." بعد تأكيد الـ OTP.
/// بتشغّل processAuthSession وتوجّه اليوزر على حسب النتيجة.
class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key, required this.session, this.provider});

  final Session session;
  /// google / facebook / x / tiktok لو الدخول بحساب
  final String? provider;

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _process();
  }

  Future<void> _process() async {
    final result = await processAuthSession(widget.session, provider: widget.provider);

    if (!mounted) return;

    Widget next;

    switch (result.destination) {
      case AuthDestination.home:
        next = const MainShell();
        break;
      case AuthDestination.onboarding:
        final error = await completeOnboarding();
        if (!mounted) return;
        next = error == null
            ? const WelcomeScreen()
            : _errorPage(error);
        break;
      case AuthDestination.error:
        next = _errorPage(result.reason);
        break;
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => next),
      (route) => false,
    );
  }

  Widget _errorPage(String? reason) => widget.provider != null
      ? ProviderLoginScreen(lang: AppLang.isArabic ? 'ar' : 'en', errorReason: reason)
      : LoginScreen(lang: 'en', errorReason: reason);

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(18)),
                    ),
                  ),
                  RotationTransition(
                    turns: _spin,
                    child: CustomPaint(
                      size: const Size(120, 120),
                      painter: _RingPainter(),
                    ),
                  ),
                  Image.asset(Brand.badger, width: 56),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Signing in…',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [
          Color(0x00A78BFA),
          Color(0x00A78BFA),
          Color(0xE6A78BFA),
          Color(0xFFFFFFFF),
        ],
        stops: const [0.0, 0.39, 0.83, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
