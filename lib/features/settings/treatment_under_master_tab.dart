import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/product.dart';
import '../../data/models/treatment_under.dart';

/// Super admin: map medicine products to Treatment Under visit tabs.
class TreatmentUnderMasterTab extends StatefulWidget {
  const TreatmentUnderMasterTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<TreatmentUnderMasterTab> createState() => TreatmentUnderMasterTabState();
}

class TreatmentUnderMasterTabState extends State<TreatmentUnderMasterTab>
    with SingleTickerProviderStateMixin {
  static const _unmapped = 'unmapped';
  static const _innerKeys = [_unmapped, ...TreatmentUnderCategory.keys];
  static const _innerLabels = [
    'Unmapped',
    'Antibiotics',
    'Fluids',
    'NSAIDS',
    'Supportive',
    'Anesthetics',
    'Unique',
  ];

  late final TabController _tabs;
  bool _loading = false;
  List<Product> _items = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _innerKeys.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant TreatmentUnderMasterTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _load();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _currentKey => _innerKeys[_tabs.index];

  bool get _isUnmapped => _currentKey == _unmapped;

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = widget.searchQuery.trim();
      final list = await context.read<AppServices>().emrMasterData.listTreatmentUnderProducts(
            search: q.isEmpty ? null : q,
            category: _currentKey,
          );
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> openAdd() async {
    if (_isUnmapped) {
      AppMessenger.show(
        context,
        const SnackBar(
          content: Text('Open a category tab, then tap Add to map a medicine.'),
        ),
      );
      return;
    }
    await _pickAndAssign(_currentKey);
  }

  Future<void> _pickAndAssign(String category) async {
    final selected = await showAppDialog<Product>(
      context: context,
      builder: (ctx) => _UnmappedMedicinePicker(
        title: 'Map to ${TreatmentUnderCategory.labelOf(category)}',
      ),
    );
    if (selected == null || !mounted) return;
    await _assign(selected.id, category);
  }

  Future<void> _assign(int productId, String? category) async {
    try {
      await context.read<AppServices>().emrMasterData.assignTreatmentUnderProduct(
            productId,
            category,
          );
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(
            category == null
                ? 'Medicine unmapped'
                : 'Mapped to ${TreatmentUnderCategory.labelOf(category)}',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: _innerLabels.map((l) => Tab(text: l)).toList(),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        _isUnmapped
                            ? 'All medicine products are mapped'
                            : 'No medicines in this category yet',
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
                              if (p.currentStock != null)
                                'Stock ${p.currentStock!.toStringAsFixed(0)}',
                              if (p.treatmentUnderCategory != null)
                                TreatmentUnderCategory.labelOf(
                                  p.treatmentUnderCategory,
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
                              ...TreatmentUnderCategory.keys.map(
                                (key) => PopupMenuItem(
                                  value: key,
                                  child: Text(TreatmentUnderCategory.labels[key]!),
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

class _UnmappedMedicinePicker extends StatefulWidget {
  const _UnmappedMedicinePicker({required this.title});

  final String title;

  @override
  State<_UnmappedMedicinePicker> createState() => _UnmappedMedicinePickerState();
}

class _UnmappedMedicinePickerState extends State<_UnmappedMedicinePicker> {
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
      final list = await context.read<AppServices>().emrMasterData.listTreatmentUnderProducts(
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
      subtitle: 'Pick an unmapped medicine product',
      icon: Icons.medication_outlined,
      maxWidth: 520,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search medicines...',
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
                        ? const Center(child: Text('No unmapped medicines'))
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
