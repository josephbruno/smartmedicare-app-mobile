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

  /// Prefer Update.ps1 from the downloaded ZIP so old installs get the latest updater.
  Future<File> extractUpdaterFromZip(File zipFile) async {
    final tempRoot = await Directory.systemTemp.createTemp('maran_updater_');
    final outPs1 = File(p.join(tempRoot.path, 'Update.ps1'));
    final zipPath = zipFile.path.replaceAll("'", "''");
    final outPath = outPs1.path.replaceAll("'", "''");

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        """
Add-Type -AssemblyName System.IO.Compression.FileSystem
\$z = [System.IO.Compression.ZipFile]::OpenRead('$zipPath')
try {
  \$entry = \$z.Entries | Where-Object { \$_.Name -eq 'Update.ps1' } | Select-Object -First 1
  if (-not \$entry) { throw 'Update.ps1 missing from update package' }
  if (Test-Path -LiteralPath '$outPath') { Remove-Item -LiteralPath '$outPath' -Force }
  [System.IO.Compression.ZipFileExtensions]::ExtractToFile(\$entry, '$outPath', \$true)
} finally {
  \$z.Dispose()
}
""",
      ],
    );

    if (result.exitCode != 0 || !await outPs1.exists()) {
      await UpdateLogger.log(
        'Extract updater failed code=${result.exitCode} stderr=${result.stderr} stdout=${result.stdout}',
      );
      // Fallback to installed updater if package extract fails.
      final installPs1 = File(p.join(File(Platform.resolvedExecutable).parent.path, 'Update.ps1'));
      if (await installPs1.exists()) {
        await installPs1.copy(outPs1.path);
        await UpdateLogger.log('Using installed Update.ps1 fallback');
        return outPs1;
      }
      throw UpdateException('Could not extract updater from package');
    }

    await UpdateLogger.log('Extracted updater to ${outPs1.path}');
    return outPs1;
  }

  Future<void> launchUpdaterAndExit({
    required File zipFile,
    required String version,
  }) async {
    final installDir = File(Platform.resolvedExecutable).parent.path;
    final updaterPs1 = await extractUpdaterFromZip(zipFile);

    // Launch via WScript.Shell so the updater survives after Flutter exits.
    // On Windows 10, a detached child of the Flutter process is often killed
    // with the app (job object), which looks like: app closes, no error, no update.
    String vbsEscape(String value) => value.replaceAll('"', '""');

    final psCommand =
        "powershell.exe -NoProfile -ExecutionPolicy Bypass"
        " -File \"${vbsEscape(updaterPs1.path)}\""
        " -ZipPath \"${vbsEscape(zipFile.path)}\""
        " -InstallDir \"${vbsEscape(installDir)}\""
        " -ExeName \"${vbsEscape(exeName)}\""
        " -WaitPid $pid"
        " -Version \"${vbsEscape(version)}\""
        " -ShowResult";

    final vbsFile = File(p.join(
      Directory.systemTemp.path,
      'maran_run_update_${DateTime.now().millisecondsSinceEpoch}.vbs',
    ));
    final vbsContent =
        "Set sh = CreateObject(\"WScript.Shell\")\r\n"
        "sh.Run \"${vbsEscape(psCommand)}\", 1, False\r\n";
    await vbsFile.writeAsString(vbsContent, flush: true);

    await UpdateLogger.log(
      'Launching updater via wscript vbs=${vbsFile.path} '
      'installDir=$installDir waitPid=$pid cmd=$psCommand',
    );

    await Process.start(
      'wscript.exe',
      [vbsFile.path],
      workingDirectory: Directory.systemTemp.path,
      mode: ProcessStartMode.detached,
    );

    // Give WScript time to spawn PowerShell outside Flutter's process tree.
    await Future<void>.delayed(const Duration(milliseconds: 2000));
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
