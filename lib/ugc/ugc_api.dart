import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';

/// محتوى اليوزرز (بوستات + ستوريز). كل الرفع والقراية بيعدّوا من هنا بس،
/// علشان لما ننقل لـ Cloudflare R2 نغيّر هنا بس (storage_provider في كل ملف).
class UgcMedia {
  UgcMedia({
    required this.idx,
    required this.type,
    required this.provider,
    required this.key,
    this.posterKey,
    this.size = 0,
    this.durationS,
    this.width,
    this.height,
  });

  final int idx;
  final String type; // image | video
  final String provider; // supabase | r2 | external (لينك من برّه، مفيش ملف عندنا)
  final String key;
  final String? posterKey;
  final int size;
  final double? durationS;
  final int? width, height;

  bool get isVideo => type == 'video';

  /// الصورة الصغيرة اللي بتظهر في القوايم (غلاف الفيديو أو الصورة نفسها)
  String get coverKey => isVideo ? (posterKey ?? key) : key;

  String get url => UgcApi.url(key, provider);
  String get coverUrl => UgcApi.url(coverKey, provider);
  /// الهيدرز: توكن Supabase للملفات بتاعتنا بس — عمره ما يتبعت لموقع برّه.
  Map<String, String> get headers => provider == 'external' ? const {} : UgcApi.headers;
  String get cacheKey => 'ugc/$key';
  String get coverCacheKey => 'ugc/$coverKey';

  factory UgcMedia.fromJson(Map<String, dynamic> j) => UgcMedia(
        idx: (j['idx'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? 'image',
        provider: j['provider'] as String? ?? 'supabase',
        key: j['key'] as String,
        posterKey: j['poster_key'] as String?,
        size: (j['size'] as num?)?.toInt() ?? 0,
        durationS: (j['duration_s'] as num?)?.toDouble(),
        width: (j['w'] as num?)?.toInt(),
        height: (j['h'] as num?)?.toInt(),
      );
}

class UgcPerson {
  UgcPerson({required this.userId, this.username, this.name, this.avatar, this.followersOnly = false});
  final int userId;
  final String? username, name, avatar;
  final bool followersOnly;
  String get label => (name?.trim().isNotEmpty ?? false) ? name! : (username ?? '');
  static UgcPerson? from(dynamic j) {
    if (j is! Map || j['user_id'] == null) return null;
    return UgcPerson(
      userId: (j['user_id'] as num).toInt(),
      username: j['username'] as String?,
      name: j['display_name'] as String?,
      avatar: j['avatar'] as String?,
      followersOnly: j['followers_only'] == true,
    );
  }
}

class UgcItem {
  UgcItem({
    required this.id,
    required this.kind,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    required this.media,
    this.caption,
    this.expiresAt,
    this.owner,
    this.hypes = 0,
    this.myHype = false,
    this.reposts = 0,
    this.myRepost = false,
    this.comments = 0,
    this.eventAt,
    this.repostedBy,
    this.iFollow,
    this.mine = false,
  });

  /// في الفيد: أنا متابع صاحب البوست؟ (null = مش معروف)
  bool? iFollow;
  final bool mine;

  final UgcPerson? owner;
  int hypes, reposts, comments;
  bool myHype, myRepost;
  /// وقت ظهوره في الفيد (النشر أو الريبوست)
  final DateTime? eventAt;
  /// لو ظاهر في الفيد بسبب ريبوست: مين عمله
  final UgcPerson? repostedBy;
  DateTime get sortAt => eventAt ?? createdAt;
  /// الريبوست ممنوع لبوستات الحسابات "للمتابعين بس"
  bool get canRepost => !(owner?.followersOnly ?? false);

  final String id;
  final String kind; // post | story
  final int ownerId;
  final String status; // published | hidden (لحد المراجعة)
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? caption;
  final List<UgcMedia> media;

  bool get underReview => status == 'hidden';
  UgcMedia? get first => media.isEmpty ? null : media.first;

  factory UgcItem.fromJson(Map<String, dynamic> j) => UgcItem(
        id: j['id'] as String,
        kind: j['kind'] as String? ?? 'post',
        ownerId: (j['owner_id'] as num).toInt(),
        status: j['status'] as String? ?? 'published',
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        expiresAt: j['expires_at'] == null ? null : DateTime.parse(j['expires_at'] as String).toLocal(),
        caption: (j['caption'] as String?)?.trim().isEmpty == true ? null : j['caption'] as String?,
        media: ((j['media'] as List?) ?? const [])
            .map((e) => UgcMedia.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        owner: UgcPerson.from(j['owner']),
        hypes: (j['hypes'] as num?)?.toInt() ?? 0,
        myHype: j['my_hype'] == true,
        reposts: (j['reposts'] as num?)?.toInt() ?? 0,
        myRepost: j['my_repost'] == true,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        eventAt: j['event_at'] == null ? null : DateTime.parse(j['event_at'] as String).toLocal(),
        repostedBy: UgcPerson.from(j['reposted_by']),
        iFollow: j['i_follow'] as bool?,
        mine: j['mine'] == true,
      );
}

class UgcLimits {
  UgcLimits(this.j);
  final Map<String, dynamic> j;
  int _i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
  String get folder => j['folder'] as String;
  int get quotaBytes => _i('quota_bytes', 104857600);
  int get usedBytes => _i('used_bytes', 0);
  int get postMaxBytes => _i('post_max_bytes', 52428800);
  int get postMaxFiles => _i('post_max_files', 10);
  int get postVideoMaxS => _i('post_video_max_s', 60);
  int get storyVideoMaxS => _i('story_video_max_s', 15);
  bool get banned => j['banned'] == true;
  int get freeBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes).toInt();
}

/// ملف جاهز للرفع (بعد الضغط)
class UgcUploadFile {
  UgcUploadFile({this.file, required this.type, this.poster, this.durationS, this.width, this.height,
      this.bytes, this.posterBytes, this.name});
  final File? file;              // الموبايل
  final String type; // image | video
  final File? poster;
  final double? durationS;
  final int? width, height;
  // الويب: الملف نفسه كـ bytes (مفيش ملفات على الجهاز)
  final Uint8List? bytes;
  final Uint8List? posterBytes;
  final String? name;

  bool get hasPoster => poster != null || posterBytes != null;
  String get path => (name ?? file?.path ?? '').toLowerCase();

  Future<int> size() async =>
      (bytes?.length ?? await file!.length()) +
      (posterBytes?.length ?? (poster != null ? await poster!.length() : 0));
}

class UgcError implements Exception {
  UgcError(this.code);
  final String code;

  /// رسالة واضحة لليوزر بدل كود السيرفر
  String get message {
    switch (code) {
      case 'private_account':
        return AppLang.t("This account is followers-only, so its posts can't be reposted.",
            'الحساب ده للمتابعين بس، فمينفعش تعمل ريبوست لبوستاته.');
      case 'own_post':
        return AppLang.t("You can't repost your own post.", 'مينفعش تعمل ريبوست لبوستك.');
      case 'quota_full':
        return AppLang.t('Your 100 MB space is full. Delete an old post to make room.',
            'مساحتك (100 ميجا) خلصت. امسح بوست قديم علشان تفضّي مكان.');
      case 'post_too_big':
        return AppLang.t('The post is bigger than 50 MB.', 'البوست أكبر من 50 ميجا.');
      case 'video_too_long':
        return AppLang.t('The video is too long.', 'الفيديو أطول من المسموح.');
      case 'one_video_max':
        return AppLang.t('Only one video per post.', 'فيديو واحد بس في البوست.');
      case 'ugc_banned':
        return AppLang.t('Posting is turned off for your account. Contact support.',
            'الرفع متوقف لحسابك. كلّم الدعم.');
      case 'too_many_reports':
        return AppLang.t('Too many reports today. Try again tomorrow.', 'بلاغات كتير النهارده. جرّب بكرة.');
      case 'own_content':
        return AppLang.t("You can't report your own post.", 'مينفعش تبلّغ عن بوستك.');
      default:
        return AppLang.t('Something went wrong. Try again.', 'حصلت مشكلة. جرّب تاني.');
    }
  }

  static UgcError from(Object e) {
    final s = e.toString();
    for (final c in const ['private_account', 'own_post', 'quota_full', 'post_too_big', 'video_too_long', 'one_video_max', 'ugc_banned',
      'too_many_reports', 'own_content', 'file_missing', 'type_mismatch']) {
      if (s.contains(c)) return UgcError(c);
    }
    return UgcError('unknown');
  }
}

class UgcApi {
  static SupabaseClient get _sb => Supabase.instance.client;
  static const bucket = 'ugc';

  /// لينك الملف حسب مكان تخزينه. R2 لسه مش متفعّل (بعدين: لينك موقّع من Edge Function).
  static String url(String key, String provider) {
    if (provider == 'external') return key;   // الملف برّه (مثلاً Wikimedia): صفر مساحة وصفر egress عندنا
    final encoded = key.split('/').map(Uri.encodeComponent).join('/');
    return '${AppConfig.supabaseUrl}/storage/v1/object/authenticated/$bucket/$encoded';
  }

  static Map<String, String> get headers => {
        'Authorization': 'Bearer ${_sb.auth.currentSession?.accessToken ?? ''}',
        'apikey': AppConfig.supabaseKey,
      };

  static Future<UgcLimits> limits() async =>
      UgcLimits(Map<String, dynamic>.from(await _sb.rpc('ugc_limits') as Map));

  static Future<List<UgcItem>> userPosts(int ownerId, {DateTime? before, int limit = 18}) async {
    final r = await _sb.rpc('ugc_user_posts', params: {
      'p_owner': ownerId,
      'p_before': before?.toUtc().toIso8601String(),
      'p_limit': limit,
    });
    return ((r as List?) ?? const [])
        .map((e) => UgcItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<UgcItem> _list(dynamic r) => ((r as List?) ?? const [])
      .map((e) => UgcItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  /// بوستات الناس اللي متابعهم + بوستاتي + ريبوستاتهم (للفيد)
  static Future<List<UgcItem>> feed({DateTime? before, int limit = 10}) async => _list(await _sb.rpc('ugc_feed',
      params: {'p_before': before?.toUtc().toIso8601String(), 'p_limit': limit}));

  static Future<List<UgcItem>> userReposts(int ownerId, {DateTime? before, int limit = 18}) async =>
      _list(await _sb.rpc('ugc_user_reposts', params: {
        'p_owner': ownerId, 'p_before': before?.toUtc().toIso8601String(), 'p_limit': limit}));

  /// بيقلب الحالة فورًا (optimistic) ويرجّعها لو السيرفر رفض
  static Future<void> toggleHype(UgcItem it) async {
    final was = it.myHype;
    it.myHype = !was; it.hypes += was ? -1 : 1;
    try {
      await _sb.rpc('ugc_hype', params: {'p_item': it.id, 'p_on': !was});
    } catch (e) {
      it.myHype = was; it.hypes += was ? 1 : -1;
      rethrow;
    }
  }

  static Future<void> toggleRepost(UgcItem it) async {
    final was = it.myRepost;
    it.myRepost = !was; it.reposts += was ? -1 : 1;
    try {
      await _sb.rpc('ugc_repost', params: {'p_item': it.id, 'p_on': !was});
    } catch (e) {
      it.myRepost = was; it.reposts += was ? 1 : -1;
      throw UgcError.from(e);
    }
  }

  /// بوست واحد بالـ id (لينكات الشير)
  static Future<UgcItem?> get(String id) async {
    final r = await _sb.rpc('ugc_item_get', params: {'p_id': id});
    if (r is! Map) return null;
    return UgcItem.fromJson(Map<String, dynamic>.from(r));
  }

  static String shareText(UgcItem it) {
    final who = it.owner?.label ?? 'BDGR';
    final cap = (it.caption ?? '').trim();
    return '${cap.isNotEmpty ? '$cap\n\n' : ''}${AppLang.t('A post by $who on BDGR', 'بوست من $who على BDGR')} 🦡\n${Brand.ugcShareLink(it.id)}';
  }

  /// متابعة صاحب البوست من الفيد مباشرة
  static Future<void> follow(int userId) async =>
      _sb.rpc('follow_user', params: {'p_target_user_id': userId});

  static String _uuid() {
    // UUID v4 من غير مكتبة زيادة
    final r = List<int>.generate(16, (_) => _rnd.nextInt(256));
    r[6] = (r[6] & 0x0f) | 0x40;
    r[8] = (r[8] & 0x3f) | 0x80;
    final h = r.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static final _rnd = Random.secure();

  static String _ext(UgcUploadFile f, String type) {
    final n = f.path;
    if (type == 'video') return n.endsWith('.mov') ? 'mov' : 'mp4';
    if (n.endsWith('.png')) return 'png';
    if (n.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static String _mime(String ext) => switch (ext) {
        'mp4' => 'video/mp4',
        'mov' => 'video/quicktime',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  /// يرفع الملفات وبعدين ينشر. لو حاجة فشلت بيمسح اللي اترفع (مايسيبش ملفات يتيمة).
  static Future<UgcItem> publish({
    required String kind,
    required List<UgcUploadFile> files,
    String? caption,
    void Function(int done, int total)? onProgress,
  }) async {
    final lim = await limits();
    if (lim.banned) throw UgcError('ugc_banned');
    final id = _uuid();
    final prefix = '${lim.folder}/$id';
    final uploaded = <String>[];
    final media = <Map<String, dynamic>>[];
    final total = files.fold<int>(0, (n, f) => n + 1 + (f.hasPoster ? 1 : 0));
    var done = 0;
    final store = _sb.storage.from(bucket);
    try {
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final ext = _ext(f, f.type);
        final key = '$prefix/$i.$ext';
        if (f.bytes != null) {
          await store.uploadBinary(key, f.bytes!, fileOptions: FileOptions(contentType: _mime(ext), upsert: false));
        } else {
          await store.upload(key, f.file!, fileOptions: FileOptions(contentType: _mime(ext), upsert: false));
        }
        uploaded.add(key);
        onProgress?.call(++done, total);
        String? posterKey;
        if (f.hasPoster) {
          posterKey = '$prefix/${i}_poster.jpg';
          if (f.posterBytes != null) {
            await store.uploadBinary(posterKey, f.posterBytes!, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
          } else {
            await store.upload(posterKey, f.poster!, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
          }
          uploaded.add(posterKey);
          onProgress?.call(++done, total);
        }
        media.add({
          'type': f.type,
          'key': key,
          if (posterKey != null) 'poster_key': posterKey,
          if (f.durationS != null) 'duration_s': double.parse(f.durationS!.toStringAsFixed(1)),
          if (f.width != null) 'w': f.width,
          if (f.height != null) 'h': f.height,
        });
      }
      final r = await _sb.rpc('ugc_item_create', params: {
        'p': {'id': id, 'kind': kind, 'caption': caption, 'media': media},
      });
      final m = Map<String, dynamic>.from(r as Map);
      final old = ((m['remove_keys'] as List?) ?? const []).cast<String>();
      if (old.isNotEmpty) store.remove(old).catchError((_) => <FileObject>[]);
      return UgcItem.fromJson(m);
    } catch (e) {
      debugPrint('ugc publish error: $e');
      if (uploaded.isNotEmpty) {
        try { await store.remove(uploaded); } catch (_) {}
      }
      throw e is UgcError ? e : UgcError.from(e);
    }
  }

  static Future<void> delete(UgcItem item) async {
    final r = await _sb.rpc('ugc_item_delete', params: {'p_id': item.id});
    final keys = (((r as Map?)?['remove_keys'] as List?) ?? const []).cast<String>();
    if (keys.isNotEmpty) {
      try { await _sb.storage.from(bucket).remove(keys); } catch (e) { debugPrint('ugc remove files: $e'); }
    }
  }

  static Future<void> report(UgcItem item, String reason) async {
    try {
      await _sb.rpc('report_content', params: {
        'p_content_id': item.id,
        'p_content_type': item.kind == 'story' ? 'ugc_story' : 'ugc_post',
        'p_reason': reason,
      });
    } catch (e) {
      throw UgcError.from(e);
    }
  }

  static String mb(int bytes) {
    final v = bytes / (1024 * 1024);
    return v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }
}
