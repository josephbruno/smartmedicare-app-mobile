import 'package:flutter/material.dart';

import '../../../core/widgets/powered_by_footer.dart';

/// Shared, understated backdrop for the SmartMediCare auth flow.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.child,
    this.showTopBar = false,
    this.showBackButton = false,
    this.showFooter = true,
    this.onBack,
  });

  final Widget child;
  final bool showTopBar;
  final bool showBackButton;
  final bool showFooter;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // StackFit.expand ensures children get tight, bounded constraints
        // from the Scaffold body (which itself is tightly constrained).
        // Without this, nested LayoutBuilders and Stacks see h=Infinity.
        fit: StackFit.expand,
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(child: child),
                if (showFooter) const PoweredByFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD6E8FA), Color(0xFFEEF5FF), Color(0xFFD3E8F8)],
          stops: [0, .5, 1],
        ),
      ),
      child: Stack(
        children: [
          // Subtle white rotated panels (depth effect)
          Positioned(
            top: -260,
            left: -180,
            child: Transform.rotate(
              angle: -.78,
              child: Container(
                  width: 680,
                  height: 360,
                  color: Colors.white.withValues(alpha: .46)),
            ),
          ),
          Positioned(
            right: -190,
            bottom: -230,
            child: Transform.rotate(
              angle: -.78,
              child: Container(
                  width: 700,
                  height: 400,
                  color: Colors.white.withValues(alpha: .44)),
            ),
          ),
          // Medical cross decorations
          const Positioned(
              top: 28, left: 28, child: _MedCross(size: 38, opacity: 0.22)),
          const Positioned(
              top: 90, left: 110, child: _MedCross(size: 22, opacity: 0.14)),
          const Positioned(
              bottom: 40, left: 60, child: _MedCross(size: 32, opacity: 0.18)),
          const Positioned(
              bottom: 130,
              left: 180,
              child: _MedCross(size: 18, opacity: 0.12)),
          const Positioned(
              top: 40, right: 36, child: _MedCross(size: 34, opacity: 0.20)),
          const Positioned(
              top: 120, right: 130, child: _MedCross(size: 20, opacity: 0.13)),
          const Positioned(
              bottom: 50, right: 50, child: _MedCross(size: 40, opacity: 0.22)),
          const Positioned(
              bottom: 150,
              right: 160,
              child: _MedCross(size: 22, opacity: 0.14)),
        ],
      ),
    );
  }
}

/// A simple medical "+" cross drawn with a CustomPainter.
class _MedCross extends StatelessWidget {
  const _MedCross({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: Size(size, size),
          painter: _CrossPainter(),
        ),
      );
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A8FD8)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final third = w / 3;

    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, third, w, third),
        const Radius.circular(3),
      ),
      paint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(third, 0, third, h),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}
