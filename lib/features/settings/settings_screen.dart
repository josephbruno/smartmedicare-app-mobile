import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../data/models/shop.dart';
import 'widgets/loyalty_settings_section.dart';
import 'widgets/pos_desktop_settings_section.dart';

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
            if (canManage) LoyaltySettingsSection(initial: loyalty),
            if (AppConfig.isCashierPlatform || AppConfig.usesLargeUiScale)
              const PosDesktopSettingsSection(),
          ],
        );
      },
    );
  }
}
