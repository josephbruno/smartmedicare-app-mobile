import '../../core/theme/app_tokens.dart';
import '../reports/widgets/report_frame.dart';
import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/services/emr_master_data_service.dart';
import 'procedure_kits_master_tab.dart';
import 'under_mapping_pane.dart';
import 'vaccination_master_tab.dart';

class EmrMasterDataScreen extends StatefulWidget {
  const EmrMasterDataScreen({super.key, this.initialTabKey});

  /// Opens on this tab key (e.g. `service_kits` for the Procedure Kits menu).
  final String? initialTabKey;

  @override
  State<EmrMasterDataScreen> createState() => _EmrMasterDataScreenState();
}

class _EmrMasterDataScreenState extends State<EmrMasterDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  final _kitsTabKey = GlobalKey<ProcedureKitsMasterTabState>();
  final _vaccinationsTabKey = GlobalKey<VaccinationMasterTabState>();
  bool _loading = false;
  List<EmrTemplateItem> _items = [];

  // Same order as EmrMasterDataPage.vue (plus the app's review intervals
  // and service kits tabs).
  static const _tabKeys = [
    'complaints',
    'review_intervals',
    'observations',
    'investigations',
    'vaccinations',
    'treatment_under',
    'prescription_under',
    'investigation_under',
    'service_kits',
  ];

  static const _tabLabels = [
    'Complaints',
    'Adv to Review',
    'Observations',
    'Investigations',
    'Vaccinations',
    'Treatment Under',
    'Prescriptions Under',
    'Investigation Under',
    'Service kits',
  ];

  bool get _isKitsTab => _currentKey == 'service_kits';
  bool get _isVaccinationsTab => _currentKey == 'vaccinations';
  bool get _isTreatmentUnderTab => _currentKey == 'treatment_under';
  bool get _isPrescriptionUnderTab => _currentKey == 'prescription_under';
  bool get _isInvestigationUnderTab => _currentKey == 'investigation_under';
  bool get _isMappingTab =>
      _isTreatmentUnderTab ||
      _isPrescriptionUnderTab ||
      _isInvestigationUnderTab;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabKey == null
        ? -1
        : _tabKeys.indexOf(widget.initialTabKey!);
    _tabs = TabController(
        length: _tabKeys.length,
        vsync: this,
        initialIndex: initial < 0 ? 0 : initial);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        if (_isKitsTab) {
          setState(() {});
          _kitsTabKey.currentState?.reload();
        } else if (_isVaccinationsTab) {
          setState(() {});
          _vaccinationsTabKey.currentState?.reload();
        } else if (_isMappingTab) {
          setState(() {}); // the mapping pane loads itself
        } else {
          _load();
        }
      }
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
    if (_isKitsTab) {
      await _kitsTabKey.currentState?.reload();
      return;
    }
    if (_isVaccinationsTab) {
      await _vaccinationsTabKey.currentState?.reload();
      return;
    }
    if (_isMappingTab) return; // the mapping pane loads itself
    setState(() => _loading = true);
    try {
      final svc = context.read<AppServices>().emrMasterData;
      final q = _search.text.trim();
      final list = switch (_currentKey) {
        'complaints' => await svc.listComplaints(
            search: q.isEmpty ? null : q,
            isActive: true,
          ),
        'review_intervals' => await svc.listReviewIntervals(
            search: q.isEmpty ? null : q,
            isActive: true,
          ),
        'observations' => await svc.listObservations(
            search: q.isEmpty ? null : q,
            isActive: true,
          ),
        'investigations' =>
          (await svc.listInvestigations(search: q.isEmpty ? null : q))
              .where((e) => e.isActive)
              .toList(),
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
    if (_isKitsTab) {
      await _kitsTabKey.currentState?.openForm();
      return;
    }
    if (_isVaccinationsTab) {
      await _vaccinationsTabKey.currentState?.openForm();
      return;
    }
    // Mapping tabs have their own "Add Tab" inside the pane.
    if (_isMappingTab) return;
    final isEdit = item != null;
    final isReview = _currentKey == 'review_intervals';
    final name = TextEditingController(text: item?.name ?? '');
    final days = TextEditingController(
      text: item?.days?.toString() ?? '',
    );

    final title = isEdit
        ? 'Edit ${_tabLabels[_tabs.index]}'
        : 'Add ${_tabLabels[_tabs.index]}';

    var isActive = item?.isActive ?? true;

    Widget formFields(void Function(void Function()) setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            decoration: appFormFieldDecoration('Name *'),
          ),
          if (isReview) ...[
            const SizedBox(height: 8),
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: appFormFieldDecoration('Days *'),
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
          builder: (ctx, setLocal) => formFields(setLocal),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
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
            body: formFields(setSheet),
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

    if (isReview) {
      final parsedDays = int.tryParse(days.text.trim());
      if (parsedDays == null || parsedDays < 1) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Enter a valid number of days')),
        );
        return;
      }
    }

    final body = <String, dynamic>{
      'is_active': isActive,
      'name': name.text.trim(),
      if (isReview) 'days': int.parse(days.text.trim()),
    };

    try {
      final svc = context.read<AppServices>().emrMasterData;
      if (isEdit && item != null) {
        switch (_currentKey) {
          case 'complaints':
            await svc.updateComplaint(item.id, body);
          case 'review_intervals':
            await svc.updateReviewInterval(item.id, body);
          case 'observations':
            await svc.updateObservation(item.id, body);
          case 'investigations':
            await svc.updateInvestigation(item.id, body);
        }
      } else {
        switch (_currentKey) {
          case 'complaints':
            await svc.createComplaint(body);
          case 'review_intervals':
            await svc.createReviewInterval(body);
          case 'observations':
            await svc.createObservation(body);
          case 'investigations':
            await svc.createInvestigation(body);
        }
      }
      _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(EmrTemplateItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${item.displayName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final svc = context.read<AppServices>().emrMasterData;
      switch (_currentKey) {
        case 'complaints':
          await svc.deleteComplaint(item.id);
        case 'review_intervals':
          await svc.deleteReviewInterval(item.id);
        case 'observations':
          await svc.deleteObservation(item.id);
        case 'investigations':
          await svc.deleteInvestigation(item.id);
      }
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == item.id));
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: ReportFrame(
        group: 'Admin',
        title: 'EMR Master Data',
        subtitle:
            'Manage complaints, observations, investigations, vaccinations, treatment-under mappings, and prescription-under mappings.',
        icon: Icons.list_alt_outlined,
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
          ),
        ],
        child: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
              ),
            ),
            if (!_isMappingTab)
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
              child: _isKitsTab
                  ? ProcedureKitsMasterTab(
                      key: _kitsTabKey,
                      searchQuery: _search.text.trim(),
                    )
                  : _isVaccinationsTab
                      ? VaccinationMasterTab(
                          key: _vaccinationsTabKey,
                          searchQuery: _search.text.trim(),
                        )
                      : _isTreatmentUnderTab
                          ? const UnderMappingPane(
                              key: ValueKey('under-treatment'),
                              kind: UnderKind.treatment)
                          : _isPrescriptionUnderTab
                              ? const UnderMappingPane(
                                  key: ValueKey('under-prescription'),
                                  kind: UnderKind.prescription)
                              : _isInvestigationUnderTab
                                  ? const UnderMappingPane(
                                      key: ValueKey('under-investigation'),
                                      kind: UnderKind.investigation)
                                  : _loading
                                      ? const Center(
                                          child: CircularProgressIndicator())
                                      : _items.isEmpty
                                          ? const Center(
                                              child: Text('No items yet'))
                                          : ListView.separated(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              itemCount: _items.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 1),
                                              itemBuilder: (ctx, i) {
                                                final item = _items[i];
                                                return ListTile(
                                                  title: Text(item.displayName),
                                                  subtitle: _currentKey ==
                                                              'review_intervals' &&
                                                          item.days != null
                                                      ? Text(
                                                          'Visit date + ${item.days} days')
                                                      : null,
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (!item.isActive)
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  right: 8),
                                                          child: Text(
                                                            'Inactive',
                                                            style: TextStyle(
                                                              color: AppTheme
                                                                  .textSecondary,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      IconButton(
                                                        icon: const Icon(Icons
                                                            .edit_outlined),
                                                        onPressed: () =>
                                                            _openForm(
                                                                item: item),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Delete',
                                                        icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: AppTheme
                                                                .danger),
                                                        onPressed: () =>
                                                            _delete(item),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
            ),
          ],
        ),
      ),
    );
  }
}
