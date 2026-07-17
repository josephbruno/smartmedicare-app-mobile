import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/services/emr_master_data_service.dart';

class EmrMasterDataScreen extends StatefulWidget {
  const EmrMasterDataScreen({super.key});

  @override
  State<EmrMasterDataScreen> createState() => _EmrMasterDataScreenState();
}

class _EmrMasterDataScreenState extends State<EmrMasterDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  bool _loading = false;
  List<EmrTemplateItem> _items = [];

  static const _tabKeys = [
    'complaints',
    'diagnoses',
    'treatments',
    'medicines',
    'dosages',
    'frequencies',
  ];

  static const _tabLabels = [
    'Complaints',
    'Diagnoses',
    'Treatments',
    'Medicines',
    'Dosages',
    'Frequencies',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabKeys.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  String get _currentKey => _tabKeys[_tabs.index];

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = context.read<AppServices>().emrMasterData;
      final q = _search.text.trim();
      final list = switch (_currentKey) {
        'complaints' => await svc.listComplaints(search: q.isEmpty ? null : q),
        'diagnoses' => await svc.listDiagnoses(search: q.isEmpty ? null : q),
        'treatments' => await svc.listTreatments(search: q.isEmpty ? null : q),
        'medicines' => await svc.listMedicines(search: q.isEmpty ? null : q),
        'dosages' => await svc.listDosages(search: q.isEmpty ? null : q),
        'frequencies' => await svc.listFrequencies(search: q.isEmpty ? null : q),
        _ => <EmrTemplateItem>[],
      };
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({EmrTemplateItem? item}) async {
    final isEdit = item != null;
    final name = TextEditingController(text: item?.name ?? '');
    final label = TextEditingController(text: item?.label ?? '');
    final icd = TextEditingController(text: item?.icdCode ?? '');
    final code = TextEditingController(text: item?.procedureCode ?? '');
    final price = TextEditingController(
      text: item?.defaultPrice?.toString() ?? '',
    );
    final category = TextEditingController(text: item?.category ?? '');
    final dosage = TextEditingController(text: item?.defaultDosage ?? '');
    final frequency = TextEditingController(text: item?.defaultFrequency ?? '');
    final days = TextEditingController(
      text: item?.defaultDurationDays?.toString() ?? '',
    );
    var isActive = item?.isActive ?? true;

    final title =
        isEdit ? 'Edit ${_tabLabels[_tabs.index]}' : 'Add ${_tabLabels[_tabs.index]}';

    Widget buildFields(void Function(VoidCallback) setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_currentKey == 'dosages' || _currentKey == 'frequencies')
            TextField(
              controller: label,
              decoration: appFormFieldDecoration('Label *'),
            )
          else
            TextField(
              controller: name,
              decoration: appFormFieldDecoration('Name *'),
            ),
          if (_currentKey == 'diagnoses') ...[
            const SizedBox(height: 16),
            TextField(
              controller: icd,
              decoration: appFormFieldDecoration('ICD Code'),
            ),
          ],
          if (_currentKey == 'treatments') ...[
            const SizedBox(height: 16),
            TextField(
              controller: code,
              decoration: appFormFieldDecoration('Procedure code'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: appFormFieldDecoration('Default price'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: category,
              decoration: appFormFieldDecoration('Category'),
            ),
          ],
          if (_currentKey == 'medicines') ...[
            const SizedBox(height: 16),
            TextField(
              controller: dosage,
              decoration: appFormFieldDecoration('Default dosage'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: frequency,
              decoration: appFormFieldDecoration('Default frequency'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: appFormFieldDecoration('Default days'),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: isActive,
            onChanged: (v) => setLocal(() => isActive = v),
          ),
        ],
      );
    }

    final bool? saved;
    if (useCenteredFormDialog(context)) {
      saved = await showAppAlertForm<bool>(
        context: context,
        title: title,
        content: StatefulBuilder(
          builder: (ctx, setLocal) => buildFields(setLocal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      );
    } else {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => AppFormBottomSheetShell(
            title: title,
            icon: Icons.medical_information_outlined,
            onClose: () => Navigator.pop(ctx, false),
            body: buildFields(setSheet),
            footer: AppFormFooter(
              primaryLabel: isEdit ? 'Save' : 'Add',
              onCancel: () => Navigator.pop(ctx, false),
              onSubmit: () => Navigator.pop(ctx, true),
            ),
          ),
        ),
      );
    }

    if (saved != true || !mounted) return;

    final body = <String, dynamic>{'is_active': isActive};
    if (_currentKey == 'dosages' || _currentKey == 'frequencies') {
      body['label'] = label.text.trim();
    } else {
      body['name'] = name.text.trim();
    }
    if (_currentKey == 'diagnoses') body['icd_code'] = icd.text.trim().isEmpty ? null : icd.text.trim();
    if (_currentKey == 'treatments') {
      body['procedure_code'] = code.text.trim().isEmpty ? null : code.text.trim();
      body['default_price'] = double.tryParse(price.text);
      body['category'] = category.text.trim().isEmpty ? null : category.text.trim();
    }
    if (_currentKey == 'medicines') {
      body['default_dosage'] = dosage.text.trim().isEmpty ? null : dosage.text.trim();
      body['default_frequency'] = frequency.text.trim().isEmpty ? null : frequency.text.trim();
      body['default_duration_days'] = int.tryParse(days.text);
    }

    try {
      final svc = context.read<AppServices>().emrMasterData;
      if (isEdit && item != null) {
        switch (_currentKey) {
          case 'complaints':
            await svc.updateComplaint(item.id, body);
          case 'diagnoses':
            await svc.updateDiagnosis(item.id, body);
          case 'treatments':
            await svc.updateTreatment(item.id, body);
          case 'medicines':
            await svc.updateMedicine(item.id, body);
          case 'dosages':
            await svc.updateDosage(item.id, body);
          case 'frequencies':
            await svc.updateFrequency(item.id, body);
        }
      } else {
        switch (_currentKey) {
          case 'complaints':
            await svc.createComplaint(body);
          case 'diagnoses':
            await svc.createDiagnosis(body);
          case 'treatments':
            await svc.createTreatment(body);
          case 'medicines':
            await svc.createMedicine(body);
          case 'dosages':
            await svc.createDosage(body);
          case 'frequencies':
            await svc.createFrequency(body);
        }
      }
      _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deactivate(EmrTemplateItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Deactivate ${item.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final svc = context.read<AppServices>().emrMasterData;
      switch (_currentKey) {
        case 'complaints':
          await svc.deleteComplaint(item.id);
        case 'diagnoses':
          await svc.deleteDiagnosis(item.id);
        case 'treatments':
          await svc.deleteTreatment(item.id);
        case 'medicines':
          await svc.deleteMedicine(item.id);
        case 'dosages':
          await svc.deleteDosage(item.id);
        case 'frequencies':
          await svc.deleteFrequency(item.id);
      }
      _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMR Master Data'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No items yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          final subtitle = _subtitleFor(item);
                          return ListTile(
                            title: Text(item.displayName),
                            subtitle: subtitle != null ? Text(subtitle) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!item.isActive)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Text(
                                      'Inactive',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _openForm(item: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                                  onPressed: () => _deactivate(item),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String? _subtitleFor(EmrTemplateItem item) {
    return switch (_currentKey) {
      'diagnoses' => item.icdCode,
      'treatments' => [
          if (item.procedureCode != null) item.procedureCode,
          if (item.defaultPrice != null) '₹${item.defaultPrice}',
          if (item.category != null) item.category,
        ].whereType<String>().join(' · ').isEmpty
          ? null
          : [
              if (item.procedureCode != null) item.procedureCode,
              if (item.defaultPrice != null) '₹${item.defaultPrice}',
              if (item.category != null) item.category,
            ].join(' · '),
      'medicines' => [
          if (item.defaultDosage != null) item.defaultDosage,
          if (item.defaultFrequency != null) item.defaultFrequency,
          if (item.defaultDurationDays != null) '${item.defaultDurationDays}d',
        ].whereType<String>().join(' · ').isEmpty
          ? null
          : [
              if (item.defaultDosage != null) item.defaultDosage,
              if (item.defaultFrequency != null) item.defaultFrequency,
              if (item.defaultDurationDays != null) '${item.defaultDurationDays}d',
            ].join(' · '),
      _ => null,
    };
  }
}
