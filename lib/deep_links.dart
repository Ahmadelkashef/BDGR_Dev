import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// لينكات المشاركة: المحتوى بيتشاف جوه التطبيق بس.
///
/// شكل اللينكات اللي التطبيق بيفهمها:
///   com.bdgr.app://moment/<id>            (من صفحة اللينك بتفتح التطبيق)
///   https://.../?m=<id>                   (لو التطبيق اتفتح من اللينك نفسه)
///
/// لو اليوزر مش عامل لوجن، الـ id بيفضل محفوظ هنا لحد ما يدخل،
/// والـ MainShell بيفتح المومنت أول ما يتبني.
class DeepLinks {
  DeepLinks._();

  /// مومنت مستني يتفتح (null = مفيش)
  static final ValueNotifier<String?> pendingMomentId = ValueNotifier<String?>(null);

  /// بوست فيد مستني يتفتح (من لينك شير)
  static final ValueNotifier<String?> pendingPostId = ValueNotifier<String?>(null);
  /// بوست يوزر (لينك شير ?u=<id>)
  static final ValueNotifier<String?> pendingUgcId = ValueNotifier<String?>(null);

  /// كود ليج مستني (من لينك دعوة)
  static final ValueNotifier<String?> pendingLeagueCode = ValueNotifier<String?>(null);
  static final RegExp _code = RegExp(r'^[A-Za-z0-9]{4,12}$');

  /// كود فريق (مسابقات) مستني — من لينك دعوة ?t=<code> أو com.bdgr.app://team/<code>
  static final ValueNotifier<String?> pendingTeamCode = ValueNotifier<String?>(null);

  /// كود فريق دوري بادجر (الفانتازي) — من ?b=<code> أو com.bdgr.app://bleague/<code>
  static final ValueNotifier<String?> pendingBLeagueCode = ValueNotifier<String?>(null);

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static bool _started = false;

  static final RegExp _uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// بتتنادى مرة واحدة بعد تشغيل Supabase
  static Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('Initial deep link error: $e');
    }
    _sub = _appLinks.uriLinkStream.listen(_handle, onError: (Object e) {
      debugPrint('Deep link stream error: $e');
    });
  }

  static void _handle(Uri uri) {
    final post = postIdFrom(uri);
    if (post != null) { pendingPostId.value = post; return; }
    final ugc = ugcIdFrom(uri);
    if (ugc != null) { pendingUgcId.value = ugc; return; }
    final id = momentIdFrom(uri);
    if (id != null) { pendingMomentId.value = id; return; }
    final bl = bLeagueCodeFrom(uri);
    if (bl != null) { pendingBLeagueCode.value = bl; return; }
    final team = teamCodeFrom(uri);
    if (team != null) { pendingTeamCode.value = team; return; }
    final code = leagueCodeFrom(uri);
    if (code != null) pendingLeagueCode.value = code;
  }

  /// com.bdgr.app://league/<code>  أو  https://...?l=<code>
  static String? leagueCodeFrom(Uri uri) {
    String? c;
    if (uri.host == 'league' && uri.pathSegments.isNotEmpty) {
      c = uri.pathSegments.first;
    } else {
      c = uri.queryParameters['l'];
    }
    if (c == null || !_code.hasMatch(c)) return null;
    return c.toUpperCase();
  }

  static void consumeLeague() => pendingLeagueCode.value = null;

  /// com.bdgr.app://team/<code>  أو  https://...?t=<code>
  static String? teamCodeFrom(Uri uri) {
    String? c;
    if (uri.host == 'team' && uri.pathSegments.isNotEmpty) {
      c = uri.pathSegments.first;
    } else {
      c = uri.queryParameters['t'];
    }
    if (c == null || !_code.hasMatch(c)) return null;
    return c.toUpperCase();
  }

  static void consumeTeam() => pendingTeamCode.value = null;

  /// com.bdgr.app://bleague/<code>  أو  https://...?b=<code>
  static String? bLeagueCodeFrom(Uri uri) {
    String? c;
    if (uri.host == 'bleague' && uri.pathSegments.isNotEmpty) {
      c = uri.pathSegments.first;
    } else {
      c = uri.queryParameters['b'];
    }
    if (c == null || !RegExp(r'^[A-Za-z2-9]{6}$').hasMatch(c)) return null;
    return c.toUpperCase();
  }

  static void consumeBLeague() => pendingBLeagueCode.value = null;

  /// بيطلّع id المومنت من اللينك، أو null لو اللينك مش لمومنت
  static String? momentIdFrom(Uri uri) {
    String? id;
    if (uri.host == 'moment' && uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;           // com.bdgr.app://moment/<id>
    } else {
      id = uri.queryParameters['m'];          // https://...?m=<id>
    }
    if (id == null || !_uuid.hasMatch(id)) return null;
    return id.toLowerCase();
  }

  /// com.bdgr.app://post/<id>  أو  https://...?p=<id>
  static String? postIdFrom(Uri uri) {
    String? id;
    if (uri.host == 'post' && uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;
    } else {
      id = uri.queryParameters['p'];
    }
    if (id == null || !_uuid.hasMatch(id)) return null;
    return id.toLowerCase();
  }

  static void consumePost() => pendingPostId.value = null;

  /// com.bdgr.app://ugc/<id>  أو  https://...?u=<id>
  static String? ugcIdFrom(Uri uri) {
    String? id;
    if (uri.host == 'ugc' && uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;
    } else {
      id = uri.queryParameters['u'];
    }
    if (id == null || !_uuid.hasMatch(id)) return null;
    return id.toLowerCase();
  }

  static void consumeUgc() => pendingUgcId.value = null;

  /// بعد ما المومنت يتفتح
  static void consume() => pendingMomentId.value = null;

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
