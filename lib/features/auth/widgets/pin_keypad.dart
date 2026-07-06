import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';

/// On-screen numeric keypad for PIN entry (no system keyboard needed).
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppConfig.usesLargeUiScale;
    final keySize = isDesktop ? 76.0 : 64.0;
    final gap = isDesktop ? 14.0 : 10.0;
    final fontSize = isDesktop ? 28.0 : 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyRow(
          keys: const ['1', '2', '3'],
          keySize: keySize,
          gap: gap,
          fontSize: fontSize,
          enabled: enabled,
          onDigit: onDigit,
        ),
        SizedBox(height: gap),
        _KeyRow(
          keys: const ['4', '5', '6'],
          keySize: keySize,
          gap: gap,
          fontSize: fontSize,
          enabled: enabled,
          onDigit: onDigit,
        ),
        SizedBox(height: gap),
        _KeyRow(
          keys: const ['7', '8', '9'],
          keySize: keySize,
          gap: gap,
          fontSize: fontSize,
          enabled: enabled,
          onDigit: onDigit,
        ),
        SizedBox(height: gap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: keySize, height: keySize),
            SizedBox(width: gap),
            _KeyButton(
              label: '0',
              size: keySize,
              fontSize: fontSize,
              enabled: enabled,
              onTap: () => onDigit('0'),
            ),
            SizedBox(width: gap),
            _KeyButton(
              icon: Icons.backspace_outlined,
              size: keySize,
              fontSize: fontSize,
              enabled: enabled,
              isDestructive: true,
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keys,
    required this.keySize,
    required this.gap,
    required this.fontSize,
    required this.enabled,
    required this.onDigit,
  });

  final List<String> keys;
  final double keySize;
  final double gap;
  final double fontSize;
  final bool enabled;
  final ValueChanged<String> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _KeyButton(
            label: keys[i],
            size: keySize,
            fontSize: fontSize,
            enabled: enabled,
            onTap: () => onDigit(keys[i]),
          ),
        ],
      ],
    );
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({
    this.label,
    this.icon,
    required this.size,
    required this.fontSize,
    required this.enabled,
    required this.onTap,
    this.isDestructive = false,
  });

  final String? label;
  final IconData? icon;
  final double size;
  final double fontSize;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  void _handleTap() {
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final pressedColor = widget.isDestructive
        ? AppTheme.danger.withValues(alpha: 0.1)
        : AppTheme.primary.withValues(alpha: 0.12);

    final pressedBorder = widget.isDestructive
        ? AppTheme.danger.withValues(alpha: 0.35)
        : AppTheme.primary.withValues(alpha: 0.45);

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              _handleTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: _pressed
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      pressedColor,
                      pressedColor.withValues(alpha: 0.6),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFFF8FAFC),
                    ],
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed ? pressedBorder : const Color(0xFFE8EDF3),
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: [
              if (!_pressed && widget.enabled)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(
                  widget.icon,
                  size: widget.fontSize * 0.8,
                  color: widget.isDestructive
                      ? AppTheme.danger.withValues(
                          alpha: widget.enabled ? 0.85 : 0.4,
                        )
                      : widget.enabled
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                )
              : Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w600,
                    color: widget.enabled
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
