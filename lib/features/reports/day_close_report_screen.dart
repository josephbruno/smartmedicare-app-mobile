import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/messaging/app_messenger.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/cashier_cash_session.dart';
import 'day_close_report_pdf.dart';
import 'report_formatters.dart';

class DayCloseReportScreen extends StatefulWidget {
  const DayCloseReportScreen({super.key});

  @override
  State<DayCloseReportScreen> createState() => _DayCloseReportScreenState();
}

class _DayCloseReportScreenState extends State<DayCloseReportScreen> {
  late DateTime _date;
  bool _loading = true;
  String? _error;
  CashierDayStatus? _report;
  List<CashierDayCloseInfo> _history = [];
  bool _closing = false;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _load();
  }

  String get _ymd => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = context.read<AppServices>().cashierCash;
      final results = await Future.wait([
        svc.dayCloseReport(date: _ymd),
        svc.dayCloseHistory(limit: 30),
      ]);
      if (!mounted) return;
      setState(() {
        _report = results[0] as CashierDayStatus;
        _history = results[1] as List<CashierDayCloseInfo>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _confirmClose() async {
    final report = _report;
    if (report == null || !report.canClose) return;

    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm day close'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Close $_ymd for this branch?'),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close day')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _closing = true);
    try {
      await context.read<AppServices>().cashierCash.dayClose(
            businessDate: _ymd,
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          );
      if (!mounted) return;
      AppMessenger.show(context, const SnackBar(content: Text('Day closed successfully')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _print({required bool share}) async {
    final report = _report;
    if (report == null) return;
    setState(() => _printing = true);
    try {
      final auth = context.read<AuthSession>();
      final clinic = auth.currentShop?.name ?? 'Maran Clinic';
      final branch = auth.currentBranch?.name;
      if (share) {
        await DayCloseReportPdf.share(
          report: report,
          clinicName: clinic,
          branchName: branch,
        );
      } else {
        await DayCloseReportPdf.print(
          report: report,
          clinicName: clinic,
          branchName: branch,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final totals = report?.totals;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Day Close Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_ymd),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: report == null || _printing ? null : () => _print(share: true),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('Export PDF'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: report == null || _printing ? null : () => _print(share: false),
                  icon: const Icon(Icons.print, size: 16),
                  label: Text(_printing ? 'Preparing…' : 'Print'),
                ),
                if (report?.canClose == true) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _closing ? null : _confirmClose,
                    icon: const Icon(Icons.lock_clock, size: 16),
                    label: Text(_closing ? 'Closing…' : 'Confirm day close'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)))
                    : report == null
                        ? const Center(child: Text('No data'))
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 260,
                                child: _HistoryPane(
                                  history: _history,
                                  selectedDate: _ymd,
                                  onSelect: (d) {
                                    setState(() => _date = DateTime.parse(d));
                                    _load();
                                  },
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    _StatusBanner(report: report),
                                    const SizedBox(height: 12),
                                    if (totals != null) _TotalsGrid(totals: totals),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Cashier shifts',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    ...report.sessions.map(_SessionCard.new),
                                    if (report.sessions.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24),
                                        child: Text(
                                          'No cashier shifts for this date.',
                                          style: TextStyle(color: AppTheme.textSecondary),
                                        ),
                                      ),
                                    if (report.movements.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Drawer movements',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                                      const SizedBox(height: 8),
                                      ...report.movements.map(_MovementTile.new),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPane extends StatelessWidget {
  const _HistoryPane({
    required this.history,
    required this.selectedDate,
    required this.onSelect,
  });

  final List<CashierDayCloseInfo> history;
  final String selectedDate;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'Closed days',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No day closes yet. Close a day from POS or Confirm here.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, i) {
                      final h = history[i];
                      final selected = h.businessDate == selectedDate;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
                        title: Text(
                          h.businessDate,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${h.sessionsCount} shifts · ${formatReportCurrency(h.totalCountedAmount)}'
                          '${h.closedByName != null ? ' · ${h.closedByName}' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => onSelect(h.businessDate),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.report});

  final CashierDayStatus report;

  @override
  Widget build(BuildContext context) {
    final closed = report.isClosed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: closed ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            closed ? Icons.verified : Icons.pending_actions,
            color: closed ? AppTheme.accent : AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  closed ? 'Day closed' : 'Day in progress',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  closed
                      ? 'Closed by ${report.dayClose?.closedByName ?? '—'}'
                          '${report.dayClose?.closedAt != null ? ' · ${report.dayClose!.closedAt}' : ''}'
                      : '${report.openSessions} open shift(s) · ${report.sessionsCount} total'
                          '${report.canClose ? ' · ready to close' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.totals});

  final CashierDayTotals totals;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Opening', totals.openingAmount),
      ('Cash collected', totals.cashCollected),
      ('Cash out', totals.cashOutTotal),
      ('Expected', totals.expectedClosingAmount),
      ('Counted', totals.countedAmount),
      ('Variance', totals.variance),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map(
            (c) => Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.$1, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    formatReportCurrency(c.$2),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard(this.session);

  final CashierCashSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          session.userName ?? 'User #${session.userId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          session.isOpen
              ? 'Open · in hand ${formatReportCurrency(session.amountInHand)}'
                  ' · taken ${formatReportCurrency(session.cashOutTotal)}'
              : 'Closed · counted ${formatReportCurrency(session.countedAmount ?? 0)}'
                  ' · expected ${formatReportCurrency(session.expectedClosingAmount)}'
                  ' · var ${formatReportCurrency(session.variance ?? 0)}',
        ),
        trailing: Text(
          session.isOpen ? 'OPEN' : 'CLOSED',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: session.isOpen ? AppTheme.warning : AppTheme.accent,
          ),
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile(this.movement);

  final CashierCashMovement movement;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${movement.type} · ${formatReportCurrency(movement.amount)}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        '${movement.userName ?? 'User #${movement.userId}'}'
        '${(movement.notes ?? '').trim().isEmpty ? '' : ' · ${movement.notes}'}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        movement.createdAt ?? '',
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    );
  }
}
