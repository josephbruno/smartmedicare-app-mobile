import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../app_config.dart';

/// Device biometric (fingerprint / Face ID) helper for mobile unlock.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True when this build can use biometrics (Android / iOS only).
  bool get isSupportedPlatform => AppConfig.isNativeMobile;

  Future<bool> canCheckBiometrics() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Biometric canCheck failed: $e');
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    if (!isSupportedPlatform) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Prefer fingerprint wording on Android; Face ID / biometrics elsewhere.
  Future<String> unlockLabel() async {
    final types = await availableBiometrics();
    if (types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong)) {
      return 'Use fingerprint';
    }
    if (types.contains(BiometricType.face)) {
      return 'Use Face ID';
    }
    return 'Use biometrics';
  }

  Future<bool> authenticate({
    String reason = 'Unlock Maran Billing',
  }) async {
    if (!isSupportedPlatform) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authenticate failed: $e');
      return false;
    }
  }
}
