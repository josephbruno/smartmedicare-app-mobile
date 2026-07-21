import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/invoice.dart';
import '../../emr/emr_pet_hub.dart';
import 'pet_form_sheet.dart';
import 'advance_payment_sheet.dart';

/// Reusable customer detail (list pane or full page).
class CustomerDetailBody extends StatefulWidget {
  const CustomerDetailBody({super.key, required this.id, this.compact = false});

  final int id;
  final bool compact;

  @override
  State<CustomerDetailBody> createState() => _CustomerDetailBodyState();
}

class _CustomerDetailBodyState extends State<CustomerDetailBody> {
  late Future<Customer> _future;
  List<Invoice> _invoices = [];
  bool _invoicesLoading = false;
  String? _invoicesError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CustomerDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _reload();
  }

  void _reload() {
    _future = context.read<AppServices>().customers.get(widget.id);
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _invoicesLoading = true;
      _invoicesError = null;
    });
    try {
      final result = await context.read<AppServices>().billing.listPaginated(
            page: 1,
            perPage: 20,
            customerId: widget.id,
          );
      if (!mounted) return;
      setState(() {
        _invoices = result.items;
        _invoicesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoicesError = e.toString();
        _invoicesLoading = false;
      });
    }
  }

  Future<void> _openPetForm({Pet? pet}) async {
    final saved = await showPetFormSheet(
      context,
      customerId: widget.id,
      pet: pet,
    );
    if (saved && mounted) setState(_reload);
  }

  String _petSubtitle(Pet p) {
    final parts = <String>[
      if (p.species != null && p.species!.isNotEmpty) p.species!,
      if (p.breed != null && p.breed!.isNotEmpty) p.breed!,
      if (p.gender.isNotEmpty) p.gender,
      if (p.weight != null) '${p.weight} kg',
      if (p.age != null && p.age!.isNotEmpty) p.age!,
    ];
    return parts.join(' · ');
  }

  String _addressLine(Customer c) {
    return [
      if (c.address != null && c.address!.isNotEmpty) c.address!,
      if (c.city != null && c.city!.isNotEmpty) c.city!,
      if (c.state != null && c.state!.isNotEmpty) c.state!,
      if (c.pincode != null && c.pincode!.isNotEmpty) c.pincode!,
    ].join(', ');
  }

  Color _invoiceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppTheme.accent;
      case 'partial':
      case 'confirmed':
        return AppTheme.warning;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  int get _totalPointsEarned =>
      _invoices.fold(0, (sum, i) => sum + i.loyaltyPointsEarned);

  int get _totalPointsRedeemed =>
      _invoices.fold(0, (sum, i) => sum + i.loyaltyPointsRedeemed);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.customersCreate);
    final canEdit = auth.hasPermission(AppPermissions.customersEdit);

    return FutureBuilder<Customer>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: Text('Customer not found'));
        }
        final c = snap.data!;
        final pets = c.pets ?? const <Pet>[];

        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _future;
            await _loadInvoices();
          },
          child: ListView(
            padding: EdgeInsets.all(widget.compact ? 12 : 16),
            children: [
              Text(c.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              SelectableText(c.phone),
              if (c.alternatePhone != null && c.alternatePhone!.isNotEmpty)
                SelectableText(
                  'Alt: ${c.alternatePhone}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              if (c.email != null && c.email!.isNotEmpty) SelectableText(c.email!),
              if (_addressLine(c).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _addressLine(c),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
              if (c.gstin != null && c.gstin!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('GSTIN: ${c.gstin}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ],
              if ((c.outstandingBalance ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Outstanding: ₹${c.outstandingBalance!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    label: 'Advance',
                    value: '₹${c.advanceBalance.toStringAsFixed(0)}',
                    color: AppTheme.accent,
                  ),
                  _StatChip(
                    label: 'Loyalty',
                    value: '${c.loyaltyPoints} pts',
                    color: AppTheme.warning,
                  ),
                  if ((c.creditLimit ?? 0) > 0)
                    _StatChip(
                      label: 'Credit limit',
                      value: '₹${c.creditLimit!.toStringAsFixed(0)}',
                      color: AppTheme.textSecondary,
                    ),
                ],
              ),
              if (canEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showAdvancePaymentSheet(context, customer: c);
                    if (ok && mounted) setState(_reload);
                  },
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Treatment Advance'),
                ),
              ],
              const Divider(height: 24),
              _invoicesSection(context),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pets',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (canCreate)
                    TextButton.icon(
                      onPressed: () => _openPetForm(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Pet'),
                    ),
                ],
              ),
              if (pets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const Icon(Icons.pets_outlined,
                          size: 40, color: AppTheme.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'No pets yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      if (canCreate) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _openPetForm(),
                          child: const Text('Add first pet'),
                        ),
                      ],
                    ],
                  ),
                )
              else
                ...pets.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.pets),
                            title: Text(p.name),
                            subtitle: Text(_petSubtitle(p)),
                            trailing: canEdit
                                ? IconButton(
                                    tooltip: 'Edit pet',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _openPetForm(pet: p),
                                  )
                                : null,
                          ),
                          EmrPetHub(petId: p.id, petName: p.name),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _invoicesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Invoices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!_invoicesLoading && _invoices.isNotEmpty)
              Text(
                '${_invoices.length} shown',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        if (!_invoicesLoading && _invoices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                label: 'Points earned',
                value: '$_totalPointsEarned pts',
                color: AppTheme.warning,
              ),
              if (_totalPointsRedeemed > 0)
                _StatChip(
                  label: 'Points redeemed',
                  value: '$_totalPointsRedeemed pts',
                  color: AppTheme.primary,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (_invoicesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_invoicesError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  _invoicesError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
                TextButton(onPressed: _loadInvoices, child: const Text('Retry')),
              ],
            ),
          )
        else if (_invoices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No invoices for this customer yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          ..._invoices.map(_invoiceTile),
      ],
    );
  }

  Widget _invoiceTile(Invoice inv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/invoices/${inv.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inv.invoiceNumber.isNotEmpty
                          ? inv.invoiceNumber
                          : 'Invoice #${inv.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _invoiceStatusColor(inv.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      inv.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _invoiceStatusColor(inv.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                inv.displayDate.isNotEmpty ? inv.displayDate : '—',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '₹${inv.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (inv.dueAmount > 0)
                    Text(
                      'Due ₹${inv.dueAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    size: 16,
                    color: AppTheme.warning.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Earned ${inv.loyaltyPointsEarned} pts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                  if (inv.loyaltyPointsRedeemed > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      'Redeemed ${inv.loyaltyPointsRedeemed}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9))),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
