import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';

/// بوست في الفيد (بتاع حساب BDGR الرسمي بس): فيديو أو صورة.
class FeedPost {
  FeedPost({
    required this.id,
    required this.kind,
    required this.storagePath,
    required this.posterPath,
    required this.durationS,
    required this.title,
    required this.description,
    required this.isPinned,
    required this.createdAt,
    required this.hypes,
    required this.views,
    required this.myHype,
    this.comments = 0,
    this.source = 'upload',
    this.externalId,
    this.externalUrl,
  });

  final String id;
  final String kind; // video | image
  final String storagePath;
  final String? posterPath;
  final int? durationS;
  final String title;
  final String description;
  final bool isPinned;
  final DateTime createdAt;
  int hypes;
  int views;
  bool myHype;
  int comments;
  /// upload (ملف عندنا) | youtube | tiktok (بيتشغّل من سيرفراتهم، صفر egress علينا)
  final String source;
  final String? externalId;
  final String? externalUrl;

  bool get isVideo => kind == 'video';
  bool get isExternal => source != 'upload' && (externalId ?? '').isNotEmpty;
  /// فيديو بيتشغّل في الريلز بتاعتنا (مرفوع عندنا)
  bool get isOwnVideo => isVideo && !isExternal;

  /// الصورة اللي بتظهر في الكارت: الغلاف للفيديو، أو الصورة نفسها
  String? get coverPath => isVideo ? posterPath : storagePath;

  factory FeedPost.fromJson(Map<String, dynamic> j) => FeedPost(
        id: '${j['id']}',
        kind: '${j['kind'] ?? 'video'}',
        storagePath: '${j['storage_path'] ?? ''}',
        posterPath: (j['poster_path'] as String?)?.isNotEmpty == true ? j['poster_path'] as String : null,
        durationS: (j['duration_s'] as num?)?.toInt(),
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        isPinned: j['is_pinned'] == true,
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
        hypes: (j['hypes'] as num?)?.toInt() ?? 0,
        views: (j['views'] as num?)?.toInt() ?? 0,
        myHype: j['my_hype'] == true,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        source: '${j['source'] ?? 'upload'}',
        externalId: (j['external_id'] as String?)?.isNotEmpty == true ? j['external_id'] as String : null,
        externalUrl: (j['external_url'] as String?)?.isNotEmpty == true ? j['external_url'] as String : null,
      );
}

/// ستوري من حساب BDGR (صورة أو فيديو قصير)
class FeedStory {
  FeedStory({required this.id, required this.kind, required this.storagePath, required this.caption, required this.createdAt});
  final String id, kind, storagePath, caption;
  final DateTime createdAt;
  bool get isVideo => kind == 'video';

  factory FeedStory.fromJson(Map<String, dynamic> j) => FeedStory(
        id: '${j['id']}',
        kind: '${j['kind'] ?? 'image'}',
        storagePath: '${j['storage_path'] ?? ''}',
        caption: '${j['caption'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

class FeedApi {
  FeedApi._();

  static SupabaseClient get _sb => Supabase.instance.client;

  /// الباكت Reels مقفول: الملفات بتتحمّل بالتوكن (والكاش بيتعرف بالمسار).
  static String mediaUrl(String path) {
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return '${AppConfig.supabaseUrl}/storage/v1/object/authenticated/Reels/$encoded';
  }

  static Map<String, String> get headers => {
        'Authorization': 'Bearer ${_sb.auth.currentSession?.accessToken ?? ''}',
        'apikey': AppConfig.supabaseKey,
      };

  static List<FeedPost> _list(dynamic r) =>
      ((r as List?) ?? const []).map((e) => FeedPost.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  /// 10 بوستات في المرة (المثبّت أول الصفحة الأولى بس)
  static Future<List<FeedPost>> page({DateTime? before, int limit = 10}) async {
    final r = await _sb.rpc('feed_page', params: {
      'p_before': before?.toUtc().toIso8601String(),
      'p_limit': limit,
    });
    return _list(r);
  }

  static Future<FeedPost?> post(String id) async {
    final r = await _sb.rpc('feed_post', params: {'p_id': id});
    return r is Map ? FeedPost.fromJson(Map<String, dynamic>.from(r)) : null;
  }

  /// Hype: بيرجّع العدد الجديد
  static Future<void> hype(FeedPost p, bool on) async {
    final r = await _sb.rpc('feed_hype', params: {'p_post': p.id, 'p_on': on});
    if (r is Map) {
      p.hypes = (r['hypes'] as num?)?.toInt() ?? p.hypes;
      p.myHype = r['my_hype'] == true;
    }
  }

  static final Set<String> _viewed = {};

  /// مشاهدة واحدة لكل يوزر (السيرفر بيتجاهل التكرار، وإحنا كمان مش بنبعت تاني في نفس الفتحة)
  static Future<void> view(FeedPost p) async {
    if (!_viewed.add(p.id)) return;
    try {
      await _sb.rpc('feed_view', params: {'p_post': p.id});
    } catch (e) {
      debugPrint('feed_view error: $e');
    }
  }

  static Future<List<FeedStory>> stories() async {
    final r = await _sb.rpc('feed_stories_list');
    return ((r as List?) ?? const []).map((e) => FeedStory.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static String shareText(FeedPost p) {
    final link = Brand.postShareLink(p.id);
    return p.title.isNotEmpty ? '${p.title}\n$link' : link;
  }

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return AppLang.t('now', 'دلوقتي');
    if (d.inMinutes < 60) return AppLang.t('${d.inMinutes}m', 'من ${d.inMinutes} د');
    if (d.inHours < 24) return AppLang.t('${d.inHours}h', 'من ${d.inHours} س');
    if (d.inDays == 1) return AppLang.t('yesterday', 'امبارح');
    if (d.inDays < 7) return AppLang.t('${d.inDays}d', 'من ${d.inDays} أيام');
    return '${t.day}/${t.month}/${t.year}';
  }

  static String count(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
