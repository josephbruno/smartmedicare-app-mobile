import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/extensions/permission_extensions.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/receipt_branch_store.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/shop.dart';
import '../subscription/plan_guard.dart';

/// Matches frontend [BranchManagementPage.vue]: card grid + add/edit form.
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  List<Branch> _branches = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<AppServices>().branches.list();
      if (mounted) setState(() => _branches = list);
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Branch? branch}) async {
    if (!context.hasPermission(AppPermissions.branchManage)) {
      context.showPermissionDenied();
      return;
    }

    final payload = await _showBranchForm(context, branch: branch);
    if (payload == null || !mounted) return;

    try {
      final svc = context.read<AppServices>().branches;
      if (branch != null) {
        await svc.update(branch.id, payload);
      } else {
        await svc.create(payload);
      }
      if (!mounted) return;
      AppMessenger.success(
        context,
        branch != null ? 'Branch updated' : 'Branch created',
      );
      await _load();
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    }
  }

  Future<void> _switchToBranch(Branch branch) async {
    final auth = context.read<AuthSession>();
    if (auth.currentBranchId == branch.id) return;

    try {
      await auth.switchBranch(branch.id);
      final info = ReceiptBranchStore.fromBranch(branch);
      if (info != null) await ReceiptBranchStore.save(info);
      if (!mounted) return;
      AppMessenger.success(context, 'Switched to branch');
    } catch (_) {
      if (mounted) AppMessenger.error(context, 'Failed to switch branch');
    }
  }

  Future<Map<String, dynamic>?> _showBranchForm(
    BuildContext context, {
    Branch? branch,
  }) {
    if (useCenteredFormDialog(context)) {
      return showAppDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => _BranchFormDialog(branch: branch),
      );
    }

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BranchFormBottomSheet(branch: branch),
    );
  }

  int _gridColumns(double width) {
    if (width >= 1100) return 3;
    if (width >= 700) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        context.watch<AuthSession>().hasPermission(AppPermissions.branchManage);
    final currentBranchId = context.watch<AuthSession>().currentBranchId;
    final width = MediaQuery.sizeOf(context).width;
    final columns = _gridColumns(width);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Branch Management',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_branches.length} branches',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canManage) ...[
                            const SizedBox(width: 12),
                            FilledButton(
                              // Plan: Multi-branch module + branch limit.
                              onPressed: () async {
                                if (await ensurePlanAllows(context,
                                    capability: 'multi_branch',
                                    capabilityLabel: 'Multi-branch',
                                    limitResource: 'branches')) {
                                  _openForm();
                                }
                              },
                              child: const Text('+ Add Branch'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!_loading && _branches.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No branches found')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: columns == 1
                              ? 1.55
                              : columns == 2
                                  ? 1.15
                                  : 1.05,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final branch = _branches[index];
                            return _BranchCard(
                              branch: branch,
                              isCurrent: currentBranchId == branch.id,
                              canManage: canManage,
                              onEdit: () => _openForm(branch: branch),
                              onSwitch: () => _switchToBranch(branch),
                            );
                          },
                          childCount: _branches.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.isCurrent,
    required this.canManage,
    required this.onEdit,
    required this.onSwitch,
  });

  final Branch branch;
  final bool isCurrent;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: branch.isMain ? AppTheme.accent : const Color(0xFFE5E7EB),
          width: branch.isMain ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header (matches n-card #header)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Text(
                        branch.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (branch.isMain)
                        _Tag(label: 'Main', color: AppTheme.accent),
                      _Tag(
                        label: branch.isActive ? 'Active' : 'Inactive',
                        color: branch.isActive ? AppTheme.accent : AppTheme.danger,
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  IconButton(
                    tooltip: 'Edit branch',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppTheme.textSecondary,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // Descriptions
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (branch.code != null && branch.code!.isNotEmpty)
                    _DescItem(label: 'Code', value: branch.code!),
                  if (branch.phone != null && branch.phone!.isNotEmpty)
                    _DescItem(label: 'Phone', value: branch.phone!),
                  if (branch.email != null && branch.email!.isNotEmpty)
                    _DescItem(label: 'Email', value: branch.email!),
                  if (branch.gstin != null && branch.gstin!.isNotEmpty)
                    _DescItem(label: 'GSTIN', value: branch.gstin!),
                  _DescItem(
                    label: 'Invoice Edit Code',
                    child: _Tag(
                      label: branch.invoiceEditCodeConfigured
                          ? 'Configured'
                          : 'Not configured',
                      color: branch.invoiceEditCodeConfigured
                          ? AppTheme.accent
                          : AppTheme.warning,
                    ),
                  ),
                  _DescItem(label: 'Address', value: branch.formattedAddress),
                ],
              ),
            ),
          ),
          // Actions
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: isCurrent
                  ? _Tag(label: 'Current Branch', color: AppTheme.accent)
                  : FilledButton(
                      onPressed: onSwitch,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Switch to Branch'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DescItem extends StatelessWidget {
  const _DescItem({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888888),
              ),
            ),
          ),
          Expanded(
            child: child ??
                Text(
                  value ?? '—',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Form dialog (desktop / tablet) ─────────────────────────────────────────

class _BranchFormDialog extends StatefulWidget {
  const _BranchFormDialog({this.branch});

  final Branch? branch;

  @override
  State<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<_BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _gstin;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _invoiceEditCode;
  late bool _isActive;
  bool _obscureCode = true;

  bool get isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _name = TextEditingController(text: b?.name ?? '');
    _code = TextEditingController(text: b?.code ?? '');
    _phone = TextEditingController(text: b?.phone ?? '');
    _email = TextEditingController(text: b?.email ?? '');
    _gstin = TextEditingController(text: b?.gstin ?? '');
    _address = TextEditingController(text: b?.address ?? '');
    _city = TextEditingController(text: b?.city ?? '');
    _state = TextEditingController(text: b?.state ?? '');
    _pincode = TextEditingController(text: b?.pincode ?? '');
    _invoiceEditCode = TextEditingController();
    _isActive = b?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _phone.dispose();
    _email.dispose();
    _gstin.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _invoiceEditCode.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _validateAndBuildPayload() {
    if (!_formKey.currentState!.validate()) return null;

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'code': _nullIfEmpty(_code.text),
      'phone': _nullIfEmpty(_phone.text),
      'email': _nullIfEmpty(_email.text),
      'gstin': _nullIfEmpty(_gstin.text),
      'address': _nullIfEmpty(_address.text),
      'city': _nullIfEmpty(_city.text),
      'state': _nullIfEmpty(_state.text),
      'pincode': _nullIfEmpty(_pincode.text),
      'is_active': _isActive,
    };

    if (_invoiceEditCode.text.trim().isNotEmpty) {
      payload['invoice_edit_code'] = _invoiceEditCode.text.trim();
    }

    return payload;
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialogShell(
      title: isEdit ? 'Edit Branch' : 'Add Branch',
      subtitle: isEdit
          ? 'Update branch details and settings'
          : 'Create a new branch location',
      icon: Icons.apartment_rounded,
      maxWidth: 600,
      onClose: () => Navigator.pop(context),
      body: _BranchFormFields(
        formKey: _formKey,
        name: _name,
        code: _code,
        phone: _phone,
        email: _email,
        gstin: _gstin,
        address: _address,
        city: _city,
        state: _state,
        pincode: _pincode,
        invoiceEditCode: _invoiceEditCode,
        isActive: _isActive,
        obscureCode: _obscureCode,
        isEdit: isEdit,
        twoColumn: true,
        onActiveChanged: (v) => setState(() => _isActive = v),
        onToggleCodeVisibility: () =>
            setState(() => _obscureCode = !_obscureCode),
      ),
      footer: AppFormFooter(
        primaryLabel: isEdit ? 'Update Branch' : 'Create Branch',
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          final payload = _validateAndBuildPayload();
          if (payload != null) Navigator.pop(context, payload);
        },
      ),
    );
  }
}

// ─── Form bottom sheet (mobile) ─────────────────────────────────────────────

class _BranchFormBottomSheet extends StatefulWidget {
  const _BranchFormBottomSheet({this.branch});

  final Branch? branch;

  @override
  State<_BranchFormBottomSheet> createState() => _BranchFormBottomSheetState();
}

class _BranchFormBottomSheetState extends State<_BranchFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _gstin;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _invoiceEditCode;
  late bool _isActive;
  bool _obscureCode = true;

  bool get isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _name = TextEditingController(text: b?.name ?? '');
    _code = TextEditingController(text: b?.code ?? '');
    _phone = TextEditingController(text: b?.phone ?? '');
    _email = TextEditingController(text: b?.email ?? '');
    _gstin = TextEditingController(text: b?.gstin ?? '');
    _address = TextEditingController(text: b?.address ?? '');
    _city = TextEditingController(text: b?.city ?? '');
    _state = TextEditingController(text: b?.state ?? '');
    _pincode = TextEditingController(text: b?.pincode ?? '');
    _invoiceEditCode = TextEditingController();
    _isActive = b?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _phone.dispose();
    _email.dispose();
    _gstin.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _invoiceEditCode.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _validateAndBuildPayload() {
    if (!_formKey.currentState!.validate()) return null;

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'code': _nullIfEmpty(_code.text),
      'phone': _nullIfEmpty(_phone.text),
      'email': _nullIfEmpty(_email.text),
      'gstin': _nullIfEmpty(_gstin.text),
      'address': _nullIfEmpty(_address.text),
      'city': _nullIfEmpty(_city.text),
      'state': _nullIfEmpty(_state.text),
      'pincode': _nullIfEmpty(_pincode.text),
      'is_active': _isActive,
    };

    if (_invoiceEditCode.text.trim().isNotEmpty) {
      payload['invoice_edit_code'] = _invoiceEditCode.text.trim();
    }

    return payload;
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormBottomSheetShell(
      title: isEdit ? 'Edit Branch' : 'Add Branch',
      subtitle: isEdit
          ? 'Update branch details and settings'
          : 'Create a new branch location',
      icon: Icons.apartment_rounded,
      onClose: () => Navigator.pop(context),
      body: _BranchFormFields(
        formKey: _formKey,
        name: _name,
        code: _code,
        phone: _phone,
        email: _email,
        gstin: _gstin,
        address: _address,
        city: _city,
        state: _state,
        pincode: _pincode,
        invoiceEditCode: _invoiceEditCode,
        isActive: _isActive,
        obscureCode: _obscureCode,
        isEdit: isEdit,
        twoColumn: false,
        onActiveChanged: (v) => setState(() => _isActive = v),
        onToggleCodeVisibility: () =>
            setState(() => _obscureCode = !_obscureCode),
      ),
      footer: AppFormFooter(
        primaryLabel: isEdit ? 'Update Branch' : 'Create Branch',
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          final payload = _validateAndBuildPayload();
          if (payload != null) Navigator.pop(context, payload);
        },
      ),
    );
  }
}

// ─── Shared form fields (same as frontend modal) ────────────────────────────

class _BranchFormFields extends StatelessWidget {
  const _BranchFormFields({
    required this.formKey,
    required this.name,
    required this.code,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.invoiceEditCode,
    required this.isActive,
    required this.obscureCode,
    required this.isEdit,
    required this.twoColumn,
    required this.onActiveChanged,
    required this.onToggleCodeVisibility,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController code;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController gstin;
  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController state;
  final TextEditingController pincode;
  final TextEditingController invoiceEditCode;
  final bool isActive;
  final bool obscureCode;
  final bool isEdit;
  final bool twoColumn;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onToggleCodeVisibility;

  @override
  Widget build(BuildContext context) {
    Widget field(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: child,
        );

    final nameField = field(
      TextFormField(
        controller: name,
        textInputAction: TextInputAction.next,
        decoration: appFormFieldDecoration(
          'Branch Name *',
          hint: 'e.g. Koramangala Branch',
        ),
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Branch name is required' : null,
      ),
    );

    final codeField = field(
      TextFormField(
        controller: code,
        textInputAction: TextInputAction.next,
        maxLength: 10,
        decoration: appFormFieldDecoration('Branch Code', hint: 'e.g. KRM'),
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) =>
            null,
      ),
    );

    final phoneField = field(
      TextFormField(
        controller: phone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: appFormFieldDecoration('Phone'),
      ),
    );

    final emailField = field(
      TextFormField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        decoration: appFormFieldDecoration('Email'),
      ),
    );

    final gstinField = field(
      TextFormField(
        controller: gstin,
        textInputAction: TextInputAction.next,
        maxLength: 15,
        decoration: appFormFieldDecoration('GSTIN'),
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) =>
            null,
      ),
    );

    final addressField = field(
      TextFormField(
        controller: address,
        textInputAction: TextInputAction.next,
        maxLines: 2,
        decoration: appFormFieldDecoration('Address'),
      ),
    );

    final cityField = field(
      TextFormField(
        controller: city,
        textInputAction: TextInputAction.next,
        decoration: appFormFieldDecoration('City'),
      ),
    );

    final stateField = field(
      TextFormField(
        controller: state,
        textInputAction: TextInputAction.next,
        decoration: appFormFieldDecoration('State'),
      ),
    );

    final pincodeField = field(
      TextFormField(
        controller: pincode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: appFormFieldDecoration('Pincode'),
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) =>
            null,
      ),
    );

    final statusField = field(
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Status'),
        subtitle: Text(isActive ? 'Active' : 'Inactive'),
        value: isActive,
        onChanged: onActiveChanged,
      ),
    );

    final invoiceCodeField = field(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: invoiceEditCode,
            obscureText: obscureCode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: appFormFieldDecoration(
              'Invoice Edit Security Code',
              hint: '6-digit code',
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  obscureCode
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleCodeVisibility,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (!RegExp(r'^\d{6}$').hasMatch(v)) {
                return 'Security code must be exactly 6 digits';
              }
              return null;
            },
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) =>
                null,
          ),
          const SizedBox(height: 6),
          Text(
            isEdit
                ? 'Leave blank to keep the current code.'
                : 'Required only if invoice editing should be protected for this branch.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );

    return Form(
      key: formKey,
      child: twoColumn
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nameField,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: codeField),
                    const SizedBox(width: 16),
                    Expanded(child: phoneField),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: emailField),
                    const SizedBox(width: 16),
                    Expanded(child: gstinField),
                  ],
                ),
                addressField,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cityField),
                    const SizedBox(width: 16),
                    Expanded(child: stateField),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: pincodeField),
                    const SizedBox(width: 16),
                    Expanded(child: statusField),
                  ],
                ),
                invoiceCodeField,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nameField,
                codeField,
                phoneField,
                emailField,
                gstinField,
                addressField,
                cityField,
                stateField,
                pincodeField,
                statusField,
                invoiceCodeField,
              ],
            ),
    );
  }
}
