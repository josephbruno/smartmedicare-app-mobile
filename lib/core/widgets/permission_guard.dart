import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../session/auth_session.dart';

/// Widget that shows content only if user has required permission.
/// Otherwise shows a fallback widget (default: 403 error).
class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final bool Function()? additionalCheck;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.additionalCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        final allowed = auth.hasPermission(permission);
        final additionalCheckPassed = additionalCheck?.call() ?? true;

        if (allowed && additionalCheckPassed) {
          return child;
        }

        return fallback ?? _PermissionDeniedWidget(homeRoute: auth.homeRoute);
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
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
    this.requireAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        final allowed = requireAll
            ? permissions.every(auth.hasPermission)
            : permissions.any(auth.hasPermission);

        if (allowed) {
          return child;
        }

        return fallback ?? _PermissionDeniedWidget(homeRoute: auth.homeRoute);
      },
    );
  }
}

/// Guard with a custom allow predicate.
class AccessGuard extends StatelessWidget {
  const AccessGuard({
    super.key,
    required this.allow,
    required this.child,
    this.fallback,
  });

  final bool Function(AuthSession auth) allow;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        if (allow(auth)) return child;
        return fallback ?? _PermissionDeniedWidget(homeRoute: auth.homeRoute);
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
    super.key,
    required this.role,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        if (auth.hasRole(role)) {
          return child;
        }

        return fallback ?? _PermissionDeniedWidget(homeRoute: auth.homeRoute);
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
    super.key,
    required this.roles,
    required this.child,
    this.fallback,
    this.requireAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSession>(
      builder: (context, auth, _) {
        final allowed = requireAll
            ? roles.every(auth.hasRole)
            : roles.any(auth.hasRole);

        if (allowed) {
          return child;
        }

        return fallback ?? _PermissionDeniedWidget(homeRoute: auth.homeRoute);
      },
    );
  }
}

/// Default permission denied widget.
class _PermissionDeniedWidget extends StatelessWidget {
  const _PermissionDeniedWidget({required this.homeRoute});

  final String homeRoute;

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
              onPressed: () => context.go(homeRoute),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
