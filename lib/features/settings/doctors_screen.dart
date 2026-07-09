import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _search = TextEditingController();
  List<Doctor> _doctors = [];
  bool _loading = false;

  static const _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final query = <String, dynamic>{};
      if (_search.text.trim().isNotEmpty) query['search'] = _search.text.trim();
      final list = await context.read<AppServices>().doctors.list(query: query);
      if (mounted) setState(() => _doctors = list);
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAvailability(Doctor d) async {
    try {
      await context.read<AppServices>().doctors.toggleAvailability(d.id);
      _load();
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDelete(Doctor d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${d.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().doctors.delete(d.id);
      _load();
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openForm({Doctor? doctor}) async {
    final isEdit = doctor != null;
    final name = TextEditingController(text: doctor?.name ?? '');
    final email = TextEditingController(text: doctor?.email ?? '');
    final phone = TextEditingController(text: doctor?.phone ?? '');
    final password = TextEditingController();
    final passwordConfirm = TextEditingController();
    final specialty = TextEditingController(text: doctor?.specialty ?? '');
    final license = TextEditingController(text: doctor?.licenseNumber ?? '');
    final fee = TextEditingController(
      text: doctor?.consultationFee?.toString() ?? '',
    );
    final bio = TextEditingController(text: doctor?.bio ?? '');
    var selectedDays = Set<String>.from(doctor?.availableDays ?? []);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdit ? 'Edit Doctor' : 'Add Doctor',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: email,
                  readOnly: isEdit,
                  decoration: const InputDecoration(labelText: 'Email *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordConfirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm password *'),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: specialty,
                  decoration: const InputDecoration(labelText: 'Specialty'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: license,
                  decoration: const InputDecoration(labelText: 'License number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Consultation fee (₹)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bio,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 12),
                const Text('Available days'),
                Wrap(
                  spacing: 6,
                  children: _weekDays.map((day) {
                    final selected = selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day),
                      selected: selected,
                      onSelected: (_) {
                        setSheet(() {
                          if (selected) {
                            selectedDays.remove(day);
                          } else {
                            selectedDays.add(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isEdit ? 'Update' : 'Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty || email.text.trim().isEmpty) return;
    if (!isEdit && (password.text.isEmpty || password.text != passwordConfirm.text)) {
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Passwords must match')),
        );
      }
      return;
    }

    final body = <String, dynamic>{
      'name': name.text.trim(),
      'email': email.text.trim(),
      if (phone.text.isNotEmpty) 'phone': phone.text.trim(),
      if (specialty.text.isNotEmpty) 'specialty': specialty.text.trim(),
      if (license.text.isNotEmpty) 'license_number': license.text.trim(),
      if (fee.text.isNotEmpty) 'consultation_fee': double.tryParse(fee.text) ?? 0,
      if (bio.text.isNotEmpty) 'bio': bio.text.trim(),
      if (selectedDays.isNotEmpty) 'available_days': selectedDays.toList(),
      if (!isEdit) ...{
        'password': password.text,
        'password_confirmation': passwordConfirm.text,
      },
      if (isEdit && password.text.isNotEmpty) ...{
        'password': password.text,
        'password_confirmation': passwordConfirm.text.isNotEmpty
            ? passwordConfirm.text
            : password.text,
      },
    };

    try {
      final svc = context.read<AppServices>().doctors;
      if (isEdit) {
        await svc.updateProfile(doctor.id, body);
      } else {
        await svc.create(body);
      }
      if (mounted) {
        AppMessenger.show(context,
          SnackBar(content: Text(isEdit ? 'Doctor updated' : 'Doctor created')),
        );
        _load();
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
    final canManage = context.watch<AuthSession>().hasPermission('doctors.manage');

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add doctor'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doctor Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 4),
                const Text('Manage doctors and clinic profiles',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search name, email, specialty...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _load,
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _doctors.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No doctors found')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _doctors.length,
                      itemBuilder: (context, i) {
                        final d = _doctors[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      child: Text(d.name.isNotEmpty
                                          ? d.name[0].toUpperCase()
                                          : '?'),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16)),
                                          if (d.specialty != null)
                                            Text(d.specialty!,
                                                style: const TextStyle(
                                                    color: AppTheme.textSecondary)),
                                          Text(d.email,
                                              style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    if (d.licenseNumber != null)
                                      Text('License: ${d.licenseNumber}',
                                          style: const TextStyle(fontSize: 12)),
                                    if (d.experienceYears != null)
                                      Text('${d.experienceYears} yrs exp',
                                          style: const TextStyle(fontSize: 12)),
                                    if (d.consultationFee != null)
                                      Text('₹${d.consultationFee}',
                                          style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                if (d.availableDays.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 4,
                                    children: d.availableDays
                                        .map((day) => Chip(
                                              label: Text(day),
                                              visualDensity: VisualDensity.compact,
                                            ))
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ActionChip(
                                      label: Text(d.isAvailable ? 'Available' : 'Unavailable'),
                                      onPressed: canManage
                                          ? () => _toggleAvailability(d)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(d.isActive ? 'Active' : 'Inactive'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const Spacer(),
                                    if (canManage) ...[
                                      TextButton(
                                        onPressed: () => _openForm(doctor: d),
                                        child: const Text('Edit'),
                                      ),
                                      TextButton(
                                        onPressed: () => _confirmDelete(d),
                                        child: const Text('Remove',
                                            style: TextStyle(color: AppTheme.danger)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
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
