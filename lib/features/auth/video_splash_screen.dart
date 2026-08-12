import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/update/windows_update_gate.dart';

/// Full-screen branded video shown once at cold start, before login / PIN.
class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  static const Duration displayDuration = Duration(seconds: 10);
  static const String assetPath = 'assets/branding/splash.mp4';

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  VideoPlayerController? _controller;
  Timer? _timer;
  bool _finished = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_start());
  }

  Future<void> _start() async {
    final controller = VideoPlayerController.asset(VideoSplashScreen.assetPath);
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(1.0);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('Splash video failed: $e\n$st');
      unawaited(_finish());
      return;
    }

    _timer = Timer(VideoSplashScreen.displayDuration, () {
      unawaited(_finish());
    });
  }

  Future<void> _finish() async {
    if (_finished || !mounted) return;
    _finished = true;
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Stay on splash while an update alert/download is active so navigation
    // does not dismiss the dialog and skip the download.
    await WindowsUpdateGate.instance.waitIfHeld();
    if (!mounted) return;

    // Hand off to `/` so existing auth redirect picks landing vs PIN.
    context.go('/');
  }

  @override
  void dispose() {
    _timer?.cancel();
    final c = _controller;
    _controller = null;
    unawaited(c?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready && controller != null && controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
