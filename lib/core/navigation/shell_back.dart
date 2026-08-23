import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Parent list/detail path for nested shell routes (detail, edit, new, modules).
/// Returns null for top-level list pages that should not show a back control.
String? shellParentPath(String location) {
  final path = Uri.tryParse(location)?.path ?? location.split('?').first;

  if (path.startsWith('/settings/') && path != '/settings') {
    return '/settings';
  }

  if (path == '/products/new' || path == '/products/datasheet') {
    return '/products';
  }
  if (RegExp(r'^/products/\d+/edit$').hasMatch(path)) {
    return '/products';
  }

  final invoiceReturn = RegExp(r'^/invoices/(\d+)/return$').firstMatch(path);
  if (invoiceReturn != null) {
    return '/invoices/${invoiceReturn[1]}';
  }
  if (RegExp(r'^/invoices/\d+$').hasMatch(path)) {
    return '/invoices';
  }

  if (path == '/emr/visits/new') return '/emr/visits';
  final visitEdit = RegExp(r'^/emr/visits/(\d+)/edit$').firstMatch(path);
  if (visitEdit != null) {
    return '/emr/visits/${visitEdit[1]}';
  }
  if (RegExp(r'^/emr/visits/\d+$').hasMatch(path)) {
    return '/emr/visits';
  }

  if (path == '/emr/appointments/new') return '/emr/appointments';
  if (RegExp(r'^/emr/appointments/\d+/edit$').hasMatch(path)) {
    return '/emr/appointments';
  }

  if (path == '/customers/new') return '/customers';
  if (RegExp(r'^/customers/\d+$').hasMatch(path)) {
    return '/customers';
  }

  if (path == '/purchases/new') return '/purchases';
  if (RegExp(r'^/purchases/\d+$').hasMatch(path)) {
    return '/purchases';
  }

  if (path == '/purchase-returns/new') return '/purchase-returns';
  if (RegExp(r'^/purchase-returns/\d+$').hasMatch(path)) {
    return '/purchase-returns';
  }

  if (path == '/stock-transfers/new') return '/stock-transfers';
  if (RegExp(r'^/stock-transfers/\d+$').hasMatch(path)) {
    return '/stock-transfers';
  }

  if (RegExp(
    r'^/emr/pets/\d+/(timeline|visit-summary|deworming|surgeries|lab-reports|documents)$',
  ).hasMatch(path)) {
    return '/patients';
  }

  return null;
}

bool shellShowsBack(String location) => shellParentPath(location) != null;

/// Pop when possible; otherwise go to the parent list/detail route.
void navigateShellBack(BuildContext context, String location) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final parent = shellParentPath(location);
  if (parent != null) {
    context.go(parent);
  }
}

/// Compact back control for the shell header (desktop + mobile AppBar).
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({
    super.key,
    required this.location,
    this.compact = false,
  });

  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => navigateShellBack(context, location),
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      visualDensity: compact ? VisualDensity.compact : null,
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
