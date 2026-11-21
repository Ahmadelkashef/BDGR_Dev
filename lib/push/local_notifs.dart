import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// إشعارات Android المحلية: القنوات، الأيقونة الصغيرة، اللون، والعداد التنازلي لإشعار القفل.
/// القنوات لازم تطابق channelFor في supabase/functions/push-dispatch/index.ts.
class LocalNotifs {
  LocalNotifs._();

  /// نسخة مميزات الإشعارات اللي التطبيق ده فاهمها (بتتبعت للسيرفر: push_tokens.notif_v).
  /// 1 = قنوات + أيقونة + لون + عداد القفل الحي.
  static const notifVersion = 1;

  static const icon = 'ic_stat_bdgr';
  static const red = Color(0xFFFF0000); // BDGR red

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// دوسة على إشعار محلي والتطبيق شغال (في الخلفية أو قدام).
  static void Function(Map<String, dynamic> data)? onTap;

  // id, AR name, EN name, AR desc, EN desc, importance
  static const _channels = <(String, String, String, String, String, Importance)>[
    ('deadline', 'قفل التشكيلة', 'Squad deadline',
        'تفكير قبل ما الجولة تقفل', 'A reminder before the round closes', Importance.high),
    ('results', 'النقاط والنتايج', 'Points & results',
        'نقطك وترتيبك بعد كل جولة', 'Your points and rank after each round', Importance.high),
    ('support', 'ردود الدعم', 'Support replies',
        'لما فريق BDGR يرد عليك', 'When the BDGR team replies to you', Importance.high),
    ('social', 'المتابعين والتفاعل', 'Followers & activity',
        'متابعين جداد، لايكات، كومنتات، ودعوات الدوريات', 'New followers, likes, comments and league invites', Importance.defaultImportance),
    ('news', 'أخبار BDGR', 'BDGR news',
        'أخبار مهمة عن التطبيق', 'Important app news', Importance.defaultImportance),
    ('offers', 'العروض والمسابقات', 'Offers & competitions',
        'عروض ومسابقات (من غير صوت)', 'Offers and competitions (silent)', Importance.low),
    ('general', 'عام', 'General',
        'أي حاجة تانية', 'Everything else', Importance.defaultImportance),
  ];

  static Future<bool> init({required bool arabic}) async {
    try {
      if (!_ready) {
        await _plugin.initialize(
          const InitializationSettings(android: AndroidInitializationSettings(icon)),
          onDidReceiveNotificationResponse: (r) {
            final d = _decode(r.payload);
            if (d != null) onTap?.call(d);
          },
        );
        _ready = true;
      }
      await _createChannels(arabic);
    } catch (e) {
      debugPrint('LocalNotifs init error: $e');
    }
    return _ready;
  }

  /// القنوات بتظهر لليوزر في إعدادات الموبايل بالاسم ده (وبتتحدّث لو غيّر اللغة).
  static Future<void> _createChannels(bool arabic) async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    for (final c in _channels) {
      await android.createNotificationChannel(AndroidNotificationChannel(
        c.$1, arabic ? c.$2 : c.$3,
        description: arabic ? c.$4 : c.$5,
        importance: c.$6,
        playSound: c.$6 != Importance.low,
      ));
    }
    // القناة اللي Firebase كان بيعملها لوحده ("Miscellaneous") قبل القنوات
    try { await android.deleteNotificationChannel('fcm_fallback_notification_channel'); } catch (_) {}
  }

  static String _name(String id, bool arabic) {
    for (final c in _channels) {
      if (c.$1 == id) return arabic ? c.$2 : c.$3;
    }
    return arabic ? 'عام' : 'General';
  }

  /// بيعرض إشعار جاي كـ data بس من السيرفر (دلوقتي: تفكير القفل بعداد حي).
  static Future<void> showFromData(Map<String, dynamic> d) async {
    if (!_ready) return;
    final title = d['title']?.toString() ?? '';
    final body = d['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final arabic = d['lang']?.toString() != 'en';
    final channel = d['channel']?.toString() ?? 'general';
    final tag = d['tag']?.toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    final deadline = int.tryParse(d['deadline_ms']?.toString() ?? '');
    final countdown = deadline != null && deadline > now;
    if (deadline != null && !countdown) return;   // الجولة قفلت خلاص: مالوش لازمة

    final details = AndroidNotificationDetails(
      channel, _name(channel, arabic),
      icon: icon,
      color: red,
      importance: Importance.high,
      priority: Priority.high,
      tag: tag,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(body),
      showWhen: true,
      when: countdown ? deadline : null,
      usesChronometer: countdown,
      chronometerCountDown: countdown,
      // بيختفي لوحده أول ما الجولة تقفل
      timeoutAfter: countdown ? deadline - now : null,
    );
    await _plugin.show(
      (tag ?? '$now').hashCode & 0x7fffffff,
      title, body,
      NotificationDetails(android: details),
      payload: jsonEncode(d),
    );
  }

  /// التطبيق اتفتح من دوسة على إشعار محلي وهو مقفول خالص.
  static Future<Map<String, dynamic>?> launchData() async {
    if (!_ready) return null;
    try {
      final l = await _plugin.getNotificationAppLaunchDetails();
      if (l == null || !l.didNotificationLaunchApp) return null;
      return _decode(l.notificationResponse?.payload);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decode(String? p) {
    if (p == null || p.isEmpty) return null;
    try {
      final v = jsonDecode(p);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }
}
