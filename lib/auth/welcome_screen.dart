import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../brand.dart';
import '../main_shell.dart';
import 'login_config.dart';
import 'login_screen.dart';
import 'video_preloader.dart';

/// فيديو ترحيب بعد التسجيل (يوزر جديد بس).
/// الفيديو بيبدأ يتحمل من لما يفتح صفحة اللوجن، فلما اليوزر يوصل هنا بيكون جاهز أو قريب.
/// مدة الشاشة 11 ثانية، أو لما الفيديو يخلص.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Duration _displayDuration  = Duration(seconds: 11);
  static const Duration _safetyTimeout    = Duration(seconds: 15);

  VideoPlayerController? _controller;
  Timer?                 _safetyTimer;
  bool                   _navigated = false;

  @override
  void initState() {
    super.initState();
    _safetyTimer = Timer(_safetyTimeout, _goHome);
    _startVideo();
  }

  Future<void> _startVideo() async {
    final url = LoginConfig.welcomeVideo;

    // لو اتحمّل مسبقًا، يجيه من الكاش
    final file = await VideoPreloader.waitFor(url);

    if (_navigated || !mounted) return;

    final controller = file != null
        ? VideoPlayerController.file(
            file,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );

    _controller = controller;

    try {
      await controller.initialize();
      if (_navigated || !mounted) return;

      await controller.setVolume(1);
      controller.addListener(_onTick);
      await controller.play();

      if (mounted) setState(() {});

      // لو الفيديو أطول من 11 ثانية نخرج بعد 11
      Timer(_displayDuration, _goHome);
    } catch (e) {
      debugPrint('Welcome video failed: $e');
      // الفيديو فشل: نفضل في الشاشة لحد الـ safety timer
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || _navigated) return;
    final v = c.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;
    if (v.position >= v.duration - const Duration(milliseconds: 200)) {
      _goHome();
    }
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _safetyTimer?.cancel();
    _controller?.pause();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c     = _controller;
    final ready = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // خلفية سوداء وفوقها الفيديو لما يجهز
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width:  c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            )
          else
            // الفيديو لسه بيتحمل: اللوجو في النص
            Center(
              child: Image.asset(Brand.badger, width: 100, color: Colors.white30),
            ),
        ],
      ),
    );
  }
}
