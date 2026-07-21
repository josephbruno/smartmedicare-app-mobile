import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/advance_transaction.dart';
import '../../../data/models/customer.dart';

Future<bool> showAdvancePaymentSheet(
  BuildContext context, {
  required Customer customer,
  int? visitId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AdvancePaymentSheet(
      customer: customer,
      visitId: visitId,
    ),
  );
  return result == true;
}

class _AdvancePaymentSheet extends StatefulWidget {
  const _AdvancePaymentSheet({required this.customer, this.visitId});

  final Customer customer;
  final int? visitId;

  @override
  State<_AdvancePaymentSheet> createState() => _AdvancePaymentSheetState();
}

class _AdvancePaymentSheetState extends State<_AdvancePaymentSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  String _mode = 'cash';
  bool _busy = false;
  List<AdvanceTransaction> _history = [];
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _balance = widget.customer.advanceBalance;
    _loadHistory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _amount.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final result = await context
          .read<AppServices>()
          .customers
          .listAdvances(widget.customer.id);
      if (mounted) {
        setState(() {
          _history = result.items;
          _balance = result.advanceBalance;
        });
      }
    } catch (_) {}
  }

  Future<void> _submit({required bool refund}) async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      AppMessenger.show(context,
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = context.read<AppServices>().customers;
      final body = {
        'amount': amount,
        'payment_mode': _mode,
        if (_ref.text.trim().isNotEmpty) 'reference_number': _ref.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (!refund && widget.visitId != null) 'visit_id': widget.visitId,
      };
      final result = refund
          ? await svc.refundAdvance(widget.customer.id, body)
          : await svc.recordAdvance(widget.customer.id, body);
      if (!mounted) return;
      setState(() {
        _balance = result.advanceBalance;
        _amount.clear();
        _busy = false;
      });
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(refund
              ? 'Advance refunded. Balance ₹${_balance.toStringAsFixed(2)}'
              : 'Advance recorded. Balance ₹${_balance.toStringAsFixed(2)}'),
        ),
      );
      await _loadHistory();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Treatment Advance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '₹${_balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Receive'),
                Tab(text: 'Refund'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _form(refund: false),
                  _form(refund: true),
                  _historyList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form({required bool refund}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: refund ? 'Refund amount (₹)' : 'Advance amount (₹)',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _mode,
          decoration: const InputDecoration(
            labelText: 'Payment mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'upi', child: Text('UPI')),
            DropdownMenuItem(value: 'card', child: Text('Card')),
            DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _mode = v ?? 'cash'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ref,
          decoration: const InputDecoration(
            labelText: 'Reference (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: refund ? 'Refund notes' : 'Notes (e.g. surgery advance)',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : () => _submit(refund: refund),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(refund ? 'Refund Advance' : 'Record Advance'),
        ),
      ],
    );
  }

  Widget _historyList() {
    if (_history.isEmpty) {
      return const Center(child: Text('No advance transactions yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final t = _history[i];
        final color = t.type == 'receive'
            ? AppTheme.accent
            : (t.type == 'refund' ? AppTheme.danger : AppTheme.warning);
        return ListTile(
          dense: true,
          title: Text(
            '${t.type.toUpperCase()} · ₹${t.amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [
              if (t.paymentMode != null) t.paymentMode!,
              if (t.notes != null && t.notes!.isNotEmpty) t.notes!,
              if (t.createdAt != null) t.createdAt!.split('T').first,
            ].join(' · '),
          ),
          trailing: Text('Bal ₹${t.balanceAfter.toStringAsFixed(0)}'),
        );
      },
    );
  }
}
