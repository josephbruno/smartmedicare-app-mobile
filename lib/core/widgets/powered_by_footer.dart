import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared “Powered by bestwaveinnovation.com” attribution.
class PoweredByFooter extends StatelessWidget {
  const PoweredByFooter({
    super.key,
    this.light = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  /// Lighter text for dark backgrounds.
  final bool light;
  final EdgeInsetsGeometry padding;

  static const url = 'https://bestwaveinnovation.com';
  static const label = 'bestwaveinnovation.com';

  Future<void> _open() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = light
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF94A3B8);

    return Padding(
      padding: padding,
      child: Center(
        child: GestureDetector(
          onTap: _open,
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 11, height: 1.4, color: base),
              children: [
                const TextSpan(text: 'Powered by '),
                TextSpan(
                  text: label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: light
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
