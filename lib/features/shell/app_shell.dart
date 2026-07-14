import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/desktop/command_palette.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../data/local/sync_coordinator.dart';
import '../../core/connectivity/connectivity_notifier.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/local/offline_invoice_queue.dart';
import '../../data/models/shop.dart';
import 'widgets/offline_queue_sheet.dart';

/// Web-like shell (sidebar + header) on tablet/desktop; mobile uses drawer + optional bottom nav.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthSession>();
      if (auth.isAuthenticated && auth.isUnlocked) {
        auth.refreshProfileIfNeeded();
      } else if (auth.isAuthenticated &&
          (auth.user?.roles.isEmpty ?? false)) {
        auth.fetchMe();
      }
    });
  }

  static List<_NavDest> _mobileDestinations(AuthSession auth) {
    if (auth.hasRole(AppRoles.doctor)) {
      return [
        const _NavDest(
          label: 'Home',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          location: '/dashboard',
        ),
        if (auth.hasPermission(AppPermissions.patientAppointmentsView))
          const _NavDest(
            label: 'Appts',
            icon: Icons.event_outlined,
            activeIcon: Icons.event_rounded,
            location: '/emr/appointments',
          ),
        if (auth.hasPermission(AppPermissions.emrVisitsView))
          const _NavDest(
            label: 'Visits',
            icon: Icons.medical_services_outlined,
            activeIcon: Icons.medical_services_rounded,
            location: '/emr/visits',
          ),
        if (auth.hasPermission(AppPermissions.emrRemindersView))
          const _NavDest(
            label: 'Reminders',
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications_rounded,
            location: '/emr/reminders',
          ),
      ];
    }

    final items = <_NavDest>[];
    if (!auth.hasRole(AppRoles.cashier)) {
      items.add(const _NavDest(
        label: 'Home',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        location: '/dashboard',
      ));
    }
    if (auth.hasPermission(AppPermissions.invoicesCreate)) {
      items.add(const _NavDest(
        label: 'POS',
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale_rounded,
        location: '/pos',
      ));
    }
    if (auth.hasPermission(AppPermissions.customersView)) {
      items.add(const _NavDest(
        label: 'Customers',
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        location: '/customers',
      ));
    }
    if (auth.hasPermission(AppPermissions.invoicesView)) {
      items.add(const _NavDest(
        label: 'Invoices',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        location: '/invoices',
      ));
    }
    if (items.isEmpty) {
      items.add(_NavDest(
        label: 'Home',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        location: auth.homeRoute,
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final loc = GoRouterState.of(context).uri.path;
    final webLike = useWebLikeShell(context);
    final connectivity = context.watch<ConnectivityNotifier>();
    final syncCoordinator = context.read<SyncCoordinator>();

    Future<void> syncAll() async {
      try {
        await syncCoordinator.syncAll(branchId: auth.currentBranchId);
        if (context.mounted) {
          AppMessenger.show(context,
            const SnackBar(
              content: Text('Catalog and offline invoices synced'),
              backgroundColor: AppTheme.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppMessenger.show(context,
            SnackBar(content: Text('Sync failed: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }

    if (webLike && loc.startsWith('/pos')) {
      return _PosFullscreenShell(
        auth: auth,
        connectivity: connectivity,
        onSync: syncAll,
        child: widget.child,
      );
    }

    if (webLike) {
      return _DesktopShell(
        auth: auth,
        location: loc,
        connectivity: connectivity,
        onSync: syncAll,
        child: widget.child,
      );
    }

    return _MobileShell(
      auth: auth,
      location: loc,
      connectivity: connectivity,
      destinations: _mobileDestinations(auth),
      onSync: syncAll,
      child: widget.child,
    );
  }
}

class _NavDest {
  const _NavDest({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.location,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String location;
}

class _PosFullscreenShell extends StatelessWidget {
  const _PosFullscreenShell({
    required this.auth,
    required this.connectivity,
    required this.onSync,
    required this.child,
  });

  final AuthSession auth;
  final ConnectivityNotifier connectivity;
  final Future<void> Function() onSync;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool desktop = AppConfig.usesLargeUiScale;
    double ic(double base) => desktop ? base * AppConfig.desktopIconScale : base;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            height: desktop ? 60 : 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
            ),
            child: Row(
              children: [
                AppLogo(size: ic(28)),
                const SizedBox(width: 10),
                const Text('POS Billing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    auth.currentBranch?.name ?? 'Branch',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
                const Spacer(),
                _OnlineChip(connectivity: connectivity),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onSync,
                  icon: Icon(Icons.cloud_upload_outlined, size: ic(18)),
                  label: const Text('Sync'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: Icon(Icons.close_rounded, size: ic(16)),
                  label: const Text('Exit POS'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DesktopShell extends StatefulWidget {
  const _DesktopShell({
    required this.auth,
    required this.location,
    required this.child,
    required this.connectivity,
    required this.onSync,
  });

  final AuthSession auth;
  final String location;
  final Widget child;
  final ConnectivityNotifier connectivity;
  final Future<void> Function() onSync;

  @override
  State<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<_DesktopShell> {
  static const _kSidebarCollapsed = 'desktop_sidebar_collapsed';

  bool _collapsed = false;
  List<Branch> _branches = [];
  bool _loadingBranches = false;
  int _offlinePending = 0;

  @override
  void initState() {
    super.initState();
    _loadSidebarPref();
    _loadBranches();
    _refreshOfflineCount();
  }

  Future<void> _refreshOfflineCount() async {
    try {
      final count = await context.read<OfflineInvoiceQueue>().pendingCount();
      if (mounted) setState(() => _offlinePending = count);
    } catch (_) {}
  }

  Future<void> _handleSync() async {
    await widget.onSync();
    await _refreshOfflineCount();
  }

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _collapsed = prefs.getBool(_kSidebarCollapsed) ?? false);
  }

  Future<void> _toggleSidebar() async {
    setState(() => _collapsed = !_collapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSidebarCollapsed, _collapsed);
  }

  Future<void> _loadBranches() async {
    if (!widget.auth.isSuperAdmin) return;
    setState(() => _loadingBranches = true);
    try {
      final list = await context.read<AppServices>().branches.list();
      if (mounted) setState(() => _branches = list);
    } catch (_) {
      // ignore — switcher hidden if load fails
    } finally {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  Future<void> _switchBranch(int? branchId) async {
    if (branchId == null) return;
    try {
      await widget.auth.switchBranch(branchId);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Branch switched'), backgroundColor: AppTheme.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  bool _isMenuItemSelected(String location, String? menuPath, List<_MenuItem> allItems) {
    if (menuPath == null) return false;

    // Since all menus are separate (no parent-child relationships),
    // only highlight on exact path match
    return location == menuPath;
  }

  @override
  Widget build(BuildContext context) {
    final items = _menuItems(widget.auth);
    final userName = widget.auth.user?.name ?? 'Admin';
    final userInitials = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'A';
    final bool desktop = AppConfig.usesLargeUiScale;
    double ic(double base) => desktop ? base * AppConfig.desktopIconScale : base;
    // Wider sidebar on desktop to fit larger fonts/icons.
    final sidebarWidth = _collapsed ? (desktop ? 84.0 : 72.0) : (desktop ? 300.0 : 260.0);

    final width = MediaQuery.of(context).size.width;
    final subtitle = widget.location.startsWith('/dashboard')
        ? "Welcome back! Here's what's happening today."
        : '';
    final showSubtitle = subtitle.isNotEmpty && width >= 900;
    final showSearch = width >= 1000;

    return KeyboardShortcutHandler(
      shortcuts: {
        ShortcutKey.ctrl(LogicalKeyboardKey.keyK): () =>
            showCommandPalette(context, widget.auth),
      },
      child: Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sidebarWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: _collapsed ? 12 : 20, vertical: 20),
                  child: Row(
                    children: [
                      const AppLogo(size: 36),
                      if (!_collapsed) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Maran Billing',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: _collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                        icon: Icon(_collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
                        onPressed: _toggleSidebar,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final m = items[idx];
                      if (m.isHeader) {
                        if (_collapsed) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: Divider(color: Color(0xFFF1F5F9), height: 1),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
                          child: Text(
                            m.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      }
                      if (m.path == null) return const SizedBox.shrink();

                      final isSelected = _isMenuItemSelected(widget.location, m.path, items);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Tooltip(
                          message: _collapsed ? m.label : '',
                          child: ListTile(
                            dense: !desktop,
                            leading: Icon(
                              m.icon,
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              size: ic(20),
                            ),
                            title: _collapsed
                                ? null
                                : Text(
                                    m.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                                    ),
                                  ),
                            selected: isSelected,
                            selectedTileColor: AppTheme.primary.withOpacity(0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onTap: () => context.go(m.path!),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!_collapsed)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: desktop ? 22 : 18,
                            backgroundColor: AppTheme.primary,
                            child: Text(userInitials, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(widget.auth.currentBranch?.name ?? 'Branch',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.logout_rounded, color: AppTheme.textSecondary, size: ic(18)),
                            onPressed: () async {
                              await widget.auth.logout();
                              if (context.mounted) context.go('/');
                            },
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: desktop ? 72 : 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _titleForPath(widget.location),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (showSubtitle)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                      if (showSearch)
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, searchConstraints) {
                              if (searchConstraints.maxWidth < 140) {
                                return const SizedBox.shrink();
                              }
                              return Align(
                                alignment: Alignment.center,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: AppConfig.usesLargeUiScale
                                        ? AppConfig.desktopSearchMaxWidth
                                        : 460,
                                  ),
                                  child: _TopSearchBox(auth: widget.auth),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      if (widget.auth.isSuperAdmin && _branches.length > 1) ...[
                        Container(
                          height: 40,
                          width: 190,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _loadingBranches
                              ? const Center(
                                  child: SizedBox(
                                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                    value: widget.auth.currentBranchId,
                                    items: _branches
                                        .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                                        .toList(),
                                    onChanged: _switchBranch,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      _OnlineChip(connectivity: widget.connectivity),
                      const SizedBox(width: 8),
                      if (_offlinePending > 0)
                        Badge(
                          label: Text('$_offlinePending'),
                          child: IconButton(
                            tooltip: 'Pending offline invoices',
                            icon: const Icon(Icons.cloud_queue_outlined, color: AppTheme.textSecondary),
                            onPressed: () async {
                              await OfflineQueueSheet.show(context);
                              await _refreshOfflineCount();
                            },
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _handleSync,
                        icon: Icon(Icons.cloud_upload_outlined, size: ic(18)),
                        label: const Text('Sync'),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Notifications',
                        icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textSecondary),
                        onPressed: () {
                          if (widget.auth.hasPermission('emr.reminders.view')) {
                            context.go('/emr/reminders');
                          } else {
                            AppMessenger.show(context,
                              const SnackBar(content: Text('No new notifications')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Command palette (Ctrl+K)',
                        icon: const Icon(Icons.manage_search_rounded),
                        onPressed: () => showCommandPalette(context, widget.auth),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
                        onPressed: widget.auth.settingsRoute != null
                            ? () => context.go(widget.auth.settingsRoute!)
                            : null,
                      ),
                    ],
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _OnlineChip extends StatelessWidget {
  const _OnlineChip({required this.connectivity});

  final ConnectivityNotifier connectivity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: connectivity.isOnline
            ? AppTheme.accent.withOpacity(0.08)
            : AppTheme.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connectivity.isOnline
              ? AppTheme.accent.withOpacity(0.3)
              : AppTheme.danger.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connectivity.isOnline ? AppTheme.accent : AppTheme.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connectivity.isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: connectivity.isOnline ? AppTheme.accent : AppTheme.danger,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


/// Global search in the desktop top bar — opens the command palette (Ctrl+K).
class _TopSearchBox extends StatelessWidget {
  const _TopSearchBox({required this.auth});

  final AuthSession auth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showShortcut = constraints.maxWidth > 220;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => showCommandPalette(context, auth),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Search customers, invoices, visits…',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showShortcut) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Ctrl + K',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem {
  _MenuItem({
    required this.label,
    this.icon,
    this.path,
    this.isHeader = false,
  });

  /// A non-navigable section title (e.g. "SALES & BILLING").
  _MenuItem.header(String title) : this(label: title, isHeader: true);

  final String label;
  final IconData? icon;
  final String? path;
  final bool isHeader;
}

List<_MenuItem> _menuItems(AuthSession auth) {
  bool can(String p) => auth.hasPermission(p);

  final result = <_MenuItem>[];

  void addSection(String title, List<_MenuItem> items) {
    if (items.isEmpty) return;
    result.add(_MenuItem.header(title));
    result.addAll(items);
  }

  if (auth.hasRole('doctor')) {
    result.add(_MenuItem(label: 'Dashboard', icon: Icons.dashboard_rounded, path: '/dashboard'));
    addSection('CUSTOMERS & PATIENTS', [
      if (can('customers.view')) ...[
        _MenuItem(label: 'Customers', icon: Icons.people_outline, path: '/customers'),
        _MenuItem(label: 'Patient List', icon: Icons.pets_outlined, path: '/patients'),
      ],
      if (can('patient_appointments.view'))
        _MenuItem(label: 'Appointments', icon: Icons.event_outlined, path: '/emr/appointments'),
      if (can('emr.visits.view'))
        _MenuItem(label: 'Visit Records', icon: Icons.medical_services_outlined, path: '/emr/visits'),
      if (can('emr.reminders.view'))
        _MenuItem(label: 'Reminders', icon: Icons.notifications_outlined, path: '/emr/reminders'),
    ]);
    return result;
  }

  result.add(_MenuItem(label: 'Dashboard', icon: Icons.dashboard_rounded, path: '/dashboard'));

  addSection('SALES & BILLING', [
    if (can('invoices.create'))
      _MenuItem(label: 'POS Billing', icon: Icons.point_of_sale_outlined, path: '/pos'),
    if (can('invoices.view'))
      _MenuItem(label: 'Invoices', icon: Icons.receipt_long_outlined, path: '/invoices'),
    if (can('purchases.view'))
      _MenuItem(label: 'Purchases', icon: Icons.shopping_bag_outlined, path: '/purchases'),
    if (can('expenses.view'))
      _MenuItem(label: 'Expenses', icon: Icons.payments_outlined, path: '/expenses'),
  ]);

  addSection('INVENTORY', [
    if (can('products.view'))
      _MenuItem(label: 'Products', icon: Icons.inventory_2_outlined, path: '/products'),
    if (can('inventory.view'))
      _MenuItem(label: 'Inventory', icon: Icons.warehouse_outlined, path: '/inventory'),
    if (can('inventory.transfer'))
      _MenuItem(label: 'Stock Transfers', icon: Icons.swap_horiz_outlined, path: '/stock-transfers'),
  ]);

  addSection('CUSTOMERS & PATIENTS', [
    if (can('customers.view')) ...[
      _MenuItem(label: 'Customers', icon: Icons.people_outline, path: '/customers'),
      _MenuItem(label: 'Patient List', icon: Icons.pets_outlined, path: '/patients'),
    ],
    if (can('emr.visits.view'))
      _MenuItem(label: 'Visit Records', icon: Icons.medical_services_outlined, path: '/emr/visits'),
    if (can('emr.reminders.view'))
      _MenuItem(label: 'Reminders', icon: Icons.notifications_outlined, path: '/emr/reminders'),
  ]);

  addSection('REPORTS', [
    if (can('reports.view')) ...[
      _MenuItem(label: 'Sales Report', icon: Icons.bar_chart_outlined, path: '/reports/sales'),
      _MenuItem(label: 'GST Report', icon: Icons.description_outlined, path: '/reports/gst'),
    ],
  ]);

  addSection('MANAGEMENT', [
    if (can('suppliers.view'))
      _MenuItem(label: 'Suppliers', icon: Icons.local_shipping_outlined, path: '/suppliers'),
    if (can('doctors.manage'))
      _MenuItem(label: 'Doctors', icon: Icons.medical_information_outlined, path: '/settings/doctors'),
    if (can('emr.master_data.manage'))
      _MenuItem(label: 'EMR Master Data', icon: Icons.list_alt_outlined, path: '/settings/emr-master-data'),
    if (can('shop.manage'))
      _MenuItem(label: 'Settings', icon: Icons.settings_outlined, path: '/settings'),
    if (can('users.view'))
      _MenuItem(label: 'Users', icon: Icons.manage_accounts_outlined, path: '/settings/users'),
    if (can('branch.manage'))
      _MenuItem(label: 'Branches', icon: Icons.apartment_outlined, path: '/settings/branches'),
  ]);

  return result;
}

String _titleForPath(String path) {
  if (path.startsWith('/pos')) return 'Point of Sale';
  if (path.startsWith('/invoices')) return 'Invoices';
  if (path.startsWith('/products')) return 'Products';
  if (path.startsWith('/inventory')) return 'Inventory';
  if (path.startsWith('/stock-ageing')) return 'Stock Ageing';
  if (path.startsWith('/stock-transfers')) return 'Stock Transfers';
  if (path.startsWith('/purchases')) return 'Purchases';
  if (path.startsWith('/suppliers')) return 'Suppliers';
  if (path.startsWith('/customers')) return 'Customers';
  if (path.startsWith('/patients')) return 'Patient List';
  if (path.startsWith('/emr/pets') && path.contains('/timeline')) return 'Pet Timeline';
  if (path.startsWith('/emr/pets') && path.contains('/deworming')) return 'Deworming';
  if (path.startsWith('/emr/pets') && path.contains('/surgeries')) return 'Surgeries';
  if (path.startsWith('/emr/pets') && path.contains('/lab-reports')) return 'Lab Reports';
  if (path.startsWith('/emr/pets') && path.contains('/documents')) return 'Documents';
  if (path.startsWith('/emr/visits')) return 'Visit Records';
  if (path.startsWith('/emr/reminders')) return 'Reminders';
  if (path.startsWith('/expenses')) return 'Expenses';
  if (path.startsWith('/reports/sales')) return 'Sales Report';
  if (path.startsWith('/reports/gst')) return 'GST Report';
  if (path.startsWith('/settings/doctors')) return 'Doctors';
  if (path.startsWith('/settings/emr-master-data')) return 'EMR Master Data';
  if (path.startsWith('/settings/users')) return 'Users';
  if (path.startsWith('/settings/branches')) return 'Branches';
  if (path.startsWith('/settings')) return 'Settings';
  return 'Dashboard';
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.auth,
    required this.location,
    required this.destinations,
    required this.connectivity,
    required this.onSync,
    required this.child,
  });

  final AuthSession auth;
  final String location;
  final List<_NavDest> destinations;
  final ConnectivityNotifier connectivity;
  final Future<void> Function() onSync;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final items = _menuItems(auth);
    final userName = auth.user?.name ?? 'Admin';
    final userInitials = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'A';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleForPath(location),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          // Network indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connectivity.isOnline ? AppTheme.accent : AppTheme.danger,
              shape: BoxShape.circle,
            ),
          ),
          IconButton(
            tooltip: 'Sync Offline Data',
            onPressed: onSync,
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Drawer Header
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      userInitials,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Store Manager',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            // Menu Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final m = items[idx];
                  if (m.isHeader) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                      child: Text(
                        m.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    );
                  }
                  if (m.path == null) return const SizedBox.shrink();

                  final isSelected = location == m.path || location.startsWith('${m.path}/');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        m.icon,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppTheme.primary.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        context.go(m.path!);
                      },
                    ),
                  );
                },
              ),
            ),
            // Drawer Footer Logout Button
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.danger,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: AppTheme.danger.withOpacity(0.05),
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/');
                },
              ),
            ),
          ],
        ),
      ),
      body: child,
      bottomNavigationBar: destinations.length >= 2
          ? Container(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBar(
                backgroundColor: Colors.white,
                elevation: 0,
                height: 64,
                indicatorColor: AppTheme.primary.withOpacity(0.12),
                selectedIndex: _mobileNavIndex(location, destinations),
                onDestinationSelected: (i) {
                  context.go(destinations[i].location);
                },
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(
                      icon: Icon(d.icon, color: AppTheme.textSecondary),
                      selectedIcon: Icon(d.activeIcon, color: AppTheme.primary),
                      label: d.label,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

int _mobileNavIndex(String location, List<_NavDest> dests) {
  for (var i = 0; i < dests.length; i++) {
    if (location.startsWith(dests[i].location)) return i;
  }
  return 0;
}
