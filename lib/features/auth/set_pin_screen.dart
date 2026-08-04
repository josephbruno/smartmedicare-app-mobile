import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import 'widgets/pin_entry_with_keypad.dart';
import 'widgets/pin_fullscreen_layout.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _pinKey = GlobalKey<PinEntryWithKeypadState>();
  final _confirmKey = GlobalKey<PinEntryWithKeypadState>();

  String _pin = '';
  bool _confirming = false;
  bool _loading = false;
  String? _error;
  int _shakeTrigger = 0;

  void _onPinEntered(String pin) {
    setState(() {
      _pin = pin;
      _confirming = true;
      _error = null;
    });
  }

  Future<void> _onConfirmEntered(String confirmPin) async {
    if (_loading) return;
    if (confirmPin != _pin) {
      setState(() {
        _error = 'PINs do not match. Please try again.';
        _confirming = false;
        _pin = '';
        _shakeTrigger++;
      });
      _pinKey.currentState?.clear();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthSession>().setPin(_pin);
      if (mounted) context.go('/dashboard');
    } on ApiException catch (e) {
      setState(() {
        _error = e.displayMessage;
        _confirming = false;
        _pin = '';
      });
      _pinKey.currentState?.clear();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _confirming = false;
        _pin = '';
      });
      _pinKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToPin() {
    setState(() {
      _confirming = false;
      _pin = '';
      _error = null;
    });
    _pinKey.currentState?.clear();
    _confirmKey.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    return PinFullscreenLayout(
      title: _confirming ? 'Confirm your PIN' : 'Set up your PIN',
      subtitle: _confirming
          ? 'Re-enter the same 6-digit PIN'
          : 'Create a 6-digit PIN to unlock',
      loading: _loading,
      error: _error,
      pinEntry: _confirming
          ? PinEntryWithKeypad(
              key: _confirmKey,
              enabled: !_loading,
              shakeTrigger: _shakeTrigger,
              onCompleted: _onConfirmEntered,
            )
          : PinEntryWithKeypad(
              key: _pinKey,
              enabled: !_loading,
              onCompleted: _onPinEntered,
            ),
      footer: _confirming
          ? PinFooterLink(
              label: 'Go back',
              icon: Icons.arrow_back_rounded,
              onPressed: _loading ? null : _backToPin,
            )
          : null,
    );
  }
}
