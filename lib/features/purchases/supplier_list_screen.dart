import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/purchase.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _tableKey = GlobalKey<AppPaginatedTableState<Supplier>>();

  Future<void> _openForm({Supplier? supplier}) async {
    final isEdit = supplier != null;
    final name = TextEditingController(text: supplier?.name ?? '');
    final company = TextEditingController(text: supplier?.companyName ?? '');
    final phone = TextEditingController(text: supplier?.phone ?? '');
    final email = TextEditingController(text: supplier?.email ?? '');
    final gstin = TextEditingController(text: supplier?.gstin ?? '');
    final creditLimit = TextEditingController(
      text: (supplier?.creditLimit ?? 0).toStringAsFixed(0),
    );
    final creditDays = TextEditingController(
      text: (supplier?.creditDays ?? 30).toString(),
    );

    Widget fields() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration(
              'Supplier Name *',
              hint: 'e.g. PetCare Distributors',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: company,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration(
              'Company Name',
              hint: 'Legal entity name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: appFormFieldDecoration('Phone *', hint: '10-digit number'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: appFormFieldDecoration('Email'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: gstin,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
            decoration: appFormFieldDecoration('GSTIN'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: creditLimit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: appFormFieldDecoration('Credit Limit (₹)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: creditDays,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: appFormFieldDecoration('Credit Days'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final title = isEdit ? 'Edit Supplier' : 'Add Supplier';
    final bool? saved;
    if (useCenteredFormDialog(context)) {
      saved = await showAppAlertForm<bool>(
        context: context,
        title: title,
        maxWidth: 560,
        content: fields(),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      );
    } else {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AppFormBottomSheetShell(
          title: title,
          icon: Icons.local_shipping_outlined,
          onClose: () => Navigator.pop(ctx, false),
          body: fields(),
          footer: AppFormFooter(
            primaryLabel: isEdit ? 'Update' : 'Create',
            onCancel: () => Navigator.pop(ctx, false),
            onSubmit: () => Navigator.pop(ctx, true),
          ),
        ),
      );
    }

    if (saved != true || !mounted) return;

    final nameText = name.text.trim();
    final phoneText = phone.text.trim();
    if (nameText.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Supplier name is required')),
      );
      return;
    }
    if (phoneText.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Phone is required')),
      );
      return;
    }

    final body = <String, dynamic>{
      'name': nameText,
      'company_name': company.text.trim().isEmpty ? null : company.text.trim(),
      'phone': phoneText,
      'email': email.text.trim().isEmpty ? null : email.text.trim(),
      'gstin': gstin.text.trim().isEmpty ? null : gstin.text.trim(),
      'credit_limit': double.tryParse(creditLimit.text.trim()) ?? 0,
      'credit_days': int.tryParse(creditDays.text.trim()) ?? 30,
    };

    try {
      final svc = context.read<AppServices>().suppliers;
      if (supplier != null) {
        await svc.update(supplier.id, body);
      } else {
        await svc.create(body);
      }
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(isEdit ? 'Supplier updated' : 'Supplier created'),
        ),
      );
      await _tableKey.currentState?.refresh();
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate =
        context.watch<AuthSession>().hasPermission(AppPermissions.suppliersCreate);
    final canEdit =
        context.watch<AuthSession>().hasPermission(AppPermissions.suppliersEdit);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Suppliers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Supplier'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppPaginatedTable<Supplier>(
              key: _tableKey,
              loadPage: ({required page, required perPage}) =>
                  services.suppliers.listPaginated(page: page, perPage: perPage),
              onRowTap: canEdit ? (s) => _openForm(supplier: s) : null,
              columns: const [
                TableColumnDef(label: 'Name', flex: 2, cellBuilder: _nameCell),
                TableColumnDef(label: 'Phone', flex: 1.2, cellBuilder: _phoneCell),
                TableColumnDef(label: 'Email', flex: 1.5, cellBuilder: _emailCell),
                TableColumnDef(label: 'GSTIN', flex: 1.2, cellBuilder: _gstinCell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _nameCell(BuildContext context, Supplier s) => Text(
        s.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _phoneCell(BuildContext context, Supplier s) => Text(s.phone);

  static Widget _emailCell(BuildContext context, Supplier s) =>
      Text(s.email ?? '—');

  static Widget _gstinCell(BuildContext context, Supplier s) =>
      Text(s.gstin ?? '—');
}
