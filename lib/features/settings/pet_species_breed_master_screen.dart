import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/customer.dart';

/// Super-admin master data for pet species and breeds.
class PetSpeciesBreedMasterScreen extends StatefulWidget {
  const PetSpeciesBreedMasterScreen({super.key});

  @override
  State<PetSpeciesBreedMasterScreen> createState() =>
      _PetSpeciesBreedMasterScreenState();
}

class _PetSpeciesBreedMasterScreenState extends State<PetSpeciesBreedMasterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  bool _loading = false;
  List<PetSpecies> _species = [];
  List<PetBreed> _breeds = [];
  int? _breedSpeciesFilter;

  static const _tabLabels = ['Species', 'Breeds'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
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

  bool get _isBreedsTab => _tabs.index == 1;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = context.read<AppServices>().customers;
      final q = _search.text.trim();
      if (_isBreedsTab) {
        // Keep species options available for filters / breed forms.
        final species = await svc.adminListPetSpecies();
        final breeds = await svc.adminListPetBreeds(
          speciesId: _breedSpeciesFilter,
          search: q.isEmpty ? null : q,
        );
        if (mounted) {
          setState(() {
            _species = species;
            _breeds = breeds;
          });
        }
      } else {
        final species = await svc.adminListPetSpecies(
          search: q.isEmpty ? null : q,
        );
        if (mounted) setState(() => _species = species);
      }
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSpeciesForm({PetSpecies? item}) async {
    final isEdit = item != null;
    final name = TextEditingController(text: item?.name ?? '');
    final code = TextEditingController(text: item?.code ?? '');
    final sort = TextEditingController(
      text: item == null ? '0' : item.sortOrder.toString(),
    );
    var isActive = item?.isActive ?? true;

    final title = isEdit ? 'Edit Species' : 'Add Species';

    Widget buildFields(void Function(VoidCallback) setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration('Name *', hint: 'e.g. Hamster'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: code,
            decoration: appFormFieldDecoration(
              'Code',
              hint: isEdit ? null : 'Optional — auto from name',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\-]')),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: sort,
            keyboardType: TextInputType.number,
            decoration: appFormFieldDecoration('Sort order'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
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

    final saved = await _showForm(title: title, icon: Icons.pets_outlined, buildFields: buildFields);
    if (saved != true || !mounted) return;

    final nameText = name.text.trim();
    if (nameText.isEmpty) {
      AppMessenger.error(context, 'Name is required.');
      return;
    }

    final body = <String, dynamic>{
      'name': nameText,
      'is_active': isActive,
      'sort_order': int.tryParse(sort.text.trim()) ?? 0,
    };
    final codeText = code.text.trim().toLowerCase();
    if (codeText.isNotEmpty) body['code'] = codeText;

    try {
      final svc = context.read<AppServices>().customers;
      if (isEdit) {
        await svc.updatePetSpecies(item.id, body);
      } else {
        await svc.createPetSpecies(body);
      }
      if (mounted) {
        AppMessenger.success(context, isEdit ? 'Species updated' : 'Species added');
        _load();
      }
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    }
  }

  Future<void> _openBreedForm({PetBreed? item}) async {
    final isEdit = item != null;
    if (_species.isEmpty) {
      try {
        final species = await context.read<AppServices>().customers.adminListPetSpecies();
        if (mounted) setState(() => _species = species);
      } catch (_) {}
    }
    if (!mounted) return;
    if (_species.isEmpty) {
      AppMessenger.error(context, 'Add a species first.');
      return;
    }

    final name = TextEditingController(text: item?.name ?? '');
    final sort = TextEditingController(
      text: item == null ? '0' : item.sortOrder.toString(),
    );
    var speciesId = item?.speciesId ??
        _breedSpeciesFilter ??
        _species.firstWhere((s) => s.isActive, orElse: () => _species.first).id;
    var isActive = item?.isActive ?? true;

    final title = isEdit ? 'Edit Breed' : 'Add Breed';

    Widget buildFields(void Function(VoidCallback) setLocal) {
      final speciesValue = _species.any((s) => s.id == speciesId) ? speciesId : null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdownButtonFormField<int>(
            value: speciesValue,
            decoration: appFormFieldDecoration('Species *'),
            items: [
              for (final s in _species)
                DropdownMenuItem(
                  value: s.id,
                  child: Text(s.isActive ? s.name : '${s.name} (inactive)'),
                ),
            ],
            onChanged: (v) => setLocal(() => speciesId = v ?? speciesId),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration('Breed name *', hint: 'e.g. Syrian'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: sort,
            keyboardType: TextInputType.number,
            decoration: appFormFieldDecoration('Sort order'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
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

    final saved = await _showForm(title: title, icon: Icons.category_outlined, buildFields: buildFields);
    if (saved != true || !mounted) return;

    final nameText = name.text.trim();
    if (nameText.isEmpty) {
      AppMessenger.error(context, 'Breed name is required.');
      return;
    }

    final body = <String, dynamic>{
      'species_id': speciesId,
      'name': nameText,
      'is_active': isActive,
      'sort_order': int.tryParse(sort.text.trim()) ?? 0,
    };

    try {
      final svc = context.read<AppServices>().customers;
      if (isEdit) {
        await svc.updatePetBreed(item.id, body);
      } else {
        await svc.createPetBreed(body);
      }
      if (mounted) {
        AppMessenger.success(context, isEdit ? 'Breed updated' : 'Breed added');
        _load();
      }
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    }
  }

  Future<bool?> _showForm({
    required String title,
    required IconData icon,
    required Widget Function(void Function(VoidCallback)) buildFields,
  }) async {
    if (useCenteredFormDialog(context)) {
      return showAppAlertForm<bool>(
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
            child: Text(title.startsWith('Edit') ? 'Save' : 'Add'),
          ),
        ],
      );
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AppFormBottomSheetShell(
          title: title,
          icon: icon,
          onClose: () => Navigator.pop(ctx, false),
          body: buildFields(setSheet),
          footer: AppFormFooter(
            primaryLabel: title.startsWith('Edit') ? 'Save' : 'Add',
            onCancel: () => Navigator.pop(ctx, false),
            onSubmit: () => Navigator.pop(ctx, true),
          ),
        ),
      ),
    );
  }

  Future<void> _deactivateSpecies(PetSpecies item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Deactivate ${item.name}?'),
        content: const Text(
          'It will be hidden from the Add Pet form. Existing pets keep their saved species.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().customers.deactivatePetSpecies(item.id);
      if (mounted) {
        AppMessenger.success(context, 'Species deactivated');
        _load();
      }
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    }
  }

  Future<void> _deactivateBreed(PetBreed item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Deactivate ${item.name}?'),
        content: const Text(
          'It will be hidden from the Add Pet form. Existing pets keep their saved breed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().customers.deactivatePetBreed(item.id);
      if (mounted) {
        AppMessenger.success(context, 'Breed deactivated');
        _load();
      }
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Species & Breeds'),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: () => _isBreedsTab ? _openBreedForm() : _openSpeciesForm(),
            icon: const Icon(Icons.add),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: _isBreedsTab ? 'Search breeds...' : 'Search species...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _load,
                      ),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                if (_isBreedsTab) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: AppDropdownButtonFormField<int?>(
                      value: _breedSpeciesFilter,
                      decoration: const InputDecoration(labelText: 'Species'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All species'),
                        ),
                        for (final s in _species)
                          DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => _breedSpeciesFilter = v);
                        _load();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _isBreedsTab
                    ? _buildBreedsList()
                    : _buildSpeciesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesList() {
    if (_species.isEmpty) {
      return const Center(child: Text('No species yet. Tap + to add one.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _species.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = _species[i];
        final count = item.breedsCount;
        return ListTile(
          title: Text(
            item.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [
              'Code: ${item.code}',
              if (count != null) '$count breed${count == 1 ? '' : 's'}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
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
                onPressed: () => _openSpeciesForm(item: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: item.isActive ? () => _deactivateSpecies(item) : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreedsList() {
    if (_breeds.isEmpty) {
      return const Center(child: Text('No breeds yet. Tap + to add one.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _breeds.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = _breeds[i];
        return ListTile(
          title: Text(
            item.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            item.speciesName ?? 'Species #${item.speciesId}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
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
                onPressed: () => _openBreedForm(item: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: item.isActive ? () => _deactivateBreed(item) : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
