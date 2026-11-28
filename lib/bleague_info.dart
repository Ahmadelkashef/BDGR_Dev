import 'package:supabase_flutter/supabase_flutter.dart';

/// Badger League state for the whole app (owner, 28 Nov): one league per arena (LOCAL / WORLD),
/// switch `app_settings.badger_league` = off | announce | on. Server `badger_league_home2()` (~2 KB),
/// kept 5 min on the phone so the fantasy page, the feed and home share ONE call.
class BLeagueInfo {
  BLeagueInfo._(this.raw);
  /// for render tests / previews
  factory BLeagueInfo.fromRaw(Map<String, dynamic> raw) => BLeagueInfo._(raw);
  final Map<String, dynamic> raw;

  static BLeagueInfo? _cache;
  static DateTime? _at;

  static Future<BLeagueInfo?> load({bool force = false}) async {
    if (!force && _cache != null && _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 5)) return _cache;
    try {
      final r = await Supabase.instance.client.rpc('badger_league_home2');
      _cache = BLeagueInfo._(Map<String, dynamic>.from(r as Map));
      _at = DateTime.now();
      return _cache;
    } catch (_) {
      return _cache;
    }
  }

  static BLeagueInfo? get cached => _cache;
  static void clear() => _at = null;

  String get state => '${raw['state'] ?? 'off'}';
  bool get visible => state == 'announce' || state == 'on';
  bool get announcing => state == 'announce';
  String get month => '${raw['month'] ?? ''}';
  bool get started => raw['started'] == true;
  bool get plays => raw['plays'] == true;
  int get minMembers => (raw['min_members'] as num?)?.toInt() ?? 2;
  int get maxMembers => (raw['max_members'] as num?)?.toInt() ?? 5;

  Map<String, dynamic> arena(String a) => Map<String, dynamic>.from((raw['arenas'] as Map?)?[a] as Map? ?? const {});
  Map<String, dynamic>? team(String a) => arena(a)['team'] is Map ? Map<String, dynamic>.from(arena(a)['team'] as Map) : null;
  int? perMember(String a) => ((arena(a)['prize'] as Map?)?['per_member_egp'] as num?)?.toInt();
  List<Map<String, dynamic>> rounds(String a) =>
      [for (final r in (arena(a)['rounds'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];

  /// the user still has no team in at least one arena
  bool get missingTeam => team('LOCAL') == null || team('WORLD') == null;
}

/// "December 2026" / "ديسمبر 2026"
String blMonthLabel(String m, bool ar, {bool withYear = true}) {
  final p = m.split('-');
  if (p.length != 2) return '';
  final i = ((int.tryParse(p[1]) ?? 1) - 1).clamp(0, 11).toInt();
  const arM = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  const enM = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final n = ar ? arM[i] : enM[i];
  return withYear ? '$n ${p[0]}' : n;
}

String blMoney(int v) => v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
