import 'package:shared_preferences/shared_preferences.dart';

/// التخزين المحلي على الجهاز
class LocalStore {
  LocalStore._();

  static const String _langKey            = 'app_lang';
  static const String _deviceIdKey        = 'app_device_id';
  static const String _consentTermsKey    = 'app_consent_terms';
  static const String _consentMarketingKey = 'app_consent_marketing';

  static Future<String> getLang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) == 'ar' ? 'ar' : 'en';
  }

  static Future<void> setLang(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang == 'ar' ? 'ar' : 'en');
  }

  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  static Future<void> setDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, id);
  }

  /// الموافقات بتتحفظ قبل إرسال الـ OTP، علشان تتبعت لـ complete_onboarding بعدين
  static Future<void> setPendingConsents({
    required bool terms,
    required bool marketing,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentTermsKey, terms);
    await prefs.setBool(_consentMarketingKey, marketing);
  }

  static Future<PendingConsents?> getPendingConsents() async {
    final prefs = await SharedPreferences.getInstance();
    final terms     = prefs.getBool(_consentTermsKey);
    final marketing = prefs.getBool(_consentMarketingKey);
    if (terms == null || marketing == null) return null;
    return PendingConsents(terms: terms, marketing: marketing);
  }

  static Future<void> clearPendingConsents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_consentTermsKey);
    await prefs.remove(_consentMarketingKey);
  }

  /// علامات بسيطة (مثلاً: النصيحة دي اتشافت قبل كده)
  static Future<bool> getFlag(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('flag_$key') ?? false;
  }

  static Future<void> setFlag(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flag_$key', true);
  }

  static Future<void> clearUserData() async {
    await clearPendingConsents();
  }
}

class PendingConsents {
  const PendingConsents({required this.terms, required this.marketing});
  final bool terms;
  final bool marketing;
}
