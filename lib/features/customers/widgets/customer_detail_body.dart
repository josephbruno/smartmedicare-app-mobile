import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/customer.dart';
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
          onRefresh: () async => setState(_reload),
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
