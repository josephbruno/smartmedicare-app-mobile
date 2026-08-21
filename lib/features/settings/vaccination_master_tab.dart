import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/services/emr_master_data_service.dart';

/// EMR Master Data tab: dog/cat vaccination names, booster duration, day-gap courses.
class VaccinationMasterTab extends StatefulWidget {
  const VaccinationMasterTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<VaccinationMasterTab> createState() => VaccinationMasterTabState();
}

class VaccinationMasterTabState extends State<VaccinationMasterTab> {
  bool _loading = false;
  List<VaccinationTemplate> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VaccinationMasterTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _load();
    }
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = widget.searchQuery.trim();
      final list = await context.read<AppServices>().emrMasterData.listVaccinations(
            search: q.isEmpty ? null : q,
          );
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> openForm({VaccinationTemplate? item}) async {
    final isEdit = item != null;
    final name = TextEditingController(text: item?.name ?? '');
    final nextDays = TextEditingController(
      text: item?.nextDueDays?.toString() ?? '365',
    );
    var species = item?.species == 'cat' ? 'cat' : 'dog';
    var scheduleType = item?.isCourse == true ? 'course' : 'booster';
    var doseDays = List<int>.from(
      item != null && item.doseDays.isNotEmpty ? item.doseDays : const [0, 3, 7, 14, 28],
    );
    var isActive = item?.isActive ?? true;
    final gapCtrl = TextEditingController();

    Widget buildFields(void Function(VoidCallback) setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdownButtonFormField<String>(
            value: species,
            decoration: appFormFieldDecoration('Species *'),
            items: const [
              DropdownMenuItem(value: 'dog', child: Text('Dog')),
              DropdownMenuItem(value: 'cat', child: Text('Cat')),
            ],
            onChanged: (v) => setLocal(() => species = v ?? 'dog'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: appFormFieldDecoration('Vaccination name *'),
          ),
          const SizedBox(height: 16),
          AppDropdownButtonFormField<String>(
            value: scheduleType,
            decoration: appFormFieldDecoration('Schedule *'),
            items: const [
              DropdownMenuItem(value: 'booster', child: Text('Booster (next consume days)')),
              DropdownMenuItem(value: 'course', child: Text('Course (day gaps, e.g. dog bite)')),
            ],
            onChanged: (v) => setLocal(() => scheduleType = v ?? 'booster'),
          ),
          const SizedBox(height: 16),
          if (scheduleType == 'booster')
            TextField(
              controller: nextDays,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appFormFieldDecoration('Next consume (days) *'),
            )
          else ...[
            Text(
              'Dose days from first shot (must include 0)',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in doseDays)
                  InputChip(
                    label: Text('Day $d'),
                    onDeleted: d == 0
                        ? null
                        : () => setLocal(() => doseDays = doseDays.where((x) => x != d).toList()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: gapCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: appFormFieldDecoration('Add day (e.g. 3)'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final n = int.tryParse(gapCtrl.text.trim());
                    if (n == null || n < 0) return;
                    setLocal(() {
                      if (!doseDays.contains(n)) {
                        doseDays = [...doseDays, n]..sort();
                      }
                      gapCtrl.clear();
                    });
                  },
                  child: const Text('Add'),
                ),
              ],
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

    final title = isEdit ? 'Edit vaccination' : 'Add vaccination';
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
            icon: Icons.vaccines_outlined,
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

    final nameText = name.text.trim();
    final nextDaysText = nextDays.text.trim();
    name.dispose();
    nextDays.dispose();
    gapCtrl.dispose();
    if (saved != true || !mounted) return;
    if (nameText.isEmpty) {
      AppMessenger.show(context, const SnackBar(content: Text('Name is required')));
      return;
    }

    final body = <String, dynamic>{
      'species': species,
      'name': nameText,
      'schedule_type': scheduleType,
      'is_active': isActive,
      'reminder_days_before': 7,
      if (scheduleType == 'booster')
        'next_due_days': int.tryParse(nextDaysText) ?? 365,
      if (scheduleType == 'course') 'dose_days': doseDays,
    };

    try {
      final svc = context.read<AppServices>().emrMasterData;
      if (isEdit) {
        await svc.updateVaccination(item.id, body);
      } else {
        await svc.createVaccination(body);
      }
      _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deactivate(VaccinationTemplate item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Deactivate ${item.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emrMasterData.deleteVaccination(item.id);
      _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('No vaccinations yet.\nTap + to add dog or cat vaccines.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return ListTile(
          title: Text(item.name),
          subtitle: Text('${item.speciesLabel} · ${item.scheduleLabel}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!item.isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    'Inactive',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openForm(item: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: () => _deactivate(item),
              ),
            ],
          ),
        );
      },
    );
  }
}
