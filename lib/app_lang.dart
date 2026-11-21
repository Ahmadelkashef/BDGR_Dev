import 'local_store.dart';

/// لغة التطبيق في مكان واحد.
/// بتتحمل مرة وقت التشغيل، وبتتغير لما اليوزر يدوس عربي/English في شاشة الـ Landing.
/// أي شاشة تقدر تستخدم AppLang.t('English', 'عربي') على طول.
class AppLang {
  AppLang._();

  static bool isArabic = false;

  static Future<void> load() async {
    isArabic = await LocalStore.getLang() == 'ar';
  }

  static void set(String lang) => isArabic = lang == 'ar';

  static String t(String en, String ar) => isArabic ? ar : en;
}
