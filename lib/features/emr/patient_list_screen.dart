import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_page.dart';
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
  Timer? _searchDebounce;
  String _appliedSearch = '';
  String? _species;
  String? _gender;
  String? _status;
  String _sortBy = 'created_at';
  bool _sortAsc = false;
  int _reloadToken = 0;
  Map<String, dynamic>? _stats;

  static const _speciesOptions = {'dog': 'Dogs', 'cat': 'Cats', 'other': 'Others'};
  static const _genderOptions = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'unknown': 'Unknown',
  };
  static const _statusOptions = {
    'active': 'Active',
    'on_treatment': 'On Treatment',
    'inactive': 'Inactive',
  };
  static const _speciesEmoji = {
    'dog': '🐶', 'cat': '🐱', 'bird': '🐦', 'fish': '🐟', 'rabbit': '🐰',
    'horse': '🐴', 'cow': '🐄', 'goat': '🐐',
  };

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reloadToken++);

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _appliedSearch = v.trim();
      _reload();
    });
  }

  bool get _hasFilters =>
      _appliedSearch.isNotEmpty || _species != null || _gender != null || _status != null;

  void _reset() {
    _search.clear();
    _appliedSearch = '';
    _species = null;
    _gender = null;
    _status = null;
    _sortBy = 'created_at';
    _sortAsc = false;
    _reload();
  }

  void _onSort(String key) {
    if (_sortBy == key) {
      _sortAsc = !_sortAsc;
    } else {
      _sortBy = key;
      _sortAsc = key == 'name' || key == 'owner';
    }
    _reload();
  }

  void _toggleSpecies(String? species) {
    _species = _species == species ? null : species;
    _reload();
  }

  void _viewRow(PetSearchResult p, AuthSession auth) {
    if (auth.isVeterinary) {
      context.push('/emr/pets/${p.id}/timeline');
    } else if (p.customerId != 0) {
      context.push('/customers/${p.customerId}');
    }
  }

  Future<void> _rowMenu(String key, PetSearchResult p) async {
    switch (key) {
      case 'ledger':
        final added = await showDialog<bool>(
          context: context,
          builder: (_) => _LedgerDialog(patient: p),
        );
        if (added == true && mounted) _reload();
      case 'owner':
        context.push('/customers/${p.customerId}');
      case 'timeline':
        context.push('/emr/pets/${p.id}/timeline');
      case 'appointment':
        context.push('/emr/appointments');
      case 'copy':
        await Clipboard.setData(ClipboardData(text: p.patientNumber ?? '${p.id}'));
        if (mounted) AppMessenger.success(context, 'Copied');
    }
  }

  List<KpiData> _kpis(AuthSession auth, String title) {
    final st = _stats;
    int n(String k) => (st?[k] as num?)?.toInt() ?? 0;
    List<double> series(String k) {
      final s = st?['series'];
      if (s is Map && s[k] is List) {
        return (s[k] as List).map((e) => (e as num?)?.toDouble() ?? 0).toList();
      }
      return const [];
    }

    final total = n('total');
    String pct(int v) => '${total == 0 ? 0 : (v / total * 1000).round() / 10}% of total';
    final change = st?['change'];
    final totalCard = KpiData(
      label: 'Total $title',
      value: '$total',
      icon: auth.isHuman ? Icons.people_outline : Icons.pets,
      sub: '+${n('new_this_month')} this month${change != null ? ' · ▲ $change%' : ''}',
      subUp: n('new_this_month') > 0,
      series: series('total'),
    );
    if (!auth.isVeterinary) {
      return [
        totalCard,
        KpiData(
            label: 'On Treatment',
            value: '${n('on_treatment')}',
            icon: Icons.medical_services,
            tone: KpiTone.orange,
            sub: pct(n('on_treatment'))),
        KpiData(
            label: 'New This Month',
            value: '${n('new_this_month')}',
            icon: Icons.person_add_alt,
            tone: KpiTone.green,
            sub: 'Registered since the 1st',
            series: series('total')),
      ];
    }
    return [
      totalCard,
      KpiData(label: 'Dogs', value: '${n('dogs')}', icon: Icons.pets, tone: KpiTone.green, sub: pct(n('dogs')), series: series('dogs')),
      KpiData(label: 'Cats', value: '${n('cats')}', icon: Icons.cruelty_free_outlined, tone: KpiTone.purple, sub: pct(n('cats')), series: series('cats')),
      KpiData(label: 'Others', value: '${n('others')}', icon: Icons.eco_outlined, tone: KpiTone.orange, sub: pct(n('others')), series: series('others')),
    ];
  }

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
    final vet = auth.isVeterinary;
    final canCreate = auth.hasPermission(AppPermissions.customersCreate);
    final title = vet ? 'Pets' : 'Patients';
    final party = vet ? 'Owner' : auth.responsiblePartyLabel;
    final kpis = _kpis(auth, title);
    const speciesKeys = [null, 'dog', 'cat', 'other'];

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: title,
        subtitle: vet
            ? 'Registered pets with owner and medical details'
            : 'Registered patients and responsible-party details',
        icon: vet ? Icons.pets : Icons.people_outline,
        actions: [
          if (canCreate)
            FilledButton(
              onPressed: _addPatient,
              child: Text('Add ${vet ? 'Pet' : 'Patient'}'),
            ),
        ],
        // Species KPI cards double as quick filters (web `toggleSpecies`).
        filters: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vet)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth < 768 ? 2 : 4;
                  final w = (c.maxWidth - 12 * (cols - 1)) / cols;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    for (var i = 0; i < kpis.length; i++)
                      SizedBox(
                        width: w,
                        child: _SelectableKpi(
                          data: kpis[i],
                          active: i > 0 && _species == speciesKeys[i],
                          onTap: () => _toggleSpecies(speciesKeys[i]),
                        ),
                      ),
                  ]);
                }),
              )
            else
              KpiGrid(items: kpis),
            FilterCard(
              searchController: _search,
              searchHint:
                  'Search by ${vet ? 'pet' : 'patient'} name, ${party.toLowerCase()}, phone...',
              onSearchChanged: _onSearchChanged,
              filters: [
                if (vet)
                  FilterSelect<String>(
                    hint: 'All Species',
                    options: _speciesOptions,
                    value: _species,
                    onChanged: (v) {
                      _species = v;
                      _reload();
                    },
                  )
                else
                  FilterSelect<String>(
                    hint: 'All Genders',
                    options: _genderOptions,
                    value: _gender,
                    onChanged: (v) {
                      _gender = v;
                      _reload();
                    },
                  ),
                FilterSelect<String>(
                  hint: 'All Status',
                  options: _statusOptions,
                  value: _status,
                  onChanged: (v) {
                    _status = v;
                    _reload();
                  },
                ),
              ],
              onReset: _reset,
              resetEnabled: _hasFilters || _sortBy != 'created_at',
            ),
          ],
        ),
        body: AppPaginatedTable<PetSearchResult>(
          key: ValueKey('patients-$_reloadToken'),
          perPage: 10,
          emptyMessage: 'No ${title.toLowerCase()} found',
          loadPage: ({required page, required perPage}) =>
              services.emr.listPatientsPaginated(
            page: page,
            perPage: perPage,
            search: _appliedSearch,
            filters: {
              'species': _species,
              'gender': _gender,
              'status': _status,
              'sort_by': _sortBy,
              'sort_dir': _sortAsc ? 'asc' : 'desc',
            },
            withStats: true,
          ),
          onLoaded: (m) {
            final st = m?.stats;
            if (st != null && mounted) setState(() => _stats = st);
          },
          sortKey: _sortBy,
          sortAsc: _sortAsc,
          onSort: _onSort,
          onRowTap: (p) => _viewRow(p, auth),
          columns: [
            TableColumnDef(
              label: '#',
              flex: 0.8,
              minWidth: 80,
              sortKey: 'patient_number',
              cellBuilder: (_, p) => Text(p.patientNumber ?? '#${p.id}',
                  style: const TextStyle(color: AppTokens.menuIcon)),
            ),
            TableColumnDef(
              label: vet ? 'Pet / Patient' : 'Patient',
              flex: 2,
              minWidth: 190,
              sortKey: 'name',
              cellBuilder: (_, p) => Row(children: [
                _PatientAvatar(patient: p, human: auth.isHuman, emoji: _speciesEmoji),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(p.patientNumber ?? '#${p.id}',
                          style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                    ],
                  ),
                ),
              ]),
            ),
            TableColumnDef(
              label: party,
              flex: 1.8,
              minWidth: 170,
              sortKey: 'owner',
              cellBuilder: (_, p) => Row(children: [
                const Icon(Icons.person, size: 16, color: AppTokens.placeholder),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.customerName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                      if ((p.customerPhone ?? '').isNotEmpty)
                        Text(p.customerPhone!,
                            style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                    ],
                  ),
                ),
              ]),
            ),
            if (vet) ...[
              TableColumnDef(
                label: 'Species / Breed',
                flex: 1.5,
                minWidth: 150,
                sortKey: 'species',
                cellBuilder: (_, p) {
                  final sp = (p.species ?? '').isEmpty
                      ? 'Animal'
                      : '${p.species![0].toUpperCase()}${p.species!.substring(1)}';
                  return Text((p.breed ?? '').isEmpty ? sp : '$sp / ${p.breed}',
                      maxLines: 2, overflow: TextOverflow.ellipsis);
                },
              ),
              TableColumnDef(
                label: 'Weight',
                flex: 0.8,
                minWidth: 80,
                sortKey: 'weight',
                cellBuilder: (_, p) => Text(p.weight != null && p.weight! > 0
                    ? '${p.weight!.toStringAsFixed(p.weight! % 1 == 0 ? 0 : 1)} kg'
                    : '—'),
              ),
              TableColumnDef(
                label: 'Color',
                flex: 0.9,
                minWidth: 90,
                sortKey: 'color',
                cellBuilder: (_, p) => Text(p.color ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ] else ...[
              TableColumnDef(
                label: 'Phone',
                flex: 1.2,
                minWidth: 120,
                cellBuilder: (_, p) => Text(p.phone ?? p.customerPhone ?? '—'),
              ),
              TableColumnDef(
                label: 'Blood Group',
                flex: 0.9,
                minWidth: 100,
                cellBuilder: (_, p) => Text(p.bloodGroup ?? '—'),
              ),
            ],
            TableColumnDef(
              label: 'Gender',
              flex: 0.9,
              minWidth: 100,
              sortKey: 'gender',
              cellBuilder: (_, p) {
                final g = (p.gender ?? 'unknown').toLowerCase();
                final sym = g == 'male' ? '♂ ' : g == 'female' ? '♀ ' : '';
                return StatusPill('$sym${g[0].toUpperCase()}${g.substring(1)}',
                    tone: g == 'male'
                        ? PillTone.blue
                        : g == 'female'
                            ? PillTone.purple
                            : PillTone.grey);
              },
            ),
            TableColumnDef(
              label: 'Age',
              flex: 0.8,
              minWidth: 80,
              sortKey: 'age',
              cellBuilder: (_, p) => Text(p.age ?? '—'),
            ),
            TableColumnDef(
              label: 'Status',
              flex: 1,
              minWidth: 110,
              sortKey: 'status',
              cellBuilder: (_, p) => !p.isActive
                  ? const StatusPill('Inactive', tone: PillTone.grey)
                  : p.onTreatment
                      ? const StatusPill('On Treatment', tone: PillTone.amber)
                      : const StatusPill('Active', tone: PillTone.green),
            ),
            TableColumnDef(
              label: 'Patient Ledger',
              flex: 1.6,
              minWidth: 160,
              sortKey: 'ledger',
              cellBuilder: (_, p) {
                final note = p.latestNote ?? p.medicalNotes;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: note ?? '',
                      child: Text(note ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${p.notesCount ?? 0} entries',
                        style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                  ],
                );
              },
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1.3,
              minWidth: 150,
              cellBuilder: (_, p) => Row(mainAxisSize: MainAxisSize.min, children: [
                TableIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: vet ? 'View timeline' : 'View ${party.toLowerCase()}',
                  onPressed: () => _viewRow(p, auth),
                ),
                const SizedBox(width: 8),
                TableIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  plain: true,
                  onPressed: p.customerId == 0 ? null : () => context.push('/customers/${p.customerId}'),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'More actions for ${p.name}',
                  onSelected: (k) => _rowMenu(k, p),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'ledger', child: Text('Add ledger entry')),
                    if (p.customerId != 0)
                      PopupMenuItem(value: 'owner', child: Text('View ${party.toLowerCase()}')),
                    if (vet) const PopupMenuItem(value: 'timeline', child: Text('Medical timeline')),
                    const PopupMenuItem(value: 'appointment', child: Text('New appointment')),
                    const PopupMenuItem(value: 'copy', child: Text('Copy patient ID')),
                  ],
                  child: const TableIconButton(icon: Icons.more_horiz, plain: true, onPressed: null),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableKpi extends StatelessWidget {
  const _SelectableKpi({required this.data, required this.active, required this.onTap});

  final KpiData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: active ? AppTokens.primary : Colors.transparent, width: 2),
          ),
          child: KpiCard(data: data),
        ),
      ),
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.patient, required this.human, required this.emoji});

  final PetSearchResult patient;
  final bool human;
  final Map<String, String> emoji;

  @override
  Widget build(BuildContext context) {
    final url = patient.imageUrl;
    if ((url ?? '').isNotEmpty) {
      return CircleAvatar(
        radius: 19,
        backgroundColor: AppTokens.bgTertiary,
        backgroundImage: NetworkImage(url!),
        onBackgroundImageError: (_, __) {},
      );
    }
    if (human) return InitialsAvatar(patient.name);
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFFF3E8FF),
      child: Text(emoji[(patient.species ?? '').toLowerCase()] ?? '🐾', style: const TextStyle(fontSize: 18)),
    );
  }
}

class _LedgerDialog extends StatefulWidget {
  const _LedgerDialog({required this.patient});

  final PetSearchResult patient;

  @override
  State<_LedgerDialog> createState() => _LedgerDialogState();
}

class _LedgerDialogState extends State<_LedgerDialog> {
  final _note = TextEditingController();
  String _type = 'medical';
  bool _saving = false;

  static const _types = {
    'medical': 'Medical',
    'growth': 'Growth',
    'grooming': 'Grooming',
    'behavioral': 'Behavioral',
    'general': 'General',
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_note.text.trim().isEmpty) {
      AppMessenger.error(context, 'Please enter a note');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppServices>().customers.addPetNote(widget.patient.id, type: _type, note: _note.text.trim());
      if (!mounted) return;
      AppMessenger.success(context, 'Ledger entry added');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to add entry: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Patient Ledger — ${widget.patient.name}'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldLabel('Type',
              child: FilterSelect<String>(
                hint: 'Type',
                options: _types,
                value: _type,
                onChanged: (v) => setState(() => _type = v ?? 'medical'),
              )),
          const SizedBox(height: 12),
          FieldLabel('Note',
              child: TextField(
                controller: _note,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'Add medical, growth, grooming, behavioral, or general note...'),
              )),
        ]),
      ),
      actions: [
        OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save Entry')),
      ],
    );
  }
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
