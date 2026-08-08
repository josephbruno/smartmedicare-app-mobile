import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/emr.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _search = TextEditingController();
  String _appliedSearch = '';
  int _reloadToken = 0;

  static const _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  void _refresh() => setState(() => _reloadToken++);

  void _applySearch() {
    setState(() {
      _appliedSearch = _search.text.trim();
      _reloadToken++;
    });
  }

  Future<void> _toggleAvailability(Doctor d) async {
    try {
      await context.read<AppServices>().doctors.toggleAvailability(d.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDelete(Doctor d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${d.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().doctors.delete(d.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openForm({Doctor? doctor}) async {
    final bool? saved;
    if (useCenteredFormDialog(context)) {
      saved = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => _DoctorFormDialog(doctor: doctor, weekDays: _weekDays),
      );
    } else {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _DoctorFormBottomSheet(doctor: doctor, weekDays: _weekDays),
      );
    }

    if (saved == true && mounted) _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.watch<AuthSession>().hasPermission('doctors.manage');
    final services = context.read<AppServices>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doctor Management',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Manage doctors and clinic profiles',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add doctor'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search name, email, specialty...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _applySearch(),
                ),
              ],
            ),
          ),
          Expanded(
            child: AppPaginatedTable<Doctor>(
              key: ValueKey('$_appliedSearch-$_reloadToken'),
              emptyMessage: _appliedSearch.isNotEmpty
                  ? 'No doctors match your search.'
                  : 'No doctors found.',
              headerFontSize: 9,
              cellFontSize: 12,
              loadPage: ({required page, required perPage}) async {
                final query = <String, dynamic>{};
                if (_appliedSearch.isNotEmpty) query['search'] = _appliedSearch;
                final all = await services.doctors.list(query: query);
                return paginateList(all, page: page, perPage: perPage);
              },
              onRowTap: canManage ? (d) => _openForm(doctor: d) : null,
              columns: [
                TableColumnDef(label: 'Name', flex: 1.6, cellBuilder: _nameCell),
                TableColumnDef(label: 'Email', flex: 1.5, cellBuilder: _emailCell),
                TableColumnDef(label: 'Phone', flex: 1, cellBuilder: _phoneCell),
                TableColumnDef(
                  label: 'Available',
                  flex: 1,
                  align: TextAlign.center,
                  cellBuilder: (context, d) => _availabilityCell(context, d, canManage),
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 0.8,
                  align: TextAlign.center,
                  cellBuilder: _statusCell,
                ),
                if (canManage)
                  TableColumnDef(
                    label: 'Actions',
                    flex: 1,
                    align: TextAlign.center,
                    cellBuilder: (context, d) => _actionsCell(context, d),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _nameCell(BuildContext context, Doctor d) => Text(
        d.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _emailCell(BuildContext context, Doctor d) => Text(
        d.email,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _phoneCell(BuildContext context, Doctor d) => Text(
        d.phone?.isNotEmpty == true ? d.phone! : '—',
        style: const TextStyle(fontSize: 12),
      );

  Widget _availabilityCell(BuildContext context, Doctor d, bool canManage) {
    final color = d.isAvailable ? AppTheme.accent : AppTheme.warning;
    final label = d.isAvailable ? 'Available' : 'Unavailable';
    final text = Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
    if (!canManage) return text;
    return TextButton(
      onPressed: () => _toggleAvailability(d),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: text,
    );
  }

  static Widget _statusCell(BuildContext context, Doctor d) => Text(
        d.isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: d.isActive ? AppTheme.accent : AppTheme.danger,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );

  Widget _actionsCell(BuildContext context, Doctor d) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => _openForm(doctor: d),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Edit', style: TextStyle(fontSize: 12)),
        ),
        TextButton(
          onPressed: () => _confirmDelete(d),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Remove', style: TextStyle(fontSize: 12, color: AppTheme.danger)),
        ),
      ],
    );
  }
}

// ─── Shared form helpers ────────────────────────────────────────────────────

class _DoctorFormController {
  _DoctorFormController({Doctor? doctor}) {
    name = TextEditingController(text: doctor?.name ?? '');
    email = TextEditingController(text: doctor?.email ?? '');
    phone = TextEditingController(text: doctor?.phone ?? '');
    password = TextEditingController();
    passwordConfirm = TextEditingController();
    specialty = TextEditingController(text: doctor?.specialty ?? '');
    license = TextEditingController(text: doctor?.licenseNumber ?? '');
    fee = TextEditingController(text: doctor?.consultationFee?.toString() ?? '');
    bio = TextEditingController(text: doctor?.bio ?? '');
    selectedDays = Set<String>.from(doctor?.availableDays ?? []);
  }

  late final TextEditingController name;
  late final TextEditingController email;
  late final TextEditingController phone;
  late final TextEditingController password;
  late final TextEditingController passwordConfirm;
  late final TextEditingController specialty;
  late final TextEditingController license;
  late final TextEditingController fee;
  late final TextEditingController bio;
  late Set<String> selectedDays;

  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    passwordConfirm.dispose();
    specialty.dispose();
    license.dispose();
    fee.dispose();
    bio.dispose();
  }

  Map<String, dynamic>? buildPayload(BuildContext context, {required bool isEdit}) {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Name and email are required')),
      );
      return null;
    }
    if (!isEdit && (password.text.isEmpty || password.text != passwordConfirm.text)) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Passwords must match')),
      );
      return null;
    }
    if (!isEdit && password.text.length < 8) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return null;
    }

    return {
      'name': name.text.trim(),
      'email': email.text.trim(),
      if (phone.text.isNotEmpty) 'phone': phone.text.trim(),
      if (specialty.text.isNotEmpty) 'specialty': specialty.text.trim(),
      if (license.text.isNotEmpty) 'license_number': license.text.trim(),
      if (fee.text.isNotEmpty) 'consultation_fee': double.tryParse(fee.text) ?? 0,
      if (bio.text.isNotEmpty) 'bio': bio.text.trim(),
      if (selectedDays.isNotEmpty) 'available_days': selectedDays.toList(),
      if (!isEdit) ...{
        'password': password.text,
        'password_confirmation': passwordConfirm.text,
      },
      if (isEdit && password.text.isNotEmpty) ...{
        'password': password.text,
        'password_confirmation': passwordConfirm.text.isNotEmpty
            ? passwordConfirm.text
            : password.text,
      },
    };
  }
}

class _DoctorFormFields extends StatelessWidget {
  const _DoctorFormFields({
    required this.controller,
    required this.isEdit,
    required this.weekDays,
    required this.onChanged,
    this.twoColumn = false,
  });

  final _DoctorFormController controller;
  final bool isEdit;
  final List<String> weekDays;
  final VoidCallback onChanged;
  final bool twoColumn;

  @override
  Widget build(BuildContext context) {
    final nameField = TextField(
      controller: controller.name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: appFormFieldDecoration('Full name *', hint: 'Dr. Priya Sharma'),
    );

    final emailField = TextField(
      controller: controller.email,
      readOnly: isEdit,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: appFormFieldDecoration('Email *', hint: 'doctor@clinic.com').copyWith(
        filled: isEdit,
        fillColor: isEdit ? const Color(0xFFF1F5F9) : null,
      ),
    );

    final phoneField = TextField(
      controller: controller.phone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: appFormFieldDecoration('Phone', hint: '10-digit mobile'),
    );

    final specialtyField = TextField(
      controller: controller.specialty,
      textInputAction: TextInputAction.next,
      decoration: appFormFieldDecoration('Specialty', hint: 'e.g. Dermatology'),
    );

    final licenseField = TextField(
      controller: controller.license,
      textInputAction: TextInputAction.next,
      decoration: appFormFieldDecoration('License number', hint: 'VCI-XXXXX'),
    );

    final feeField = TextField(
      controller: controller.fee,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: appFormFieldDecoration('Consultation fee (₹)', hint: '0.00'),
    );

    final bioField = TextField(
      controller: controller.bio,
      maxLines: 2,
      minLines: 2,
      textInputAction: TextInputAction.newline,
      decoration: appFormFieldDecoration('Bio', hint: 'Brief introduction...'),
    );

    final passwordFields = <Widget>[
      if (!isEdit) ...[
        TextField(
          controller: controller.password,
          obscureText: true,
          textInputAction: TextInputAction.next,
          decoration: appFormFieldDecoration('Password *', hint: 'Min. 8 characters'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.passwordConfirm,
          obscureText: true,
          textInputAction: TextInputAction.next,
          decoration: appFormFieldDecoration('Confirm password *'),
        ),
        const SizedBox(height: 12),
      ],
    ];

    final daysSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available days',
          style: Theme.of(context).inputDecorationTheme.labelStyle,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weekDays.map((day) {
            final selected = controller.selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppTheme.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              side: BorderSide(
                color: selected ? AppTheme.primary : const Color(0xFFCBD5E1),
              ),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onSelected: (_) {
                if (selected) {
                  controller.selectedDays.remove(day);
                } else {
                  controller.selectedDays.add(day);
                }
                onChanged();
              },
            );
          }).toList(),
        ),
      ],
    );

    if (!twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          nameField,
          const SizedBox(height: 12),
          emailField,
          const SizedBox(height: 12),
          phoneField,
          const SizedBox(height: 12),
          ...passwordFields,
          specialtyField,
          const SizedBox(height: 12),
          licenseField,
          const SizedBox(height: 12),
          feeField,
          const SizedBox(height: 12),
          bioField,
          const SizedBox(height: 14),
          daysSection,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        nameField,
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: emailField),
            const SizedBox(width: 12),
            Expanded(child: phoneField),
          ],
        ),
        const SizedBox(height: 12),
        ...passwordFields,
        specialtyField,
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: licenseField),
            const SizedBox(width: 12),
            Expanded(child: feeField),
          ],
        ),
        const SizedBox(height: 12),
        bioField,
        const SizedBox(height: 14),
        daysSection,
      ],
    );
  }
}

Future<bool> _saveDoctor(
  BuildContext context, {
  required _DoctorFormController form,
  required Doctor? doctor,
}) async {
  final isEdit = doctor != null;
  final body = form.buildPayload(context, isEdit: isEdit);
  if (body == null) return false;

  try {
    final svc = context.read<AppServices>().doctors;
    if (isEdit) {
      await svc.updateProfile(doctor.id, body);
    } else {
      await svc.create(body);
    }
    if (context.mounted) {
      AppMessenger.show(
        context,
        SnackBar(content: Text(isEdit ? 'Doctor updated' : 'Doctor created')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
    return false;
  }
}

// ─── Desktop / web dialog ───────────────────────────────────────────────────

class _DoctorFormDialog extends StatefulWidget {
  const _DoctorFormDialog({
    required this.doctor,
    required this.weekDays,
  });

  final Doctor? doctor;
  final List<String> weekDays;

  @override
  State<_DoctorFormDialog> createState() => _DoctorFormDialogState();
}

class _DoctorFormDialogState extends State<_DoctorFormDialog> {
  late final _DoctorFormController _form;
  bool _saving = false;

  bool get _isEdit => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    _form = _DoctorFormController(doctor: widget.doctor);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final ok = await _saveDoctor(context, form: _form, doctor: widget.doctor);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialogShell(
      title: _isEdit ? 'Edit Doctor' : 'Add Doctor',
      subtitle: _isEdit ? 'Update doctor profile' : 'Create a doctor account',
      icon: Icons.medical_services_outlined,
      onClose: () => Navigator.pop(context),
      body: _DoctorFormFields(
        controller: _form,
        isEdit: _isEdit,
        weekDays: widget.weekDays,
        twoColumn: true,
        onChanged: () => setState(() {}),
      ),
      footer: AppFormFooter(
        primaryLabel: _isEdit ? 'Update Doctor' : 'Add Doctor',
        saving: _saving,
        onCancel: () => Navigator.pop(context),
        onSubmit: _submit,
      ),
    );
  }
}

// ─── Mobile bottom sheet ────────────────────────────────────────────────────

class _DoctorFormBottomSheet extends StatefulWidget {
  const _DoctorFormBottomSheet({
    required this.doctor,
    required this.weekDays,
  });

  final Doctor? doctor;
  final List<String> weekDays;

  @override
  State<_DoctorFormBottomSheet> createState() => _DoctorFormBottomSheetState();
}

class _DoctorFormBottomSheetState extends State<_DoctorFormBottomSheet> {
  late final _DoctorFormController _form;
  bool _saving = false;

  bool get _isEdit => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    _form = _DoctorFormController(doctor: widget.doctor);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final ok = await _saveDoctor(context, form: _form, doctor: widget.doctor);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AppFormBottomSheetShell(
      title: _isEdit ? 'Edit Doctor' : 'Add Doctor',
      subtitle: _isEdit ? 'Update doctor profile' : 'Create a doctor account',
      icon: Icons.medical_services_outlined,
      onClose: () => Navigator.pop(context),
      body: _DoctorFormFields(
        controller: _form,
        isEdit: _isEdit,
        weekDays: widget.weekDays,
        onChanged: () => setState(() {}),
      ),
      footer: AppFormFooter(
        primaryLabel: _isEdit ? 'Update Doctor' : 'Add Doctor',
        saving: _saving,
        onCancel: () => Navigator.pop(context),
        onSubmit: _submit,
      ),
    );
  }
}
