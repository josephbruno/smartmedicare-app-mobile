import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../messaging/app_messenger.dart';
import '../network/network_resilience.dart';
import 'android_apk_installer.dart';
import 'update_models.dart';
import 'update_service.dart';
import 'windows_update_gate.dart';

/// Whether cold-start auto-update check runs on this build/platform.
bool shouldRunAppUpdateFlow() {
  if (kIsWeb) return false;
  if (kDebugMode) return false;
  if (Platform.isWindows && AppConfig.enableWindowsAutoUpdate) {
    return UpdateService().isSupported;
  }
  if (Platform.isAndroid && AppConfig.enableAndroidAutoUpdate) {
    return UpdateService().isSupported;
  }
  return false;
}

/// Runs update check + UI after the first frame (Windows ZIP or Android APK).
///
/// While an update prompt or download is active, [WindowsUpdateGate] blocks
/// splash from navigating to login/dashboard so the download is not skipped.
Future<void> runAppUpdateFlow(BuildContext context) async {
  if (!shouldRunAppUpdateFlow()) {
    WindowsUpdateGate.instance.release();
    return;
  }

  final service = UpdateService();
  final gate = WindowsUpdateGate.instance;
  gate.acquire();
  try {
    final prev = await service.consumeLastResult();
    if (prev != null && context.mounted) {
      final ok = prev['ok'] == true;
      final msg = prev['message']?.toString() ??
          (ok ? 'Application updated successfully.' : 'Previous update failed.');
      if (ok) {
        AppMessenger.success(context, msg);
      } else {
        AppMessenger.error(context, msg);
      }
    }

    UpdateCheckResult check;
    try {
      check = await service.checkForUpdate();
    } catch (_) {
      // Soft-fail on optional network issues at startup.
      return;
    }

    if (!check.updateAvailable) return;
    if (check.package == null) return;
    if (!context.mounted) return;

    final bool? proceed;
    if (check.mandatory) {
      proceed = await _showMandatoryDialog(context, check);
    } else {
      proceed = await _showOptionalDialog(context, check);
    }

    if (proceed != true) return;
    if (!context.mounted) return;

    // Stay blocking through download / app exit.
    await _downloadAndInstall(context, service, check);
  } finally {
    // If the app is exiting for install, this is a no-op for navigation.
    gate.release();
  }
}

Future<bool?> _showOptionalDialog(BuildContext context, UpdateCheckResult check) {
  final notes = check.releaseNotes?.trim().isNotEmpty == true
      ? check.releaseNotes!
      : 'A new version of Maran Billing is available.';
  final extra = Platform.isAndroid
      ? 'The Android installer will open after the download. '
          'If asked, allow Maran Billing to install unknown apps.'
      : 'If the app is installed under Program Files, Windows may ask for '
          'permission (UAC) — click Yes.\n'
          'If installed under AppData (recommended), no admin permission is needed.';
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Update available (v${check.version})'),
        content: Text('$notes\n\n$extra'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update now')),
        ],
      ),
    ),
  );
}

Future<bool?> _showMandatoryDialog(BuildContext context, UpdateCheckResult check) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Required update (v${check.version})'),
        content: Text(
          check.releaseNotes?.trim().isNotEmpty == true
              ? check.releaseNotes!
              : 'You must install this update to continue using Maran Billing.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update now')),
        ],
      ),
    ),
  );
}

Future<void> _downloadAndInstall(
  BuildContext context,
  UpdateService service,
  UpdateCheckResult check,
) async {
  final progress = ValueNotifier<double>(0);
  final cancel = CancelToken();
  var closed = false;
  var progressVisible = true;

  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Downloading update'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: value.clamp(0, 1)),
                const SizedBox(height: 12),
                Text('${(value * 100).clamp(0, 100).toStringAsFixed(0)}%'),
              ],
            );
          },
        ),
        actions: [
          if (!check.mandatory)
            TextButton(
              onPressed: () {
                cancel.cancel('Cancelled by user');
                closed = true;
                progressVisible = false;
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
        ],
      ),
    ),
  );

  try {
    final file = await service.downloadPackage(
      check.package!,
      cancelToken: cancel,
      onProgress: (p) => progress.value = p,
    );
    if (context.mounted && !closed && progressVisible) {
      Navigator.of(context, rootNavigator: true).pop();
      progressVisible = false;
    }
    if (Platform.isAndroid) {
      if (!context.mounted) return;
      final allowed = await _ensureAndroidInstallPermission(context, check.mandatory);
      if (!allowed) {
        if (check.mandatory && context.mounted) {
          await _showMandatoryDialog(context, check);
          if (context.mounted) {
            await _downloadAndInstall(context, service, check);
          }
        }
        return;
      }
      if (!context.mounted) return;
      await service.launchAndroidInstaller(file);
      return;
    }
    await service.launchUpdaterAndExit(
      zipFile: file,
      version: check.version ?? '',
    );
  } on UpdateException catch (e) {
    if (context.mounted && !closed) {
      if (progressVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        progressVisible = false;
      }
      final retry = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: const Text('Update failed'),
          content: Text(e.message),
          actions: [
            if (!check.mandatory)
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retry')),
          ],
        ),
      );
      if (retry == true && context.mounted) {
        await _downloadAndInstall(context, service, check);
      } else if (check.mandatory && context.mounted) {
        await _showMandatoryDialog(context, check);
        if (context.mounted) {
          await _downloadAndInstall(context, service, check);
        }
      }
    }
  } on DioException catch (e) {
    if (cancel.isCancelled) return;
    if (context.mounted && !closed) {
      if (progressVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        progressVisible = false;
      }
      AppMessenger.error(
        context,
        humanizeNetworkError(e),
      );
    }
  } finally {
    progress.dispose();
  }
}

Future<bool> _ensureAndroidInstallPermission(BuildContext context, bool mandatory) async {
  if (await AndroidApkInstaller.canInstallPackages()) return true;
  if (!context.mounted) return false;

  final proceed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Allow app installs'),
        content: const Text(
          'Android must allow Maran Billing to install updates. '
          'On the next screen, enable “Allow from this source”, then return here.',
        ),
        actions: [
          if (!mandatory)
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
        ],
      ),
    ),
  );

  if (proceed != true) return false;

  await AndroidApkInstaller.openUnknownSourcesSettings();
  final granted = await _waitForAndroidInstallPermission();
  if (granted) return true;

  if (!context.mounted) return false;
  if (mandatory) {
    return _ensureAndroidInstallPermission(context, mandatory);
  }

  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Install not allowed'),
      content: const Text(
        'Maran Billing is not allowed to install updates yet. '
        'Enable “Allow from this source” and try again.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
  return false;
}

Future<bool> _waitForAndroidInstallPermission() async {
  if (await AndroidApkInstaller.canInstallPackages()) return true;

  final completer = Completer<bool>();
  Timer? poll;
  late final AppLifecycleListener listener;

  Future<void> finish(bool value) async {
    if (completer.isCompleted) return;
    completer.complete(value);
  }

  listener = AppLifecycleListener(
    onResume: () {
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await finish(await AndroidApkInstaller.canInstallPackages());
      }());
    },
  );

  poll = Timer.periodic(const Duration(seconds: 1), (_) {
    unawaited(() async {
      if (await AndroidApkInstaller.canInstallPackages()) {
        await finish(true);
      }
    }());
  });

  try {
    return await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => AndroidApkInstaller.canInstallPackages(),
    );
  } finally {
    poll.cancel();
    listener.dispose();
  }
}
