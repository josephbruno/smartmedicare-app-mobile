import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_page.dart';

enum UnderKind { treatment, prescription, investigation }

/// One tab ("category") a medicine or investigation can be mapped under.
class _Cat {
  _Cat(this.id, this.slug, this.label, this.isActive);
  final int id;
  final String slug;
  final String label;
  final bool isActive;
}

class _Item {
  _Item({required this.id, required this.name, this.sub, this.slug, this.price});
  final int id;
  final String name;
  final String? sub;
  final String? slug;
  double? price;
}

/// Treatment / Prescription / Investigation "Under" mapping — mirrors
/// `frontend/src/pages/settings/UnderMappingPane.vue`: tabs with counts,
/// Unmapped bucket, pick-and-add, inline default price for investigations.
class UnderMappingPane extends StatefulWidget {
  const UnderMappingPane({super.key, required this.kind});

  final UnderKind kind;

  @override
  State<UnderMappingPane> createState() => _UnderMappingPaneState();
}

class _UnderMappingPaneState extends State<UnderMappingPane> {
  static const _unmapped = '__unmapped__';

  final _search = TextEditingController();
  final _newName = TextEditingController();
  final _newPrice = TextEditingController();
  Timer? _debounce;

  List<_Cat> _cats = [];
  List<_Item> _items = [];
  bool _loadingCats = false;
  bool _loading = false;
  bool _assigning = false;
  bool _creating = false;
  String _selected = _unmapped;
  final Set<int> _picked = {};

  bool get _isInv => widget.kind == UnderKind.investigation;
  String get _singular => _isInv ? 'investigation' : 'medicine';
  String get _plural => _isInv ? 'investigations' : 'medicines';

  List<_Cat> get _active => _cats.where((c) => c.isActive).toList();
  Set<String> get _known => _active.map((c) => c.slug).toSet();

  List<_Item> get _visible {
    if (_selected == _unmapped) return _items.where((i) => i.slug == null || !_known.contains(i.slug)).toList();
    return _items.where((i) => i.slug == _selected).toList();
  }

  int _countFor(String slug) {
    if (slug == _unmapped) return _items.where((i) => i.slug == null || !_known.contains(i.slug)).length;
    return _items.where((i) => i.slug == slug).length;
  }

  List<_Item> get _pickerItems => _items.where((i) => i.slug == null || !_known.contains(i.slug)).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCats();
      if (!mounted) return;
      setState(() => _selected = _active.isNotEmpty ? _active.first.slug : _unmapped);
      await _loadItems();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _newName.dispose();
    _newPrice.dispose();
    super.dispose();
  }

  String _errorText(Object e, String fallback) => e.toString().isEmpty ? fallback : '$fallback: $e';

  Future<void> _loadCats() async {
    setState(() => _loadingCats = true);
    final svc = context.read<AppServices>().emrMasterData;
    try {
      final List<_Cat> cats = switch (widget.kind) {
        UnderKind.treatment => (await svc.listTreatmentUnderCategories(includeInactive: true))
            .map((c) => _Cat(c.id, c.slug, c.label, c.isActive))
            .toList(),
        UnderKind.prescription => (await svc.listPrescriptionUnderCategories(includeInactive: true))
            .map((c) => _Cat(c.id, c.slug, c.label, c.isActive))
            .toList(),
        UnderKind.investigation => (await svc.listInvestigationUnderCategories(includeInactive: true))
            .map((c) => _Cat(c.id, c.slug, c.label, c.isActive))
            .toList(),
      };
      if (!mounted) return;
      setState(() {
        _cats = cats;
        if (_selected != _unmapped && !_active.any((c) => c.slug == _selected)) {
          _selected = _active.isNotEmpty ? _active.first.slug : _unmapped;
        }
      });
    } catch (e) {
      if (mounted) AppMessenger.error(context, _errorText(e, 'Failed to load tabs'));
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final svc = context.read<AppServices>().emrMasterData;
    final q = _search.text.trim();
    try {
      final List<_Item> items;
      if (_isInv) {
        final list = await svc.listInvestigations(search: q.isEmpty ? null : q);
        items = list
            .where((r) => r.isActive)
            .map((r) => _Item(id: r.id, name: r.displayName, slug: r.category, price: r.defaultPrice))
            .toList();
      } else {
        final list = widget.kind == UnderKind.treatment
            ? await svc.listTreatmentUnderProducts(search: q.isEmpty ? null : q)
            : await svc.listPrescriptionUnderProducts(search: q.isEmpty ? null : q);
        items = list
            .map((p) => _Item(
                  id: p.id,
                  name: p.name,
                  sub: [p.categoryName, p.brandName].where((e) => (e ?? '').isNotEmpty).join(' · '),
                  slug: widget.kind == UnderKind.treatment ? p.treatmentUnderCategory : p.prescriptionUnderCategory,
                ))
            .toList();
      }
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) AppMessenger.error(context, _errorText(e, 'Failed to load $_plural'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignOne(int id, String? slug) {
    final svc = context.read<AppServices>().emrMasterData;
    return switch (widget.kind) {
      UnderKind.investigation => svc.updateInvestigation(id, {'category': slug}),
      UnderKind.treatment => svc.assignTreatmentUnderProduct(id, slug),
      UnderKind.prescription => svc.assignPrescriptionUnderProduct(id, slug),
    };
  }

  Future<void> _assign(Iterable<int> ids, String? slug) async {
    if (ids.isEmpty) return;
    setState(() => _assigning = true);
    try {
      await Future.wait(ids.map((id) => _assignOne(id, slug)));
      if (!mounted) return;
      AppMessenger.success(context, slug != null ? 'Mapped' : 'Removed from tab');
      _picked.clear();
      await _loadItems();
    } catch (e) {
      if (mounted) AppMessenger.error(context, _errorText(e, 'Failed to update mapping'));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _createInvestigation() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      await context.read<AppServices>().emrMasterData.createInvestigation({
        'name': name,
        'category': _selected == _unmapped ? null : _selected,
        'default_price': double.tryParse(_newPrice.text.trim()),
      });
      _newName.clear();
      _newPrice.clear();
      if (mounted) AppMessenger.success(context, 'Investigation created');
      await _loadItems();
    } catch (e) {
      if (mounted) AppMessenger.error(context, _errorText(e, 'Failed to create investigation'));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _savePrice(_Item row, String text) async {
    final price = text.trim().isEmpty ? null : double.tryParse(text.trim());
    if (price == row.price) return;
    try {
      await context.read<AppServices>().emrMasterData.updateInvestigation(row.id, {'default_price': price});
      row.price = price;
      if (mounted) AppMessenger.success(context, 'Price saved');
    } catch (e) {
      if (mounted) AppMessenger.error(context, _errorText(e, 'Failed to save price'));
      await _loadItems();
    }
  }

  Future<void> _openCategoryForm([_Cat? cat]) async {
    final label = TextEditingController(text: cat?.label ?? '');
    var active = cat?.isActive ?? true;
    final svc = context.read<AppServices>().emrMasterData;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(cat == null ? 'Add tab' : 'Edit tab'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FieldLabel('Label', required: true, child: TextField(controller: label, autofocus: true)),
              if (cat != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive tabs hide on the visit form'),
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
            ]),
          ),
          actions: [
            if (cat != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'deactivate'),
                style: TextButton.styleFrom(foregroundColor: AppTokens.error),
                child: const Text('Deactivate'),
              ),
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      if (result == 'deactivate' && cat != null) {
        switch (widget.kind) {
          case UnderKind.treatment:
            await svc.deleteTreatmentUnderCategory(cat.id);
          case UnderKind.prescription:
            await svc.deletePrescriptionUnderCategory(cat.id);
          case UnderKind.investigation:
            await svc.deleteInvestigationUnderCategory(cat.id);
        }
        if (mounted) AppMessenger.success(context, 'Tab deactivated');
      } else {
        final text = label.text.trim();
        if (text.isEmpty) {
          AppMessenger.error(context, 'Label is required');
          return;
        }
        if (cat == null) {
          switch (widget.kind) {
            case UnderKind.treatment:
              await svc.createTreatmentUnderCategory(label: text);
            case UnderKind.prescription:
              await svc.createPrescriptionUnderCategory(label: text);
            case UnderKind.investigation:
              await svc.createInvestigationUnderCategory(label: text);
          }
          if (mounted) AppMessenger.success(context, 'Tab added');
        } else {
          switch (widget.kind) {
            case UnderKind.treatment:
              await svc.updateTreatmentUnderCategory(cat.id, label: text, isActive: active);
            case UnderKind.prescription:
              await svc.updatePrescriptionUnderCategory(cat.id, label: text, isActive: active);
            case UnderKind.investigation:
              await svc.updateInvestigationUnderCategory(cat.id, label: text, isActive: active);
          }
          if (mounted) AppMessenger.success(context, 'Tab updated');
        }
      }
      await _loadCats();
      if (cat == null && _active.isNotEmpty) setState(() => _selected = _active.last.slug);
      await _loadItems();
    } catch (e) {
      if (mounted) AppMessenger.error(context, _errorText(e, 'Failed to save tab'));
    }
  }

  Future<void> _pickItems() async {
    final options = _pickerItems;
    final chosen = Set<int>.from(_picked);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Select $_plural'),
          content: SizedBox(
            width: 460,
            height: 420,
            child: ListView(children: [
              for (final i in options)
                CheckboxListTile(
                  dense: true,
                  value: chosen.contains(i.id),
                  title: Text(i.name),
                  subtitle: (i.sub ?? '').isEmpty ? null : Text(i.sub!),
                  onChanged: (v) => setD(() => v == true ? chosen.add(i.id) : chosen.remove(i.id)),
                ),
            ]),
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Done')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _picked
          ..clear()
          ..addAll(chosen);
      });
    }
  }

  Widget _priceField(_Item row) => TextFormField(
        key: ValueKey('price-${row.id}'),
        initialValue: row.price?.toStringAsFixed(2) ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: const InputDecoration(hintText: '0.00', prefixText: '₹ '),
        onFieldSubmitted: (v) => _savePrice(row, v),
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 800), () => _savePrice(row, v));
        },
      );

  Widget _rowAction(_Item row) => _selected == _unmapped
      ? FilterSelect<String>(
          hint: 'Move to…',
          options: {for (final c in _active) c.slug: c.label},
          value: null,
          onChanged: (v) {
            if (v != null) _assign([row.id], v);
          },
        )
      : Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _assigning ? null : () => _assign([row.id], null),
            icon: const Icon(Icons.remove_circle_outline, size: 16),
            label: const Text('Remove'),
            style: TextButton.styleFrom(foregroundColor: AppTokens.error),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final current = _selected == _unmapped ? null : _active.where((c) => c.slug == _selected).firstOrNull;
    final rows = _visible;
    final emoji = _isInv ? '🧪' : '💊';

    Widget subtab(String slug, String label, {bool muted = false}) {
      final active = _selected == slug;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          selected: active,
          showCheckmark: false,
          selectedColor: AppTokens.primaryLight,
          side: BorderSide(color: active ? AppTokens.primary : AppTokens.border),
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppTokens.primary : (muted ? AppTokens.text3 : AppTokens.text2))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: AppTokens.bgTertiary, borderRadius: BorderRadius.circular(999)),
              child: Text('${_countFor(slug)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          onSelected: (_) => setState(() {
            _selected = slug;
            _picked.clear();
          }),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            decoration: InputDecoration(hintText: 'Search $_plural...', prefixIcon: const Icon(Icons.search, size: 18)),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _loadItems);
            },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: () => _openCategoryForm(), child: const Text('Add Tab')),
      ]),
      const SizedBox(height: 12),
      if (_loadingCats) const LinearProgressIndicator(minHeight: 2),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final c in _active) subtab(c.slug, c.label),
          subtab(_unmapped, 'Unmapped', muted: true),
        ]),
      ),
      const SizedBox(height: 12),
      WebCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('$emoji ', style: const TextStyle(fontSize: 18)),
            Text(current?.label ?? 'Unmapped', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (current != null)
              TextButton.icon(
                onPressed: () => _openCategoryForm(current),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit tab'),
              ),
          ]),
          if (current != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickerItems.isEmpty ? null : _pickItems,
                  icon: const Icon(Icons.checklist, size: 18),
                  label: Text(_picked.isEmpty
                      ? 'Select $_plural to add to ${current.label}'
                      : '${_picked.length} selected'),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _picked.isEmpty || _assigning ? null : () => _assign(Set<int>.from(_picked), current.slug),
                child: Text('Add to ${current.label}'),
              ),
            ]),
            if (_pickerItems.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No unmapped $_plural available to add.', style: const TextStyle(color: AppTokens.text3, fontSize: 12)),
              ),
          ],
          if (_isInv) ...[
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              final nameField = TextField(
                controller: _newName,
                decoration: const InputDecoration(hintText: 'New investigation name (e.g. CBC, X-Ray)'),
                onSubmitted: (_) => _createInvestigation(),
              );
              final priceField = TextField(
                controller: _newPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(hintText: 'Default price', prefixText: '₹ '),
              );
              final button = OutlinedButton(
                onPressed: _creating ? null : _createInvestigation,
                child: Text(
                  _selected == _unmapped ? 'Create investigation' : 'Create in ${current?.label ?? ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
              if (c.maxWidth < 640) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  nameField,
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: priceField),
                    const SizedBox(width: 10),
                    Expanded(child: button),
                  ]),
                ]);
              }
              return Row(children: [
                Expanded(flex: 3, child: nameField),
                const SizedBox(width: 10),
                SizedBox(width: 140, child: priceField),
                const SizedBox(width: 10),
                button,
              ]);
            }),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      WebCard(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            : rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text('No $_plural here.', style: const TextStyle(color: AppTokens.text3))),
                  )
                : LayoutBuilder(builder: (context, c) {
                    final narrow = c.maxWidth < 640;
                    if (narrow) {
                      // Phones: one card-like block per row.
                      return Column(children: [
                        for (var i = 0; i < rows.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6)))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text('${i + 1}. ${rows[i].name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              if ((rows[i].sub ?? '').isNotEmpty)
                                Text(rows[i].sub!, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                              const SizedBox(height: 8),
                              Row(children: [
                                if (_isInv) ...[Expanded(child: _priceField(rows[i])), const SizedBox(width: 10)],
                                Expanded(child: _rowAction(rows[i])),
                              ]),
                            ]),
                          ),
                      ]);
                    }
                    return Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(color: const Color(0xFFF4F7FB), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const SizedBox(width: 40, child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(
                            child: Text('${_singular[0].toUpperCase()}${_singular.substring(1)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          if (_isInv)
                            const SizedBox(width: 140, child: Text('Default price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          SizedBox(
                            width: 180,
                            child: Text(_selected == _unmapped ? 'Move to tab' : 'Actions',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                      for (var i = 0; i < rows.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6)))),
                          child: Row(children: [
                            SizedBox(width: 40, child: Text('${i + 1}', style: const TextStyle(color: AppTokens.menuIcon))),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(rows[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if ((rows[i].sub ?? '').isNotEmpty)
                                  Text(rows[i].sub!, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                              ]),
                            ),
                            if (_isInv)
                              SizedBox(
                                width: 140,
                                child: Padding(padding: const EdgeInsets.only(right: 12), child: _priceField(rows[i])),
                              ),
                            SizedBox(width: 180, child: _rowAction(rows[i])),
                          ]),
                        ),
                    ]);
                  }),
      ),
    ]);
  }
}
