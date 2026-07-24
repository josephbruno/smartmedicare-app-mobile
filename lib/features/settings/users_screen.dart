import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/extensions/permission_extensions.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/shop.dart';
import '../../data/models/user.dart';
import '../../core/widgets/app_dropdown.dart';
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _tableKey = GlobalKey<AppPaginatedTableState<User>>();

  List<Branch> _branches = [];
  List<({String value, String label})> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadFormOptions();
  }

  Future<void> _loadFormOptions() async {
    final services = context.read<AppServices>();
    try {
      final results = await Future.wait([
        services.branches.list(),
        services.users.listRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = results[0] as List<Branch>;
        _roles = results[1] as List<({String value, String label})>;
      });
    } catch (_) {
      // Form still works with defaults if options fail to load.
    }
  }

  List<({String value, String label})> _defaultRoleOptions() => const [
        (value: 'cashier', label: 'Cashier'),
        (value: 'doctor', label: 'Doctor'),
        (value: 'branch_manager', label: 'Branch Manager'),
      ];

  /// On native mobile only doctors can be assigned; desktop/web keeps all roles.
  List<({String value, String label})> _assignableRoleOptions() {
    final all = _roles.isNotEmpty ? _roles : _defaultRoleOptions();
    if (!AppConfig.isNativeMobile) return all;
    return const [(value: 'doctor', label: 'Doctor')];
  }

  /// Non-doctor roles cannot be changed from the mobile app.
  bool _isRoleLockedOnMobile(User? user) {
    if (!AppConfig.isNativeMobile || user == null) return false;
    final current = user.roles.isNotEmpty ? user.roles.first : '';
    return current != 'doctor';
  }

  Future<void> _refreshTable() async {
    await _tableKey.currentState?.refresh();
  }

  Future<void> _openForm({User? user}) async {
    final canCreate = context.hasPermission(AppPermissions.usersCreate);
    final canEdit = context.hasPermission(AppPermissions.usersEdit);

    if (user != null && !canEdit) {
      context.showPermissionDenied();
      return;
    }
    if (user == null && !canCreate) {
      context.showPermissionDenied();
      return;
    }

    final roleOptions = _assignableRoleOptions();
    final roleLocked = _isRoleLockedOnMobile(user);
    final doctorRoleOnly = AppConfig.isNativeMobile;

    final result = await _showUserFormDialog(
      context,
      user: user,
      branches: _branches,
      roleOptions: roleOptions,
      roleLocked: roleLocked,
      doctorRoleOnly: doctorRoleOnly,
    );

    if (result == null || !mounted) return;

    try {
      final svc = context.read<AppServices>().users;
      if (user != null) {
        await svc.update(user.id, result);
      } else {
        await svc.create(result);
      }
      if (!mounted) return;
      AppMessenger.success(
        context,
        user != null ? 'User updated successfully' : 'User created successfully',
      );
      await _refreshTable();
    } catch (e) {
      if (mounted) {
        AppMessenger.error(context, '$e');
      }
    }
  }

  Future<Map<String, dynamic>?> _showUserFormDialog(
    BuildContext context, {
    User? user,
    required List<Branch> branches,
    required List<({String value, String label})> roleOptions,
    required bool roleLocked,
    required bool doctorRoleOnly,
  }) {
    if (useCenteredFormDialog(context)) {
      return showAppDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => _UserFormDialog(
          user: user,
          branches: branches,
          roleOptions: roleOptions,
          roleLocked: roleLocked,
          doctorRoleOnly: doctorRoleOnly,
        ),
      );
    }

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserFormBottomSheet(
        user: user,
        branches: branches,
        roleOptions: roleOptions,
        roleLocked: roleLocked,
        doctorRoleOnly: doctorRoleOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate = context.watch<AuthSession>().hasPermission(AppPermissions.usersCreate);
    final canEdit = context.watch<AuthSession>().hasPermission(AppPermissions.usersEdit);
    final isMobile = ResponsiveLayout.isMobile(context);

    final columns = <TableColumnDef<User>>[
      const TableColumnDef(label: 'User', flex: 2, cellBuilder: _userCell),
      const TableColumnDef(label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
      const TableColumnDef(label: 'Role', flex: 1.3, cellBuilder: _rolesCell),
      const TableColumnDef(label: 'Branch', flex: 1.4, cellBuilder: _branchCell),
      const TableColumnDef(
        label: 'Status',
        flex: 0.9,
        align: TextAlign.center,
        cellBuilder: _statusCell,
      ),
      if (canEdit)
        TableColumnDef(
          label: '',
          flex: 0.5,
          align: TextAlign.center,
          cellBuilder: (_, u) => Tooltip(
            message: 'Edit user',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppTheme.primary,
              onPressed: () => _openForm(user: u),
            ),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canCreate && isMobile
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add user'),
            )
          : null,
      body: AppPaginatedTable<User>(
        key: _tableKey,
        loadPage: ({required page, required perPage}) =>
            services.users.listPaginated(page: page, perPage: perPage),
        columns: columns,
        onRowTap: canEdit ? (u) => _openForm(user: u) : null,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.manage_accounts_rounded,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Management',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Manage staff accounts, roles, and branch access',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Add User'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _userCell(BuildContext context, User u) {
    final initial = u.name.isNotEmpty ? u.name[0].toUpperCase() : '?';
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _roleColor(u.roles.isNotEmpty ? u.roles.first : '').withValues(alpha: 0.15),
          child: Text(
            initial,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _roleColor(u.roles.isNotEmpty ? u.roles.first : ''),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                u.email,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _phoneCell(BuildContext context, User u) => Text(
        u.phone ?? '—',
        style: const TextStyle(fontSize: 13),
      );

  static Widget _branchCell(BuildContext context, User u) => Text(
        u.branch?.name ?? 'All branches',
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        overflow: TextOverflow.ellipsis,
      );

  static Widget _rolesCell(BuildContext context, User u) {
    if (u.roles.isEmpty) return const Text('—');
    final role = u.roles.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _roleColor(role).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _roleColor(role).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_roleIcon(role), size: 14, color: _roleColor(role)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _roleLabel(role),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _roleColor(role),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statusCell(BuildContext context, User u) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: u.isActive
              ? AppTheme.accent.withValues(alpha: 0.12)
              : AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: u.isActive ? AppTheme.accent : AppTheme.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              u.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: u.isActive ? AppTheme.accent : AppTheme.danger,
              ),
            ),
          ],
        ),
      );

  static String _roleLabel(String role) =>
      role.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }).join(' ');

  static IconData _roleIcon(String role) => switch (role) {
        'super_admin' => Icons.admin_panel_settings_outlined,
        'branch_manager' => Icons.storefront_outlined,
        'doctor' => Icons.medical_services_outlined,
        'cashier' => Icons.point_of_sale_outlined,
        'groomer' => Icons.content_cut_outlined,
        _ => Icons.badge_outlined,
      };

  static Color _roleColor(String role) => switch (role) {
        'super_admin' => const Color(0xFF7C3AED),
        'branch_manager' => AppTheme.primary,
        'doctor' => const Color(0xFF0EA5E9),
        'cashier' => AppTheme.accent,
        'groomer' => const Color(0xFFF59E0B),
        _ => AppTheme.textSecondary,
      };
}

// ─── Form dialog (desktop / tablet) ─────────────────────────────────────────

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({
    required this.user,
    required this.branches,
    required this.roleOptions,
    required this.roleLocked,
    required this.doctorRoleOnly,
  });

  final User? user;
  final List<Branch> branches;
  final List<({String value, String label})> roleOptions;
  final bool roleLocked;
  final bool doctorRoleOnly;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _passwordConfirm;
  late String _selectedRole;
  int? _selectedBranchId;
  late bool _isActive;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _password = TextEditingController();
    _passwordConfirm = TextEditingController();
    _selectedRole = u?.roles.isNotEmpty == true
        ? u!.roles.first
        : (widget.doctorRoleOnly ? 'doctor' : widget.roleOptions.first.value);
    _selectedBranchId = u?.branchId;
    _isActive = u?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _validateAndBuildPayload() {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Name and email are required')),
      );
      return null;
    }
    if (!isEdit && _password.text.length < 8) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return null;
    }
    if (!isEdit && _password.text != _passwordConfirm.text) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Passwords must match')),
      );
      return null;
    }
    if (isEdit && _password.text.isNotEmpty) {
      if (_password.text.length < 8) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Password must be at least 8 characters')),
        );
        return null;
      }
      if (_password.text != _passwordConfirm.text) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Passwords must match')),
        );
        return null;
      }
    }

    return {
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      if (!widget.roleLocked) 'role': widget.doctorRoleOnly && !isEdit ? 'doctor' : _selectedRole,
      'branch_id': _selectedBranchId,
      'is_active': _isActive,
      if (!isEdit) ...{
        'email': _email.text.trim(),
        'password': _password.text,
        'password_confirmation': _passwordConfirm.text,
      },
      if (isEdit && _password.text.isNotEmpty) ...{
        'password': _password.text,
        'password_confirmation': _passwordConfirm.text,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = 720.0;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: maxHeight),
        child: SizedBox(
          width: dialogWidth,
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UserFormHeader(
                isEdit: isEdit,
                name: _name.text,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: _UserFormFields(
                    isEdit: isEdit,
                    name: _name,
                    email: _email,
                    phone: _phone,
                    password: _password,
                    passwordConfirm: _passwordConfirm,
                    selectedRole: _selectedRole,
                    selectedBranchId: _selectedBranchId,
                    isActive: _isActive,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    roleOptions: widget.roleOptions,
                    branches: widget.branches,
                    twoColumn: true,
                    roleLocked: widget.roleLocked,
                    doctorRoleOnly: widget.doctorRoleOnly,
                    onRoleChanged: (v) => setState(() => _selectedRole = v),
                    onBranchChanged: (v) => setState(() => _selectedBranchId = v),
                    onActiveChanged: (v) => setState(() => _isActive = v),
                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              _UserFormFooter(
                isEdit: isEdit,
                onCancel: () => Navigator.pop(context),
                onSubmit: () {
                  final payload = _validateAndBuildPayload();
                  if (payload != null) Navigator.pop(context, payload);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Form bottom sheet (mobile) ─────────────────────────────────────────────

class _UserFormBottomSheet extends StatefulWidget {
  const _UserFormBottomSheet({
    required this.user,
    required this.branches,
    required this.roleOptions,
    required this.roleLocked,
    required this.doctorRoleOnly,
  });

  final User? user;
  final List<Branch> branches;
  final List<({String value, String label})> roleOptions;
  final bool roleLocked;
  final bool doctorRoleOnly;

  @override
  State<_UserFormBottomSheet> createState() => _UserFormBottomSheetState();
}

class _UserFormBottomSheetState extends State<_UserFormBottomSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _passwordConfirm;
  late String _selectedRole;
  int? _selectedBranchId;
  late bool _isActive;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _password = TextEditingController();
    _passwordConfirm = TextEditingController();
    _selectedRole = u?.roles.isNotEmpty == true
        ? u!.roles.first
        : (widget.doctorRoleOnly ? 'doctor' : widget.roleOptions.first.value);
    _selectedBranchId = u?.branchId;
    _isActive = u?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _validateAndBuildPayload() {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Name and email are required')),
      );
      return null;
    }
    if (!isEdit && _password.text.length < 8) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return null;
    }
    if (!isEdit && _password.text != _passwordConfirm.text) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Passwords must match')),
      );
      return null;
    }
    if (isEdit && _password.text.isNotEmpty) {
      if (_password.text.length < 8 || _password.text != _passwordConfirm.text) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Check password fields')),
        );
        return null;
      }
    }

    return {
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      if (!widget.roleLocked) 'role': widget.doctorRoleOnly && !isEdit ? 'doctor' : _selectedRole,
      'branch_id': _selectedBranchId,
      'is_active': _isActive,
      if (!isEdit) ...{
        'email': _email.text.trim(),
        'password': _password.text,
        'password_confirmation': _passwordConfirm.text,
      },
      if (isEdit && _password.text.isNotEmpty) ...{
        'password': _password.text,
        'password_confirmation': _passwordConfirm.text,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _UserFormHeader(
              isEdit: isEdit,
              name: _name.text,
              onClose: () => Navigator.pop(context),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _UserFormFields(
                  isEdit: isEdit,
                  name: _name,
                  email: _email,
                  phone: _phone,
                  password: _password,
                  passwordConfirm: _passwordConfirm,
                  selectedRole: _selectedRole,
                  selectedBranchId: _selectedBranchId,
                  isActive: _isActive,
                  obscurePassword: _obscurePassword,
                  obscureConfirm: _obscureConfirm,
                  roleOptions: widget.roleOptions,
                  branches: widget.branches,
                  twoColumn: false,
                  roleLocked: widget.roleLocked,
                  doctorRoleOnly: widget.doctorRoleOnly,
                  onRoleChanged: (v) => setState(() => _selectedRole = v),
                  onBranchChanged: (v) => setState(() => _selectedBranchId = v),
                  onActiveChanged: (v) => setState(() => _isActive = v),
                  onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                  onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            _UserFormFooter(
              isEdit: isEdit,
              onCancel: () => Navigator.pop(context),
              onSubmit: () {
                final payload = _validateAndBuildPayload();
                if (payload != null) Navigator.pop(context, payload);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared form widgets ────────────────────────────────────────────────────

class _UserFormHeader extends StatelessWidget {
  const _UserFormHeader({
    required this.isEdit,
    required this.name,
    required this.onClose,
  });

  final bool isEdit;
  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: isEdit
                ? Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit User' : 'Add New User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? 'Update profile, role, or access settings'
                      : 'Create a staff account with role and branch',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.textSecondary,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _UserFormFooter extends StatelessWidget {
  const _UserFormFooter({
    required this.isEdit,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isEdit;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        color: Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                foregroundColor: AppTheme.textSecondary,
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onSubmit,
              icon: Icon(isEdit ? Icons.save_outlined : Icons.person_add_alt_1_rounded, size: 18),
              label: Text(isEdit ? 'Update User' : 'Create User'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserFormFields extends StatelessWidget {
  const _UserFormFields({
    required this.isEdit,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirm,
    required this.selectedRole,
    required this.selectedBranchId,
    required this.isActive,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.roleOptions,
    required this.branches,
    required this.twoColumn,
    required this.roleLocked,
    required this.doctorRoleOnly,
    required this.onRoleChanged,
    required this.onBranchChanged,
    required this.onActiveChanged,
    required this.onTogglePassword,
    required this.onToggleConfirm,
  });

  final bool isEdit;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController password;
  final TextEditingController passwordConfirm;
  final String selectedRole;
  final int? selectedBranchId;
  final bool isActive;
  final bool obscurePassword;
  final bool obscureConfirm;
  final List<({String value, String label})> roleOptions;
  final List<Branch> branches;
  final bool twoColumn;
  final bool roleLocked;
  final bool doctorRoleOnly;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;

  @override
  Widget build(BuildContext context) {
    final roleValue = roleOptions.any((r) => r.value == selectedRole)
        ? selectedRole
        : roleOptions.first.value;

    Widget field(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: child,
        );

    final profileFields = [
      field(TextField(
        controller: name,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Full name',
          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
        ),
      )),
      field(TextField(
        controller: email,
        readOnly: isEdit,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Email',
          prefixIcon: const Icon(Icons.email_outlined, size: 20),
          filled: isEdit,
          fillColor: isEdit ? const Color(0xFFF1F5F9) : null,
        ),
      )),
      field(TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Phone',
          prefixIcon: Icon(Icons.phone_outlined, size: 20),
        ),
      )),
    ];

    final securityFields = [
      field(TextField(
        controller: password,
        obscureText: obscurePassword,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: isEdit ? 'New password' : 'Password',
          hintText: isEdit ? 'Leave blank to keep current' : 'Min. 8 characters',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: onTogglePassword,
          ),
        ),
      )),
      field(TextField(
        controller: passwordConfirm,
        obscureText: obscureConfirm,
        decoration: InputDecoration(
          labelText: isEdit ? 'Confirm new password' : 'Confirm password',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: onToggleConfirm,
          ),
        ),
      )),
    ];

    final accessFields = [
      field(_buildRoleField(roleValue)),
      field(_BranchDropdown(
        value: selectedBranchId,
        branches: branches,
        onChanged: onBranchChanged,
      )),
      field(_ActiveToggleCard(
        isActive: isActive,
        onChanged: onActiveChanged,
      )),
    ];

    if (!twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(title: 'Profile', icon: Icons.person_outline_rounded),
          ...profileFields,
          const _SectionLabel(title: 'Security', icon: Icons.shield_outlined),
          ...securityFields,
          const _SectionLabel(title: 'Access', icon: Icons.key_outlined),
          ...accessFields,
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel(title: 'Profile', icon: Icons.person_outline_rounded),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: profileFields[0]),
            const SizedBox(width: 16),
            Expanded(child: profileFields[1]),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: profileFields[2]),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ],
        ),
        const _SectionLabel(title: 'Security', icon: Icons.shield_outlined),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: securityFields[0]),
            const SizedBox(width: 16),
            Expanded(child: securityFields[1]),
          ],
        ),
        const _SectionLabel(title: 'Access', icon: Icons.key_outlined),
        accessFields[0],
        accessFields[1],
        accessFields[2],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRoleField(String roleValue) {
    if (roleLocked) {
      return _LockedRoleField(
        role: selectedRole,
        helperText: 'This role can only be changed from the desktop app',
      );
    }
    if (doctorRoleOnly) {
      return _LockedRoleField(
        role: 'doctor',
        helperText: isEdit
            ? 'Doctor role on mobile'
            : 'Mobile app can only create doctor accounts',
      );
    }
    return _RoleDropdown(
      value: roleValue,
      roleOptions: roleOptions,
      onChanged: onRoleChanged,
    );
  }
}

class _LockedRoleField extends StatelessWidget {
  const _LockedRoleField({
    required this.role,
    required this.helperText,
  });

  final String role;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    final color = _UsersScreenState._roleColor(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Role',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
            filled: true,
          ),
          child: Row(
            children: [
              Icon(_UsersScreenState._roleIcon(role), size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _UsersScreenState._roleLabel(role),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helperText,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.value,
    required this.roleOptions,
    required this.onChanged,
  });

  final String value;
  final List<({String value, String label})> roleOptions;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppDropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Role',
        prefixIcon: Icon(Icons.badge_outlined, size: 20),
      ),
      selectedItemBuilder: (context) => roleOptions
          .map(
            (r) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                r.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      items: roleOptions
          .map(
            (r) => DropdownMenuItem(
              value: r.value,
              child: Row(
                children: [
                  Icon(
                    _UsersScreenState._roleIcon(r.value),
                    size: 18,
                    color: _UsersScreenState._roleColor(r.value),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.value,
    required this.branches,
    required this.onChanged,
  });

  final int? value;
  final List<Branch> branches;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppDropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Branch',
        prefixIcon: Icon(Icons.storefront_outlined, size: 20),
      ),
      selectedItemBuilder: (context) => [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'All branches',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        ...branches.map(
          (b) => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              b.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All branches', overflow: TextOverflow.ellipsis),
        ),
        ...branches.map(
          (b) => DropdownMenuItem<int?>(
            value: b.id,
            child: Text(b.name, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        ],
      ),
    );
  }
}

class _ActiveToggleCard extends StatelessWidget {
  const _ActiveToggleCard({
    required this.isActive,
    required this.onChanged,
  });

  final bool isActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppTheme.accent.withValues(alpha: 0.06)
          : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onChanged(!isActive),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppTheme.accent.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Account active' : 'Account inactive',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      isActive
                          ? 'User can sign in and access the system'
                          : 'User is blocked from signing in',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: onChanged,
                activeTrackColor: AppTheme.accent.withValues(alpha: 0.35),
                thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.accent;
                  }
                  return Colors.white;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
