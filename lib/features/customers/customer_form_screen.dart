import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _alternatePhone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _gstin = TextEditingController();
  final _creditLimit = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _dob;
  String? _gender;
  bool _whatsappOpted = true;
  bool _saving = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  static final _namePattern = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$');
  static final _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );
  static final _indiaPhonePattern = RegExp(r'^[6-9]\d{9}$');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _alternatePhone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _gstin.dispose();
    _creditLimit.dispose();
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      );

  String? _validateName(String? value) {
    final name = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return 'Name is required';
    if (!_namePattern.hasMatch(name)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return 'Phone is required';
    if (!_indiaPhonePattern.hasMatch(phone)) {
      return 'Enter a valid 10-digit Indian mobile number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return null;
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String _formatDob(DateTime? date) {
    if (date == null) return '';
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Select date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String? _nullIfEmpty(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;

    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!form.validate()) return;

    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final phone = _phone.text.trim();
    final email = _nullIfEmpty(_email.text);

    double? creditLimit;
    final creditText = _creditLimit.text.trim();
    if (creditText.isNotEmpty) {
      creditLimit = double.tryParse(creditText);
      if (creditLimit == null || creditLimit < 0) {
        AppMessenger.error(context, 'Enter a valid credit limit.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final created = await context.read<AppServices>().customers.create({
        'name': name,
        'phone': phone,
        'email': email,
        'alternate_phone': _nullIfEmpty(_alternatePhone.text),
        'address': _nullIfEmpty(_address.text),
        'city': _nullIfEmpty(_city.text),
        'state': _nullIfEmpty(_state.text),
        'pincode': _nullIfEmpty(_pincode.text),
        'dob': _dob?.toIso8601String().substring(0, 10),
        'gender': _gender,
        'gstin': _nullIfEmpty(_gstin.text),
        'credit_limit': creditLimit ?? 0,
        'whatsapp_opted': _whatsappOpted,
        'notes': _nullIfEmpty(_notes.text),
        'is_active': true,
      });
      if (!mounted) return;
      AppMessenger.success(context, 'Customer created successfully');
      if (context.canPop()) {
        context.pop<Customer>(created);
      } else {
        context.go('/customers');
      }
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _twoCol(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppConfig.usesLargeUiScale ||
        MediaQuery.sizeOf(context).width >= AppConfig.mobileCompactBreakpoint;

    final nameField = TextFormField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autovalidateMode: _autovalidateMode,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
        LengthLimitingTextInputFormatter(150),
      ],
      validator: _validateName,
      decoration: _dec('Full Name *', hint: 'Customer name'),
    );
    final phoneField = TextFormField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autovalidateMode: _autovalidateMode,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: _validatePhone,
      decoration: _dec('Phone *', hint: '10-digit Indian mobile'),
    );
    final emailField = TextFormField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autovalidateMode: _autovalidateMode,
      validator: _validateEmail,
      decoration: _dec('Email', hint: 'email@example.com'),
    );
    final altPhoneField = TextField(
      controller: _alternatePhone,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      textInputAction: TextInputAction.next,
      decoration: _dec('Alternate Phone', hint: 'Optional contact'),
    );
    final addressField = TextField(
      controller: _address,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 2,
      textInputAction: TextInputAction.next,
      decoration: _dec('Address', hint: 'Street / locality'),
    );
    final cityField = TextField(
      controller: _city,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: _dec('City'),
    );
    final stateField = TextField(
      controller: _state,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: _dec('State'),
    );
    final pincodeField = TextField(
      controller: _pincode,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      textInputAction: TextInputAction.next,
      decoration: _dec('Pincode'),
    );

    final dobText = _formatDob(_dob);
    final dobField = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDob,
      child: InputDecorator(
        decoration: _dec('Date of birth', hint: 'YYYY-MM-DD').copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dob != null)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _dob = null),
                ),
              IconButton(
                tooltip: 'Pick date',
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                onPressed: _pickDob,
              ),
            ],
          ),
        ),
        child: Text(
          dobText.isEmpty ? 'YYYY-MM-DD' : dobText,
          style: TextStyle(
            color: dobText.isEmpty
                ? AppTheme.textSecondary
                : AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );

    final genderField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: Theme.of(context).inputDecorationTheme.labelStyle,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'male', label: Text('Male')),
              ButtonSegment(value: 'female', label: Text('Female')),
              ButtonSegment(value: 'other', label: Text('Other')),
            ],
            selected: {if (_gender != null) _gender!},
            onSelectionChanged: (s) {
              setState(() => _gender = s.isEmpty ? null : s.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.comfortable,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return AppTheme.textSecondary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary;
                }
                return Colors.white;
              }),
            ),
          ),
        ),
      ],
    );

    final gstinField = TextField(
      controller: _gstin,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [LengthLimitingTextInputFormatter(15)],
      textInputAction: TextInputAction.next,
      decoration: _dec('GSTIN', hint: 'Optional GST number'),
    );
    final creditField = TextField(
      controller: _creditLimit,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      textInputAction: TextInputAction.next,
      decoration: _dec('Credit Limit (₹)', hint: '0'),
    );
    final notesField = TextField(
      controller: _notes,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: _dec('Notes', hint: 'Internal notes'),
    );
    final whatsappField = SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('WhatsApp opted-in'),
      subtitle: const Text('Receive updates on WhatsApp'),
      value: _whatsappOpted,
      activeColor: AppTheme.primary,
      onChanged: (v) => setState(() => _whatsappOpted = v),
    );

    final saveButton = FilledButton(
      onPressed: _saving ? null : _save,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _saving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Save Customer'),
    );

    final contactColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('CONTACT'),
        if (wide) ...[
          _twoCol(nameField, phoneField),
          const SizedBox(height: 16),
          _twoCol(emailField, altPhoneField),
        ] else ...[
          nameField,
          const SizedBox(height: 16),
          phoneField,
          const SizedBox(height: 16),
          emailField,
          const SizedBox(height: 16),
          altPhoneField,
        ],
        const SizedBox(height: 8),
        const Divider(height: 32),
        _sectionTitle('ADDRESS'),
        addressField,
        const SizedBox(height: 16),
        if (wide) ...[
          _twoCol(cityField, stateField),
          const SizedBox(height: 16),
          pincodeField,
        ] else ...[
          cityField,
          const SizedBox(height: 16),
          stateField,
          const SizedBox(height: 16),
          pincodeField,
        ],
      ],
    );

    final optionalColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('OPTIONAL DETAILS'),
        dobField,
        const SizedBox(height: 16),
        genderField,
        const SizedBox(height: 16),
        if (wide) ...[
          _twoCol(gstinField, creditField),
        ] else ...[
          gstinField,
          const SizedBox(height: 16),
          creditField,
        ],
        const SizedBox(height: 16),
        notesField,
        const SizedBox(height: 8),
        whatsappField,
        if (wide) ...[
          const SizedBox(height: 20),
          saveButton,
        ],
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('New customer')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 32),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(wide ? 24 : 20),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 24),
                                child: contactColumn,
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: optionalColumn),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        contactColumn,
                        const SizedBox(height: 8),
                        const Divider(height: 32),
                        optionalColumn,
                        const SizedBox(height: 20),
                        saveButton,
                      ],
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
