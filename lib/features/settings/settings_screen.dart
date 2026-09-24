import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/shop.dart';
import 'widgets/loyalty_settings_section.dart';
import 'widgets/pos_desktop_settings_section.dart';
import 'widgets/visit_summary_printer_settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canManage =
        context.watch<AuthSession>().hasPermission(AppPermissions.shopManage);

    return FutureBuilder<Shop>(
      future: context.read<AppServices>().shop.get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: Text('Shop not found'));
        }
        final s = snap.data!;
        final loyalty = s.settings ?? ShopSettings();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Currency'),
                    trailing: Text(s.currency),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Timezone'),
                    trailing: Text(s.timezone),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('GSTIN'),
                    trailing: Text(s.gstin ?? '—'),
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading:
                    const Icon(Icons.shield_outlined, color: AppTheme.primary),
                title: const Text('Account Security',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Change your password and PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/settings/security'),
              ),
            ),
            if (context.watch<AuthSession>().isSuperAdmin)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined,
                      color: AppTheme.primary),
                  title: const Text('Subscription & Plans',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle:
                      const Text('Current plan, features and upgrade options'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/settings/subscription'),
                ),
              ),
            if (canManage) LoyaltySettingsSection(initial: loyalty),
            if (AppConfig.isCashierPlatform || AppConfig.usesLargeUiScale) ...[
              const PosDesktopSettingsSection(),
              const VisitSummaryPrinterSettingsSection(),
            ],
          ],
        );
      },
    );
  }
}
