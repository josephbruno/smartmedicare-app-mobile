import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late final FocusNode _focusNode;

  String get digits => _digits;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyboardInput(RawKeyEvent event) {
    if (!widget.enabled || event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return;
    }

    // Try to use the character property first
    if (event.character != null) {
      final char = event.character!;
      if (char.runes.length == 1 && char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        _addDigit(char);
        return;
      }
    }

    // Map numpad keys explicitly
    final numpadMap = {
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };

    if (numpadMap.containsKey(key)) {
      _addDigit(numpadMap[key]!);
      return;
    }
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
    final size = MediaQuery.sizeOf(context);
    final isWideDesktop = size.width >= 1280;
    final isDesktop = AppConfig.usesLargeUiScale;
    final isTablet = size.width >= 600 && size.width < 840;

    final maxWidth = isWideDesktop ? 440.0 : isDesktop ? 380.0 : isTablet ? 360.0 : 340.0;
    final dotSize = isWideDesktop ? 28.0 : isDesktop ? 22.0 : isTablet ? 20.0 : 18.0;
    final dotGap = isWideDesktop ? 18.0 : isDesktop ? 14.0 : isTablet ? 12.0 : 10.0;
    final containerPaddingH = isWideDesktop ? 36.0 : isDesktop ? 28.0 : isTablet ? 24.0 : 20.0;
    final containerPaddingV = isWideDesktop ? 36.0 : isDesktop ? 28.0 : isTablet ? 26.0 : 22.0;
    final containerPaddingBottom = isWideDesktop ? 40.0 : isDesktop ? 32.0 : isTablet ? 28.0 : 26.0;
    final spacerHeight = isWideDesktop ? 18.0 : isDesktop ? 14.0 : isTablet ? 12.0 : 10.0;
    final keypadGap = isWideDesktop ? 32.0 : isDesktop ? 28.0 : isTablet ? 24.0 : 22.0;

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyboardInput,
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            containerPaddingH,
            containerPaddingV,
            containerPaddingH,
            containerPaddingBottom,
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
                          EdgeInsets.only(right: i < pinLength - 1 ? dotGap : 0),
                      width: dotSize,
                      height: dotSize,
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
              SizedBox(height: spacerHeight),
              Text(
                '${_digits.length}/$pinLength',
                style: TextStyle(
                  fontSize: isWideDesktop ? 13.0 : 12.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: keypadGap),
              PinKeypad(
                enabled: widget.enabled,
                onDigit: _addDigit,
                onBackspace: _backspace,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
