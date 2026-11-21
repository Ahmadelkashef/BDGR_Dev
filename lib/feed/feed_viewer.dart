import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../ads/ad_widgets.dart';
import '../app_lang.dart';
import '../brand.dart';
import '../media_cache.dart';
import '../official_account.dart';
import 'external_media.dart';
import '../social/comments_sheet.dart';
import 'feed_api.dart';
import 'feed_page.dart' show HypeButton, HypeMark;
import '../web/web_layout.dart' show WebStage;

/// الفيد full-screen: صور وفيديوهات ولينكات يوتيوب/تيك توك في نفس السكرول، سحبة لفوق للي بعده.
/// كل فيديو بينزل مرة واحدة ويتكاش؛ بنجهّز الفيديو اللي بعده بس (مش أكتر) علشان الـ egress.
/// الـ Hype هنا وبره هو نفس الأوبجكت، فاللي يدوسه جوه بيبان بره على طول.
Future<void> openFeedViewer(BuildContext context, List<FeedPost> posts, int start) {
  if (posts.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => WebStage(child: _FeedViewer(videos: posts, start: start.clamp(0, posts.length - 1).toInt())),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _FeedViewer extends StatefulWidget {
  const _FeedViewer({required this.videos, required this.start});
  final List<FeedPost> videos;   // كل البوستات (مش فيديوهات بس)
  final int start;
  @override
  State<_FeedViewer> createState() => _FeedViewerState();
}

class _FeedViewerState extends State<_FeedViewer> {
  late final PageController _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;
  final Map<int, VideoPlayerController> _ctrls = {};
  final Set<int> _loading = {};
  bool _paused = false;
  bool _showBurst = false;
  Timer? _burstTimer;

  bool get _ar => AppLang.isArabic;

  @override
  void initState() {
    super.initState();
    _prepare(_i, play: true);
    _prepare(_i + 1);
    _countView(_i);
    // لو فتح لينك يوتيوب/تيك توك من الفيد: نشغّله على طول، ولما يقفل يكمّل يقلّب عادي
    if (widget.videos[_i].isExternal) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _openExternal(widget.videos[_i]); });
    }
  }

  // الفيديو بيتحسب لما يشتغل؛ الصورة لما تتشاف؛ يوتيوب/تيك توك لما يتفتح المشغّل
  void _countView(int i) {
    final p = widget.videos[i];
    if (!p.isVideo) FeedApi.view(p);
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _burstTimer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _prepare(int i, {bool play = false}) async {
    if (i < 0 || i >= widget.videos.length || _ctrls.containsKey(i) || !_loading.add(i)) return;
    final p = widget.videos[i];
    if (!p.isOwnVideo) { _loading.remove(i); return; }
    final c = await MediaCache.video(FeedApi.mediaUrl(p.storagePath), headers: FeedApi.headers);
    _loading.remove(i);
    if (!mounted || (i - _i).abs() > 1) { c.dispose(); return; }
    try {
      await c.initialize();
      await c.setLooping(true);
    } catch (e) {
      debugPrint('feed video init error: $e');
    }
    if (!mounted) { c.dispose(); return; }
    _ctrls[i] = c;
    if (i == _i) {
      FeedApi.view(p);
      if (!_paused) c.play();
    }
    setState(() {});
  }

  void _onPage(int i) {
    _ctrls[_i]?.pause();
    setState(() { _i = i; _paused = false; });
    // اللي بعيد بنقفله علشان الذاكرة
    for (final k in _ctrls.keys.where((k) => (k - i).abs() > 1).toList()) {
      _ctrls.remove(k)?.dispose();
    }
    final c = _ctrls[i];
    if (c != null) {
      c.seekTo(Duration.zero);
      c.play();
      FeedApi.view(widget.videos[i]);
    } else {
      _prepare(i, play: true);
    }
    _prepare(i + 1);
    _countView(i);
    _maybeShowAd();
  }

  // إعلان شاشة كاملة كل كام سوايب (الأرقام من السيرفر: first_after / every_n). بيتقفل في أي وقت.
  int _swipes = 0, _adsShown = 0;
  bool _adOpen = false;
  Future<void> _maybeShowAd() async {
    _swipes++;
    final cfg = Ads.cfg('feed_viewer');
    final first = (cfg.firstAfter ?? 5).clamp(1, 1000).toInt();
    final every = (cfg.everyN ?? 8).clamp(2, 1000).toInt();
    if (_adOpen || !(_swipes == first || (_swipes > first && (_swipes - first) % every == 0))) return;
    if (cfg.maxPerSession != null && _adsShown >= cfg.maxPerSession!) return;
    final ad = Ads.rotate('feed_viewer', _adsShown);
    if (ad == null) return;
    _adOpen = true;
    _adsShown++;
    _ctrls[_i]?.pause();
    await Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (ctx, __, ___) => GestureDetector(
        // سحبة لفوق أو لتحت = تخطي
        onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0).abs() > 200) Navigator.of(ctx).maybePop(); },
        child: AdFullscreen(ad: ad, showSwipeHint: true, onClose: () => Navigator.of(ctx).maybePop()),
      ),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child),
    ));
    _adOpen = false;
    if (mounted && !_paused) _ctrls[_i]?.play();
  }

  void _togglePause() {
    final c = _ctrls[_i];
    if (c == null) return;
    setState(() => _paused = !_paused);
    _paused ? c.pause() : c.play();
  }

  Future<void> _hype(FeedPost p, {bool burst = false}) async {
    HapticFeedback.lightImpact();
    if (burst) {
      _burstTimer?.cancel();
      setState(() => _showBurst = true);
      _burstTimer = Timer(const Duration(milliseconds: 700), () { if (mounted) setState(() => _showBurst = false); });
      if (p.myHype) return;   // الدبل تاب بيعمل Hype بس، مش بيشيله
    }
    final was = p.myHype;
    setState(() { p.myHype = !was; p.hypes += was ? -1 : 1; });
    try {
      await FeedApi.hype(p, !was);
    } catch (_) {
      p.myHype = was; p.hypes += was ? 1 : -1;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            PageView.builder(
              controller: _pc,
              scrollDirection: Axis.vertical,
              itemCount: widget.videos.length,
              onPageChanged: _onPage,
              itemBuilder: (_, i) => _page(i),
            ),
            SafeArea(child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _page(int i) {
    final p = widget.videos[i];
    if (p.isExternal) return _shell(i, p, _externalBody(p), onTap: () => _openExternal(p));
    if (!p.isVideo) return _shell(i, p, _imageBody(p));
    final c = _ctrls[i];
    final ready = c != null && c.value.isInitialized;
    final cover = p.posterPath;
    return _shell(i, p, Stack(fit: StackFit.expand, children: [
      // الغلاف لحد ما الفيديو يجهز
      if (cover != null && !ready)
        Image(image: MediaCache.image(FeedApi.mediaUrl(cover), headers: FeedApi.headers, cacheKey: 'reels/$cover'),
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      if (ready)
        Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
      if (!ready)
        const Center(child: SizedBox(width: 30, height: 30,
            child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))),
      if (ready && _paused && i == _i)
        const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 80)),
    ]), onTap: _togglePause, progress: ready ? c : null);
  }

  Widget _imageBody(FeedPost p) => Image(
        image: MediaCache.image(FeedApi.mediaUrl(p.storagePath), headers: FeedApi.headers,
            cacheKey: 'reels/${p.storagePath}'),
        fit: BoxFit.contain,
        loadingBuilder: (_, child, prog) => prog == null ? child : const Center(child: SizedBox(width: 30, height: 30,
            child: CircularProgressIndicator(color: Brand.navAccent, strokeWidth: 2))),
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48)),
      );

  // يوتيوب / تيك توك: الصورة المصغّرة + زرار تشغيل؛ الدوسة بتفتح المشغّل الرسمي بتاعهم
  Widget _externalBody(FeedPost p) => Stack(fit: StackFit.expand, children: [
        Center(child: AspectRatio(aspectRatio: p.source == 'youtube' ? 16 / 9 : 9 / 16, child: ExternalThumb(post: p))),
        Center(child: Container(
          width: 76, height: 76,
          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 46),
        )),
        PositionedDirectional(top: 0, end: 12, child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(top: 14), child: ExternalBadge(post: p)))),
      ]);

  Future<void> _openExternal(FeedPost p) async {
    await openExternalPlayer(context, p);
    if (mounted) setState(() {});   // Hype ممكن يكون اتغيّر جوه المشغّل
  }

  // الإطار المشترك لأي بوست: المحتوى + الحساب والعنوان + Hype وشير + الدبل تاب
  Widget _shell(int i, FeedPost p, Widget body, {VoidCallback? onTap, VideoPlayerController? progress}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: () => _hype(p, burst: true),
      child: Stack(fit: StackFit.expand, children: [
        body,
        if (_showBurst && i == _i)
          const Center(child: _HypeBurst()),
        // تدرّج تحت علشان الكلام يبان
        const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)], stops: [0, 0.6, 1])))),
        // الحساب + العنوان + الوصف
        PositionedDirectional(
          start: 16, end: 84, bottom: 0,
          child: SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const OfficialMark(size: 30),
                const SizedBox(width: 8),
                const Text('BDGR', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                const OfficialBadge(size: 15),
                const SizedBox(width: 8),
                Text(FeedApi.ago(p.createdAt), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
              if (p.title.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ],
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(p.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFD5D8DF), fontSize: 13, height: 1.5)),
              ],
            ]),
          )),
        ),
        // Hype + شير على الجنب
        PositionedDirectional(
          end: 6, bottom: 0,
          child: SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HypeButton(active: p.myHype, count: p.hypes, onTap: () => _hype(p), vertical: true),
              const SizedBox(height: 4),
              CommentButton(count: p.comments, vertical: true, onTap: () => showCommentsSheet(context,
                  postType: 'official', postId: p.id,
                  onCount: (n) { if (mounted) setState(() => p.comments = n); })),
              const SizedBox(height: 4),
              ShareButton(vertical: true, onTap: () => Share.share(FeedApi.shareText(p))),
            ]),
          )),
        ),
        // شريط التقدّم (للفيديو بس)
        if (progress != null)
          Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false,
              child: VideoProgressIndicator(progress, allowScrubbing: true, padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(playedColor: Brand.navAccent,
                      bufferedColor: Colors.white24, backgroundColor: Colors.white10)))),
      ]),
    );
  }
}

/// علامة الـ Hype الكبيرة اللي بتطلع مع الدبل تاب
class _HypeBurst extends StatelessWidget {
  const _HypeBurst();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: v, child: child)),
        child: const HypeMark(active: true, size: 150, glow: true),
      );
}
