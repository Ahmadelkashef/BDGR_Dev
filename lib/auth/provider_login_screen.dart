import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../local_store.dart';
import 'login_config.dart';
import 'social_auth.dart';
import 'video_playlist_background.dart';
import 'video_preloader.dart';

const String _googleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path fill="#EA4335" d="M12 5c1.6 0 3 .6 4.1 1.6l3.1-3.1C17.3 1.8 14.8 1 12 1 7.5 1 3.7 3.6 1.9 7.4l3.7 2.9C6.5 7.3 9 5 12 5z"/>
<path fill="#4285F4" d="M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h6.5c-.3 1.5-1.1 2.8-2.4 3.7l3.7 2.9c2.2-2 3.7-5 3.7-8.8z"/>
<path fill="#FBBC05" d="M5.6 14.7c-.2-.7-.4-1.5-.4-2.7s.2-2 .4-2.7L1.9 6.4C.7 8.8 0 10.4 0 12s.7 3.2 1.9 5.6l3.7-2.9z"/>
<path fill="#34A853" d="M12 23c3.2 0 6-1.1 8-3l-3.7-2.9c-1.1-.7-2.5-1.2-4.3-1.2-3 0-5.5-2.3-6.4-5.3L1.9 15.6C3.7 19.4 7.5 23 12 23z"/>
</svg>
''';

const String _facebookSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#ffffff">
<path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
</svg>
''';

const String _tiktokSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#ffffff">
<path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/>
</svg>
''';

const String _xSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#ffffff">
<path d="M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z"/>
</svg>
''';

/// صفحة الدخول بالحسابات (لما app_settings.login_method = social).
/// نفس خلفية صفحة الـ OTP + لوجو BDGR + "Continue with" + زرار لكل حساب من login_providers
/// + نفس موافقات الشروط (13+) والعروض. الزراير مقفولة لحد ما يوافق على الشروط.
class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key, this.lang = 'en', this.errorReason});

  final String  lang;
  final String? errorReason;

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  static const Color _green = Color(0xFF00FF87);
  static const Color _dark  = Color(0xFF0B0B0F);

  static const ColorFilter _dim = ColorFilter.matrix(<double>[
    0.6, 0, 0, 0, 0,
    0, 0.6, 0, 0, 0,
    0, 0, 0.6, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  late String _lang;
  bool _terms = false;
  bool _marketing = false;
  String? _busy;

  bool get _ar => _lang == 'ar';

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    VideoPreloader.prefetch(LoginConfig.welcomeVideo);
    if (widget.errorReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _snack(_ar
            ? 'حصل خطأ في الدخول (${widget.errorReason})، حاول تاني'
            : 'Sign-in failed (${widget.errorReason}). Please try again.');
      });
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _go(String key) async {
    if (_busy != null) return;
    if (!_terms) {
      _snack(_ar ? 'علّم على الموافقة على الشروط الأول' : 'Please accept the Terms first');
      return;
    }
    setState(() => _busy = key);
    try {
      await LocalStore.setPendingConsents(terms: _terms, marketing: _marketing);
      await SocialAuth.signIn(key);
    } catch (e) {
      debugPrint('social sign-in start error ($key): $e');
      if (mounted) _snack(_ar ? 'مقدرناش نفتح صفحة الدخول، حاول تاني' : 'Could not open the sign-in page. Try again.');
    }
    // الزرار يرجع شغال بعد ثانيتين (لو اليوزر رجع من المتصفح من غير ما يكمّل)
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _openTerms() async {
    try {
      await launchUrl(Uri.parse(LoginConfig.termsUrl), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _button(String key) {
    final (svg, label) = switch (key) {
      'google'   => (_googleSvg, 'Google'),
      'facebook' => (_facebookSvg, 'Facebook'),
      'tiktok'   => (_tiktokSvg, 'TikTok'),
      _          => (_xSvg, 'X'),
    };
    final white = key == 'google';
    final on = _terms;
    final loading = _busy == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: on ? 1 : 0.45,
        child: Material(
          color: white ? Colors.white : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _go(key),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: white ? null : Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: white ? _dark : Colors.white),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      SvgPicture.string(svg, width: 22, height: 22),
                      const SizedBox(width: 12),
                      Text(label,
                          style: TextStyle(
                              color: white ? const Color(0xFF1F1F1F) : Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String text,
    String? linkText,
  }) {
    const style = TextStyle(color: Colors.white, fontSize: 14, height: 1.5);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 22,
        height: 22,
        child: Checkbox(
          value: value,
          activeColor: _green,
          checkColor: _dark,
          side: const BorderSide(color: Colors.white54),
          onChanged: (v) => onChanged(v ?? false),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Wrap(children: [
          GestureDetector(onTap: () => onChanged(!value), child: Text(text, style: style)),
          if (linkText != null)
            GestureDetector(onTap: _openTerms, child: Text(linkText, style: style.copyWith(color: _green))),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final providers = LoginConfig.loginProviders;
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          ColorFiltered(
            colorFilter: _dim,
            child: VideoPlaylistBackground(urls: LoginConfig.loginVideos, posterUrl: LoginConfig.loginPoster),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topInset + 20 + 80, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const BrandLogo(width: 160),
                  const SizedBox(height: 8),
                  Text(_ar ? 'ساحتك بتبدأ من هنا' : 'Your arena starts here',
                      style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 14)),
                  const SizedBox(height: 30),
                  Text(_ar ? 'كمّل بحساب' : 'CONTINUE WITH',
                      style: const TextStyle(
                          color: Color(0xFF99AAAA), fontSize: 13, letterSpacing: 3, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  for (final p in providers) _button(p),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _checkRow(
                        value: _terms,
                        onChanged: (v) => setState(() => _terms = v),
                        text: _ar ? 'عندي 13 سنة أو أكتر، وأوافق على ' : "I'm 13 or older and agree to the ",
                        linkText: _ar ? 'الشروط وسياسة الخصوصية' : 'Terms & Privacy Policy',
                      ),
                      const SizedBox(height: 12),
                      _checkRow(
                        value: _marketing,
                        onChanged: (v) => setState(() => _marketing = v),
                        text: _ar
                            ? 'أوافق على استقبال عروض وأحداث (اختياري)'
                            : "I'd like to receive offers & events (optional)",
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          PositionedDirectional(
            top: topInset + 8,
            start: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ]),
      ),
    );
  }
}
