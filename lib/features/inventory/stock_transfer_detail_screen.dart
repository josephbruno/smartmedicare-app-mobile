import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../data/models/stock_transfer.dart';

class StockTransferDetailScreen extends StatefulWidget {
  const StockTransferDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<StockTransferDetailScreen> createState() =>
      _StockTransferDetailScreenState();
}

class _StockTransferDetailScreenState extends State<StockTransferDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  StockTransfer? _transfer;
  final TextEditingController _reviewNotes = TextEditingController();
  final Map<int, TextEditingController> _acceptQty = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewNotes.dispose();
    for (final c in _acceptQty.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _branchId => context.read<AuthSession>().currentBranchId;

  bool get _isSource =>
      _transfer != null && _transfer!.fromBranchId == _branchId;

  bool get _isDest =>
      _transfer != null && _transfer!.toBranchId == _branchId;

  bool get _canApprove =>
      _transfer != null && _transfer!.isRequested && _isSource;

  bool get _canComplete =>
      _transfer != null && _transfer!.isApproved && _isSource;

  bool get _canReceive =>
      _transfer != null && _transfer!.isDispatched && _isDest;

  bool get _canCancel =>
      _transfer != null && _transfer!.isRequested && _isDest;

  String? get _waitingHint {
    final t = _transfer;
    if (t == null) return null;
    if (_isDest && t.isApproved) {
      return 'Waiting for the sending branch to dispatch.';
    }
    if (_isSource && t.isDispatched) {
      return 'Waiting for the receiving branch to confirm.';
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await context.read<AppServices>().inventory.getTransfer(widget.id);
      for (final c in _acceptQty.values) {
        c.dispose();
      }
      _acceptQty.clear();
      for (final item in t.items) {
        _acceptQty[item.id] = TextEditingController(
          text: (item.acceptedQuantity ??
                  item.dispatchedQuantity ??
                  item.requestedQuantity)
              .toString(),
        );
      }
      setState(() {
        _transfer = t;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await context.read<AppServices>().inventory.approveTransfer(widget.id);
      _done('Request approved. Complete the transfer when ready to ship.');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await context.read<AppServices>().inventory.completeTransfer(widget.id);
      _done('Stock dispatched. Awaiting receiving branch approval.');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final t = _transfer!;
    setState(() => _busy = true);
    try {
      final items = t.items.map((item) {
        final qty = double.tryParse(_acceptQty[item.id]?.text.trim() ?? '') ?? 0;
        return {'id': item.id, 'accepted_quantity': qty};
      }).toList();
      await context.read<AppServices>().inventory.acceptTransfer(widget.id, {
        if (_reviewNotes.text.trim().isNotEmpty)
          'review_notes': _reviewNotes.text.trim(),
        'items': items,
      });
      _done('Transfer received and stock added to this branch.');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await context.read<AppServices>().inventory.rejectTransfer(widget.id, {
        if (_reviewNotes.text.trim().isNotEmpty)
          'review_notes': _reviewNotes.text.trim(),
      });
      _done('Transfer rejected.');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await context.read<AppServices>().inventory.cancelTransfer(widget.id);
      _done('Transfer request cancelled.');
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done(String msg) {
    if (!mounted) return;
    _snack(msg);
    context.pop();
  }

  void _snack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context, SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = _transfer;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t?.transferNumber ?? 'Transfer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _info('From', t!.fromBranchName ?? 'Branch #${t.fromBranchId}'),
                    _info('To', t.toBranchName ?? 'Branch #${t.toBranchId}'),
                    _info('Requested by', t.requestedByName ?? '—'),
                    if (t.approvedByName != null)
                      _info('Approved by', t.approvedByName!),
                    if (t.dispatchedByName != null)
                      _info('Dispatched by', t.dispatchedByName!),
                    if (t.reviewedByName != null)
                      _info('Received by', t.reviewedByName!),
                    _info('Status', t.status),
                    if (t.notes != null && t.notes!.isNotEmpty)
                      _info('Notes', t.notes!),
                    if (t.reviewNotes != null && t.reviewNotes!.isNotEmpty)
                      _info('Review notes', t.reviewNotes!),
                    const Divider(height: 32),
                    const Text('Items',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (final item in t.items) _itemRow(item),
                    if (_canApprove) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reviewNotes,
                        decoration: const InputDecoration(
                            labelText: 'Review notes (optional)'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : _reject,
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _approve,
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_canComplete) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _complete,
                        child: const Text('Complete & Dispatch'),
                      ),
                    ] else if (_canReceive) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reviewNotes,
                        decoration: const InputDecoration(
                            labelText: 'Review notes (optional)'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : _reject,
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _accept,
                              child: const Text('Approve & Receive'),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_canCancel) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _busy ? null : _cancel,
                        child: const Text('Cancel Request'),
                      ),
                    ] else if (_waitingHint != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _waitingHint!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _itemRow(StockTransferItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(item.product?.name ?? 'Product #${item.productId}'),
          ),
          Expanded(
            flex: 1,
            child: Text('Req: ${item.requestedQuantity}',
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _canReceive
                ? TextField(
                    controller: _acceptQty[item.id],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Accept',
                      isDense: true,
                    ),
                  )
                : Text(
                    [
                      if (item.dispatchedQuantity != null)
                        'Sent: ${item.dispatchedQuantity}',
                      'Acc: ${item.acceptedQuantity ?? '—'}',
                    ].join('  '),
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }
}
