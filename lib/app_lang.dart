import 'package:flutter/foundation.dart';

import 'local_store.dart';

/// لغة التطبيق في مكان واحد.
/// بتتحمل مرة وقت التشغيل، وبتتغير لما اليوزر يدوس عربي/English في شاشة الـ Landing.
/// أي شاشة تقدر تستخدم AppLang.t('English', 'عربي') على طول.
class AppLang {
  AppLang._();

  static bool isArabic = false;

  /// بيتغير مع كل تغيير لغة، عشان الصفحات المفتوحة (زي البروفايل) تتحدث على طول
  /// بدل ما تفضل بنسخة قديمة من اللغة (27 نوفمبر: البروفايل طلع نص عربي ونص إنجليزي).
  static final ValueNotifier<bool> changes = ValueNotifier<bool>(false);

  static Future<void> load() async {
    isArabic = await LocalStore.getLang() == 'ar';
    changes.value = isArabic;
  }

  static void set(String lang) {
    isArabic = lang == 'ar';
    changes.value = isArabic;
  }

  static String t(String en, String ar) => isArabic ? ar : en;
}
