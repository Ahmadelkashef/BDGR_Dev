import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app_lang.dart';
import '../local_store.dart';
import '../media_cache.dart';
import '../official_account.dart';
import 'feed_api.dart';
import '../web/web_layout.dart' show WebStage;

/// دايرة ستوريز BDGR أول الشريط (نفس شكل هايلايتس الفانتازي):
/// حلقة دهبي لو فيه جديد ما اتشافش، رمادي لو اتشاف.
class OfficialStoriesCircle extends StatefulWidget {
  const OfficialStoriesCircle({super.key, required this.stories});
  final List<FeedStory> stories;
  @override
  State<OfficialStoriesCircle> createState() => _OfficialStoriesCircleState();
}

class _OfficialStoriesCircleState extends State<OfficialStoriesCircle> {
  final Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  @override
  void didUpdateWidget(covariant OfficialStoriesCircle old) {
    super.didUpdateWidget(old);
    if (old.stories != widget.stories) _loadSeen();
  }

  Future<void> _loadSeen() async {
    for (final s in widget.stories) {
      if (await LocalStore.getFlag('story_seen_${s.id}')) _seen.add(s.id);
    }
    if (mounted) setState(() {});
  }

  bool get _allSeen => widget.stories.every((s) => _seen.contains(s.id));

  Future<void> _open() async {
    // نبدأ من أول ستوري لسه ما اتشافش
    final first = widget.stories.indexWhere((s) => !_seen.contains(s.id));
    await Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => WebStage(background: Colors.transparent, child: _StoryViewer(stories: widget.stories, start: first < 0 ? 0 : first, onSeen: (s) {
        _seen.add(s.id);
        LocalStore.setFlag('story_seen_${s.id}');
      })),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final seen = _allSeen;
    return GestureDetector(
      onTap: _open,
      child: SizedBox(width: 64, child: Column(children: [
        Container(
          width: 62, height: 62, padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: seen ? null : const LinearGradient(
                colors: [OfficialAccount.gold, Color(0xFFFF8A00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: seen ? Border.all(color: Colors.white24, width: 1.5) : null,
          ),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0B0B0F), width: 2)),
            child: const ClipOval(child: OfficialAvatarFallback(padding: 0.2)),
          ),
        ),
        const SizedBox(height: 5),
        Text('BDGR', maxLines: 1,
            style: TextStyle(color: seen ? Colors.white54 : Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ])),
    );
  }
}

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({required this.stories, required this.start, required this.onSeen});
  final List<FeedStory> stories;
  final int start;
  final void Function(FeedStory) onSeen;
  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> with SingleTickerProviderStateMixin {
  static const _imageDuration = Duration(seconds: 5);
  late int _i = widget.start;
  late final AnimationController _timer = AnimationController(vsync: this, duration: _imageDuration)
    ..addStatusListener((s) { if (s == AnimationStatus.completed) _next(); });
  VideoPlayerController? _video;
  bool _ready = false;

  FeedStory get _s => widget.stories[_i];

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void dispose() {
    _timer.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    _timer.stop();
    _video?.dispose();
    _video = null;
    setState(() => _ready = !_s.isVideo);
    widget.onSeen(_s);
    if (!_s.isVideo) {
      _timer.duration = _imageDuration;
      _timer.forward(from: 0);
      return;
    }
    final index = _i;
    final c = await MediaCache.video(FeedApi.mediaUrl(_s.storagePath), headers: FeedApi.headers);
    if (!mounted || index != _i) { c.dispose(); return; }
    try {
      await c.initialize();
    } catch (e) {
      debugPrint('story video error: $e');
    }
    if (!mounted || index != _i) { c.dispose(); return; }
    _video = c;
    final d = c.value.duration;
    _timer.duration = d > Duration.zero && d < const Duration(seconds: 60) ? d : const Duration(seconds: 15);
    setState(() => _ready = true);
    c.play();
    _timer.forward(from: 0);
  }

  void _next() {
    if (_i >= widget.stories.length - 1) { if (mounted) Navigator.pop(context); return; }
    setState(() => _i++);
    _show();
  }

  void _prev() {
    if (_i == 0) { _timer.forward(from: 0); _video?.seekTo(Duration.zero); return; }
    setState(() => _i--);
    _show();
  }

  void _hold(bool on) {
    if (on) { _timer.stop(); _video?.pause(); } else { _timer.forward(); _video?.play(); }
  }

  @override
  Widget build(BuildContext context) {
    final rtl = AppLang.isArabic;
    final s = _s;
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => _hold(true),
          onLongPressEnd: (_) => _hold(false),
          onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context); },
          onTapUp: (d) {
            final w = MediaQuery.of(context).size.width;
            final x = d.globalPosition.dx;
            final backSide = rtl ? x > w * 0.7 : x < w * 0.3;
            backSide ? _prev() : _next();
          },
          child: Stack(fit: StackFit.expand, children: [
            if (!s.isVideo)
              Image(image: MediaCache.image(FeedApi.mediaUrl(s.storagePath), headers: FeedApi.headers,
                      cacheKey: 'reels/${s.storagePath}'),
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
            else if (_ready && _video != null && _video!.value.isInitialized)
              Center(child: AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!)))
            else
              const Center(child: SizedBox(width: 30, height: 30,
                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2))),
            const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Colors.transparent, Colors.transparent, Color(0xDD000000)],
              stops: [0, 0.2, 0.6, 1])))),
            if (s.caption.isNotEmpty)
              Positioned(left: 20, right: 20, bottom: 40, child: SafeArea(top: false,
                  child: Text(s.caption, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.5)))),
            // الشرط + الحساب + إغلاق
            SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Column(children: [
              AnimatedBuilder(animation: _timer, builder: (_, __) => Row(children: [
                for (var j = 0; j < widget.stories.length; j++)
                  Expanded(child: Container(
                    height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: j < _i ? 1 : j > _i ? 0 : _timer.value,
                      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))))),
              ])),
              const SizedBox(height: 10),
              Row(children: [
                const OfficialMark(size: 30),
                const SizedBox(width: 8),
                const Text('BDGR', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                const OfficialBadge(size: 15),
                const SizedBox(width: 8),
                Text(FeedApi.ago(s.createdAt), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26)),
              ]),
            ]))),
          ]),
        ),
      ),
    );
  }
}
