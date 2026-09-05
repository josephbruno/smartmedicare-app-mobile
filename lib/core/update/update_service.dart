import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_config.dart';
import 'android_apk_installer.dart';
import 'update_logger.dart';
import 'update_models.dart';
import '../network/network_resilience.dart';

class UpdateService {
  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(minutes: 10),
                sendTimeout: const Duration(minutes: 10),
                validateStatus: (s) => s != null && s >= 200 && s < 300,
              ),
            ) {
    if (dio == null) {
      configureDioNetworking(_dio);
    }
  }

  final Dio _dio;

  /// Fallback when [Platform.resolvedExecutable] is unavailable (tests).
  static const defaultExeName = 'mobile.exe';
  static const updaterBat = 'Update.bat';

  /// Actual on-disk EXE name for this install (usually `mobile.exe`).
  static String get exeName {
    try {
      final base = p.basename(Platform.resolvedExecutable);
      if (base.toLowerCase().endsWith('.exe') && base.isNotEmpty) {
        return base;
      }
    } catch (_) {}
    return defaultExeName;
  }

  bool get isSupported {
    if (Platform.isWindows) return AppConfig.enableWindowsAutoUpdate;
    if (Platform.isAndroid) return AppConfig.enableAndroidAutoUpdate;
    return false;
  }

  String get updatePlatform {
    if (Platform.isAndroid) return 'android';
    return 'windows';
  }

  Future<PackageInfo> currentPackageInfo() => PackageInfo.fromPlatform();

  Future<UpdateCheckResult> checkForUpdate() async {
    final info = await currentPackageInfo();
    final build = int.tryParse(info.buildNumber) ?? 0;
    await UpdateLogger.log(
      'Checking updates platform=$updatePlatform current=$build url=${AppConfig.appUpdateCheckUrl}',
    );

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        AppConfig.appUpdateCheckUrl,
        queryParameters: {
          'platform': updatePlatform,
          'current_build': build,
        },
      );
      final body = res.data ?? const {};
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw UpdateException('Invalid update check response');
      }
      final result = UpdateCheckResult.fromJson(data);
      await UpdateLogger.log(
        'Check result available=${result.updateAvailable} '
        'version=${result.version} mandatory=${result.mandatory}',
      );
      return result;
    } on DioException catch (e) {
      await UpdateLogger.log('Check failed: ${e.message}');
      throw UpdateException('Could not check for updates: ${e.message}');
    }
  }

  Future<File> downloadPackage(
    UpdatePackageInfo package, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (package.url.isEmpty || package.sha256.isEmpty) {
      throw UpdateException('Update package metadata is incomplete');
    }
    if (!package.url.toLowerCase().startsWith('https://')) {
      throw UpdateException('Update download must use HTTPS');
    }

    final tempDir = await getTemporaryDirectory();
    final ext = Platform.isAndroid ? 'apk' : 'zip';
    final zipPath = p.join(
      tempDir.path,
      'maran_update_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await UpdateLogger.log('Downloading ${package.url} -> $zipPath');

    try {
      await _dio.download(
        package.url,
        zipPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
    } on DioException catch (e) {
      final detail = [
        e.message,
        e.error,
        if (e.response != null) 'HTTP ${e.response!.statusCode}',
      ].where((p) => p != null && '$p'.trim().isNotEmpty && '$p' != 'null').join(' — ');
      await UpdateLogger.log(
        'Download failed type=${e.type} status=${e.response?.statusCode} '
        'error=${e.error} message=${e.message}',
      );
      throw UpdateException(
        detail.isEmpty ? 'Download failed. Check internet and retry.' : 'Download failed: $detail',
      );
    }

    final file = File(zipPath);
    if (!await file.exists()) {
      throw UpdateException('Downloaded file missing');
    }

    final digest = await sha256.bind(file.openRead()).first;
    final hash = digest.toString();
    if (hash.toLowerCase() != package.sha256.toLowerCase()) {
      await file.delete();
      await UpdateLogger.log('Checksum mismatch expected=${package.sha256} got=$hash');
      throw UpdateException('Downloaded file failed SHA-256 verification');
    }
    await UpdateLogger.log('Checksum OK $hash');
    return file;
  }

  Future<void> launchUpdaterAndExit({
    required File zipFile,
    required String version,
  }) async {
    final installDir = File(Platform.resolvedExecutable).parent.path;
    final updaterPs1 = File(p.join(installDir, 'Update.ps1'));
    if (!await updaterPs1.exists()) {
      throw UpdateException('Update.ps1 not found in install folder');
    }

    // Quote for use inside a .cmd file body (not for Process argv).
    String batQuote(String value) => '"${value.replaceAll('"', '""')}"';

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory.systemTemp.path;
    final workerCmd = File(p.join(tempDir, 'maran_update_worker_$stamp.cmd'));
    final bootstrapCmd = File(p.join(tempDir, 'maran_update_boot_$stamp.cmd'));

    // Worker: run Update.ps1 with fully quoted paths (handles "Maran Billing").
    await workerCmd.writeAsString(
      [
        '@echo off',
        'setlocal EnableExtensions',
        'powershell.exe -NoProfile -ExecutionPolicy RemoteSigned'
            ' -File ${batQuote(updaterPs1.path)}'
            ' -ZipPath ${batQuote(zipFile.path)}'
            ' -InstallDir ${batQuote(installDir)}'
            ' -ExeName ${batQuote(exeName)}'
            ' -WaitPid $pid'
            ' -Version ${batQuote(version)}'
            ' -ShowResult',
        'exit /b %ERRORLEVEL%',
        '',
      ].join('\r\n'),
      flush: true,
    );

    // Bootstrap: `start "title" ...` MUST live inside a .cmd file.
    // If we pass start "" / title via Process argv, Windows/Dart quoting breaks
    // (errors like cannot find '\\' or cannot find 'MaranUpdate').
    await bootstrapCmd.writeAsString(
      [
        '@echo off',
        'start "MaranUpdate" /MIN ${batQuote(workerCmd.path)}',
        'exit /b 0',
        '',
      ].join('\r\n'),
      flush: true,
    );

    await UpdateLogger.log(
      'Launching updater boot=${bootstrapCmd.path} worker=${workerCmd.path} '
      'installDir=$installDir waitPid=$pid',
    );

    // Run bootstrap only — it calls `start` so the worker outlives Flutter.
    await Process.start(
      'cmd.exe',
      ['/c', bootstrapCmd.path],
      workingDirectory: tempDir,
      mode: ProcessStartMode.detached,
    );

    await Future<void>.delayed(const Duration(milliseconds: 2500));
    await UpdateLogger.log('Exiting application for update');
    exit(0);
  }

  Future<void> launchAndroidInstaller(File apkFile) async {
    if (!await apkFile.exists()) {
      throw UpdateException('Downloaded APK is missing');
    }
    await UpdateLogger.log('Launching Android package installer path=${apkFile.path}');
    try {
      await AndroidApkInstaller.installApk(apkFile.path);
    } on PlatformException catch (e) {
      await UpdateLogger.log('Android install failed: ${e.code} ${e.message}');
      throw UpdateException(e.message ?? 'Could not open the Android installer');
    }
  }

  Future<Map<String, dynamic>?> consumeLastResult() async {
    final resultFile = File(p.join(Directory.systemTemp.path, 'maran_update_result.json'));
    if (!await resultFile.exists()) return null;
    try {
      final map = jsonDecode(await resultFile.readAsString());
      await resultFile.delete();
      if (map is Map<String, dynamic>) {
        await UpdateLogger.log('Previous update result: $map');
        return map;
      }
    } catch (e) {
      await UpdateLogger.log('Failed reading update result: $e');
    }
    return null;
  }
}
