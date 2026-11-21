import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final Set<String> _registered = {};

class WebIframe extends StatelessWidget {
  const WebIframe({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final type = 'bdgr-iframe-${url.hashCode}';
    if (_registered.add(type)) {
      ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
        final f = web.HTMLIFrameElement()
          ..src = url
          ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'
          ..allowFullscreen = true
          ..referrerPolicy = 'strict-origin-when-cross-origin';
        f.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'black';
        return f;
      });
    }
    return HtmlElementView(viewType: type);
  }
}

void webOpenUrl(String url) => web.window.open(url, '_blank');
void webSetTitle(String title) => web.document.title = title;

/// معلومات فيديو اتختار من المتصفح (blob URL): المدة + المقاس + غلاف JPEG من ثانية 1.
Future<({double secs, int w, int h, List<int>? poster})?> webVideoInfo(String url) async {
  final v = web.HTMLVideoElement()
    ..muted = true
    ..preload = 'auto'
    ..crossOrigin = 'anonymous'
    ..src = url;
  try {
    await v.onLoadedMetadata.first.timeout(const Duration(seconds: 20));
    final secs = v.duration.isFinite ? v.duration.toDouble() : 0.0;
    final w = v.videoWidth, h = v.videoHeight;
    List<int>? poster;
    try {
      v.currentTime = secs > 1.2 ? 1.0 : secs / 2;
      await v.onSeeked.first.timeout(const Duration(seconds: 10));
      final scale = w > 720 ? 720 / w : 1.0;
      final cw = (w * scale).round(), ch = (h * scale).round();
      final c = web.HTMLCanvasElement()..width = cw..height = ch;
      (c.getContext('2d') as web.CanvasRenderingContext2D).drawImage(v, 0, 0, cw, ch);
      final data = c.toDataURL('image/jpeg', 0.75.toJS);
      poster = base64Decode(data.substring(data.indexOf(',') + 1));
    } catch (_) {}
    return (secs: secs, w: w, h: h, poster: poster);
  } catch (_) {
    return null;
  } finally {
    v.src = '';
  }
}
