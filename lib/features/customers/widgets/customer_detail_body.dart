import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../data/models/customer.dart';
import '../../emr/emr_pet_hub.dart';

/// Reusable customer detail (list pane or full page).
class CustomerDetailBody extends StatelessWidget {
  const CustomerDetailBody({super.key, required this.id, this.compact = false});

  final int id;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Customer>(
      future: context.read<AppServices>().customers.get(id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: Text('Customer not found'));
        }
        final c = snap.data!;
        return ListView(
          padding: EdgeInsets.all(compact ? 12 : 16),
          children: [
            Text(c.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            SelectableText(c.phone),
            if (c.email != null) SelectableText(c.email!),
            if (c.city != null) ...[
              const SizedBox(height: 4),
              Text(c.city!, style: const TextStyle(color: Colors.grey)),
            ],
            if ((c.outstandingBalance ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Outstanding: ₹${c.outstandingBalance!.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ],
            if (c.pets != null && c.pets!.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Pets', style: Theme.of(context).textTheme.titleMedium),
              ...c.pets!.map(
                (p) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.pets),
                          title: Text(p.name),
                          subtitle: Text(
                            [p.species, p.breed, p.gender]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(' · '),
                          ),
                        ),
                        EmrPetHub(petId: p.id, petName: p.name),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
