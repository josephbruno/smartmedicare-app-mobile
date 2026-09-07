import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/product.dart';

/// Manage product catalog categories.
class CatalogMasterDataScreen extends StatefulWidget {
  const CatalogMasterDataScreen({super.key});

  @override
  State<CatalogMasterDataScreen> createState() =>
      _CatalogMasterDataScreenState();
}

class _CatalogMasterDataScreenState extends State<CatalogMasterDataScreen> {
  bool _loading = false;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<AppServices>().products.listCategories();
      if (mounted) setState(() => _categories = list);
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Category? category}) async {
    final isEdit = category != null;
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    var isActive = category?.isActive ?? true;

    const titlePrefix = 'Category';
    final title = '${isEdit ? 'Edit' : 'Add'} $titlePrefix';

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

    final body = <String, dynamic>{
      'name': nameText,
      'is_active': isActive,
    };

    try {
      final svc = context.read<AppServices>().products;
      if (isEdit) {
        await svc.updateCategory(category.id, body);
      } else {
        await svc.createCategory(body);
      }
      if (!mounted) return;
      AppMessenger.success(
        context,
        isEdit ? 'Category updated' : 'Category created',
      );
      await _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(Category category) async {
    final count = category.productsCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: Text(
          count > 0
              ? 'This category has $count product${count == 1 ? '' : 's'}. '
                  'They will be unassigned from this category. This cannot be undone.'
              : 'This action cannot be undone.',
        ),
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
      await context.read<AppServices>().products.deleteCategory(category.id);
      if (!mounted) return;
      AppMessenger.success(context, 'Category deleted');
      await _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.categoriesCreate);
    final canEdit = auth.hasPermission(AppPermissions.categoriesEdit);
    final canDelete = auth.hasPermission(AppPermissions.categoriesDelete);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Categories'),
        actions: [
          if (canCreate)
            IconButton(
              tooltip: 'Add category',
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildList(canEdit: canEdit, canDelete: canDelete),
      ),
    );
  }

  Widget _buildList({required bool canEdit, required bool canDelete}) {
    if (_categories.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No categories yet')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = _categories[i];
        final count = c.productsCount;
        return ListTile(
          title: Text(
            c.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            count == 1 ? '1 product' : '$count products',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!c.isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    'Inactive',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              if (canEdit)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openForm(category: c),
                ),
              if (canDelete)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  onPressed: () => _delete(c),
                ),
            ],
          ),
        );
      },
    );
  }
}
