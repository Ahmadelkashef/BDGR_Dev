import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_preloader.dart';

/// خلفية فيديو بتشغّل قائمة فيديوهات ورا بعض.
/// بتاخد الفيديو من الموبايل لو اتحمّل قبل كده (VideoPreloader)، ولو لأ من النت.
/// وبتعرض صورة ثابتة لحد ما أول فيديو يشتغل.
class VideoPlaylistBackground extends StatefulWidget {
  const VideoPlaylistBackground({
    super.key,
    required this.urls,
    required this.posterUrl,
  });

  final List<String> urls;
  final String posterUrl;

  @override
  State<VideoPlaylistBackground> createState() =>
      _VideoPlaylistBackgroundState();
}

class _VideoPlaylistBackgroundState extends State<VideoPlaylistBackground> {
  VideoPlayerController? _current;
  VideoPlayerController? _next;
  int _index = 0;
  int? _nextIndex;
  bool _disposed = false;
  bool _switching = false;
  bool _prefetching = false;

  File? _posterFile;
  bool _posterChecked = false;

  @override
  void initState() {
    super.initState();
    _loadPoster();
    _start();
  }

  Future<void> _loadPoster() async {
    final file = await VideoPreloader.waitFor(widget.posterUrl);

    if (!_disposed && mounted) {
      setState(() {
        _posterFile = file;
        _posterChecked = true;
      });
    }
  }

  Future<VideoPlayerController?> _create(int index) async {
    final url = widget.urls[index];
    final options = VideoPlayerOptions(mixWithOthers: true);

    // لو الفيديو بيتحمّل دلوقتي بنستناه بدل ما نحمّله مرتين
    final file = await VideoPreloader.waitFor(url);

    final controller = file != null
        ? VideoPlayerController.file(file, videoPlayerOptions: options)
        : VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: options,
          );

    try {
      await controller.initialize();
      await controller.setVolume(0);
      return controller;
    } catch (e) {
      debugPrint('Video init failed: $e');
      await controller.dispose();
      return null;
    }
  }

  Future<void> _start() async {
    if (widget.urls.isEmpty) {
      return;
    }

    final controller = await _create(0);

    if (_disposed) {
      await controller?.dispose();
      return;
    }

    if (controller == null) {
      return;
    }

    _current = controller;
    controller.addListener(_onTick);
    await controller.play();

    if (mounted) {
      setState(() {});
    }

    _prefetchNext();
  }

  Future<void> _prefetchNext() async {
    if (widget.urls.length < 2 || _disposed || _prefetching) {
      return;
    }

    _prefetching = true;
    final nextIndex = (_index + 1) % widget.urls.length;
    final controller = await _create(nextIndex);
    _prefetching = false;

    if (_disposed) {
      await controller?.dispose();
      return;
    }

    if (controller == null) {
      return;
    }

    await _next?.dispose();
    _next = controller;
    _nextIndex = nextIndex;
  }

  void _onTick() {
    final controller = _current;

    if (controller == null || _switching || _disposed) {
      return;
    }

    final value = controller.value;

    if (!value.isInitialized || value.duration == Duration.zero) {
      return;
    }

    if (value.position >= value.duration - const Duration(milliseconds: 150)) {
      _advance();
    }
  }

  Future<void> _advance() async {
    if (_switching || _disposed) {
      return;
    }

    _switching = true;

    final old = _current;
    _index = (_index + 1) % widget.urls.length;

    VideoPlayerController? next;

    if (_next != null && _nextIndex == _index) {
      next = _next;
    } else {
      await _next?.dispose();
    }

    _next = null;
    _nextIndex = null;

    next ??= await _create(_index);

    if (_disposed) {
      await next?.dispose();
      return;
    }

    if (next == null) {
      // ما قدرناش نحمّل التالي: نعيد الحالي بدل ما الشاشة تقف
      await old?.seekTo(Duration.zero);
      await old?.play();
      _switching = false;
      return;
    }

    old?.removeListener(_onTick);
    next.addListener(_onTick);
    await next.play();
    _current = next;

    if (mounted) {
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
    });

    _switching = false;
    _prefetchNext();
  }

  @override
  void dispose() {
    _disposed = true;
    _current?.removeListener(_onTick);
    _current?.dispose();
    _next?.dispose();
    super.dispose();
  }

  Widget _poster() {
    final file = _posterFile;

    if (file != null) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: Colors.black),
      );
    }

    // الصورة ما اتحمّلتش مسبقًا: نجيبها من النت
    if (_posterChecked) {
      return Image.network(
        widget.posterUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: Colors.black),
      );
    }

    return const ColoredBox(color: Colors.black);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _current;
    final ready = controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        _poster(),
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
      ],
    );
  }
}
