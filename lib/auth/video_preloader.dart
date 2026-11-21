import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// بيحمّل صورة اللوجن والفيديوهات في الخلفية، واحد ورا التاني بالترتيب،
/// وبيحفظهم على الموبايل. من تاني مرة بيرجّعهم من الموبايل على طول من غير نت.
class VideoPreloader {
  VideoPreloader._();

  static final CacheManager _cache = CacheManager(
    Config(
      'login_media',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 20,
    ),
  );

  /// "مسح الملفات المؤقتة" في تفضيلات التطبيق. الفيديوهات بتتحمّل تاني لوحدها لما تتطلب.
  static Future<void> clearCache() async {
    if (kIsWeb) return;
    await _cache.emptyCache();
    _jobs.clear();
    _started = false;
    readyVideos.value = 0;
  }

  static final Map<String, Completer<File?>> _jobs =
      <String, Completer<File?>>{};

  /// عدد الفيديوهات اللي خلصت (للعرض في وضع التجربة)
  static final ValueNotifier<int> readyVideos = ValueNotifier<int>(0);
  static int totalVideos = 0;

  static bool _started = false;

  /// بتتنادى مرة واحدة بس. أي نداء بعدها بيتجاهل.
  static void start({required String poster, required List<String> videos}) {
    // الويب: مفيش ملفات على الجهاز، المتصفح بيكاش لوحده والفيديو بيشتغل من النت
    if (kIsWeb) return;
    if (_started) {
      return;
    }

    _started = true;
    totalVideos = videos.length;

    // الصورة الأول (صغيرة)، وبعدين الفيديوهات بالترتيب
    final urls = <String>[poster, ...videos];

    for (final url in urls) {
      _jobs.putIfAbsent(url, () => Completer<File?>());
    }

    unawaited(_run(urls, videos.toSet()));
  }

  static Future<void> _run(List<String> urls, Set<String> videos) async {
    for (final url in urls) {
      File? file;

      try {
        file = await _cache.getSingleFile(url);
      } catch (e) {
        debugPrint('Preload failed for $url: $e');
      }

      final job = _jobs[url];
      if (job != null && !job.isCompleted) {
        job.complete(file);
      }

      if (file != null && videos.contains(url)) {
        readyVideos.value = readyVideos.value + 1;
      }
    }
  }

  /// يبدأ تحميل URL واحد في الخلفية بدون انتظار (مثلًا فيديو الويلكم).
  /// لو اتحمّل قبل كده، يتجاهل.
  static void prefetch(String url) {
    if (kIsWeb) return;
    if (_jobs.containsKey(url)) return;
    _jobs[url] = Completer<File?>();
    unawaited(_downloadOne(url, isVideo: false));
  }

  static Future<void> _downloadOne(String url, {required bool isVideo}) async {
    File? file;
    try {
      file = await _cache.getSingleFile(url);
    } catch (e) {
      debugPrint('Prefetch failed for $url: $e');
    }
    final job = _jobs[url];
    if (job != null && !job.isCompleted) job.complete(file);
    if (file != null && isVideo) readyVideos.value = readyVideos.value + 1;
  }

  /// بيرجّع الملف من الموبايل لما يخلص تحميل.
  /// لو التحميل ما بدأش أصلًا أو فشل بيرجّع null، والفيديو يشتغل من النت.
  static Future<File?> waitFor(String url) {
    return _jobs[url]?.future ?? Future<File?>.value(null);
  }
}
