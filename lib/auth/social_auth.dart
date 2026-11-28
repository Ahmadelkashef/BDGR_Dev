import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../local_store.dart';
import 'login_config.dart';

/// الدخول بحساب جوجل / فيسبوك / X / تيك توك (نفس كود iPLAY اللي كان شغال).
/// بيفتح صفحة الدخول في المتصفح، والنتيجة بترجع بالـ deep link `<APP_ID>://auth-callback`
/// ويلتقطها Supabase SDK (signedIn) → main.dart يكمّل في AuthCallbackScreen.
class SocialAuth {
  SocialAuth._();

  /// اسم المزوّد زي ما Supabase بيعرفه
  static const Map<String, String> _supabaseNames = {
    'google':   'google',
    'facebook': 'facebook',
    'tiktok':   'custom:tiktok',
    'x':        'x',
  };

  static Future<void> signIn(String key) async {
    final name = _supabaseNames[key];
    if (name == null) throw ArgumentError('Unknown provider: $key');

    await LocalStore.setPendingProvider(key);

    final query = <String, String>{
      'provider':    name,
      'redirect_to': AppConfig.redirectUrl,
    };
    if (key == 'tiktok' && LoginConfig.tiktokClientKey.isNotEmpty) {
      query['client_key'] = LoginConfig.tiktokClientKey;
    }

    final uri = Uri.parse('${AppConfig.supabaseUrl}/auth/v1/authorize').replace(queryParameters: query);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await LocalStore.clearPendingProvider();
      throw Exception('could_not_open_browser');
    }
  }
}
