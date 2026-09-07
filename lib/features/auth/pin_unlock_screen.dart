import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/security/biometric_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/pin_entry_with_keypad.dart';
import 'widgets/pin_fullscreen_layout.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _pinKey = GlobalKey<PinEntryWithKeypadState>();
  final _biometrics = BiometricService();

  bool _loading = false;
  String? _error;
  int _shakeTrigger = 0;

  bool _biometricAvailable = false;
  bool _canUseBiometricUnlock = false;
  String _biometricLabel = 'Use fingerprint';
  bool _biometricPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareBiometrics());
  }

  Future<void> _prepareBiometrics() async {
    if (!AppConfig.isNativeMobile) return;
    final available = await _biometrics.canCheckBiometrics();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _biometricAvailable = false;
        _canUseBiometricUnlock = false;
      });
      return;
    }

    final auth = context.read<AuthSession>();
    final ready = await auth.canUnlockWithBiometrics();
    final label = await _biometrics.unlockLabel();
    if (!mounted) return;

    setState(() {
      _biometricAvailable = true;
      _canUseBiometricUnlock = ready;
      _biometricLabel = label;
    });

    // Auto-prompt once when fingerprint unlock is already set up.
    if (ready && !_biometricPrompted) {
      _biometricPrompted = true;
      await _unlockWithBiometrics();
    }
  }

  Future<void> _afterUnlock() async {
    if (!mounted) return;
    final auth = context.read<AuthSession>();
    if (!auth.cashierPlatformAllowed) {
      context.go('/cashier-desktop-only');
      return;
    }
    context.go(auth.homeRoute);
  }

  Future<void> _offerEnableBiometrics(String pin) async {
    if (!_biometricAvailable || !mounted) return;
    final auth = context.read<AuthSession>();
    if (auth.biometricEnabled) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable fingerprint unlock?'),
        content: const Text(
          'Use your fingerprint next time instead of typing your PIN. '
          'You can still use the PIN anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable == true && mounted) {
      await auth.rememberPinForBiometrics(pin);
    }
  }

  Future<void> _submit(String pin) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthSession>();
      await auth.verifyPin(pin);
      await _offerEnableBiometrics(pin);
      await _afterUnlock();
    } on ApiException catch (e) {
      _pinKey.currentState?.clear();
      setState(() {
        _error = e.displayMessage;
        _shakeTrigger++;
      });
    } catch (e) {
      _pinKey.currentState?.clear();
      setState(() {
        _error = e is ApiException
            ? e.displayMessage
            : 'Could not verify PIN. Please try again.';
        _shakeTrigger++;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthSession>();
      final ready = await auth.canUnlockWithBiometrics();
      if (!ready) {
        setState(() {
          _error = 'Enter your PIN once to enable fingerprint unlock.';
          _canUseBiometricUnlock = false;
        });
        return;
      }

      final ok = await _biometrics.authenticate(
        reason: 'Unlock Maran Billing',
      );
      if (!ok) {
        // User cancelled or failed — fall back to PIN keypad silently.
        return;
      }
      if (!mounted) return;
      await auth.unlockWithStoredBiometricPin();
      await _afterUnlock();
    } on ApiException catch (e) {
      setState(() {
        _error = e.displayMessage;
        _canUseBiometricUnlock = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException
            ? e.displayMessage
            : 'Fingerprint unlock failed. Enter your PIN.';
        _canUseBiometricUnlock = false;
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
    final showBiometric = _biometricAvailable;

    return PinFullscreenLayout(
      title: 'Welcome back',
      subtitle: userName,
      secondaryText: showBiometric && _canUseBiometricUnlock
          ? 'Use fingerprint or enter your 6-digit PIN'
          : 'Enter your 6-digit PIN',
      loading: _loading,
      error: _error,
      pinEntry: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinEntryWithKeypad(
            key: _pinKey,
            enabled: !_loading,
            shakeTrigger: _shakeTrigger,
            onCompleted: _submit,
          ),
          if (showBiometric) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loading ? null : _unlockWithBiometrics,
              icon: const Icon(Icons.fingerprint, size: 28),
              label: Text(
                _biometricLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
      footer: PinFooterLink(
        label: 'Use a different account',
        onPressed: _loading ? null : _switchAccount,
      ),
    );
  }
}
