import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// owner 28 Nov: the language buttons live in Settings only (switch `app_lang_toggles` = settings | everywhere).
  /// false = hide the quick buttons (home, fantasy, competitions, my stats, profile). Default hidden.
  static bool togglesEverywhere = false;
  /// owner 28 Nov: feed comments (switch `feed_comments`, default hide); copied into CommentsUi at app open
  static bool feedComments = false;
  /// owner 28 Nov: feed top = badger logo + HIGHLIGHTS (`feed_header` = logo | text) and one story per winner
  /// after the big highlights (`feed_people_stories` = show | hide).
  static bool feedHeaderLogo = true;
  static bool feedPeopleStories = true;
  static Future<void> loadUi() async {
    try {
      togglesEverywhere = await LocalStore.getStr('lang_toggles') == 'everywhere';
      final r = await Supabase.instance.client.rpc('fantasy_app_config');
      if (r is Map) feedComments = r['feed_comments']?.toString() == 'show';
      if (r is Map) feedHeaderLogo = r['feed_header']?.toString() != 'text';
      if (r is Map) feedPeopleStories = r['feed_people_stories']?.toString() != 'hide';
      if (r is Map && r['lang_toggles'] != null) {
        final v = '${r['lang_toggles']}';
        await LocalStore.setStr('lang_toggles', v);
        togglesEverywhere = v == 'everywhere';
      }
    } catch (_) {}
  }
}
