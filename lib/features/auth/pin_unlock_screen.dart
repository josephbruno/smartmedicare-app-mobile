import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import 'widgets/pin_entry_with_keypad.dart';
import 'widgets/pin_fullscreen_layout.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _pinKey = GlobalKey<PinEntryWithKeypadState>();
  bool _loading = false;
  String? _error;
  int _shakeTrigger = 0;

  Future<void> _submit(String pin) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthSession>().verifyPin(pin);
      if (mounted) context.go('/dashboard');
    } on ApiException catch (e) {
      _pinKey.currentState?.clear();
      setState(() {
        _error = e.message;
        _shakeTrigger++;
      });
    } catch (e) {
      _pinKey.currentState?.clear();
      setState(() {
        _error = e.toString();
        _shakeTrigger++;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchAccount() async {
    await context.read<AuthSession>().logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final userName = auth.user?.name ?? 'User';

    return PinFullscreenLayout(
      title: 'Welcome back',
      subtitle: userName,
      secondaryText: 'Enter your 6-digit PIN',
      loading: _loading,
      error: _error,
      pinEntry: PinEntryWithKeypad(
        key: _pinKey,
        enabled: !_loading,
        shakeTrigger: _shakeTrigger,
        onCompleted: _submit,
      ),
      footer: PinFooterLink(
        label: 'Use a different account',
        onPressed: _loading ? null : _switchAccount,
      ),
    );
  }
}
