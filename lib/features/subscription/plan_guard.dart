import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/messaging/app_messenger.dart';
import '../../core/session/auth_session.dart';

const _resourceLabels = {'users': 'users', 'branches': 'branches', 'products': 'products'};

/// Checks the subscription plan before an "Add …" form opens, so the user learns about
/// a missing module or a full limit up front. The API enforces the same rules
/// (PLAN_UPGRADE_REQUIRED / PLAN_LIMIT_REACHED); if the check can't load, we allow.
Future<bool> ensurePlanAllows(
  BuildContext context, {
  String? capability,
  String? capabilityLabel,
  String? limitResource,
}) async {
  final auth = context.read<AuthSession>();

  if (capability != null && !auth.hasCapability(capability)) {
    _notice(context, auth,
        '${capabilityLabel ?? 'This'} is not included in your current plan. Upgrade to use it.');
    return false;
  }

  if (limitResource != null) {
    try {
      final sub = await context.read<AppServices>().subscription.get();
      if (!context.mounted) return false;
      if (sub.atLimit(limitResource)) {
        final plan = sub.planName != null ? ' on the ${sub.planName} plan' : '';
        _notice(context, auth,
            "You've used ${sub.usage[limitResource]} of ${sub.limits[limitResource]} "
            '${_resourceLabels[limitResource] ?? limitResource}$plan. Upgrade your plan to add more.');
        return false;
      }
    } catch (_) {
      // Offline / transient: let the form open; the server still enforces the limit.
    }
  }
  return context.mounted;
}

void _notice(BuildContext context, AuthSession auth, String message) {
  AppMessenger.show(
    context,
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: auth.isSuperAdmin
          ? SnackBarAction(
              label: 'View plans',
              onPressed: () => context.go('/settings/subscription'),
            )
          : null,
    ),
  );
}
