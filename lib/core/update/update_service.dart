import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_config.dart';
import 'update_logger.dart';
import 'update_models.dart';

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
            );

  final Dio _dio;

  static const exeName = 'mobile.exe';
  static const updaterBat = 'Update.bat';

  bool get isSupported =>
      !AppConfig.isNativeMobile && Platform.isWindows && AppConfig.isDesktopPlatform;

  Future<PackageInfo> currentPackageInfo() => PackageInfo.fromPlatform();

  Future<UpdateCheckResult> checkForUpdate() async {
    final info = await currentPackageInfo();
    final build = int.tryParse(info.buildNumber) ?? 0;
    await UpdateLogger.log('Checking updates current=$build url=${AppConfig.appUpdateCheckUrl}');

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        AppConfig.appUpdateCheckUrl,
        queryParameters: {
          'platform': 'windows',
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
    final zipPath = p.join(
      tempDir.path,
      'maran_update_${DateTime.now().millisecondsSinceEpoch}.zip',
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
      await UpdateLogger.log('Download failed: ${e.message}');
      throw UpdateException('Download failed: ${e.message}');
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
    final updaterBatFile = File(p.join(installDir, updaterBat));
    if (!await updaterPs1.exists() && !await updaterBatFile.exists()) {
      throw UpdateException('Updater not found in $installDir');
    }

    final args = <String>[
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', updaterPs1.path,
      '-ZipPath', zipFile.path,
      '-InstallDir', installDir,
      '-ExeName', exeName,
      '-WaitPid', '$pid',
      '-Version', version,
      '-ShowResult',
    ];

    await UpdateLogger.log('Launching powershell updater args=$args');
    await Process.start(
      'powershell.exe',
      args,
      workingDirectory: installDir,
      mode: ProcessStartMode.detached,
    );

    // Give the updater a moment to start before we exit.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await UpdateLogger.log('Exiting application for update');
    exit(0);
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
