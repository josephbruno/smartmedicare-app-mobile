import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/customer.dart';

/// Add / edit customer — mirrors `frontend/src/pages/customers/CustomerFormPage.vue`.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  /// Null → create; otherwise the customer to edit.
  final int? customerId;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _alternatePhone = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  final _notes = TextEditingController();

  String? _state;
  String? _dob; // yyyy-MM-dd
  String? _gender;
  String _customerType = 'individual';
  double _creditLimit = 0;
  // Customers give their number to the clinic, so WhatsApp updates are on
  // unless switched off (same default as the web).
  bool _whatsappOpted = true;

  bool _loading = false;
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool get _isEdit => widget.customerId != null;

  static const _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa',
    'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
    'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland',
    'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
  ];
  static const _genders = {'male': 'Male', 'female': 'Female', 'other': 'Other'};
  static const _customerTypes = {
    'individual': 'Individual',
    'corporate': 'Corporate',
    'insurance': 'Insurance',
    'others': 'Others',
  };

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _email, _alternatePhone, _gstin, _address, _address2,
      _city, _pincode, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await context.read<AppServices>().customers.get(widget.customerId!);
      if (!mounted) return;
      setState(() {
        _name.text = c.name;
        _phone.text = c.phone;
        _email.text = c.email ?? '';
        _alternatePhone.text = c.alternatePhone ?? '';
        _gstin.text = c.gstin ?? '';
        _address.text = c.address ?? '';
        _address2.text = c.addressLine2 ?? '';
        _city.text = c.city ?? '';
        _pincode.text = c.pincode ?? '';
        _notes.text = c.notes ?? '';
        _state = (c.state ?? '').isEmpty ? null : c.state;
        _dob = (c.dob ?? '').isEmpty ? null : c.dob!.substring(0, 10);
        _gender = c.gender;
        _customerType = c.customerType ?? 'individual';
        _creditLimit = c.creditLimit ?? 0;
        _whatsappOpted = c.whatsappOpted ?? true;
      });
    } catch (e) {
      if (!mounted) return;
      AppMessenger.error(context, 'Failed to load customer: $e');
      context.canPop() ? context.pop() : context.go('/customers');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _optional(String? v, RegExp pattern, String error) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return pattern.hasMatch(t) ? null : error;
  }

  String? _nullIfEmpty(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickDob() async {
    final today = nowIst();
    final initial = DateTime.tryParse(_dob ?? '') ?? DateTime(today.year - 25);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Select date of birth',
    );
    if (picked != null) {
      setState(() => _dob =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': _nullIfEmpty(_email.text),
      'alternate_phone': _nullIfEmpty(_alternatePhone.text),
      'address': _nullIfEmpty(_address.text),
      'address_line_2': _nullIfEmpty(_address2.text),
      'city': _nullIfEmpty(_city.text),
      'state': _state,
      'pincode': _nullIfEmpty(_pincode.text),
      'dob': _dob,
      'gender': _gender,
      'customer_type': _customerType,
      'notes': _nullIfEmpty(_notes.text),
      'gstin': _gstin.text.trim().isEmpty ? null : _gstin.text.trim().toUpperCase(),
      'credit_limit': _creditLimit,
      'whatsapp_opted': _whatsappOpted,
    };

    setState(() => _saving = true);
    final svc = context.read<AppServices>().customers;
    try {
      final Customer saved;
      if (_isEdit) {
        saved = await svc.update(widget.customerId!, payload);
      } else {
        saved = await svc.create({...payload, 'is_active': true});
      }
      if (!mounted) return;
      AppMessenger.success(
          context, _isEdit ? 'Customer updated successfully' : 'Customer created successfully');
      if (context.canPop()) {
        context.pop<Customer>(saved);
      } else {
        context.go('/customers/${saved.id}');
      }
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── field helpers ──────────────────────────────────────────────────

  Widget _text(
    String label,
    TextEditingController ctrl, {
    required IconData icon,
    String? prefixText,
    String? hint,
    bool required = false,
    int? maxLength,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return FieldLabel(
      label,
      required: required,
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        textCapitalization: caps,
        autovalidateMode: _autovalidate,
        inputFormatters: [
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ...?formatters,
        ],
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: inputAddon(icon: icon, text: prefixText),
          prefixIconConstraints: const BoxConstraints(minHeight: 40),
        ),
      ),
    );
  }

  Widget _select(
    String label,
    Map<String, String> options,
    String? value,
    ValueChanged<String?> onChanged, {
    String? hint,
    IconData? icon,
    bool clearable = true,
  }) {
    return FieldLabel(
      label,
      child: AppDropdownButtonFormField<String?>(
        value: options.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null ? null : inputAddon(icon: icon),
          prefixIconConstraints: const BoxConstraints(minHeight: 40),
        ),
        hint: hint == null ? null : Text(hint),
        items: [
          if (clearable) DropdownMenuItem<String?>(value: null, child: Text(hint ?? '—')),
          for (final e in options.entries)
            DropdownMenuItem<String?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final stateOptions = {
      if (_state != null && !_indianStates.contains(_state)) _state!: _state!,
      for (final s in _indianStates) s: s,
    };
    final title = _isEdit ? 'Edit Customer' : 'Add Customer';
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final basic = WebFormSection(
      step: 1,
      title: 'Basic Information',
      description: "Customer's primary details (required fields)",
      children: [
        _text('Full Name', _name,
            icon: Icons.person_outline,
            hint: 'Enter customer name',
            required: true,
            maxLength: 150,
            caps: TextCapitalization.words,
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Full name is required';
              return null;
            }),
        _text('Phone Number', _phone,
            icon: Icons.call_outlined,
            prefixText: '+91',
            hint: '10-digit mobile number',
            required: true,
            maxLength: 10,
            keyboard: TextInputType.phone,
            formatters: digits,
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Phone number is required';
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(t)) return 'Enter a valid 10-digit mobile number';
              return null;
            }),
        _text('Email', _email,
            icon: Icons.mail_outline,
            hint: 'email@example.com',
            keyboard: TextInputType.emailAddress,
            validator: (v) => _optional(v, RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$'), 'Enter a valid email')),
        _text('Alternate Phone', _alternatePhone,
            icon: Icons.phone_iphone_outlined,
            hint: 'Alternate contact number',
            maxLength: 15,
            keyboard: TextInputType.phone,
            formatters: digits,
            validator: (v) => _optional(v, RegExp(r'^\d{10,15}$'), 'Alternate phone must be 10 to 15 digits')),
        _text('GSTIN', _gstin,
            icon: Icons.description_outlined,
            hint: '15-character GSTIN (optional)',
            maxLength: 15,
            caps: TextCapitalization.characters,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z]'))],
            validator: (v) => _optional(
                v,
                RegExp(r'^\d{2}[A-Za-z]{5}\d{4}[A-Za-z][0-9A-Za-z]Z[0-9A-Za-z]$'),
                'Enter a valid 15-character GSTIN')),
        FieldLabel(
          'WhatsApp updates',
          child: SizedBox(
            height: 40,
            child: Row(children: [
              Switch(value: _whatsappOpted, onChanged: (v) => setState(() => _whatsappOpted = v)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Send invoices, visit records and reminders on WhatsApp',
                    style: TextStyle(fontSize: 13, color: AppTokens.text2)),
              ),
            ]),
          ),
        ),
      ],
    );

    final address = WebFormSection(
      step: 2,
      title: 'Address Information',
      description: 'Billing and communication address',
      children: [
        _text('Address Line 1', _address,
            icon: Icons.location_on_outlined, hint: 'House / Street / Area', maxLength: 300),
        _text('Address Line 2', _address2,
            icon: Icons.location_on_outlined, hint: 'Apartment, Landmark (optional)', maxLength: 200),
      ],
      trailing: [
        FormGrid(columns: 3, children: [
          _text('City', _city,
              icon: Icons.business_outlined, hint: 'City', maxLength: 100, caps: TextCapitalization.words),
          _select('State', stateOptions, _state, (v) => _state = v, hint: 'Select State'),
          _text('Pincode', _pincode,
              icon: Icons.near_me_outlined,
              hint: '6-digit pincode',
              maxLength: 6,
              keyboard: TextInputType.number,
              formatters: digits,
              validator: (v) => _optional(v, RegExp(r'^\d{6}$'), 'Pincode must be 6 digits')),
        ]),
      ],
    );

    final additional = WebFormSection(
      step: 3,
      title: 'Additional Details',
      description: 'Optional information for better identification',
      children: [
        FieldLabel(
          'Date of Birth',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickDob,
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: inputAddon(icon: Icons.calendar_today_outlined),
                prefixIconConstraints: const BoxConstraints(minHeight: 40),
                suffixIcon: _dob == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _dob = null),
                      ),
              ),
              child: Text(
                _dob == null ? 'dd-mm-yyyy' : formatDateIst(_dob, pattern: 'dd-MM-yyyy'),
                style: TextStyle(
                    fontSize: 14, color: _dob == null ? AppTokens.placeholder : AppTokens.text1),
              ),
            ),
          ),
        ),
        _select('Gender', _genders, _gender, (v) => _gender = v, hint: 'Select Gender'),
        _select('Customer Type', _customerTypes, _customerType,
            (v) => _customerType = v ?? 'individual',
            icon: Icons.badge_outlined, clearable: false),
        _text('Notes', _notes,
            icon: Icons.description_outlined, hint: 'Add any notes...', maxLength: 500),
      ],
    );

    final actions = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: _saving ? null : () => context.canPop() ? context.pop() : context.go('/customers'),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_isEdit ? 'Update Customer' : 'Create Customer'),
        ),
      ],
    );

    final formCard = WebCard(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [basic, address, if (auth.isHuman) additional, actions],
              ),
            ),
    );

    final side = _SidePanel(
      responsibleParty: auth.responsiblePartyLabel,
      responsibleParties: auth.responsiblePartiesLabel,
    );

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        scrollable: true,
        bodyInCard: false,
        title: '$title (${auth.responsiblePartyLabel})',
        subtitle:
            '${_isEdit ? 'Update' : 'Add'} customer details who will be responsible for billing, payments and communication.',
        icon: Icons.person_add_alt_1_outlined,
        breadcrumbs: [Crumb(auth.responsiblePartiesLabel, path: '/customers'), Crumb(title)],
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/customers'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back'),
          ),
        ],
        body: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: formCard),
                  const SizedBox(width: 16),
                  SizedBox(width: 320, child: side),
                ],
              )
            : Column(children: [formCard, const SizedBox(height: 16), side]),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.responsibleParty, required this.responsibleParties});

  final String responsibleParty;
  final String responsibleParties;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, List<String> lines) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: AppTokens.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTokens.text1),
                  children: const [TextSpan(text: ' *', style: TextStyle(color: AppTokens.error))],
                )),
                for (final l in lines)
                  Text(l, style: const TextStyle(fontSize: 12, color: AppTokens.text2)),
              ]),
            ),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTokens.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: AppTokens.primaryLight,
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info, color: AppTokens.primaryHover, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Required Fields - $responsibleParties',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15, color: AppTokens.primaryHover)),
                    const SizedBox(height: 2),
                    const Text('Following fields are mandatory to create a customer:',
                        style: TextStyle(fontSize: 12, color: AppTokens.text2)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            item(Icons.person_outline, 'Full Name', const ["Customer's complete name"]),
            item(Icons.call_outlined, 'Phone Number',
                const ['Valid 10-digit mobile number', '(with country code if required)']),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline, color: AppTokens.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Note', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '$responsibleParty (Customer) can be used for billing, invoices, appointments and patient '
                  'management. You can add more details later from the edit page.',
                  style: const TextStyle(fontSize: 12, color: AppTokens.text2),
                ),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}
