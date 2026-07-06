import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';

class DewormingManagementScreen extends StatefulWidget {
  const DewormingManagementScreen({super.key, required this.petId});

  final int petId;

  @override
  State<DewormingManagementScreen> createState() => _DewormingManagementScreenState();
}

class _DewormingManagementScreenState extends State<DewormingManagementScreen> {
  late Future<List<PetDeworming>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppServices>().emr.listDeworming(widget.petId);
  }

  Future<void> _showAddForm() async {
    final medicine = TextEditingController();
    final dosage = TextEditingController();
    final administeredBy = TextEditingController();
    final notes = TextEditingController();
    var administered = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add deworming record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medicine,
                decoration: const InputDecoration(labelText: 'Medicine *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dosage,
                decoration: const InputDecoration(labelText: 'Dosage'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: administeredBy,
                decoration: const InputDecoration(labelText: 'Administered by'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || medicine.text.trim().isEmpty || !mounted) return;

    try {
      await context.read<AppServices>().emr.addDeworming(widget.petId, {
        'medicine_name': medicine.text.trim(),
        'administered_date': administered.toIso8601String().substring(0, 10),
        if (dosage.text.isNotEmpty) 'dosage': dosage.text.trim(),
        if (administeredBy.text.isNotEmpty) 'administered_by': administeredBy.text.trim(),
        if (notes.text.isNotEmpty) 'notes': notes.text.trim(),
      });
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Deworming record added')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(PetDeworming record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emr.deleteDeworming(widget.petId, record.id);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deworming')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddForm,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<PetDeworming>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No deworming records')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                final overdue = r.nextDueDate != null &&
                    DateTime.tryParse(r.nextDueDate!)?.isBefore(DateTime.now()) == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(r.medicineName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        'Given: ${r.administeredDate}',
                        if (r.nextDueDate != null) 'Next due: ${r.nextDueDate}',
                        if (r.dosage != null) r.dosage!,
                      ].join('\n'),
                    ),
                    trailing: overdue
                        ? const Chip(
                            label: Text('Overdue', style: TextStyle(color: AppTheme.danger)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                            onPressed: () => _delete(r),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
