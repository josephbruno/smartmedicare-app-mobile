import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/customer.dart';
import '../../data/models/emr.dart';
import '../customers/widgets/pet_form_sheet.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _search = TextEditingController();
  String? _speciesFilter;
  String? _genderFilter;
  String _statusFilter = 'all';
  int _reloadToken = 0;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  bool? get _isActiveFilter {
    return switch (_statusFilter) {
      'active' => true,
      'inactive' => false,
      _ => null,
    };
  }

  InputDecoration get _filterDec => const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Future<void> _addPatient() async {
    final auth = context.read<AuthSession>();
    final customer = await showDialog<Customer>(
      context: context,
      builder: (ctx) => const _PickCustomerDialog(),
    );
    if (!context.mounted || customer == null) return;

    bool saved;
    if (auth.isHuman) {
      saved = await _showHumanPatientForm(customer);
    } else {
      if (!mounted) return;
      saved = await showPetFormSheet(context, customerId: customer.id);
    }
    if (!mounted || !saved) return;
    AppMessenger.success(context, 'Patient added');
    setState(() => _reloadToken++);
  }

  Future<bool> _showHumanPatientForm(Customer customer) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _HumanPatientDialog(customer: customer),
    );
    if (!mounted || data == null) return false;

    try {
      await context.read<AppServices>().customers.createPatient(data);
      return true;
    } catch (error) {
      if (mounted) {
        AppMessenger.error(context, 'Unable to create patient: $error');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.customersCreate);
    final search = _search.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search patients by name or owner…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 10),
                if (auth.isVeterinary) ...[
                  SizedBox(
                    width: 140,
                    child: AppDropdownButtonFormField<String?>(
                      value: _speciesFilter,
                      isDense: true,
                      decoration: _filterDec.copyWith(labelText: 'Species'),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('All species')),
                        DropdownMenuItem(value: 'dog', child: Text('Dog')),
                        DropdownMenuItem(value: 'cat', child: Text('Cat')),
                        DropdownMenuItem(value: 'bird', child: Text('Bird')),
                        DropdownMenuItem(value: 'fish', child: Text('Fish')),
                        DropdownMenuItem(
                            value: 'rabbit', child: Text('Rabbit')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _speciesFilter = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: AppDropdownButtonFormField<String?>(
                    value: _genderFilter,
                    isDense: true,
                    decoration: _filterDec.copyWith(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All genders')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(
                          value: 'unknown', child: Text('Unknown')),
                    ],
                    onChanged: (v) => setState(() => _genderFilter = v),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: AppDropdownButtonFormField<String>(
                    value: _statusFilter,
                    isDense: true,
                    decoration: _filterDec.copyWith(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _statusFilter = v);
                    },
                  ),
                ),
                if (canCreate) ...[
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _addPatient,
                    child: const Text('New Patient'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: AppPaginatedTable<PetSearchResult>(
              key: ValueKey(
                '$search-$_speciesFilter-$_genderFilter-$_statusFilter-$_reloadToken',
              ),
              emptyMessage: search.length >= 2 ||
                      _speciesFilter != null ||
                      _genderFilter != null ||
                      _statusFilter != 'all'
                  ? 'No patients match your filters.'
                  : 'No patients found.',
              headerFontSize: 9,
              cellFontSize: 12,
              loadPage: ({required page, required perPage}) =>
                  services.emr.listPatientsPaginated(
                page: page,
                perPage: perPage,
                search: search.length >= 2 ? search : null,
                species: _speciesFilter,
                gender: _genderFilter,
                isActive: _isActiveFilter,
              ),
              onRowTap: auth.isVeterinary
                  ? (patient) =>
                      context.push('/emr/pets/${patient.id}/timeline')
                  : null,
              columns: auth.isVeterinary
                  ? const [
                      TableColumnDef(
                          label: 'Pet', flex: 1.2, cellBuilder: _petCell),
                      TableColumnDef(
                          label: 'Species', flex: 1, cellBuilder: _speciesCell),
                      TableColumnDef(
                          label: 'Breed', flex: 1.2, cellBuilder: _breedCell),
                      TableColumnDef(
                          label: 'Owner', flex: 1.5, cellBuilder: _ownerCell),
                      TableColumnDef(
                          label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
                    ]
                  : const [
                      TableColumnDef(
                          label: 'Patient',
                          flex: 1.4,
                          cellBuilder: _humanPatientCell),
                      TableColumnDef(
                          label: 'Gender', flex: 0.8, cellBuilder: _genderCell),
                      TableColumnDef(
                          label: 'Blood Group',
                          flex: 0.8,
                          cellBuilder: _bloodGroupCell),
                      TableColumnDef(
                          label: 'Responsible Party',
                          flex: 1.5,
                          cellBuilder: _ownerCell),
                      TableColumnDef(
                          label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _petCell(BuildContext context, PetSearchResult p) => Text(
        p.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _humanPatientCell(BuildContext context, PetSearchResult p) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (p.patientNumber != null)
            Text(p.patientNumber!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
        ],
      );

  static Widget _genderCell(BuildContext context, PetSearchResult p) =>
      Text(p.gender ?? '—');

  static Widget _bloodGroupCell(BuildContext context, PetSearchResult p) =>
      Text(p.bloodGroup ?? '—');

  static Widget _speciesCell(BuildContext context, PetSearchResult p) =>
      Text(p.species ?? '—');

  static Widget _breedCell(BuildContext context, PetSearchResult p) =>
      Text(p.breed ?? '—');

  static Widget _ownerCell(BuildContext context, PetSearchResult p) =>
      Text(p.customerName ?? '—');

  static Widget _phoneCell(BuildContext context, PetSearchResult p) =>
      Text(p.phone ?? p.customerPhone ?? '—',
          style: const TextStyle(color: AppTheme.textSecondary));
}

class _HumanPatientDialog extends StatefulWidget {
  const _HumanPatientDialog({required this.customer});

  final Customer customer;

  @override
  State<_HumanPatientDialog> createState() => _HumanPatientDialogState();
}

class _HumanPatientDialogState extends State<_HumanPatientDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  String _gender = 'unknown';
  String? _bloodGroup;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _dob.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      AppMessenger.error(context, 'Patient name is required');
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'customer_id': widget.customer.id,
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'dob': _dob.text.trim().isEmpty ? null : _dob.text.trim(),
      'gender': _gender,
      'blood_group': _bloodGroup,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Human Patient'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Patient Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dob,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 12),
              AppDropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                  DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _gender = value);
                },
              ),
              const SizedBox(height: 12),
              AppDropdownButtonFormField<String?>(
                value: _bloodGroup,
                decoration: const InputDecoration(labelText: 'Blood Group'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Not specified')),
                  DropdownMenuItem(value: 'A+', child: Text('A+')),
                  DropdownMenuItem(value: 'A-', child: Text('A-')),
                  DropdownMenuItem(value: 'B+', child: Text('B+')),
                  DropdownMenuItem(value: 'B-', child: Text('B-')),
                  DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                  DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                  DropdownMenuItem(value: 'O+', child: Text('O+')),
                  DropdownMenuItem(value: 'O-', child: Text('O-')),
                ],
                onChanged: (value) => setState(() => _bloodGroup = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Responsible party: ${widget.customer.name}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create Patient')),
      ],
    );
  }
}

class _PickCustomerDialog extends StatefulWidget {
  const _PickCustomerDialog();

  @override
  State<_PickCustomerDialog> createState() => _PickCustomerDialogState();
}

class _PickCustomerDialogState extends State<_PickCustomerDialog> {
  final _search = TextEditingController();
  List<Customer> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(''));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      final list = q.trim().length >= 2
          ? await services.customers.search(q.trim())
          : (await services.customers.listPaginated(page: 1, perPage: 20))
              .items;
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select owner'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search owner by name or phone…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: (v) {
                if (v.trim().isEmpty || v.trim().length >= 2) _load(v);
              },
              onSubmitted: _load,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: AppTheme.danger)))
                      : _results.isEmpty
                          ? const Center(child: Text('No customers found.'))
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = _results[i];
                                return ListTile(
                                  title: Text(c.name),
                                  subtitle:
                                      Text(c.phone.isEmpty ? '—' : c.phone),
                                  onTap: () => Navigator.of(context).pop(c),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
