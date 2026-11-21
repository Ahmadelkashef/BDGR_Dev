import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../app_config.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../web/iframe_view.dart';
import 'feed_api.dart';
import 'feed_page.dart' show HypeButton;

/// بوستات لينك من يوتيوب / تيك توك: الفيديو بيتشغّل بمشغّل المنصة الرسمي (iframe)
/// من سيرفراتهم، فمفيش ولا بايت egress على Supabase.

String externalLabel(FeedPost p) => p.source == 'youtube' ? 'YouTube' : 'TikTok';

String externalOpenUrl(FeedPost p) {
  if ((p.externalUrl ?? '').isNotEmpty) return p.externalUrl!;
  return p.source == 'youtube'
      ? 'https://www.youtube.com/shorts/${p.externalId}'
      : 'https://www.tiktok.com/@bdgr/video/${p.externalId}';
}

/// صورة الغلاف: يوتيوب ثابتة؛ تيك توك من oEmbed بتاعهم (مرة واحدة وبتتحفظ على الموبايل).
class ExternalThumb extends StatefulWidget {
  const ExternalThumb({super.key, required this.post});
  final FeedPost post;
  @override
  State<ExternalThumb> createState() => _ExternalThumbState();
}

class _ExternalThumbState extends State<ExternalThumb> {
  static final Map<String, Future<File?>> _jobs = {};
  static final Map<String, Future<String?>> _webUrls = {};
  Future<File?>? _file;
  Future<String?>? _webUrl;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    final key = '${p.source}/${p.externalId}';
    if (kIsWeb) {
      _webUrl = _webUrls.putIfAbsent(key, () => _thumbUrl(p));
    } else {
      _file = _jobs.putIfAbsent(key, () => _resolve(p, key));
    }
  }

  /// الويب: لينك الصورة بس، والمتصفح بيكاشها.
  static Future<String?> _thumbUrl(FeedPost p) async {
    if (p.source == 'youtube') return 'https://i.ytimg.com/vi/${p.externalId}/hqdefault.jpg';
    try {
      final r = await http.get(Uri.parse(
          'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(externalOpenUrl(p))}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return (jsonDecode(r.body) as Map)['thumbnail_url']?.toString();
    } catch (e) {
      debugPrint('external thumb (web) error: $e');
    }
    return null;
  }

  static Future<File?> _resolve(FeedPost p, String key) async {
    final cache = DefaultCacheManager();
    try {
      final hit = await cache.getFileFromCache(key);
      if (hit != null) return hit.file;
      String? url;
      if (p.source == 'youtube') {
        url = 'https://i.ytimg.com/vi/${p.externalId}/hqdefault.jpg';
      } else {
        final r = await http.get(Uri.parse(
            'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(externalOpenUrl(p))}'))
            .timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) url = (jsonDecode(r.body) as Map)['thumbnail_url']?.toString();
      }
      if (url == null || url.isEmpty) return null;
      return await cache.getSingleFile(url, key: key);
    } catch (e) {
      debugPrint('external thumb error: $e');
      _jobs.remove(key);   // نجرّب تاني المرة الجاية
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<String?>(
        future: _webUrl,
        builder: (_, snap) {
          final u = snap.data;
          if (u == null || u.isEmpty) return const ColoredBox(color: Color(0xFF1E2027));
          return Image.network(u, fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1E2027)));
        },
      );
    }
    return _native();
  }

  Widget _native() => FutureBuilder<File?>(
        future: _file,
        builder: (_, snap) {
          final f = snap.data;
          if (f == null) return const ColoredBox(color: Color(0xFF1E2027));
          return Image.file(f, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1E2027)));
        },
      );
}

/// علامة صغيرة على الكارت: "▶ YouTube" / "▶ TikTok"
class ExternalBadge extends StatelessWidget {
  const ExternalBadge({super.key, required this.post});
  final FeedPost post;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 2),
          Text(externalLabel(post), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

Future<void> openExternalPlayer(BuildContext context, FeedPost p) {
  return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    builder: (_) => _ExternalPlayerPage(post: p),
  ));
}

class _ExternalPlayerPage extends StatefulWidget {
  const _ExternalPlayerPage({required this.post});
  final FeedPost post;
  @override
  State<_ExternalPlayerPage> createState() => _ExternalPlayerPageState();
}

class _ExternalPlayerPageState extends State<_ExternalPlayerPage> {
  WebViewController? _c;
  bool _loading = true;

  FeedPost get _p => widget.post;

  Uri get _embed => _p.source == 'youtube'
      ? Uri.parse('https://www.youtube.com/embed/${_p.externalId}?autoplay=1&playsinline=1&rel=0&modestbranding=1')
      : Uri.parse('https://www.tiktok.com/player/v1/${_p.externalId}?autoplay=1&loop=1&rel=0&description=0&music_info=0');

  bool _allowed(String url) =>
      url.startsWith('https://www.youtube.com/embed/') || url.startsWith('https://www.tiktok.com/player/') || url == 'about:blank';

  @override
  void initState() {
    super.initState();
    FeedApi.view(_p);
    if (kIsWeb) { _loading = false; return; }   // الويب: iframe رسمي، مفيش WebView
    // الآيفون: الفيديو يشتغل جوه الصفحة (مش شاشة كاملة) ومن غير ما يستنى دوسة
    final c = (!kIsWeb && Platform.isIOS)
        ? WebViewController.fromPlatformCreationParams(WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          ))
        : WebViewController();
    _c = c;
    c
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) { if (mounted) setState(() => _loading = false); },
        onNavigationRequest: (r) {
          // جوه المشغّل بس؛ أي لينك تاني (اللوجو، "شوف على يوتيوب") بيفتح في التطبيق بتاعه
          if (!r.isMainFrame || _allowed(r.url)) return NavigationDecision.navigate;
          launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ));
    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    // يوتيوب بيطلب إن التطبيق يعرّف نفسه (Referer) وإلا بيطلع خطأ 153
    c.loadRequest(_embed, headers: {'Referer': 'https://${AppConfig.appId}'});
  }

  Future<void> _hype() async {
    HapticFeedback.lightImpact();
    final was = _p.myHype;
    setState(() { _p.myHype = !was; _p.hypes += was ? -1 : 1; });
    try {
      await FeedApi.hype(_p, !was);
    } catch (_) {
      _p.myHype = was; _p.hypes += was ? 1 : -1;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppLang.isArabic;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(externalOpenUrl(_p)), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white70),
                label: Text(AppLang.t('Open in ${externalLabel(_p)}', 'افتح في ${externalLabel(_p)}'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ),
              const SizedBox(width: 6),
            ]),
            // مشغّل المنصة (من غير أي حاجة فوقه، دي شروطهم)
            Expanded(child: Stack(children: [
              if (kIsWeb)
                Positioned.fill(child: WebIframe(url: _embed.toString()))
              else
                WebViewWidget(controller: _c!),
              if (_loading)
                const Center(child: SizedBox(width: 28, height: 28,
                    child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))),
            ])),
            // البوست بتاعنا تحت المشغّل
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (_p.title.isNotEmpty)
                    Text(_p.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
                  if (_p.description.isNotEmpty)
                    Text(_p.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFA6AAB5), fontSize: 12.5, height: 1.45)),
                ])),
                HypeButton(active: _p.myHype, count: _p.hypes, onTap: _hype),
                IconButton(
                  onPressed: () => Share.share(FeedApi.shareText(_p)),
                  icon: const Icon(Icons.send_outlined, color: Color(0xFFC5C9D2), size: 21),
                ),
              ]),
            ),
          ])),
        ),
      ),
    );
  }
}
