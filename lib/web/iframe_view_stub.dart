import 'package:flutter/widgets.dart';

class WebIframe extends StatelessWidget {
  const WebIframe({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void webOpenUrl(String url) {}
void webSetTitle(String title) {}

/// معلومات فيديو اتختار من المتصفح (المدة + المقاس + صورة غلاف JPEG).
Future<({double secs, int w, int h, List<int>? poster})?> webVideoInfo(String url) async => null;
