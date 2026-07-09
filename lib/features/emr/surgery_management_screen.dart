import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';

class SurgeryManagementScreen extends StatefulWidget {
  const SurgeryManagementScreen({super.key, required this.petId});

  final int petId;

  @override
  State<SurgeryManagementScreen> createState() => _SurgeryManagementScreenState();
}

class _SurgeryManagementScreenState extends State<SurgeryManagementScreen> {
  late Future<List<PetSurgery>> _future;
  List<DoctorLite> _doctors = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _reload();
    try {
      _doctors = await context.read<AppServices>().emr.listDoctors();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _reload() {
    _future = context.read<AppServices>().emr.listSurgeries(widget.petId);
  }

  Future<void> _showAddForm() async {
    final name = TextEditingController();
    final anesthesia = TextEditingController();
    final preOp = TextEditingController();
    final postOp = TextEditingController();
    final cost = TextEditingController();
    var date = DateTime.now();
    var status = 'scheduled';
    int? surgeonId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Add surgery record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Surgery name *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) => setDialog(() => status = v ?? 'scheduled'),
                ),
                if (_doctors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: surgeonId,
                    decoration: const InputDecoration(labelText: 'Surgeon'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— None —')),
                      ..._doctors.map(
                        (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ),
                    ],
                    onChanged: (v) => setDialog(() => surgeonId = v),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: anesthesia,
                  decoration: const InputDecoration(labelText: 'Anesthesia type'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cost'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: preOp,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Pre-op notes'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: postOp,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Post-op notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty || !mounted) return;

    try {
      await context.read<AppServices>().emr.addSurgery(widget.petId, {
        'surgery_name': name.text.trim(),
        'surgery_date': date.toIso8601String().substring(0, 10),
        'status': status,
        if (surgeonId != null) 'surgeon_id': surgeonId,
        if (anesthesia.text.isNotEmpty) 'anesthesia_type': anesthesia.text.trim(),
        if (cost.text.isNotEmpty) 'cost': double.tryParse(cost.text) ?? 0,
        if (preOp.text.isNotEmpty) 'pre_op_notes': preOp.text.trim(),
        if (postOp.text.isNotEmpty) 'post_op_notes': postOp.text.trim(),
      });
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Surgery record added')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.accent;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate =
        context.watch<AuthSession>().hasPermission(AppPermissions.emrSurgeriesCreate);

    return Scaffold(
      appBar: AppBar(title: const Text('Surgeries')),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: _showAddForm,
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<List<PetSurgery>>(
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
                  Center(child: Text('No surgery records')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final s = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(s.surgeryName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        s.surgeryDate,
                        if (s.surgeonName != null) 'Surgeon: ${s.surgeonName}',
                        if (s.cost > 0) 'Cost: ${s.cost}',
                      ].join(' · '),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(s.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(s.status, style: TextStyle(color: _statusColor(s.status))),
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
