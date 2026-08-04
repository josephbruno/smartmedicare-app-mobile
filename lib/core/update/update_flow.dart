import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../messaging/app_messenger.dart';
import 'update_models.dart';
import 'update_service.dart';

/// Runs Windows update check + UI after the first frame.
Future<void> runWindowsUpdateFlow(BuildContext context) async {
  if (kIsWeb || !Platform.isWindows) return;
  if (kDebugMode) return; // release / profile builds only
  if (!AppConfig.enableWindowsAutoUpdate) return;

  final service = UpdateService();
  if (!service.isSupported) return;

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

  await _downloadAndInstall(context, service, check);
}

Future<bool?> _showOptionalDialog(BuildContext context, UpdateCheckResult check) {
  final notes = check.releaseNotes?.trim().isNotEmpty == true
      ? check.releaseNotes!
      : 'A new version of Maran Billing is available.';
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text('Update available (v${check.version})'),
      content: Text(
        '$notes\n\n'
        'If the app is installed under Program Files, Windows may ask for '
        'permission (UAC) — click Yes.\n'
        'If installed under AppData (recommended), no admin permission is needed.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update now')),
      ],
    ),
  );
}

Future<bool?> _showMandatoryDialog(BuildContext context, UpdateCheckResult check) {
  return showDialog<bool>(
    context: context,
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

  showDialog<void>(
    context: context,
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
    if (context.mounted && !closed) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await service.launchUpdaterAndExit(
      zipFile: file,
      version: check.version ?? '',
    );
  } on UpdateException catch (e) {
    if (context.mounted && !closed) {
      Navigator.of(context, rootNavigator: true).pop();
      final retry = await showDialog<bool>(
        context: context,
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
      Navigator.of(context, rootNavigator: true).pop();
      AppMessenger.error(context, 'Download failed: ${e.message}');
    }
  } finally {
    progress.dispose();
  }
}
