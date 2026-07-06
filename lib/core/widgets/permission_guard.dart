import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/permission_service.dart';
import '../session/auth_session.dart';

/// Widget that shows content only if user has required permission.
/// Otherwise shows a fallback widget (default: 403 error).
class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final bool Function()? additionalCheck;

  const PermissionGuard({
    Key? key,
    required this.permission,
    required this.child,
    this.fallback,
    this.additionalCheck,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        final hasPermission = PermissionService.hasPermission(
          auth.user?.permissions ?? [],
          permission,
        );

        final additionalCheckPassed = additionalCheck?.call() ?? true;

        if (hasPermission && additionalCheckPassed) {
          return child;
        }

        return fallback ?? const _PermissionDeniedWidget();
      },
    );
  }
}

/// Guard for multiple permissions (ANY of them).
class MultiPermissionGuard extends StatelessWidget {
  final List<String> permissions;
  final Widget child;
  final Widget? fallback;
  final bool requireAll;

  const MultiPermissionGuard({
    Key? key,
    required this.permissions,
    required this.child,
    this.fallback,
    this.requireAll = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        final hasPermission = requireAll
            ? PermissionService.hasAllPermissions(
                auth.user?.permissions ?? [],
                permissions,
              )
            : PermissionService.hasAnyPermission(
                auth.user?.permissions ?? [],
                permissions,
              );

        if (hasPermission) {
          return child;
        }

        return fallback ?? const _PermissionDeniedWidget();
      },
    );
  }
}

/// Guard based on role.
class RoleGuard extends StatelessWidget {
  final String role;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    Key? key,
    required this.role,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        final hasRole = PermissionService.hasRole(
          auth.user?.roles ?? [],
          role,
        );

        if (hasRole) {
          return child;
        }

        return fallback ?? const _PermissionDeniedWidget();
      },
    );
  }
}

/// Guard for multiple roles (ANY of them).
class MultiRoleGuard extends StatelessWidget {
  final List<String> roles;
  final Widget child;
  final Widget? fallback;
  final bool requireAll;

  const MultiRoleGuard({
    Key? key,
    required this.roles,
    required this.child,
    this.fallback,
    this.requireAll = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        final hasRole = requireAll
            ? PermissionService.hasAllPermissions(
                auth.user?.roles ?? [],
                roles,
              )
            : PermissionService.hasAnyRole(
                auth.user?.roles ?? [],
                roles,
              );

        if (hasRole) {
          return child;
        }

        return fallback ?? const _PermissionDeniedWidget();
      },
    );
  }
}

/// Default permission denied widget.
class _PermissionDeniedWidget extends StatelessWidget {
  const _PermissionDeniedWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'You do not have permission',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'to access this feature.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
