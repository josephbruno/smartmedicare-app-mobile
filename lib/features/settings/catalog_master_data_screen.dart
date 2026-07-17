import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/product.dart';

/// Manage product catalog master data: Categories, Brands and Units.
class CatalogMasterDataScreen extends StatefulWidget {
  const CatalogMasterDataScreen({super.key});

  @override
  State<CatalogMasterDataScreen> createState() =>
      _CatalogMasterDataScreenState();
}

class _CatalogMasterDataScreenState extends State<CatalogMasterDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = false;

  List<Category> _categories = [];
  List<Brand> _brands = [];
  List<Unit> _units = [];

  static const _tabLabels = ['Categories', 'Brands', 'Units'];

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = context.read<AppServices>().products;
      switch (_tabs.index) {
        case 0:
          final list = await svc.listCategories();
          if (mounted) setState(() => _categories = list);
        case 1:
          final list = await svc.listBrands();
          if (mounted) setState(() => _brands = list);
        case 2:
          final list = await svc.listUnits();
          if (mounted) setState(() => _units = list);
      }
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _singular => switch (_tabs.index) {
        0 => 'Category',
        1 => 'Brand',
        _ => 'Unit',
      };

  Future<void> _openForm({int? id, String? name, String? extra, bool? active}) async {
    final isEdit = id != null;
    final isUnit = _tabs.index == 2;
    final nameCtrl = TextEditingController(text: name ?? '');
    final abbrCtrl = TextEditingController(text: extra ?? '');
    var isActive = active ?? true;

    final title = '${isEdit ? 'Edit' : 'Add'} $_singular';

    Widget buildFields(void Function(VoidCallback) setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration('Name *'),
          ),
          if (isUnit) ...[
            const SizedBox(height: 16),
            TextField(
              controller: abbrCtrl,
              decoration: appFormFieldDecoration(
                'Abbreviation *',
                hint: 'e.g. kg, pcs, ml',
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: isActive,
              onChanged: (v) => setLocal(() => isActive = v),
            ),
          ],
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
            icon: Icons.sell_outlined,
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

    final nameText = nameCtrl.text.trim();
    if (nameText.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    final body = <String, dynamic>{'name': nameText};
    if (isUnit) {
      final abbr = abbrCtrl.text.trim();
      if (abbr.isEmpty) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Abbreviation is required')),
        );
        return;
      }
      body['abbreviation'] = abbr;
    } else {
      body['is_active'] = isActive;
    }

    try {
      final svc = context.read<AppServices>().products;
      switch (_tabs.index) {
        case 0:
          isEdit
              ? await svc.updateCategory(id, body)
              : await svc.createCategory(body);
        case 1:
          isEdit
              ? await svc.updateBrand(id, body)
              : await svc.createBrand(body);
        case 2:
          isEdit
              ? await svc.updateUnit(id, body)
              : await svc.createUnit(body);
      }
      _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(int id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
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
      final svc = context.read<AppServices>().products;
      switch (_tabs.index) {
        case 0:
          await svc.deleteCategory(id);
        case 1:
          await svc.deleteBrand(id);
        case 2:
          await svc.deleteUnit(id);
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
        title: const Text('Catalog'),
        bottom: TabBar(
          controller: _tabs,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final tiles = switch (_tabs.index) {
      0 => _categories
          .map((c) => _rowTile(
                id: c.id,
                title: c.name,
                subtitle: c.slug,
                isActive: c.isActive,
                onEdit: () => _openForm(id: c.id, name: c.name, active: c.isActive),
                onDelete: () => _delete(c.id, c.name),
              ))
          .toList(),
      1 => _brands
          .map((b) => _rowTile(
                id: b.id,
                title: b.name,
                subtitle: b.slug,
                isActive: b.isActive,
                onEdit: () => _openForm(id: b.id, name: b.name, active: b.isActive),
                onDelete: () => _delete(b.id, b.name),
              ))
          .toList(),
      _ => _units
          .map((u) => _rowTile(
                id: u.id,
                title: u.name,
                subtitle: u.abbreviation,
                isActive: u.isActive,
                onEdit: () =>
                    _openForm(id: u.id, name: u.name, extra: u.abbreviation),
                onDelete: () => _delete(u.id, u.name),
              ))
          .toList(),
    };

    if (tiles.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text('No ${_tabLabels[_tabs.index].toLowerCase()} yet')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: tiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => tiles[i],
    );
  }

  Widget _rowTile({
    required int id,
    required String title,
    String? subtitle,
    required bool isActive,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: (subtitle != null && subtitle.isNotEmpty) ? Text(subtitle) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isActive)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Inactive',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
