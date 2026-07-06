import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/shop.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Shop>(
      future: context.read<AppServices>().shop.get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final s = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.name, style: Theme.of(context).textTheme.headlineSmall),
            ListTile(title: const Text('Currency'), trailing: Text(s.currency)),
            ListTile(title: const Text('Timezone'), trailing: Text(s.timezone)),
            ListTile(title: const Text('GSTIN'), subtitle: Text(s.gstin ?? '-')),
          ],
        );
      },
    );
  }
}
