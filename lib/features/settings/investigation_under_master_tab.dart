import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/investigation_under.dart';
import '../../data/models/product.dart';

/// Super admin: manage Investigation tabs and map service products into them.
class InvestigationUnderMasterTab extends StatefulWidget {
  const InvestigationUnderMasterTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<InvestigationUnderMasterTab> createState() =>
      InvestigationUnderMasterTabState();
}

class InvestigationUnderMasterTabState
    extends State<InvestigationUnderMasterTab> {
  static const _unmapped = 'unmapped';

  bool _loadingCats = true;
  bool _loadingProducts = false;
  List<InvestigationUnderCategoryItem> _categories = [];
  List<Product> _items = [];
  String _currentKey = _unmapped;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant InvestigationUnderMasterTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _loadProducts();
    }
  }

  bool get _isUnmapped => _currentKey == _unmapped;

  InvestigationUnderCategoryItem? get _currentCategory {
    for (final c in _categories) {
      if (c.slug == _currentKey) return c;
    }
    return null;
  }

  Future<void> reload() async {
    await _loadCategories(keepSelection: true);
    await _loadProducts();
  }

  Future<void> _bootstrap() async {
    await _loadCategories();
    await _loadProducts();
  }

  Future<void> _loadCategories({bool keepSelection = false}) async {
    setState(() => _loadingCats = true);
    try {
      final list = await context
          .read<AppServices>()
          .emrMasterData
          .listInvestigationUnderCategories(includeInactive: true);
      if (!mounted) return;
      final active = list.where((c) => c.isActive).toList();
      final prev = keepSelection ? _currentKey : _unmapped;
      var next = prev;
      if (next != _unmapped && !active.any((c) => c.slug == next)) {
        next = active.isNotEmpty ? active.first.slug : _unmapped;
      }
      setState(() {
        _categories = list;
        _currentKey = next;
        _loadingCats = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCats = false);
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final q = widget.searchQuery.trim();
      final list = await context
          .read<AppServices>()
          .emrMasterData
          .listInvestigationUnderProducts(
            search: q.isEmpty ? null : q,
            category: _currentKey,
          );
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> openAdd() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tab),
              title: const Text('Add category tab'),
              onTap: () => Navigator.pop(ctx, 'category'),
            ),
            ListTile(
              leading: const Icon(Icons.biotech_outlined),
              title: const Text('Map service'),
              subtitle: Text(
                _isUnmapped
                    ? 'Open a category tab first'
                    : 'Map to ${InvestigationUnderCategory.labelOf(_currentKey, _categories)}',
              ),
              enabled: !_isUnmapped,
              onTap: _isUnmapped ? null : () => Navigator.pop(ctx, 'service'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'category') {
      await openAddCategory();
    } else {
      await _pickAndAssign(_currentKey);
    }
  }

  Future<void> openAddCategory() async {
    final labelCtrl = TextEditingController();
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppFormDialogShell(
        title: 'Add Investigation tab',
        subtitle: 'Creates a new category chip on the visit form',
        icon: Icons.tab,
        maxWidth: 420,
        onClose: () => Navigator.pop(ctx, false),
        body: TextField(
          controller: labelCtrl,
          autofocus: true,
          decoration: appFormFieldDecoration('Label *'),
          textCapitalization: TextCapitalization.words,
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final label = labelCtrl.text.trim();
    labelCtrl.dispose();
    if (ok != true || label.isEmpty || !mounted) return;

    try {
      final created = await context
          .read<AppServices>()
          .emrMasterData
          .createInvestigationUnderCategory(label: label);
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('Added ${created.label}')),
      );
      await _loadCategories();
      setState(() => _currentKey = created.slug);
      await _loadProducts();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editCategory(InvestigationUnderCategoryItem cat) async {
    final labelCtrl = TextEditingController(text: cat.label);
    var isActive = cat.isActive;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppFormDialogShell(
          title: 'Edit ${cat.label}',
          subtitle: 'Slug stays "${cat.slug}" (visit history safe)',
          icon: Icons.edit_outlined,
          maxWidth: 420,
          onClose: () => Navigator.pop(ctx, false),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: appFormFieldDecoration('Label *'),
                textCapitalization: TextCapitalization.words,
              ),
              if (cat.slug != InvestigationUnderCategory.unique)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive tabs hide on the visit form'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
            ],
          ),
          footer: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final label = labelCtrl.text.trim();
    labelCtrl.dispose();
    if (ok != true || label.isEmpty || !mounted) return;

    try {
      await context
          .read<AppServices>()
          .emrMasterData
          .updateInvestigationUnderCategory(
            cat.id,
            label: label,
            isActive: isActive,
          );
      if (!mounted) return;
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Category updated')),
      );
      await _loadCategories(keepSelection: true);
      await _loadProducts();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deactivateCategory(InvestigationUnderCategoryItem cat) async {
    if (cat.slug == InvestigationUnderCategory.unique) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Unique cannot be deactivated')),
      );
      return;
    }
    try {
      await context
          .read<AppServices>()
          .emrMasterData
          .deleteInvestigationUnderCategory(cat.id);
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('${cat.label} deactivated')),
      );
      await _loadCategories();
      await _loadProducts();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pickAndAssign(String category) async {
    final selected = await showAppDialog<Product>(
      context: context,
      builder: (ctx) => _UnmappedServicePicker(
        title:
            'Map to ${InvestigationUnderCategory.labelOf(category, _categories)}',
      ),
    );
    if (selected == null || !mounted) return;
    await _assign(selected.id, category);
  }

  Future<void> _assign(int productId, String? category) async {
    try {
      await context
          .read<AppServices>()
          .emrMasterData
          .assignInvestigationUnderProduct(
            productId,
            category,
          );
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(
            category == null
                ? 'Service unmapped'
                : 'Mapped to ${InvestigationUnderCategory.labelOf(category, _categories)}',
          ),
        ),
      );
      await _loadProducts();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  List<InvestigationUnderCategoryItem> get _activeCategories =>
      _categories.where((c) => c.isActive).toList();

  @override
  Widget build(BuildContext context) {
    if (_loadingCats) {
      return const Center(child: CircularProgressIndicator());
    }

    final chips = [
      ChoiceChip(
        label: const Text('Unmapped'),
        selected: _isUnmapped,
        onSelected: (_) {
          setState(() => _currentKey = _unmapped);
          _loadProducts();
        },
      ),
      for (final c in _activeCategories)
        ChoiceChip(
          label: Text(c.label),
          selected: _currentKey == c.slug,
          onSelected: (_) {
            setState(() => _currentKey = c.slug);
            _loadProducts();
          },
        ),
    ];

    final current = _currentCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final chip in chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add tab'),
                onPressed: openAddCategory,
              ),
            ],
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Slug: ${current.slug}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _editCategory(current),
                  child: const Text('Edit tab'),
                ),
                if (current.slug != InvestigationUnderCategory.unique)
                  TextButton(
                    onPressed: () => _deactivateCategory(current),
                    child: const Text(
                      'Deactivate',
                      style: TextStyle(color: AppTheme.danger),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        _isUnmapped
                            ? 'All service products are mapped'
                            : 'No services in this category yet',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final p = _items[i];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                            [
                              '₹${p.sellingPrice.toStringAsFixed(2)}',
                              if (p.investigationUnderCategory != null)
                                InvestigationUnderCategory.labelOf(
                                  p.investigationUnderCategory,
                                  _categories,
                                ),
                            ].join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Change category',
                            onSelected: (value) {
                              if (value == _unmapped) {
                                _assign(p.id, null);
                              } else {
                                _assign(p.id, value);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: _unmapped,
                                child: Text('Unmapped'),
                              ),
                              ..._activeCategories.map(
                                (c) => PopupMenuItem(
                                  value: c.slug,
                                  child: Text(c.label),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _UnmappedServicePicker extends StatefulWidget {
  const _UnmappedServicePicker({required this.title});

  final String title;

  @override
  State<_UnmappedServicePicker> createState() => _UnmappedServicePickerState();
}

class _UnmappedServicePickerState extends State<_UnmappedServicePicker> {
  final _search = TextEditingController();
  bool _loading = true;
  List<Product> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _search.text.trim();
      final list = await context
          .read<AppServices>()
          .emrMasterData
          .listInvestigationUnderProducts(
            search: q.isEmpty ? null : q,
            category: 'unmapped',
          );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialogShell(
      title: widget.title,
      subtitle: 'Pick an unmapped service product',
      icon: Icons.biotech_outlined,
      maxWidth: 520,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search services...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 360,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? const Center(child: Text('No unmapped services'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = _items[i];
                              return ListTile(
                                title: Text(p.name),
                                subtitle: Text(
                                  '₹${p.sellingPrice.toStringAsFixed(2)}',
                                ),
                                onTap: () => Navigator.pop(context, p),
                              );
                            },
                          ),
          ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
