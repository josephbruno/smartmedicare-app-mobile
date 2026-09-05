import 'package:flutter/services.dart';

/// Native bridge for sideload APK install (unknown-apps permission + installer).
class AndroidApkInstaller {
  AndroidApkInstaller._();

  static const MethodChannel _channel = MethodChannel(
    'com.maranbilling.mobile/apk_update',
  );

  static Future<bool> canInstallPackages() async {
    final result = await _channel.invokeMethod<bool>('canInstallPackages');
    return result ?? false;
  }

  static Future<void> openUnknownSourcesSettings() {
    return _channel.invokeMethod<void>('openUnknownSourcesSettings');
  }

  static Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }
}
