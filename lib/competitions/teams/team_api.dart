import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_lang.dart';
import '../../brand.dart';

/// الفرق (المسابقات): كل الكلام مع السيرفر هنا. كل حاجة بتعدّي على RPCs آمنة (SECURITY DEFINER).
class TeamApi {
  TeamApi._();
  static SupabaseClient get _sb => Supabase.instance.client;

  /// أي تغيير في الفرق (إنشاء / انضمام / قبول…) → كارت "فريقي" بيعيد التحميل
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);
  static void bump() => changed.value++;

  static Map<String, dynamic> _m(dynamic r) => Map<String, dynamic>.from(r as Map);

  static Future<Map<String, dynamic>> home({String sport = 'football'}) async =>
      _m(await _sb.rpc('team_home', params: {'p_sport': sport}));
  static Future<Map<String, dynamic>> athlete() async => _m(await _sb.rpc('athlete_get'));
  static Future<Map<String, dynamic>> athleteSave(Map<String, dynamic> p) async =>
      _m(await _sb.rpc('athlete_save', params: {'p': p}));
  static Future<Map<String, dynamic>> areas(String? governorate) async =>
      _m(await _sb.rpc('team_areas_list', params: {'p_governorate': governorate}));
  static Future<Map<String, dynamic>> create(Map<String, dynamic> p) async {
    final r = _m(await _sb.rpc('team_create', params: {'p': p}));
    bump();
    return r;
  }
  static Future<Map<String, dynamic>> get(String id) async => _m(await _sb.rpc('team_get', params: {'p_team': id}));
  static Future<Map<String, dynamic>> preview(String code) async =>
      _m(await _sb.rpc('team_preview', params: {'p_code': code.trim().toUpperCase()}));
  static Future<Map<String, dynamic>> join(String code) async {
    final r = _m(await _sb.rpc('team_join', params: {'p_code': code.trim().toUpperCase()}));
    bump();
    return r;
  }
  static Future<Map<String, dynamic>> invite(String team, String username) async =>
      _m(await _sb.rpc('team_invite', params: {'p_team': team, 'p_username': username.trim()}));
  static Future<Map<String, dynamic>> decide(String request, bool accept) async {
    final r = _m(await _sb.rpc('team_request_decide', params: {'p_request': request, 'p_accept': accept}));
    bump();
    return r;
  }
  static Future<void> cancel(String request) async {
    await _sb.rpc('team_request_cancel', params: {'p_request': request});
    bump();
  }
  static Future<Map<String, dynamic>> remove(String team, int user) async {
    final r = _m(await _sb.rpc('team_remove_member', params: {'p_team': team, 'p_user': user}));
    bump();
    return r;
  }
  static Future<void> leave(String team) async {
    await _sb.rpc('team_leave', params: {'p_team': team});
    bump();
  }
  static Future<void> disband(String team) async {
    await _sb.rpc('team_disband', params: {'p_team': team});
    bump();
  }

  static String shareLink(String code) => '${Brand.shareLinkBase}?t=${Uri.encodeComponent(code)}';

  static String shareText(String name, String code) => AppLang.t(
      'Join my football team "$name" on BDGR 🦡⚽\nTeam code: $code\n${shareLink(code)}',
      'انضم لفريقي "$name" على BDGR 🦡⚽\nكود الفريق: $code\n${shareLink(code)}');

  /// رسالة الغلط بالعربي/الإنجليزي
  static String error(Object e) {
    final msg = e is PostgrestException ? e.message : e.toString();
    String has(String k) => msg.contains(k) ? k : '';
    const map = <String, List<String>>{
      'athlete_incomplete': ['Complete your player info first.', 'كمّل بيانات اللاعب الأول.'],
      'gps_required': ['Tap "Locate me" first — location comes from GPS only.', 'دوس "حدّد موقعي" الأول — الموقع بيتاخد من الـ GPS بس.'],
      'location_required': ['Pick your governorate and city.', 'اختار المحافظة والمدينة.'],
      'birth_date_invalid': ['Check your date of birth (13+).', 'راجع تاريخ الميلاد (13 سنة أو أكبر).'],
      'gender_invalid': ['Pick your gender.', 'اختار النوع.'],
      'team_name_invalid': ['Team name: 2–30 characters.', 'اسم الفريق من 2 لـ 30 حرف.'],
      'team_name_reserved': ['This team name is not allowed.', 'الاسم ده مش مسموح.'],
      'already_in_format': ['You are already in a team with this format.', 'إنت في فريق بنفس الشكل ده بالفعل.'],
      'team_not_found': ['No team with this code.', 'مفيش فريق بالكود ده.'],
      'team_full': ['This team is full.', 'الفريق ده كامل.'],
      'already_member': ['Already in this team.', 'موجود في الفريق ده بالفعل.'],
      'already_pending': ['There is already a pending request.', 'فيه طلب مستني بالفعل.'],
      'user_not_found': ['This username doesn\'t exist on BDGR.', 'اليوزرنيم ده مش موجود عندنا.'],
      'cannot_invite_self': ['You are already the captain 🙂', 'إنت الكابتن أصلاً 🙂'],
      'captain_must_disband': ['Captain can\'t leave while players are in the team. Disband or remove them first.', 'الكابتن مايقدرش يسيب الفريق وفيه لاعيبة. احذف الفريق أو شيلهم الأول.'],
      'too_many': ['Too many tries today. Try again tomorrow.', 'محاولات كتير النهارده. جرّب بكرة.'],
      'request_not_found': ['This request is no longer available.', 'الطلب ده مبقاش موجود.'],
      'not_captain': ['Only the captain can do this.', 'الكابتن بس يقدر يعمل كده.'],
      'format_invalid': ['Pick a format.', 'اختار شكل الفريق.'],
    };
    for (final k in map.keys) {
      if (has(k).isNotEmpty) return AppLang.t(map[k]![0], map[k]![1]);
    }
    debugPrint('team error: $msg');
    return AppLang.t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.');
  }
}
