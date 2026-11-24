// Makes team crest SVGs safe for the Flutter engine (Impeller). See safeSvg().
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

// 24 Nov 2026: the Man United crest crashed the app (native SIGSEGV in Impeller Paint::ConvertStops):
// 17 of its gradients only point to another gradient (xlink:href), flutter_svg turns them into
// gradients with ZERO colours, and the engine crashes drawing them. Tested with vector_graphics_compiler
// 1.3.4 on all 115 crests in Storage: 3 were broken (BAD 17 / 3 / 9), 0 after safeSvg.
/// Makes an SVG safe for the Flutter engine (Impeller):
/// - removes <filter> effects (blur etc.);
/// - gradients that only point to another gradient (xlink:href="#a") get that gradient's <stop>s copied in
///   (flutter_svg turns them into gradients with ZERO colours → native crash in Impeller, 24 Nov);
/// - any gradient still without colours is dropped, and shapes that used it get a plain grey.
String safeSvg(String s) {
  s = s
      .replaceAll(RegExp(r'<filter\b[\s\S]*?</filter>'), '')
      .replaceAll(RegExp(r'<filter\b[^>]*/>'), '')
      .replaceAll(RegExp(r'''\sfilter=("[^"]*"|'[^']*')'''), '')
      .replaceAll(RegExp(r'filter\s*:\s*url\([^)]*\)\s*;?'), '');
  final gradRe = RegExp(r'<(linearGradient|radialGradient)\b([^>]*?)(?:/>|>([\s\S]*?)</\1\s*>)');
  final idRe = RegExp(r'''\bid\s*=\s*["']([^"']+)["']''');
  final hrefRe = RegExp(r'''\b(?:xlink:)?href\s*=\s*["']#([^"']+)["']''');
  final stopsOf = <String, String>{};
  final hrefOf = <String, String>{};
  for (final m in gradRe.allMatches(s)) {
    final id = idRe.firstMatch(m.group(2)!)?.group(1);
    if (id == null) continue;
    final body = m.group(3) ?? '';
    if (body.contains('<stop')) stopsOf[id] = body;
    final h = hrefRe.firstMatch(m.group(2)!)?.group(1);
    if (h != null) hrefOf[id] = h;
  }
  String? resolve(String id) {
    final seen = <String>{};
    String? cur = id;
    while (cur != null && seen.add(cur)) {
      final st = stopsOf[cur];
      if (st != null) return st;
      cur = hrefOf[cur];
    }
    return null;
  }
  final broken = <String>{};
  s = s.replaceAllMapped(gradRe, (m) {
    final tag = m.group(1)!, attrs = m.group(2)!, body = m.group(3) ?? '';
    final id = idRe.firstMatch(attrs)?.group(1);
    if (body.contains('<stop')) return m.group(0)!;
    final st = id == null ? null : resolve(id);
    if (st == null || st.trim().isEmpty) { if (id != null) broken.add(id); return ''; }
    return '<$tag${attrs.replaceAll(hrefRe, '')}>$st</$tag>';
  });
  for (final id in broken) {
    s = s.replaceAll(RegExp('url\\(\\s*["\']?#${RegExp.escape(id)}["\']?\\s*\\)'), '#888888');
  }
  return s;
}

/// Network SVG, cached on the phone, made safe with [safeSvg] before drawing.
class SafeSvgNet extends StatelessWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  final Widget? placeholder;
  const SafeSvgNet(this.url, {super.key, this.width, this.height, this.fit = BoxFit.contain, this.placeholder});

  static final Map<String, Future<String?>> _cache = {};
  static Future<String?> load(String url) => _cache[url] ??= () async {
    try {
      final f = await DefaultCacheManager().getSingleFile(url);
      return safeSvg(await f.readAsString());
    } catch (_) {
      _cache.remove(url);   // try again next time
      return null;
    }
  }();

  @override
  Widget build(BuildContext context) {
    final ph = placeholder ?? SizedBox(width: width, height: height);
    // Web has no Impeller and no file cache: keep the plain network SVG there.
    if (kIsWeb) {
      return SvgPicture.network(url, width: width, height: height, fit: fit, placeholderBuilder: (_) => ph);
    }
    return FutureBuilder<String?>(future: load(url), builder: (_, s) => s.data == null
      ? ph
      : SvgPicture.string(s.data!, width: width, height: height, fit: fit));
  }
}
