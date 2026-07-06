import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import 'emr_pet_hub.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _search = TextEditingController();
  List<PetSearchResult> _patients = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, dynamic>{'per_page': 50};
      if (search != null && search.trim().length >= 2) {
        query['search'] = search.trim();
      }
      final list = await context.read<AppServices>().emr.listPets(query: query);
      if (mounted) setState(() => _patients = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addLedgerEntry(PetSearchResult pet) async {
    final noteCtrl = TextEditingController();
    var type = 'medical';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ledger entry — ${pet.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Entry type'),
                items: const [
                  DropdownMenuItem(value: 'medical', child: Text('Medical')),
                  DropdownMenuItem(value: 'growth', child: Text('Growth')),
                  DropdownMenuItem(value: 'grooming', child: Text('Grooming')),
                  DropdownMenuItem(value: 'behavioral', child: Text('Behavioral')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (v) => type = v ?? 'medical',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Note'),
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
    if (saved != true || noteCtrl.text.trim().isEmpty || !mounted) return;
    try {
      await context.read<AppServices>().emr.addPetNote(pet.id, {
        'type': type,
        'note': noteCtrl.text.trim(),
      });
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Ledger entry added')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient List',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Registered pets with owner details',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search patient, owner, phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              _load();
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    if (v.length >= 2 || v.isEmpty) _load(search: v);
                  },
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(search: _search.text),
              child: _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text(_error!)),
                        ),
                      ],
                    )
                  : _patients.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('No patients found')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _patients.length,
                          itemBuilder: (context, i) {
                            final p = _patients[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                leading: const Icon(Icons.pets, color: AppTheme.primary),
                                title: Text(p.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  [
                                    if (p.species != null) p.species,
                                    if (p.breed != null) p.breed,
                                    if (p.customerName != null) 'Owner: ${p.customerName}',
                                  ].whereType<String>().join(' · '),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        EmrPetHub(petId: p.id, petName: p.name),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            if (p.customerId > 0)
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    context.push('/customers/${p.customerId}'),
                                                icon: const Icon(Icons.person_outline, size: 18),
                                                label: const Text('View owner'),
                                              ),
                                            OutlinedButton.icon(
                                              onPressed: () => _addLedgerEntry(p),
                                              icon: const Icon(Icons.note_add_outlined, size: 18),
                                              label: const Text('Add note'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
