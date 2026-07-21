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
              const SizedBox(height: 20),
              _petsSection(context, pets: pets, canCreate: canCreate, canEdit: canEdit),
              const SizedBox(height: 20),
              _invoicesSection(context),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    String? trailing,
    Widget? action,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailing,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _petsSection(
    BuildContext context, {
    required List<Pet> pets,
    required bool canCreate,
    required bool canEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          context,
          title: 'Pets',
          trailing: pets.isEmpty ? null : '${pets.length}',
          action: canCreate
              ? TextButton.icon(
                  onPressed: () => _openPetForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Pet'),
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (pets.isEmpty)
          _EmptyBlock(
            icon: Icons.pets_outlined,
            message: 'No pets yet',
            actionLabel: canCreate ? 'Add first pet' : null,
            onAction: canCreate ? () => _openPetForm() : null,
          )
        else
          ...pets.map((p) => _petCard(p, canEdit: canEdit)),
      ],
    );
  }

  Widget _petCard(Pet p, {required bool canEdit}) {
    final subtitle = _petSubtitle(p);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pets, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Edit pet',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _openPetForm(pet: p),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            EmrPetHub(petId: p.id),
          ],
        ),
      ),
    );
  }

  Widget _invoicesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          context,
          title: 'Invoices',
          trailing: !_invoicesLoading && _invoices.isNotEmpty
              ? '${_invoices.length}'
              : null,
        ),
        if (!_invoicesLoading && _invoices.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LoyaltySummaryBar(
            earned: _totalPointsEarned,
            redeemed: _totalPointsRedeemed,
          ),
        ],
        const SizedBox(height: 10),
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
          const _EmptyBlock(
            icon: Icons.receipt_long_outlined,
            message: 'No invoices for this customer yet.',
          )
        else
          ..._invoices.map(_invoiceTile),
      ],
    );
  }

  Widget _invoiceTile(Invoice inv) {
    final statusColor = _invoiceStatusColor(inv.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/invoices/${inv.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            inv.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: statusColor,
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
                        Text(
                          '₹${inv.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (inv.dueAmount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Due ₹${inv.dueAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.stars_rounded,
                          size: 14,
                          color: AppTheme.warning.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '+${inv.loyaltyPointsEarned}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warning,
                          ),
                        ),
                        if (inv.loyaltyPointsRedeemed > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '−${inv.loyaltyPointsRedeemed}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoyaltySummaryBar extends StatelessWidget {
  const _LoyaltySummaryBar({required this.earned, required this.redeemed});

  final int earned;
  final int redeemed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.stars_rounded,
            size: 18,
            color: AppTheme.warning.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Points earned  $earned pts',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.warning,
              ),
            ),
          ),
          if (redeemed > 0)
            Text(
              'Redeemed $redeemed',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
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
