import 'package:flutter/material.dart';

import '../app_lang.dart';
import '../media_cache.dart';
import '../official_account.dart';
import 'external_media.dart';
import 'feed_api.dart';
import 'feed_viewer.dart';

/// بوستات BDGR في صفحته: شبكة غلافات صغيرة (متكاشة)، والدوسة بتفتح البوست.
class OfficialPostsGrid extends StatefulWidget {
  const OfficialPostsGrid({super.key});
  @override
  State<OfficialPostsGrid> createState() => _OfficialPostsGridState();
}

class _OfficialPostsGridState extends State<OfficialPostsGrid> {
  List<FeedPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await FeedApi.page(limit: 18);
      if (mounted) setState(() { _posts = p; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(FeedPost p) async {
    await openFeedViewer(context, _posts, _posts.indexOf(p));
    if (mounted) setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(30),
          child: Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))));
    }
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
        child: Center(child: Text(AppLang.t('BDGR posts show up here', 'بوستات BDGR هتظهر هنا'),
            style: const TextStyle(color: Colors.white38, fontSize: 13))),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(AppLang.t('Posts', 'البوستات'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 3 / 4),
          itemBuilder: (_, i) {
            final p = _posts[i];
            final cover = p.coverPath;
            return GestureDetector(
              onTap: () => _open(p),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(fit: StackFit.expand, children: [
                  if (p.isExternal)
                    ExternalThumb(post: p)
                  else if (cover != null)
                    Image(
                      image: MediaCache.image(FeedApi.mediaUrl(cover), headers: FeedApi.headers, cacheKey: 'reels/$cover'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1E2027)),
                    )
                  else
                    const ColoredBox(color: Color(0xFF1E2027), child: Center(child: OfficialMark(size: 34))),
                  if (p.isVideo)
                    const PositionedDirectional(top: 6, end: 6,
                        child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 18)),
                  if (p.isPinned)
                    const PositionedDirectional(top: 6, start: 6,
                        child: Icon(Icons.push_pin_rounded, color: Colors.white, size: 15)),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}
