import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import 'global_search.dart';

/// Quick navigation + entity search: Ctrl+K (desktop / web-like shell).
Future<void> showCommandPalette(BuildContext context, AuthSession auth) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _CommandPaletteDialog(auth: auth),
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.auth});

  final AuthSession auth;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  int _selected = 0;
  bool _searching = false;
  List<_PaletteEntry> _entityResults = [];

  late final List<_PaletteEntry> _navEntries;

  @override
  void initState() {
    super.initState();
    _navEntries = _buildNavEntries(widget.auth);
    _focus.requestFocus();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      if (_entityResults.isNotEmpty) setState(() => _entityResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final gs = GlobalSearch(context.read<AppServices>());
      final hits = await gs.search(q);
      if (!mounted) return;
      setState(() {
        _entityResults = hits
            .map(
              (h) => _PaletteEntry(
                label: h.label,
                path: h.path,
                icon: _iconForKind(h.kind),
                subtitle: '${h.kind} · ${h.subtitle}',
              ),
            )
            .toList();
        _selected = 0;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'Customer':
        return Icons.person_outline;
      case 'Invoice':
        return Icons.receipt_long_outlined;
      case 'Visit':
        return Icons.medical_services_outlined;
      default:
        return Icons.search;
    }
  }

  List<_PaletteEntry> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _navEntries;
    final nav = _navEntries
        .where((e) =>
            e.label.toLowerCase().contains(q) ||
            e.keywords.any((k) => k.contains(q)))
        .toList();
    return [..._entityResults, ...nav];
  }

  void _go(_PaletteEntry e) {
    Navigator.of(context).pop();
    context.go(e.path);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    if (_selected >= items.length) _selected = items.isEmpty ? 0 : items.length - 1;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _MoveIntent(1),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _MoveIntent(-1),
        LogicalKeySet(LogicalKeyboardKey.enter): const _ActivateIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(onInvoke: (intent) {
            if (items.isEmpty) return null;
            setState(() {
              _selected = (_selected + intent.delta).clamp(0, items.length - 1);
            });
            return null;
          }),
          _ActivateIntent: CallbackAction<_ActivateIntent>(onInvoke: (_) {
            if (items.isNotEmpty) _go(items[_selected]);
            return null;
          }),
        },
        child: Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search customers, invoices, visits, or jump to…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onSubmitted: (_) {
                      if (items.isNotEmpty) _go(items[_selected]);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ctrl+K · type 2+ chars for records · ↑↓ · Enter',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No matches'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final e = items[i];
                            final selected = i == _selected;
                            return ListTile(
                              selected: selected,
                              selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
                              leading: Icon(
                                e.icon,
                                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                              title: Text(e.label),
                              subtitle: e.subtitle != null ? Text(e.subtitle!) : null,
                              onTap: () => _go(e),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteEntry {
  _PaletteEntry({
    required this.label,
    required this.path,
    required this.icon,
    this.subtitle,
    this.keywords = const [],
  });

  final String label;
  final String path;
  final IconData icon;
  final String? subtitle;
  final List<String> keywords;
}

List<_PaletteEntry> _buildNavEntries(AuthSession auth) {
  bool can(String p) => auth.hasPermission(p);
  final entries = <_PaletteEntry>[];

  void add(String label, String path, IconData icon, {bool Function()? visible, List<String>? keywords}) {
    if (visible != null && !visible()) return;
    entries.add(_PaletteEntry(
      label: label,
      path: path,
      icon: icon,
      keywords: keywords ?? [],
    ));
  }

  add('Dashboard', '/dashboard', Icons.dashboard_rounded);
  add('POS Billing', '/pos', Icons.point_of_sale_outlined,
      visible: () => can(AppPermissions.invoicesCreate), keywords: ['sale', 'checkout', 'bill']);
  add('Invoices', '/invoices', Icons.receipt_long_outlined, visible: () => can(AppPermissions.invoicesView));
  add('Customers', '/customers', Icons.people_outline, visible: () => can(AppPermissions.customersView),
      keywords: ['advance', 'loyalty', 'credit limit', 'treatment advance']);
  add('Patient list', '/patients', Icons.pets_outlined, visible: () => can(AppPermissions.petsView));
  // Appointments menu hidden for now
  // add('Appointments', '/emr/appointments', Icons.event_outlined,
  //     visible: () => can(AppPermissions.patientAppointmentsView));
  add('Visit records', '/emr/visits', Icons.medical_services_outlined,
      visible: () => can(AppPermissions.emrVisitsView), keywords: ['emr', 'consultation']);
  add('New visit', '/emr/visits/new', Icons.add_circle_outline,
      visible: () => can(AppPermissions.emrVisitsCreate), keywords: ['create']);
  add('Reminders', '/emr/reminders', Icons.notifications_outlined,
      visible: () => can(AppPermissions.emrRemindersView));
  add('Products', '/products', Icons.inventory_2_outlined, visible: () => can(AppPermissions.productsView));
  add('Inventory', '/inventory', Icons.warehouse_outlined, visible: () => can(AppPermissions.inventoryView));
  add('Stock Alerts', '/stock-alerts', Icons.notification_important_outlined,
      visible: () => can(AppPermissions.inventoryView),
      keywords: ['low stock', 'reorder']);
  add('Stock Expiry', '/stock-alerts?tab=expiry', Icons.event_busy_outlined,
      visible: () => can(AppPermissions.inventoryView),
      keywords: ['expiry', 'near expiry', 'expired', 'batch']);
  add('Stock Ageing', '/stock-ageing', Icons.hourglass_bottom_outlined,
      visible: () => can(AppPermissions.inventoryView),
      keywords: ['dead stock', 'slow moving']);
  add('Purchases', '/purchases', Icons.shopping_bag_outlined, visible: () => can(AppPermissions.purchasesView));
  add('Expenses', '/expenses', Icons.payments_outlined, visible: () => can(AppPermissions.expensesView));
  add('Sales report', '/reports/sales', Icons.bar_chart_outlined,
      visible: () => auth.isSuperAdmin && can(AppPermissions.reportsView));
  add('GST report', '/reports/gst', Icons.description_outlined,
      visible: () => auth.isSuperAdmin && can(AppPermissions.reportsView));
  add('Stock transfer report', '/reports/stock-transfers', Icons.swap_horiz_outlined,
      visible: () => auth.isSuperAdmin && can(AppPermissions.reportsView),
      keywords: ['inventory', 'transfer']);
  add('Day close report', '/reports/day-close', Icons.summarize_outlined,
      visible: () => can(AppPermissions.cashierDayClose),
      keywords: ['cashier', 'shift', 'eod', 'drawer']);
  add('USB Printer', '/settings/printer', Icons.print_outlined,
      visible: () =>
          can(AppPermissions.shopManage) ||
          (auth.hasRole(AppRoles.cashier) &&
              AppConfig.isCashierPlatform &&
              can(AppPermissions.invoicesCreate)),
      keywords: ['thermal', 'escpos', 'xprinter', 'receipt', 'print']);
  add(
    auth.settingsRoute == '/settings/printer' ? 'USB Printer settings' : 'Settings',
    auth.settingsRoute ?? '/settings',
    auth.settingsRoute == '/settings/printer'
        ? Icons.print_outlined
        : Icons.settings_outlined,
    visible: () => auth.canAccessSettings && auth.settingsRoute != '/settings/printer',
  );

  return entries;
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}
