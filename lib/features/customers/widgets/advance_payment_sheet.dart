import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../data/models/advance_transaction.dart';
import '../../../data/models/customer.dart';
import '../../../core/widgets/app_dropdown.dart';
Future<bool> showAdvancePaymentSheet(
  BuildContext context, {
  required Customer customer,
  int? visitId,
}) async {
  final bool? result;
  if (useCenteredFormDialog(context)) {
    result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => _AdvancePaymentDialog(
        customer: customer,
        visitId: visitId,
      ),
    );
  } else {
    result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdvancePaymentBottomSheet(
        customer: customer,
        visitId: visitId,
      ),
    );
  }
  return result == true;
}

class _AdvancePaymentDialog extends StatelessWidget {
  const _AdvancePaymentDialog({required this.customer, this.visitId});

  final Customer customer;
  final int? visitId;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogH = (screenH * 0.85).clamp(420.0, 640.0);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 480,
        height: dialogH,
        child: _AdvancePaymentBody(
          customer: customer,
          visitId: visitId,
          showHandle: false,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _AdvancePaymentBottomSheet extends StatelessWidget {
  const _AdvancePaymentBottomSheet({required this.customer, this.visitId});

  final Customer customer;
  final int? visitId;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final sheetH = (MediaQuery.sizeOf(context).height * 0.88).clamp(420.0, 720.0);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: sheetH,
              child: _AdvancePaymentBody(
                customer: customer,
                visitId: visitId,
                showHandle: true,
                onClose: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvancePaymentBody extends StatefulWidget {
  const _AdvancePaymentBody({
    required this.customer,
    required this.onClose,
    this.visitId,
    this.showHandle = false,
  });

  final Customer customer;
  final int? visitId;
  final VoidCallback onClose;
  final bool showHandle;

  @override
  State<_AdvancePaymentBody> createState() => _AdvancePaymentBodyState();
}

class _AdvancePaymentBodyState extends State<_AdvancePaymentBody>
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
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
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

  bool get _isHistoryTab => _tabs.index == 2;
  bool get _isRefundTab => _tabs.index == 1;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHandle) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.showHandle ? 12 : 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Treatment Advance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
              IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
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
              _formFields(refund: false),
              _formFields(refund: true),
              _historyList(),
            ],
          ),
        ),
        if (!_isHistoryTab) _footer(),
      ],
    );
  }

  Widget _formFields({required bool refund}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: refund ? 'Refund amount (₹)' : 'Advance amount (₹)',
          ),
        ),
        const SizedBox(height: 12),
        AppDropdownButtonFormField<String>(
          value: _mode,
          decoration: const InputDecoration(
            labelText: 'Payment mode',
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
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: refund ? 'Refund notes' : 'Notes (e.g. surgery advance)',
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    final refund = _isRefundTab;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        color: Colors.white,
      ),
      child: FilledButton(
        onPressed: _busy ? null : () => _submit(refund: refund),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(refund ? 'Refund Advance' : 'Record Advance'),
      ),
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
