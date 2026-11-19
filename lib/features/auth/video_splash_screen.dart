import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/update/windows_update_gate.dart';
import '../../core/widgets/app_logo.dart';

/// Branded splash shown once at cold start, before login / PIN.
///
/// Mirrors the web app's branding: the SmartMediCare logo, the
/// "**Smart**MediCare" wordmark and the brand line on the web login page.
class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 1600);

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Desktop goes straight to login / PIN, as before.
    if (AppConfig.isDesktopPlatform) {
      unawaited(_finish());
      return;
    }
    _fade.forward();
    _timer = Timer(VideoSplashScreen.displayDuration, () => unawaited(_finish()));
  }

  Future<void> _finish() async {
    if (_finished || !mounted) return;
    _finished = true;
    _timer?.cancel();

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
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgPrimary,
      body: DecoratedBox(
        // Same soft blue wash as the web login background.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9F3FF), Color(0xFFF8FBFF), Color(0xFFE5F1FF)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 112, borderRadius: 0),
                const SizedBox(height: 20),
                Text.rich(
                  const TextSpan(children: [
                    TextSpan(
                      text: 'Smart',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: 'MediCare'),
                  ]),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTokens.text1,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('SMARTER CLINICS', style: _brandLine),
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE60018),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text('HEALTHIER LIVES', style: _brandLine),
                  ],
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTokens.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const TextStyle _brandLine = TextStyle(
  color: AppTokens.text3,
  fontSize: AppTokens.fontXs,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.6,
);
