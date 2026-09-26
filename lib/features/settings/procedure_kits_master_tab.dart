import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/product.dart';
import '../../data/services/emr_master_data_service.dart';

/// EMR Master Data tab: manage service kits (procedure kits) with product lines.
class ProcedureKitsMasterTab extends StatefulWidget {
  const ProcedureKitsMasterTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<ProcedureKitsMasterTab> createState() => ProcedureKitsMasterTabState();
}

class ProcedureKitsMasterTabState extends State<ProcedureKitsMasterTab> {
  bool _loading = false;
  List<ProcedureKit> _kits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProcedureKitsMasterTab oldWidget) {
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
      final list = await context.read<AppServices>().emrMasterData.listProcedureKits(
            search: q.isEmpty ? null : q,
          );
      if (mounted) setState(() => _kits = list);
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> openForm({ProcedureKit? kit}) async {
    final isEdit = kit != null;
    final name = TextEditingController(text: kit?.name ?? '');
    final code = TextEditingController(text: kit?.procedureCode ?? '');
    final notes = TextEditingController(text: kit?.notes ?? '');
    final productSearch = TextEditingController();
    final searchFocus = FocusNode();
    final searchLink = LayerLink();
    var isActive = kit?.isActive ?? true;
    final items = List<ProcedureKitItem>.from(kit?.items ?? const []);
    var productHits = <Product>[];
    var searching = false;
    Timer? debounce;
    OverlayEntry? overlay;

    void removeOverlay() {
      overlay?.remove();
      overlay = null;
    }

    void disposeControllers() {
      debounce?.cancel();
      removeOverlay();
      name.dispose();
      code.dispose();
      notes.dispose();
      productSearch.dispose();
      searchFocus.dispose();
    }

    final saved = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void showOverlay() {
            removeOverlay();
            if (productHits.isEmpty || !ctx.mounted) return;
            final overlayState = Overlay.of(ctx, rootOverlay: true);
            overlay = OverlayEntry(
              builder: (overlayCtx) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          removeOverlay();
                          setSheet(() => productHits = []);
                        },
                      ),
                    ),
                    CompositedTransformFollower(
                      link: searchLink,
                      showWhenUnlinked: false,
                      offset: const Offset(0, 48),
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 240,
                            minWidth: 280,
                            maxWidth: 520,
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: productHits.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (_, i) {
                              final p = productHits[i];
                              final already = items.any((e) => e.productId == p.id);
                              return ListTile(
                                dense: true,
                                title: Text(p.name, style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  [
                                    '₹${p.sellingPrice.toStringAsFixed(0)}',
                                    if (p.isService) 'Service',
                                    if (p.isMedicine) 'Medicine',
                                  ].join(' · '),
                                ),
                                trailing: already
                                    ? const Text(
                                        'Added',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      )
                                    : IconButton(
                                        tooltip: 'Add to kit',
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: AppTheme.primary,
                                        ),
                                        onPressed: () {
                                          setSheet(() {
                                            items.add(ProcedureKitItem(
                                              productId: p.id,
                                              quantity: 1,
                                              unitPrice: p.sellingPrice,
                                              treatmentName: p.name,
                                              productName: p.name,
                                            ));
                                            productHits = [];
                                            productSearch.clear();
                                          });
                                          removeOverlay();
                                          searchFocus.requestFocus();
                                        },
                                      ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
            overlayState.insert(overlay!);
          }

          Future<void> runSearch(String raw) async {
            final q = raw.trim();
            if (q.isEmpty) {
              setSheet(() {
                productHits = [];
                searching = false;
              });
              removeOverlay();
              return;
            }
            setSheet(() => searching = true);
            try {
              // Search all active catalog items (services + products + medicines).
              final list = await context.read<AppServices>().products.list(
                    query: {
                      'search': q,
                      'per_page': 30,
                      'is_active': 1,
                    },
                  );
              if (!ctx.mounted) return;
              setSheet(() {
                productHits = list;
                searching = false;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) showOverlay();
              });
            } catch (_) {
              if (ctx.mounted) {
                setSheet(() {
                  searching = false;
                  productHits = [];
                });
                removeOverlay();
              }
            }
          }

          return AppFormDialogShell(
            title: isEdit ? 'Edit service kit' : 'Add service kit',
            icon: Icons.medical_services_outlined,
            maxWidth: 640,
            onClose: () {
              removeOverlay();
              Navigator.pop(ctx, false);
            },
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  decoration: appFormFieldDecoration('Kit name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: appFormFieldDecoration('Procedure code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: appFormFieldDecoration('Notes'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setSheet(() => isActive = v),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Service products in this kit',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    Text(
                      '${items.length} added',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CompositedTransformTarget(
                  link: searchLink,
                  child: TextField(
                    controller: productSearch,
                    focusNode: searchFocus,
                    decoration: appFormFieldDecoration('Search services / products...')
                        .copyWith(
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Clear',
                              icon: Icon(
                                productSearch.text.isEmpty ? Icons.search : Icons.clear,
                                size: 20,
                              ),
                              onPressed: productSearch.text.isEmpty
                                  ? null
                                  : () {
                                      productSearch.clear();
                                      setSheet(() => productHits = []);
                                      removeOverlay();
                                    },
                            ),
                    ),
                    onTap: () {
                      if (productHits.isNotEmpty) showOverlay();
                    },
                    onChanged: (q) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 280), () {
                        unawaited(runSearch(q));
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Add at least one service / product. Search above to add more.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  )
                else
                  ...List.generate(items.length, (i) {
                    final item = items[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.productName ?? item.treatmentName),
                        subtitle: Text(
                          '₹${item.unitPrice.toStringAsFixed(0)} · qty ${item.quantity}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppTheme.danger,
                          ),
                          onPressed: () => setSheet(() => items.removeAt(i)),
                        ),
                      ),
                    );
                  }),
              ],
            ),
            footer: AppFormFooter(
              primaryLabel: isEdit ? 'Save' : 'Add',
              onCancel: () {
                removeOverlay();
                Navigator.pop(ctx, false);
              },
              onSubmit: () {
                if (name.text.trim().isEmpty || items.isEmpty) return;
                removeOverlay();
                Navigator.pop(ctx, true);
              },
            ),
          );
        },
      ),
    );

    final body = <String, dynamic>{
      'name': name.text.trim(),
      'procedure_code': code.text.trim().isEmpty ? null : code.text.trim(),
      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      'is_active': isActive,
      'items': items.map((e) => e.toBody()).toList(),
    };
    disposeControllers();

    if (saved != true || !mounted) return;

    try {
      final svc = context.read<AppServices>().emrMasterData;
      if (isEdit) {
        await svc.updateProcedureKit(kit.id, body);
      } else {
        await svc.createProcedureKit(body);
      }
      await _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deactivate(ProcedureKit kit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Deactivate ${kit.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emrMasterData.deleteProcedureKit(kit.id);
      await _load();
    } catch (e) {
      if (mounted) AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_kits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No service kits yet.\nSeed EMR master data or tap + to create one with service products.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _kits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final kit = _kits[i];
        final subtitle = [
          if (kit.procedureCode != null && kit.procedureCode!.isNotEmpty) kit.procedureCode,
          '${kit.itemsCount} products',
          '₹${kit.itemsTotal.toStringAsFixed(0)}',
        ].join(' · ');
        return ListTile(
          title: Text(kit.name),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!kit.isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    'Inactive',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openForm(kit: kit),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                onPressed: () => _deactivate(kit),
              ),
            ],
          ),
        );
      },
    );
  }
}
