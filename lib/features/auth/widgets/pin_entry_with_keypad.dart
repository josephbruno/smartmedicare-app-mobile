import 'package:flutter/material.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';
import 'pin_keypad.dart';

/// Six-digit PIN dots + on-screen numeric keypad.
class PinEntryWithKeypad extends StatefulWidget {
  const PinEntryWithKeypad({
    super.key,
    required this.onCompleted,
    this.enabled = true,
    this.obscure = true,
    this.shakeTrigger = 0,
  });

  final ValueChanged<String> onCompleted;
  final bool enabled;
  final bool obscure;
  final int shakeTrigger;

  @override
  State<PinEntryWithKeypad> createState() => PinEntryWithKeypadState();
}

class PinEntryWithKeypadState extends State<PinEntryWithKeypad>
    with SingleTickerProviderStateMixin {
  static const pinLength = 6;

  String _digits = '';
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  String get digits => _digits;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant PinEntryWithKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTrigger != oldWidget.shakeTrigger) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void clear() {
    setState(() => _digits = '');
  }

  void _addDigit(String d) {
    if (!widget.enabled || _digits.length >= pinLength) return;
    setState(() => _digits += d);
    if (_digits.length == pinLength) {
      widget.onCompleted(_digits);
    }
  }

  void _backspace() {
    if (!widget.enabled || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppConfig.usesLargeUiScale;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 380 : 340),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 28 : 20,
            isDesktop ? 28 : 22,
            isDesktop ? 28 : 20,
            isDesktop ? 32 : 26,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pinLength, (i) {
                    final filled = i < _digits.length;
                    final active = i == _digits.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      margin:
                          EdgeInsets.only(right: i < pinLength - 1 ? 14 : 0),
                      width: isDesktop ? 22 : 18,
                      height: isDesktop ? 22 : 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppTheme.primary
                            : active
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: filled
                              ? AppTheme.primary
                              : active
                                  ? AppTheme.primary
                                  : const Color(0xFFCBD5E1),
                          width: active ? 2 : 1.5,
                        ),
                        boxShadow: filled
                            ? [
                                BoxShadow(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: isDesktop ? 14 : 10),
              Text(
                '${_digits.length}/$pinLength',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: isDesktop ? 28 : 22),
              PinKeypad(
                enabled: widget.enabled,
                onDigit: _addDigit,
                onBackspace: _backspace,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
