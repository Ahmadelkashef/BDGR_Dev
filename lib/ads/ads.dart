import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_lang.dart';

/// الإعلانات من السيرفر (ADS.md).
/// نداء واحد `ads_for` بيرجّع كل الإعلانات اللي تخص اليوزر ده (السيرفر بيفلتر بالسن/النوع/المحافظة/التطبيق/التواريخ/الحدود)،
/// والتطبيق بيختار لكل مكان (slot) حسب السياق (الجولة / الرياضة) واللغة.
/// مفيش إعلان = المكان مش بيترسم خالص.
class AdItem {
  final String id, campaignId, placement, template, lang;
  final String? title, body, cta, media, poster, linkType, link, sponsorName, sponsorLogo;
  final Color? bg, fg;
  final int weight, priority;
  final int? durationS;
  /// takeover: ✕ بتظهر بعد كام ثانية (0 = على طول) — الباقة البريميوم بتاخد 2
  final int? closeAfterS;
  /// takeover بريميوم: صفحة تفاصيل جوه التطبيق قبل اللينك
  final String? details;
  final bool demo;
  final List<String>? sports, eventIds;

  AdItem({
    required this.id, required this.campaignId, required this.placement, required this.template,
    required this.lang, this.title, this.body, this.cta, this.media, this.poster, this.linkType,
    this.link, this.sponsorName, this.sponsorLogo, this.bg, this.fg, this.weight = 1,
    this.priority = 0, this.durationS, this.closeAfterS, this.details, this.demo = false, this.sports, this.eventIds,
  });

  static Color? _color(dynamic v) {
    final s = v?.toString() ?? '';
    final m = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$').firstMatch(s);
    if (m == null) return null;
    final rgb = int.parse(m.group(1)!, radix: 16);
    final a = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
    return Color((a << 24) | rgb);
  }

  static List<String>? _list(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : null;

  factory AdItem.fromJson(Map<String, dynamic> j) {
    final sp = (j['sponsor'] is Map) ? Map<String, dynamic>.from(j['sponsor'] as Map) : const <String, dynamic>{};
    String? s(String k) {
      final v = j[k]?.toString();
      return (v == null || v.trim().isEmpty) ? null : v;
    }
    return AdItem(
      id: '${j['id']}', campaignId: '${j['campaign_id']}', placement: '${j['placement']}',
      template: '${j['template']}', lang: '${j['lang'] ?? 'any'}',
      title: s('title'), body: s('body'), cta: s('cta'), media: s('media'), poster: s('poster'),
      linkType: s('link_type'), link: s('link'),
      sponsorName: sp['name']?.toString(), sponsorLogo: (sp['logo']?.toString().isEmpty ?? true) ? null : sp['logo'].toString(),
      bg: _color(j['bg']), fg: _color(j['fg']),
      weight: (j['weight'] as num?)?.toInt() ?? 1, priority: (j['priority'] as num?)?.toInt() ?? 0,
      durationS: (j['duration_s'] as num?)?.toInt(), demo: j['demo'] == true,
      closeAfterS: (j['close_after_s'] as num?)?.toInt(), details: s('details'),
      sports: _list(j['sports']), eventIds: _list(j['event_ids']),
    );
  }

  bool get isVideo {
    final m = (media ?? '').toLowerCase().split('?').first;
    return m.endsWith('.mp4') || m.endsWith('.webm') || m.endsWith('.mov') || m.endsWith('.m4v');
  }

  bool get hasLink => linkType != null && linkType != 'none' && (link?.isNotEmpty ?? false);

  /// اسم الراعي أو العنوان (للقوالب الصغيرة)
  String get displayName => sponsorName ?? title ?? '';
}

class AdPlacementCfg {
  final int? everyN, firstAfter, maxPerSession;
  const AdPlacementCfg({this.everyN, this.firstAfter, this.maxPerSession});
  factory AdPlacementCfg.fromJson(Map<String, dynamic> j) => AdPlacementCfg(
        everyN: (j['every_n'] as num?)?.toInt(),
        firstAfter: (j['first_after'] as num?)?.toInt(),
        maxPerSession: (j['max_per_session'] as num?)?.toInt(),
      );
}

class Ads with WidgetsBindingObserver {
  Ads._();
  static final Ads _i = Ads._();

  /// بيزيد كل ما الإعلانات تتحمّل/تتغير → الأماكن بتعيد رسم نفسها
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  /// لينك "deeplink" جوه التطبيق (MainShell بيسمعه): fantasy / feed / competitions[:sport] / profile / home
  static final ValueNotifier<String?> deepLink = ValueNotifier<String?>(null);

  static List<AdItem> _ads = const [];
  /// حساب جديد (أقل من 24 ساعة) — مبقاش بيمنع الـ Takeover (21 نوفمبر)
  static bool newUser = true;
  /// إعلان الـ Takeover بعد ما اتقفل: بينزل مكانه في الهوم كبانر (مكان home_banner)
  static final ValueNotifier<AdItem?> docked = ValueNotifier<AdItem?>(null);
  static final Set<String> _takeoverShown = {};
  static Map<String, AdPlacementCfg> _cfg = const {};
  static DateTime? _loadedAt;
  static Duration _ttl = const Duration(minutes: 10);
  static Future<void>? _loading;
  static bool _observing = false;
  static String? _loadedFor;   // auth uid اللي اتحملت عشانه

  // الاختيار ثابت طول الجلسة لنفس المكان/السياق (مفيش رعشة بين إعلانين)
  static final Map<String, String> _chosen = {};
  static final Set<String> _dismissed = {};
  static final Set<String> _seen = {};
  static final Map<String, int> _queue = {};   // "c|p|t" → n
  static Timer? _flushTimer;
  static final _rnd = math.Random();

  static String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// يتنادى من أي مكان (رخيص): بيحمّل مرة كل 10 دقايق بس
  static Future<void> ensure({bool force = false}) {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(_i);
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < _ttl && _loadedFor == uid;
    if (!force && fresh) return Future.value();
    return _loading ??= _load(uid).whenComplete(() => _loading = null);
  }

  static Future<void> _load(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = _today;
      for (final k in prefs.getKeys().where((k) => k.startsWith('ad_x_'))) {
        if (prefs.getString(k) == day) {
          _dismissed.add(k.substring(5));
        } else {
          await prefs.remove(k);
        }
      }
      final res = await Supabase.instance.client.rpc('ads_for');
      final m = Map<String, dynamic>.from(res as Map);
      _ads = ((m['ads'] as List?) ?? [])
          .map((e) => AdItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _cfg = ((m['placements'] as Map?) ?? {}).map((k, v) =>
          MapEntry(k.toString(), AdPlacementCfg.fromJson(Map<String, dynamic>.from(v as Map))));
      newUser = m['new_user'] == true;
      final ttl = (m['ttl_s'] as num?)?.toInt();
      if (ttl != null && ttl >= 60) _ttl = Duration(seconds: ttl);
      _loadedAt = DateTime.now();
      _loadedFor = uid;
      _chosen.removeWhere((_, id) => !_ads.any((a) => a.id == id));
      version.value++;
    } catch (e) {
      // السيرفر لسه مافيهوش الإعلانات أو النت قاطع: مفيش إعلانات، والشاشة زي ما هي
      debugPrint('Ads load failed: $e');
      _loadedAt = DateTime.now().subtract(_ttl - const Duration(minutes: 2));   // نحاول تاني بعد دقيقتين
    }
  }

  static AdPlacementCfg cfg(String placement) => _cfg[placement] ?? const AdPlacementCfg();

  static bool _langOk(AdItem a) =>
      a.lang == 'any' || a.lang == (AppLang.isArabic ? 'ar' : 'en');

  // بعد ما اليوزر يدوس على إعلان ويروح لصفحة جوه التطبيق: مفيش إعلانات خالص لمدة دقيقة،
  // علشان عمره ما يدوس على إعلان يلاقي نفسه قدام إعلان تاني.
  static DateTime? _quietUntil;
  static Timer? _quietTimer;
  static bool get _quiet => _quietUntil != null && DateTime.now().isBefore(_quietUntil!);

  static void _startQuiet() {
    _quietUntil = DateTime.now().add(const Duration(seconds: 60));
    _quietTimer?.cancel();
    _quietTimer = Timer(const Duration(seconds: 61), () {
      _quietUntil = null;
      version.value++;   // الإعلانات ترجع لأماكنها
    });
    version.value++;     // الأماكن المفتوحة دلوقتي تخفي إعلاناتها
  }

  /// كل الإعلانات المناسبة لمكان + سياق (أعلى أولوية الأول)
  static List<AdItem> candidates(String placement, {String? eventId, String? sport}) {
    if (!_cfg.containsKey(placement)) return const [];
    if (_quiet) return const [];
    final list = _ads.where((a) {
      if (a.placement != placement || _dismissed.contains(a.id)) return false;
      if (a.eventIds != null && (eventId == null || !a.eventIds!.contains(eventId))) return false;
      if (a.sports != null && a.sports!.isNotEmpty && (sport == null || !a.sports!.contains(sport))) return false;
      return true;
    }).toList();
    // لو فيه نسخة بلغة اليوزر نستخدمها، وإلا "any"
    final byLang = list.where(_langOk).toList();
    final out = byLang.isNotEmpty ? byLang : list.where((a) => a.lang == 'any').toList();
    out.sort((a, b) => b.priority.compareTo(a.priority));
    return out;
  }

  /// إعلان واحد للمكان ده (أعلى أولوية، وبين المتساويين بالوزن)، وثابت طول الجلسة
  static AdItem? pick(String placement, {String? eventId, String? sport, String slotKey = ''}) {
    final list = candidates(placement, eventId: eventId, sport: sport);
    if (list.isEmpty) return null;
    final key = '$placement|${eventId ?? ''}|${sport ?? ''}|$slotKey';
    final prev = _chosen[key];
    if (prev != null) {
      for (final a in list) {
        if (a.id == prev) return a;
      }
    }
    final top = list.where((a) => a.priority == list.first.priority).toList();
    final total = top.fold<int>(0, (s, a) => s + math.max(1, a.weight));
    var r = _rnd.nextInt(total);
    var chosen = top.first;
    for (final a in top) {
      r -= math.max(1, a.weight);
      if (r < 0) { chosen = a; break; }
    }
    _chosen[key] = chosen.id;
    return chosen;
  }

  /// للفيد: إعلان رقم n في المكان (بيلف على الحملات بالترتيب)
  static AdItem? rotate(String placement, int n) {
    final list = candidates(placement);
    if (list.isEmpty) return null;
    return list[n % list.length];
  }

  // ── تتبّع (مجمّع، بيتبعت كل 30 ثانية أو لما التطبيق يروح الخلفية) ──────────
  static void impression(AdItem a) {
    final k = '${a.id}|${a.placement}';
    if (!_seen.add(k)) return;   // مرة واحدة في الجلسة لكل إعلان في كل مكان
    _enqueue(a, 'i');
  }

  static void _enqueue(AdItem a, String t) {
    final k = '${a.id}|${a.placement}|$t';
    _queue[k] = (_queue[k] ?? 0) + 1;
    _flushTimer ??= Timer(const Duration(seconds: 30), flush);
  }

  static Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_queue.isEmpty) return;
    final batch = _queue.entries.take(100).map((e) {
      final p = e.key.split('|');
      return {'c': p[0], 'p': p[1], 't': p[2], 'n': e.value};
    }).toList();
    final keys = _queue.keys.take(100).toList();
    for (final k in keys) {
      _queue.remove(k);
    }
    try {
      await Supabase.instance.client.rpc('ads_track', params: {'p_events': batch});
    } catch (e) {
      debugPrint('Ads track failed: $e');
    }
    if (_queue.isNotEmpty) _flushTimer ??= Timer(const Duration(seconds: 30), flush);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) flush();
    if (state == AppLifecycleState.resumed) ensure();
  }

  /// الـ Takeover: إعلان واحد مرة في اليوم (التجريبي: مرة في كل فتحة للتطبيق عشان التجربة)
  static Future<AdItem?> takeoverToShow() async {
    await ensure();
    // الأونر (21 نوفمبر): الـ Takeover بيظهر للكل، حتى الحساب الجديد
    final ad = pick('home_takeover');
    if (ad == null || _takeoverShown.contains(ad.id)) return null;
    if (!ad.demo) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('ad_to_day') == _today) return null;
        await prefs.setString('ad_to_day', _today);
      } catch (_) {}
    }
    _takeoverShown.add(ad.id);
    return ad;
  }

  /// "مش عايز أشوفه": الإعلان ده يختفي النهارده
  static Future<void> dismiss(AdItem a) async {
    _dismissed.add(a.id);
    version.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ad_x_${a.id}', _today);
    } catch (_) {}
  }

  /// ضغطة من غير ما نفتح لينك (زي "اعرف أكتر" اللي بيفتح صفحة تفاصيل جوه التطبيق)
  static void click(AdItem a) => _enqueue(a, 'c');

  /// الضغط على الإعلان: نعدّ الضغطة ونفتح اللينك
  static Future<void> open(AdItem a) async {
    if (!a.hasLink) return;
    _enqueue(a, 'c');
    final link = a.link!.trim();
    if (a.linkType == 'deeplink') {
      _startQuiet();
      deepLink.value = null;
      deepLink.value = link;
      return;
    }
    final uri = Uri.tryParse(link.contains('://') ? link : 'https://$link');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Ad link failed: $e');
    }
  }
}

/// بيعدّ النوافذ المفتوحة فوق الشاشة (Dialog / BottomSheet = PopupRoute) في كل الـ Navigators.
/// الـ Takeover بيستنى لحد ما مفيش ولا نافذة، وعدّاده بيقف لو نافذة طلعت فوقه
/// (زي "حدّثنا الشروط" أو طلب الإشعارات) — عشان المعلن ياخد حقه واليوزر يشوف الإعلان فعلاً.
class AdsRouteGuard extends NavigatorObserver {
  static final ValueNotifier<int> popups = ValueNotifier<int>(0);
  static bool get clear => popups.value == 0;

  static void _add(Route<dynamic>? r, int d) {
    if (r is PopupRoute) popups.value = (popups.value + d) < 0 ? 0 : popups.value + d;
  }

  /// بيرجع لما مفيش أي نافذة مفتوحة
  static Future<void> waitClear() {
    if (clear) return Future.value();
    final c = Completer<void>();
    void l() {
      if (clear && !c.isCompleted) {
        popups.removeListener(l);
        c.complete();
      }
    }
    popups.addListener(l);
    return c.future;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route, 1);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route, -1);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route, -1);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _add(oldRoute, -1);
    _add(newRoute, 1);
  }
}
