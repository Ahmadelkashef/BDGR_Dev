import 'package:flutter/material.dart';
import '../web/web_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import '../local_store.dart';
import 'auth_callback_screen.dart';
import 'login_config.dart';
import 'phone_otp_form.dart';
import 'video_playlist_background.dart';
import 'video_preloader.dart';

/// صفحة اللوجن: خلفية فيديو + فورم رقم الموبايل.
/// الفيديوهات بتيجي جاهزة من VideoPreloader اللي شتغل من شاشة الترحيب.
/// وبمجرد فتح الصفحة بيبدأ تحميل فيديو الويلكم في الخلفية.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.lang = 'en', this.errorReason});

  final String  lang;
  final String? errorReason;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String _lang;

  bool get _ar => _lang == 'ar';

  static const ColorFilter _dim = ColorFilter.matrix(<double>[
    0.6, 0, 0, 0, 0,
    0, 0.6, 0, 0, 0,
    0, 0, 0.6, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;

    // ابدأ تحميل فيديو الويلكم في الخلفية الآن
    VideoPreloader.prefetch(LoginConfig.welcomeVideo);

    if (widget.errorReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _ar
                ? 'حصل خطأ (${widget.errorReason})، حاول تاني'
                : 'Sign-in failed (${widget.errorReason}). Please try again.',
          ),
        ));
      });
    }
  }

  void _onVerified(Session session) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AuthCallbackScreen(session: session),
      ),
      (route) => false,
    );
  }

  /// الويب على شاشة كبيرة: الفورم جوه كارت زجاجي فوق الفيديو
  Widget _webCard(BuildContext context, Widget child) {
    if (!WebLayout.isDesktop(context)) return child;
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 34, 34, 30),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 50, offset: Offset(0, 20))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset  = MediaQuery.of(context).padding.top;
    final direction = _ar ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: _dim,
              child: VideoPlaylistBackground(
                urls:      LoginConfig.loginVideos,
                posterUrl: LoginConfig.loginPoster,
              ),
            ),

            // المحتوى
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                topInset + 20 + 100,
                20,
                24,
              ),
              child: Center(
                child: _webCard(context, ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrandLogo(width: 160),
                      const SizedBox(height: 8),
                      Text(
                        _ar
                            ? 'ساحتك بتبدأ من هنا'
                            : 'Your arena starts here',
                        style: const TextStyle(
                          color: Color(0xFFDDDDDD),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),
                      PhoneOtpForm(
                        isArabic:   _ar,
                        onVerified: _onVerified,
                      ),
                    ],
                  ),
                )),
              ),
            ),

            // زرار الرجوع
            PositionedDirectional(
              top: topInset + 8,
              start: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
