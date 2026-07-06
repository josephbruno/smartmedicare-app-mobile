import 'package:flutter/material.dart';

/// Shared app branding logo asset.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 48,
    this.borderRadius = 12,
  });

  final double size;
  final double borderRadius;

  static const assetPath = 'assets/branding/logo.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
