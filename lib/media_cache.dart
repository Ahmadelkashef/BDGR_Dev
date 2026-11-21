import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart' show ImageRenderMethodForWeb;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

/// كاش الفيديوهات والصور على الموبايل.
/// كل ملف بينزل من Supabase مرة واحدة بس، وبعد كده بيشتغل من الموبايل
/// (علشان الـ egress في الخطة المجانية: 5 GB في الشهر).
class MediaCache {
  MediaCache._();

  static final CacheManager videos = CacheManager(Config(
    'bdgr_videos',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 120,
  ));

  /// كنترولر فيديو: من الموبايل لو متحمّل قبل كده، وإلا ينزله مرة واحدة ويشغله من الملف.
  /// لو التحميل فشل أو اتأخر، يشتغل من النت زي الأول.
  static Future<VideoPlayerController> video(String url,
      {VideoPlayerOptions? options, Map<String, String> headers = const {}}) async {
    if (kIsWeb) return _webVideo(url, options);
    try {
      final hit = await videos.getFileFromCache(url);
      if (hit != null) {
        return VideoPlayerController.file(hit.file, videoPlayerOptions: options);
      }
      final f = await videos
          .getSingleFile(url, headers: headers)
          .timeout(const Duration(seconds: 30));
      return VideoPlayerController.file(f, videoPlayerOptions: options);
    } catch (e) {
      debugPrint('MediaCache video fallback ($url): $e');
      return VideoPlayerController.networkUrl(Uri.parse(url),
          httpHeaders: headers, videoPlayerOptions: options);
    }
  }

  /// صورة من النت بكاش على الموبايل (بديل NetworkImage).
  /// على الويب: المتصفح هو اللي بيكاش، والصور الخاصة بتتجاب بـ HTTP GET مع الهيدر.
  static ImageProvider image(String url, {Map<String, String>? headers, String? cacheKey}) =>
      CachedNetworkImageProvider(url,
          headers: headers,
          cacheKey: cacheKey,
          imageRenderMethodForWeb: (headers != null && headers.isNotEmpty)
              ? ImageRenderMethodForWeb.HttpGet
              : ImageRenderMethodForWeb.HtmlImage);

  // ── الويب ────────────────────────────────────────────────────────────────
  // مشغّل الفيديو في المتصفح مايقدرش يبعت هيدر، فالملفات الخاصة
  // (/object/authenticated/<bucket>/<path>) بتتحوّل للينك موقّع مؤقت.
  static final Map<String, ({String url, DateTime until})> _signed = {};
  static final _authRe = RegExp(r'/storage/v1/object/authenticated/([^/]+)/(.+)$');

  static Future<VideoPlayerController> _webVideo(String url, VideoPlayerOptions? options) async {
    var play = url;
    final m = _authRe.firstMatch(url);
    if (m != null) {
      final hit = _signed[url];
      if (hit != null && hit.until.isAfter(DateTime.now())) {
        play = hit.url;
      } else {
        try {
          final bucket = m.group(1)!;
          final path = Uri.decodeFull(m.group(2)!);
          play = await Supabase.instance.client.storage.from(bucket).createSignedUrl(path, 3600);
          _signed[url] = (url: play, until: DateTime.now().add(const Duration(minutes: 50)));
        } catch (e) {
          debugPrint('MediaCache web sign failed ($url): $e');
        }
      }
    }
    return VideoPlayerController.networkUrl(Uri.parse(play), videoPlayerOptions: options);
  }

  /// "مسح الملفات المؤقتة" في تفضيلات التطبيق.
  static Future<void> clear() async {
    if (kIsWeb) { _signed.clear(); return; }
    await videos.emptyCache();
    await DefaultCacheManager().emptyCache();   // كاش الصور
  }
}
