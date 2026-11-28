import 'package:flutter/foundation.dart';

import '../app_config.dart';
import '../brand.dart';

/// بيانات عرض صفحات الدخول (الفيديوهات والصور ورابط الشروط).
/// المصدر الأساسي هو الداتابيز (دالة get_login_config).
/// القيم اللي هنا احتياطي بس، لو الإنترنت ضعيف أو الدالة فشلت.
class LoginConfig {
  LoginConfig._();

  static const String _mediaBase =
      'https://huggingface.co/datasets/Meekkii/IPLAY/resolve/main';

  static List<String> loginVideos = <String>[
    '$_mediaBase/Videos/index/background.mp4',
    '$_mediaBase/Videos/index/background_1.mp4',
    '$_mediaBase/Videos/index/background_2.mp4',
  ];

  static String loginPoster =
      '$_mediaBase/Videos/index/background_poster.jpg';

  /// الشروط والسياسة: مصدر واحد على bdgr-link (مش من الداتابيز، علشان ما يرجعش للّينك القديم).
  static String termsUrl = Brand.legalUrl;

  /// فيديو الترحيب بعد التسجيل (رابط ثابت، مش من الداتابيز)
  static const String welcomeVideo =
      'https://huggingface.co/datasets/Meekkii/IPLAY/resolve/main'
      '/BDGR/welcome/videos/welcome_intro.mp4';

  /// طريقة الدخول من الداتابيز (app_settings.login_method): otp | social
  static String loginMethod = 'otp';
  /// الحسابات اللي تظهر في صفحة social (app_settings.login_providers)
  static List<String> loginProviders = const ['google', 'facebook', 'x', 'tiktok'];
  static String tiktokClientKey = '';
  static bool _loaded = false;

  /// الويب يفضل على الـ OTP (الدخول بالحسابات معمول للتطبيق بس)
  static bool get useSocial => !kIsWeb && loginMethod == 'social' && loginProviders.isNotEmpty;

  /// قبل فتح صفحة الدخول: لو الإعدادات لسه ما وصلتش نستناها (5 ثواني بالكتير)
  static Future<void> ensureLoaded() async {
    if (!_loaded) await load();
  }

  /// بنقبل روابط https بس
  static String? _url(dynamic value) {
    if (value is! String) {
      return null;
    }

    final v = value.trim();
    return v.startsWith('https://') ? v : null;
  }

  /// نسخة الشروط والخصوصية الحالية من الداتابيز.
  /// بترجع null لو فشلت.
  static Future<Map<String, String>?> fetchLegalVersions() async {
    try {
      final rows = await supa.rpc('get_current_legal_versions');
      if (rows is! List || rows.isEmpty || rows.first is! Map) {
        return null;
      }
      final row = rows.first as Map;
      final terms   = '${row['out_terms_version']   ?? ''}'.trim();
      final privacy = '${row['out_privacy_version'] ?? ''}'.trim();
      if (terms.isEmpty || privacy.isEmpty) return null;
      return {'terms': terms, 'privacy': privacy};
    } catch (e) {
      debugPrint('fetchLegalVersions error: $e');
      return null;
    }
  }

  /// بتتنادى مرة واحدة وقت تشغيل التطبيق. أي فشل = نكمل بالقيم الافتراضية.
  static Future<void> load() async {
    try {
      final data = await supa
          .rpc('get_login_config')
          .timeout(const Duration(seconds: 5));

      if (data is! Map) {
        return;
      }

      final videos = <String>[
        for (final key in const ['login_video_1', 'login_video_2', 'login_video_3'])
          if (_url(data[key]) != null) _url(data[key])!,
      ];

      if (videos.isNotEmpty) {
        loginVideos = videos;
      }

      loginPoster = _url(data['login_poster']) ?? loginPoster;

      final m = '${data['login_method'] ?? ''}'.trim();
      if (m == 'otp' || m == 'social') loginMethod = m;
      if (data['login_providers'] is String) {
        const ok = ['google', 'facebook', 'x', 'tiktok'];
        final list = '${data['login_providers']}'.split(',').map((e) => e.trim()).where(ok.contains).toList();
        loginProviders = list;
      }
      tiktokClientKey = '${data['tiktok_client_key'] ?? ''}'.trim();
      _loaded = true;
    } catch (_) {
      debugPrint('Login config unavailable, using defaults');
    }
  }
}
