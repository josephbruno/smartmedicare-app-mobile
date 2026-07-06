import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../services/permission_service.dart';
import '../session/auth_session.dart';

/// Extension on BuildContext to easily check permissions.
extension PermissionContextExtension on BuildContext {
  /// Get the current user from auth session.
  AuthSession get authSession => read<AuthSession>();

  /// Check if user has a specific permission.
  bool hasPermission(String permission) {
    final auth = read<AuthSession>();
    return PermissionService.hasPermission(
      auth.user?.permissions ?? [],
      permission,
    );
  }

  /// Check if user has ANY of the permissions.
  bool hasAnyPermission(List<String> permissions) {
    final auth = read<AuthSession>();
    return PermissionService.hasAnyPermission(
      auth.user?.permissions ?? [],
      permissions,
    );
  }

  /// Check if user has ALL of the permissions.
  bool hasAllPermissions(List<String> permissions) {
    final auth = read<AuthSession>();
    return PermissionService.hasAllPermissions(
      auth.user?.permissions ?? [],
      permissions,
    );
  }

  /// Check if user has a specific role.
  bool hasRole(String role) {
    final auth = read<AuthSession>();
    return PermissionService.hasRole(
      auth.user?.roles ?? [],
      role,
    );
  }

  /// Check if user has ANY of the roles.
  bool hasAnyRole(List<String> roles) {
    final auth = read<AuthSession>();
    return PermissionService.hasAnyRole(
      auth.user?.roles ?? [],
      roles,
    );
  }

  /// Check if user is super admin.
  bool get isSuperAdmin {
    final auth = read<AuthSession>();
    return PermissionService.isSuperAdmin(auth.user?.roles ?? []);
  }

  /// Show a permission denied snackbar.
  void showPermissionDenied({String? message}) {
    AppMessenger.show(
      this,
      SnackBar(
        content: Text(message ?? 'You do not have permission to perform this action.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show a permission denied dialog.
  Future<void> showPermissionDeniedDialog({
    String title = 'Access Denied',
    String? message,
  }) {
    return showDialog<void>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message ?? 'You do not have permission to access this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Extension on widgets for permission checking.
extension PermissionWidgetExtension on Widget {
  /// Wrap this widget with permission guard.
  Widget withPermission(
    String permission, {
    Widget? fallback,
  }) {
    return _PermissionGuardWrapper(
      permission: permission,
      child: this,
      fallback: fallback,
    );
  }
}

class _PermissionGuardWrapper extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;

  const _PermissionGuardWrapper({
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (context.hasPermission(permission)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
