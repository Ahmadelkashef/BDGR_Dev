import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../app_lang.dart';
import '../local_store.dart';
import 'local_notifs.dart';

/// رسالة وصلت والتطبيق في الخلفية أو مقفول.
/// إشعارات notification العادية Android بيعرضها لوحده (بالقناة والأيقونة)؛
/// هنا بنعرض بس رسايل الـ data (تفكير القفل بالعداد الحي).
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage m) async {
  if (m.notification != null) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: PushService.options);
  } catch (_) {}
  final d = Map<String, dynamic>.from(m.data);
  await LocalNotifs.init(arabic: d['lang']?.toString() != 'en');
  await LocalNotifs.showFromData(d);
}

/// الإشعارات (Firebase Cloud Messaging).
/// Firebase بيتشغّل من هنا بالقيم بتاعة google-services.json (مشروع bdgr-3ef34)،
/// من غير ملفات Gradle — علشان الـ workflow بيعمل مجلد android من الأول كل بيلد.
/// التطبيق المسجّل في Firebase هو com.bdgr.app بس (BDGR على dev).
class PushService {
  PushService._();

  static const options = FirebaseOptions(
    apiKey: 'AIzaSyBQgOde1ZYinimcw5QVBe8CXDKdHgckZ3g',
    appId: '1:1033657344799:android:ad40ecdad4a9654bf8062a',
    messagingSenderId: '1033657344799',
    projectId: 'bdgr-3ef34',
    storageBucket: 'bdgr-3ef34.firebasestorage.app',
  );

  static bool _ready = false;
  static StreamSubscription<String>? _refreshSub;
  static StreamSubscription<RemoteMessage>? _fgSub;

  /// إشعار وصل والتطبيق مفتوح (Android مش بيعرضه لوحده) — MainShell بيعرضه كبانر.
  static final ValueNotifier<RemoteMessage?> foreground = ValueNotifier<RemoteMessage?>(null);

  /// اليوزر داس على إشعار (والتطبيق في الخلفية أو مقفول) — MainShell بيفتح الصفحة المناسبة.
  static final ValueNotifier<Map<String, dynamic>?> opened = ValueNotifier<Map<String, dynamic>?>(null);
  static StreamSubscription<RemoteMessage>? _openSub;
  static bool _initialChecked = false;

  /// لازم يتنده في main() قبل runApp.
  static void registerBackgroundHandler() {
    if (!supported) return;
    try {
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
    } catch (e) {
      debugPrint('onBackgroundMessage error: $e');
    }
  }

  /// الإشعارات شغالة بس على Android وفي تطبيق BDGR (com.bdgr.app).
  static bool get supported =>
      !kIsWeb && Platform.isAndroid && AppConfig.appId == 'com.bdgr.app';

  static Future<bool> _init() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      _fgSub ??= FirebaseMessaging.onMessage.listen((m) => foreground.value = m);
      _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen((m) => opened.value = Map<String, dynamic>.from(m.data));
      LocalNotifs.onTap = (d) => opened.value = d;
      await LocalNotifs.init(arabic: AppLang.isArabic);
      _ready = true;
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }
    return _ready;
  }

  /// هل اليوزر سامح بالإشعارات على الموبايل ده؟
  static Future<bool> isAllowed() async {
    if (!await _init()) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// هل لسه ما اتسألش (علشان نعرض شرح قبل رسالة الموبايل)؟
  static Future<bool> notAskedYet() async {
    if (!await _init()) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.notDetermined;
    } catch (_) {
      return false;
    }
  }

  /// بيطلب الإذن (رسالة الموبايل)، ولو اتوافق بيسجّل الموبايل للحساب ده.
  static Future<bool> requestAndRegister() async {
    if (!await _init()) return false;
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      final ok = s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
      if (ok) await sync();
      return ok;
    } catch (e) {
      debugPrint('push permission error: $e');
      return false;
    }
  }

  /// التطبيق اتفتح من إشعار وهو مقفول خالص.
  static Future<void> checkInitialMessage() async {
    if (_initialChecked || !await _init()) return;
    _initialChecked = true;
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      if (m != null) {
        opened.value = Map<String, dynamic>.from(m.data);
      } else {
        final d = await LocalNotifs.launchData();   // دوسة على إشعار القفل (المحلي)
        if (d != null) opened.value = d;
      }
    } catch (e) {
      debugPrint('getInitialMessage error: $e');
    }
  }

  /// مع كل فتح للتطبيق: لو مسموح، نتأكد إن الموبايل متسجّل للحساب الحالي.
  static Future<void> sync() async {
    if (!await isAllowed()) return;
    await LocalNotifs.init(arabic: AppLang.isArabic);   // أسامي القنوات بلغة التطبيق الحالية
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('push getToken error: $e');
    }
  }

  static Future<void> _register(String token) async {
    final sb = Supabase.instance.client;
    if (sb.auth.currentSession == null) return;
    try {
      await sb.rpc('push_register_v3', params: {
        'p_token': token,
        'p_platform': 'android',
        'p_device_id': await LocalStore.getDeviceId(),
        'p_lang': AppLang.isArabic ? 'ar' : 'en',
        'p_notif_v': LocalNotifs.notifVersion,
      });
    } catch (e) {
      debugPrint('push_register error: $e');
    }
  }

  /// قبل تسجيل الخروج: الموبايل ده يبطّل يستقبل إشعارات الحساب ده.
  static Future<void> unregister() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client.rpc('push_unregister', params: {'p_token': token})
            .timeout(const Duration(seconds: 5));
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('push unregister error: $e');
    }
  }
}
