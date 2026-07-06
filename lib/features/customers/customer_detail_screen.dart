import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/customer.dart';
import '../emr/emr_pet_hub.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<Customer> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().customers.get(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Customer>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: Text('Not found'));
        }
        final c = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
            Text(c.phone),
            if (c.email != null) Text(c.email!),
            if (c.pets != null && c.pets!.isNotEmpty) ...[
              const Divider(),
              Text('Pets', style: Theme.of(context).textTheme.titleMedium),
              ...c.pets!.map(
                (p) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
