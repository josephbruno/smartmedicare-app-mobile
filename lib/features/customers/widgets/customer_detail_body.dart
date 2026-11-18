import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_services.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/ist.dart';
import '../../../core/widgets/web_page.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/emr.dart' show PetVaccination;
import '../../../data/models/invoice.dart';
import 'advance_payment_sheet.dart';
import 'collect_due_sheet.dart';
import 'pet_form_sheet.dart';

/// Customer detail — mirrors `frontend/src/pages/customers/CustomerDetailPage.vue`:
/// header card, contact information, account balances, pets. The app also
/// keeps the customer's invoices (with due collection) at the bottom.
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
  final Set<int> _openVax = {};

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

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
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
    final saved = await showPetFormSheet(context, customerId: widget.id, pet: pet);
    if (saved && mounted) await _refresh();
  }

  Future<void> _openCollectDue(Customer c, {Invoice? invoice}) async {
    final open = _invoices.where((i) => i.dueAmount > 0.009).toList();
    final ok = await showCollectDueSheet(
      context,
      customer: c,
      openInvoices: open.isNotEmpty ? open : null,
      initialInvoice: invoice,
    );
    if (ok && mounted) await _refresh();
  }

  Future<void> _toggleActive(Customer c) async {
    final deactivating = c.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deactivating ? 'Deactivate customer' : 'Activate customer'),
        content: Text(deactivating
            ? 'Are you sure you want to deactivate ${c.name}? They will be hidden from POS customer search.'
            : 'Are you sure you want to activate ${c.name}? They will be available again for billing.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(deactivating ? 'Deactivate' : 'Activate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().customers.update(c.id, {'is_active': !deactivating});
      if (!mounted) return;
      AppMessenger.success(context, deactivating ? 'Customer deactivated' : 'Customer activated');
      await _refresh();
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to update customer status: $e');
    }
  }

  Future<void> _addVaccination(Pet pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _VaccinationDialog(pet: pet),
    );
    if (ok == true && mounted) await _refresh();
  }

  String _address(Customer c) {
    final parts = [c.address, c.addressLine2, c.city, c.state, c.pincode]
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  static String _money(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final digits = parts[0];
    // Indian grouping: 12,34,567.89
    if (digits.length <= 3) return '$digits.${parts[1]}';
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canEdit = auth.hasPermission(AppPermissions.customersEdit);
    final canCreate = auth.hasPermission(AppPermissions.customersCreate);
    final canCollect = auth.hasPermission(AppPermissions.invoicesCreate) || canEdit;
    final narrow = MediaQuery.sizeOf(context).width < AppTokens.bpTablet;

    return FutureBuilder<Customer>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) return const Center(child: Text('Customer not found'));
        final c = snap.data!;
        final openDues = _invoices.where((i) => i.dueAmount > 0.009).toList();
        final duesTotal = openDues.fold<double>(0, (s, i) => s + i.dueAmount);
        final outstanding =
            (c.outstandingBalance ?? 0) > 0.009 ? c.outstandingBalance! : duesTotal;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.all(narrow ? 12 : 16),
            children: [
              if (!narrow && !widget.compact)
                PageBreadcrumbs(items: [
                  Crumb(auth.responsiblePartiesLabel, path: '/customers'),
                  const Crumb('Customer Details'),
                ]),
              _HeaderCard(
                customer: c,
                vet: auth.isVeterinary,
                canEdit: canEdit,
                canCreatePet: canCreate || canEdit,
                onMore: (k) {
                  if (k == 'toggle') _toggleActive(c);
                  if (k == 'billing') {
                    context.go(Uri(path: '/invoices', queryParameters: {
                      'search': c.phone.isNotEmpty ? c.phone : c.name,
                    }).toString());
                  }
                },
                onAddPet: () => _openPetForm(),
                onAdvance: () async {
                  final ok = await showAdvancePaymentSheet(context, customer: c);
                  if (ok && mounted) await _refresh();
                },
                onEdit: () async {
                  await context.push('/customers/${c.id}/edit');
                  if (mounted) await _refresh();
                },
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.person_outline,
                iconColor: const Color(0xFF2563EB),
                title: 'Contact Information',
                child: _ContactGrid(customer: c, address: _address(c)),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Account Balances',
                trailing: canCollect && outstanding > 0.009
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppTokens.warning),
                        onPressed: () => _openCollectDue(c),
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Receive payment'),
                      )
                    : null,
                child: FormGrid(
                  columns: 4,
                  gap: 12,
                  minColumnWidth: 150, // 2 per row on phones
                  children: [
                    _BalanceCard(
                        label: 'Treatment Advance',
                        value: '₹${_money(c.advanceBalance)}',
                        icon: Icons.payments_outlined,
                        tone: KpiTone.green),
                    _BalanceCard(
                        label: 'Loyalty Points',
                        value: '${c.loyaltyPoints} pts',
                        icon: Icons.card_giftcard_outlined,
                        tone: KpiTone.purple),
                    _BalanceCard(
                        label: 'Credit Limit',
                        value: '₹${_money(c.creditLimit ?? 0)}',
                        icon: Icons.credit_card_outlined,
                        tone: KpiTone.blue),
                    _BalanceCard(
                        label: 'Outstanding',
                        value: '₹${_money(outstanding)}',
                        icon: Icons.receipt_outlined,
                        tone: KpiTone.red),
                  ],
                ),
              ),
              if (auth.isVeterinary) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.pets_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Pets',
                  child: _petsBody(c, auth),
                ),
              ],
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.receipt_long_outlined,
                iconColor: AppTokens.primary,
                title: 'Invoices',
                trailing: _invoices.isEmpty
                    ? null
                    : Text('${_invoices.length}',
                        style: const TextStyle(color: AppTokens.text3, fontWeight: FontWeight.w600)),
                child: _invoicesBody(c, canCollect),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _petsBody(Customer c, AuthSession auth) {
    final pets = c.pets ?? const <Pet>[];
    final banner = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: const Row(children: [
        Icon(Icons.health_and_safety_outlined, color: AppTokens.primary, size: 36),
        SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Keep your pet's health records up to date",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTokens.text1)),
            SizedBox(height: 4),
            Text('Add visits, vaccinations, and lab reports to provide better care.',
                style: TextStyle(fontSize: 13, color: AppTokens.text2)),
          ]),
        ),
      ]),
    );

    if (pets.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(children: [
              Icon(Icons.pets_outlined, size: 36, color: AppTokens.placeholder),
              SizedBox(height: 8),
              Text('No pets registered', style: TextStyle(color: AppTokens.text3)),
            ]),
          ),
        ),
        banner,
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FormGrid(
        columns: 2,
        gap: 14,
        children: [
          for (var i = 0; i < pets.length; i++)
            _PetCard(
              pet: pets[i],
              index: i,
              vaxOpen: _openVax.contains(pets[i].id),
              onToggleVax: () => setState(() {
                _openVax.contains(pets[i].id) ? _openVax.remove(pets[i].id) : _openVax.add(pets[i].id);
              }),
              onEdit: () => _openPetForm(pet: pets[i]),
              onVaccination: () => _addVaccination(pets[i]),
              auth: auth,
            ),
        ],
      ),
      const SizedBox(height: 14),
      banner,
    ]);
  }

  Widget _invoicesBody(Customer c, bool canCollect) {
    if (_invoicesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_invoicesError != null) {
      return Column(children: [
        Text(_invoicesError!, style: const TextStyle(color: AppTokens.error, fontSize: 13)),
        TextButton(onPressed: _loadInvoices, child: const Text('Retry')),
      ]);
    }
    if (_invoices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: Text('No invoices for this customer yet.', style: TextStyle(color: AppTokens.text3))),
      );
    }
    return Column(children: [
      for (final inv in _invoices)
        _InvoiceRow(
          invoice: inv,
          money: _money,
          onTap: () => context.push('/invoices/${inv.id}'),
          onCollect: canCollect && inv.dueAmount > 0.009 ? () => _openCollectDue(c, invoice: inv) : null,
        ),
    ]);
  }
}

// ── Header ────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.customer,
    required this.vet,
    required this.canEdit,
    required this.canCreatePet,
    required this.onMore,
    required this.onAddPet,
    required this.onAdvance,
    required this.onEdit,
  });

  final Customer customer;
  final bool vet;
  final bool canEdit;
  final bool canCreatePet;
  final ValueChanged<String> onMore;
  final VoidCallback onAddPet;
  final VoidCallback onAdvance;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final narrow = MediaQuery.sizeOf(context).width < AppTokens.bpTablet;
    final parts = c.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();

    final info = Row(children: [
      Container(
        width: narrow ? 56 : 72,
        height: narrow ? 56 : 72,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF0B5ED7)]),
        ),
        child: Text(initials,
            style: TextStyle(color: Colors.white, fontSize: narrow ? 20 : 26, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(c.name,
                style: TextStyle(fontSize: narrow ? 20 : 24, fontWeight: FontWeight.w700, color: AppTokens.text1)),
            c.isActive
                ? const StatusPill('Active', tone: PillTone.green)
                : const StatusPill('Inactive', tone: PillTone.red),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 16, runSpacing: 4, children: [
            Text('Customer ID: ${c.customerCode ?? '#${c.id}'}',
                style: const TextStyle(fontSize: 13, color: AppTokens.text2)),
            if ((c.createdAt ?? '').isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppTokens.text3),
                const SizedBox(width: 6),
                Text('Joined on ${formatDateIst(c.createdAt)}',
                    style: const TextStyle(fontSize: 13, color: AppTokens.text2)),
              ]),
          ]),
        ]),
      ),
    ]);

    final actions = Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: [
      PopupMenuButton<String>(
        onSelected: onMore,
        position: PopupMenuPosition.under,
        itemBuilder: (_) => [
          if (canEdit)
            PopupMenuItem(value: 'toggle', child: Text(c.isActive ? 'Deactivate' : 'Activate')),
          const PopupMenuItem(value: 'billing', child: Text('View Billing')),
        ],
        child: IgnorePointer(
          child: OutlinedButton(
            onPressed: () {},
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('More'),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16),
            ]),
          ),
        ),
      ),
      if (vet && canCreatePet) FilledButton(onPressed: onAddPet, child: const Text('Add Pet')),
      if (canEdit) FilledButton(onPressed: onAdvance, child: const Text('Add Advance Payment')),
      if (canEdit)
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTokens.warning),
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit Customer'),
        ),
    ]);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF0F6FF)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTokens.border),
        boxShadow: AppTokens.shadowCard,
      ),
      padding: EdgeInsets.all(narrow ? 16 : 22),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              info,
              const SizedBox(height: 14),
              actions,
            ])
          : Row(children: [Expanded(child: info), const SizedBox(width: 16), Flexible(child: actions)]),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return WebCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTokens.text1)),
          ),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class _ContactGrid extends StatelessWidget {
  const _ContactGrid({required this.customer, required this.address});

  final Customer customer;
  final String address;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    Widget item(IconData icon, Color bg, Color fg, String label, String? value, {VoidCallback? onTap}) {
      final v = (value ?? '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: v.isEmpty || v == '—' ? null : onTap,
                child: Text(v.isEmpty ? '—' : v,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: v.isEmpty || v == '—'
                            ? AppTokens.text3
                            : onTap != null
                                ? AppTokens.primary
                                : AppTokens.text1)),
              ),
            ]),
          ),
        ]),
      );
    }

    const blue = (Color(0xFFDBEAFE), Color(0xFF2563EB));
    const purple = (Color(0xFFF3E8FF), Color(0xFF9333EA));
    const red = (Color(0xFFFEE2E2), Color(0xFFDC2626));
    const green = (Color(0xFFDCFCE7), Color(0xFF16A34A));

    return FormGrid(columns: 3, gap: 16, children: [
      Column(children: [
        item(Icons.call_outlined, blue.$1, blue.$2, 'Phone', c.phone,
            onTap: () => launchUrl(Uri.parse('tel:${c.phone}'))),
        item(Icons.call_outlined, purple.$1, purple.$2, 'Alternate Phone', c.alternatePhone),
      ]),
      Column(children: [
        item(Icons.mail_outline, red.$1, red.$2, 'Email', c.email,
            onTap: () => launchUrl(Uri.parse('mailto:${c.email}'))),
        item(Icons.description_outlined, green.$1, green.$2, 'GSTIN', c.gstin),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: item(Icons.location_on_outlined, blue.$1, blue.$2, 'Address', address)),
        if (address != '—')
          TableIconButton(
            icon: Icons.location_on_outlined,
            tooltip: 'Open in Maps',
            onPressed: () => launchUrl(
              Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
      ]),
    ]);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.label, required this.value, required this.icon, required this.tone});

  final String label;
  final String value;
  final IconData icon;
  final KpiTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      KpiTone.green => (const Color(0xFFECFDF5), const Color(0xFF059669)),
      KpiTone.purple => (const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
      KpiTone.red => (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      _ => (const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: fg, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTokens.text2)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          ]),
        ),
      ]),
    );
  }
}

// ── Pets ──────────────────────────────────────────────────────────────

const _petAccents = [Color(0xFF8B5CF6), Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEC4899)];

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.index,
    required this.vaxOpen,
    required this.onToggleVax,
    required this.onEdit,
    required this.onVaccination,
    required this.auth,
  });

  final Pet pet;
  final int index;
  final bool vaxOpen;
  final VoidCallback onToggleVax;
  final VoidCallback onEdit;
  final VoidCallback onVaccination;
  final AuthSession auth;

  @override
  Widget build(BuildContext context) {
    final accent = _petAccents[index % _petAccents.length];
    final vax = pet.vaccinations ?? const <PetVaccination>[];
    final female = pet.gender.toLowerCase() == 'female';
    final genderLabel = pet.gender.isEmpty ? 'Unknown' : '${pet.gender[0].toUpperCase()}${pet.gender.substring(1)}';

    Widget actionBtn(IconData? icon, String label, VoidCallback onTap, {bool green = false}) => OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: green ? Colors.white : AppTokens.text2,
            backgroundColor: green ? AppTokens.success : Colors.white,
            side: BorderSide(color: green ? AppTokens.success : AppTokens.border),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          onPressed: onTap,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 15),
          label: Text(label),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accent, width: 4),
          top: const BorderSide(color: AppTokens.border),
          right: const BorderSide(color: AppTokens.border),
          bottom: const BorderSide(color: AppTokens.border),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if ((pet.imageUrl ?? '').isNotEmpty)
            CircleAvatar(radius: 30, backgroundImage: NetworkImage(pet.imageUrl!))
          else
            CircleAvatar(
              radius: 30,
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(Icons.pets_outlined, color: accent, size: 26),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTokens.text1)),
                ),
                const SizedBox(width: 8),
                StatusPill('${female ? '♀' : '♂'} $genderLabel',
                    tone: female ? PillTone.purple : PillTone.blue),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Edit Pet',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                ),
              ]),
              Text(pet.breed ?? pet.species ?? 'Unknown',
                  style: const TextStyle(fontSize: 13, color: AppTokens.text3)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Text(pet.age ?? '—', style: const TextStyle(fontSize: 13)),
              ]),
            ),
            Container(width: 1, height: 18, color: AppTokens.border),
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.monitor_weight_outlined, size: 16, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Text(pet.weight != null ? '${pet.weight} kg' : '—', style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggleVax,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, size: 17, color: AppTokens.success),
              const SizedBox(width: 8),
              Text('Vaccinations${vax.isNotEmpty ? ' (${vax.length})' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              AnimatedRotation(
                turns: vaxOpen ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.chevron_right, size: 18, color: AppTokens.text3),
              ),
            ]),
          ),
        ),
        if (vaxOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: vax.isEmpty
                ? const Text('No vaccinations recorded', style: TextStyle(fontSize: 12, color: AppTokens.text3))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final v in vax)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switch (v.status) {
                                'overdue' => AppTokens.error,
                                'scheduled' || 'due' => AppTokens.warning,
                                _ => AppTokens.success,
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(v.vaccineName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(
                                '${formatDateIst(v.administeredDate)} → Next: ${(v.nextDueDate ?? '').isEmpty ? 'N/A' : formatDateIst(v.nextDueDate)}',
                                style: const TextStyle(fontSize: 12, color: AppTokens.text3),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
          ),
        const Divider(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (auth.hasPermission('emr.visits.view'))
            actionBtn(Icons.description_outlined, 'Full Report', () => context.push('/emr/pets/${pet.id}/visit-summary')),
          actionBtn(Icons.vaccines_outlined, 'Vaccination', onVaccination),
          if (auth.hasPermission('emr.visits.create'))
            actionBtn(null, 'New Visit', () => context.push('/emr/visits/new?pet_id=${pet.id}'), green: true),
          if (auth.hasPermission('emr.visits.view'))
            actionBtn(Icons.timeline_outlined, 'Timeline', () => context.push('/emr/pets/${pet.id}/timeline')),
          if (auth.hasPermission('emr.lab_reports.view'))
            actionBtn(Icons.biotech_outlined, 'Lab Reports', () => context.push('/emr/pets/${pet.id}/lab-reports')),
          if (auth.hasPermission('emr.documents.view'))
            actionBtn(Icons.folder_outlined, 'Documents', () => context.push('/emr/pets/${pet.id}/documents')),
        ]),
      ]),
    );
  }
}

class _VaccinationDialog extends StatefulWidget {
  const _VaccinationDialog({required this.pet});

  final Pet pet;

  @override
  State<_VaccinationDialog> createState() => _VaccinationDialogState();
}

class _VaccinationDialogState extends State<_VaccinationDialog> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  String? _given;
  String? _next;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool next) async {
    final today = nowIst();
    final base = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse((next ? _next : _given) ?? '') ?? base,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) setState(() => next ? _next = _ymd(picked) : _given = _ymd(picked));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _given == null) {
      AppMessenger.error(context, 'Please fill required fields');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppServices>().customers.addPetVaccination(widget.pet.id, {
        'vaccine_name': _name.text.trim(),
        'vaccine_brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        'administered_date': _given,
        'next_due_date': _next,
        'status': 'completed',
      });
      if (!mounted) return;
      AppMessenger.success(context, 'Vaccination recorded');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to save vaccination: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget dateField(String label, String? value, bool next, {bool required = false}) => FieldLabel(
          label,
          required: required,
          child: InkWell(
            onTap: () => _pick(next),
            child: InputDecorator(
              decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
              child: Text(value == null ? 'Select date' : formatDateIst(value),
                  style: TextStyle(color: value == null ? AppTokens.placeholder : AppTokens.text1)),
            ),
          ),
        );
    return AlertDialog(
      title: Text('Add Vaccination — ${widget.pet.name}'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldLabel('Vaccine Name', required: true, child: TextField(controller: _name)),
          const SizedBox(height: 12),
          FieldLabel('Brand', child: TextField(controller: _brand)),
          const SizedBox(height: 12),
          dateField('Date Given', _given, false, required: true),
          const SizedBox(height: 12),
          dateField('Next Due Date', _next, true),
        ]),
      ),
      actions: [
        OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Invoices ──────────────────────────────────────────────────────────

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.money, required this.onTap, this.onCollect});

  final Invoice invoice;
  final String Function(double) money;
  final VoidCallback onTap;
  final VoidCallback? onCollect;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final tone = switch (inv.status.toLowerCase()) {
      'paid' => PillTone.green,
      'partial' || 'confirmed' => PillTone.amber,
      'cancelled' => PillTone.red,
      _ => PillTone.grey,
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6)))),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.invoiceNumber.isNotEmpty ? inv.invoiceNumber : 'Invoice #${inv.id}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(inv.displayDate.isNotEmpty ? inv.displayDate : '—',
                  style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${money(inv.totalAmount)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if (inv.dueAmount > 0.009)
                Text('Due ₹${money(inv.dueAmount)}',
                    style: const TextStyle(fontSize: 12, color: AppTokens.warning, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 12),
          StatusPill(inv.status.isEmpty ? '—' : '${inv.status[0].toUpperCase()}${inv.status.substring(1)}', tone: tone),
          if (onCollect != null) ...[
            const SizedBox(width: 8),
            TableIconButton(icon: Icons.payments_outlined, tooltip: 'Collect due', color: AppTokens.warning, onPressed: onCollect),
          ],
        ]),
      ),
    );
  }
}
