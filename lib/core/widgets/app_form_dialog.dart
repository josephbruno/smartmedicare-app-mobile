import 'package:flutter/material.dart';

import '../app_config.dart';
import '../theme/app_theme.dart';

/// Shows a dialog on the root navigator, centered in the full viewport.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.4),
    builder: builder,
  );
}

/// Whether form UIs should use a centered dialog (web/desktop/tablet).
bool useCenteredFormDialog(BuildContext context) {
  return AppConfig.usesLargeUiScale ||
      MediaQuery.sizeOf(context).width >= AppConfig.mobileCompactBreakpoint;
}

/// Shared shell for add/edit forms: header with close, scroll body, footer.
class AppFormDialogShell extends StatelessWidget {
  const AppFormDialogShell({
    super.key,
    required this.title,
    required this.onClose,
    required this.body,
    required this.footer,
    this.subtitle,
    this.icon = Icons.edit_outlined,
    this.maxWidth = 560,
    this.showHandle = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onClose;
  final Widget body;
  final Widget footer;
  final double maxWidth;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: SizedBox(
          width: maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FormHeader(
                title: title,
                subtitle: subtitle,
                icon: icon,
                onClose: onClose,
                showHandle: showHandle,
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: body,
                ),
              ),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet variant of [AppFormDialogShell] for narrow mobile layouts.
class AppFormBottomSheetShell extends StatelessWidget {
  const AppFormBottomSheetShell({
    super.key,
    required this.title,
    required this.onClose,
    required this.body,
    required this.footer,
    this.subtitle,
    this.icon = Icons.edit_outlined,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onClose;
  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FormHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    onClose: onClose,
                    showHandle: true,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: body,
                    ),
                  ),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppFormFooter extends StatelessWidget {
  const AppFormFooter({
    super.key,
    required this.primaryLabel,
    required this.onCancel,
    required this.onSubmit,
    this.saving = false,
  });

  final String primaryLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      fixedSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : onCancel,
              style: buttonStyle.copyWith(
                foregroundColor: const WidgetStatePropertyAll(AppTheme.primary),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: saving ? null : onSubmit,
              style: buttonStyle.copyWith(
                backgroundColor: const WidgetStatePropertyAll(AppTheme.primary),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
              ),
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alert-style form dialog with close (X), fixed width, and root centering.
Future<T?> showAppAlertForm<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
  double maxWidth = 480,
}) {
  return showAppDialog<T>(
    context: context,
    builder: (ctx) {
      final screenH = MediaQuery.sizeOf(ctx).height;
      return AlertDialog(
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: screenH * 0.7,
          ),
          child: SingleChildScrollView(child: content),
        ),
        actions: actions,
      );
    },
  );
}

InputDecoration appFormFieldDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
  );
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.title,
    required this.onClose,
    required this.icon,
    this.subtitle,
    this.showHandle = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onClose;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHandle) ...[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20, showHandle ? 12 : 16, 8, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }
}
