import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../session/auth_session.dart';

/// Extension on BuildContext to easily check permissions.
extension PermissionContextExtension on BuildContext {
  /// Get the current user from auth session.
  AuthSession get authSession => read<AuthSession>();

  /// Check if user has a specific permission (respects super_admin bypass).
  bool hasPermission(String permission) => authSession.hasPermission(permission);

  /// Check if user has ANY of the permissions.
  bool hasAnyPermission(List<String> permissions) {
    return permissions.any(authSession.hasPermission);
  }

  /// Check if user has ALL of the permissions.
  bool hasAllPermissions(List<String> permissions) {
    return permissions.every(authSession.hasPermission);
  }

  /// Check if user has a specific role.
  bool hasRole(String role) => authSession.hasRole(role);

  /// Check if user has ANY of the roles.
  bool hasAnyRole(List<String> roles) {
    return roles.any(authSession.hasRole);
  }

  /// Check if user is super admin.
  bool get isSuperAdmin => authSession.isSuperAdmin;

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
