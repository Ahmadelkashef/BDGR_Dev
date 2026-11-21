import 'package:supabase_flutter/supabase_flutter.dart';

/// كل الإعدادات بتيجي من --dart-define وقت البناء (من الـ workflow).
/// مفيش ولا اسم ولا مفتاح مكتوب هنا.
class AppConfig {
  AppConfig._();

  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  /// الـ applicationId، ومنه بيطلع الـ deep link scheme
  static const String appId = String.fromEnvironment('APP_ID');

  /// اسم التطبيق اللي بيظهر للناس
  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'App');

  /// وضع التجربة: بيعرض معلومات للاختبار (زي حالة تحميل الفيديوهات).
  /// بيتحدد من الـ workflow، والافتراضي false، فأي بيلد من غيره مش هيعرضها.
  static const bool devMode = bool.fromEnvironment('DEV_MODE');

  /// النسخة بتتبعت للداتابيز مع كل لوجن
  static const String appVersion = 'v1.0';

  static String get supabaseUrl =>
      _supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static String get supabaseKey => _supabaseKey.trim();

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty && appId.isNotEmpty;

  /// لازم يكون متضاف في Supabase > Authentication > URL Configuration
  static String get redirectUrl => '$appId://auth-callback';
}

SupabaseClient get supa => Supabase.instance.client;
