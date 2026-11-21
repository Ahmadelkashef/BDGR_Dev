import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// بيسجّل إن اليوزر فتح التطبيق ده (جدول user_apps في الداتابيز).
/// بيتنادى من MainShell، مرة واحدة لكل يوزر في كل تشغيل.
/// لازم يفضل متنادي من الشِل الحقيقي لما يتبدل.
class AppUsage {
  AppUsage._();

  static String? _trackedFor;

  static Future<void> trackOpen() async {
    final uid = supa.auth.currentUser?.id;
    if (uid == null || _trackedFor == uid) return;
    _trackedFor = uid;
    try {
      await supa.rpc('track_app_open', params: {'p_app_id': AppConfig.appId});
    } catch (e) {
      _trackedFor = null; // نحاول تاني المرة الجاية
      debugPrint('track_app_open error: $e');
    }
  }
}
