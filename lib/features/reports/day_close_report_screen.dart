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
      final report = await context.read<AppServices>().cashierCash.dayCloseReport(date: _ymd);
      if (!mounted) return;
      setState(() {
        _report = report;
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBar(
            dateLabel: _ymd,
            loading: _loading,
            printing: _printing,
            canExport: report != null,
            canClose: report?.canClose == true,
            closing: _closing,
            onPickDate: _pickDate,
            onRefresh: _load,
            onExport: () => _print(share: true),
            onPrint: () => _print(share: false),
            onConfirmClose: _confirmClose,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.danger),
                        ),
                      )
                    : report == null
                        ? const Center(child: Text('No data'))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            children: [
                              _StatusBanner(report: report),
                              const SizedBox(height: 14),
                              if (totals != null) _TotalsGrid(totals: totals),
                              const SizedBox(height: 20),
                              const Text(
                                'Cashier shifts',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (report.sessions.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'No cashier shifts for this date.',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                )
                              else
                                ...report.sessions.map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _SessionCard(session: s),
                                  ),
                                ),
                              if (report.movements.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'Drawer movements',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _MovementsTable(movements: report.movements),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.dateLabel,
    required this.loading,
    required this.printing,
    required this.canExport,
    required this.canClose,
    required this.closing,
    required this.onPickDate,
    required this.onRefresh,
    required this.onExport,
    required this.onPrint,
    required this.onConfirmClose,
  });

  final String dateLabel;
  final bool loading;
  final bool printing;
  final bool canExport;
  final bool canClose;
  final bool closing;
  final VoidCallback onPickDate;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onPrint;
  final VoidCallback onConfirmClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day Close Report',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View summary of cash and shift activity for the selected date.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : onPickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(dateLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Refresh',
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: !canExport || printing ? null : onExport,
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              FilledButton.icon(
                onPressed: !canExport || printing ? null : onPrint,
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(printing ? 'Preparing…' : 'Print'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (canClose)
                FilledButton.tonalIcon(
                  onPressed: closing ? null : onConfirmClose,
                  icon: const Icon(Icons.lock_clock, size: 16),
                  label: Text(closing ? 'Closing…' : 'Confirm day close'),
                ),
            ],
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
    final closedAt = formatReportDateTime(report.dayClose?.closedAt);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: closed ? AppTheme.accent : AppTheme.warning,
            width: 4,
          ),
          top: BorderSide(color: closed ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA)),
          right: BorderSide(color: closed ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA)),
          bottom: BorderSide(color: closed ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (closed ? AppTheme.accent : AppTheme.warning).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              closed ? Icons.verified_outlined : Icons.pending_actions_outlined,
              color: closed ? AppTheme.accent : AppTheme.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  closed ? 'Day closed' : 'Day in progress',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  closed
                      ? 'Closed by ${report.dayClose?.closedByName ?? '—'}'
                          '${closedAt == '—' ? '' : ' · $closedAt'}'
                      : '${report.openSessions} open shift(s) · ${report.sessionsCount} total'
                          '${report.canClose ? ' · ready to close' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
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

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.totals});

  final CashierDayTotals totals;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricCardData>[
      _MetricCardData(
        label: 'Opening',
        value: totals.openingAmount,
        icon: Icons.account_balance_wallet_outlined,
        iconColor: const Color(0xFF3B82F6),
      ),
      _MetricCardData(
        label: 'Cash collected',
        value: totals.cashCollected,
        icon: Icons.payments_outlined,
        iconColor: const Color(0xFF10B981),
      ),
      _MetricCardData(
        label: 'Cash out',
        value: totals.cashOutTotal,
        icon: Icons.outbox_outlined,
        iconColor: const Color(0xFFEF4444),
      ),
      _MetricCardData(
        label: 'Expected',
        value: totals.expectedClosingAmount,
        icon: Icons.calculate_outlined,
        iconColor: const Color(0xFF6366F1),
      ),
      _MetricCardData(
        label: 'Counted',
        value: totals.countedAmount,
        icon: Icons.fact_check_outlined,
        iconColor: const Color(0xFF8B5CF6),
      ),
      _MetricCardData(
        label: 'Variance',
        value: totals.variance,
        icon: Icons.balance_outlined,
        iconColor: const Color(0xFFF59E0B),
        valueColor: totals.variance == 0
            ? AppTheme.accent
            : (totals.variance < 0 ? AppTheme.danger : AppTheme.textPrimary),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 6
            : width >= 900
                ? 3
                : width >= 600
                    ? 2
                    : 1;
        final gap = 10.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              SizedBox(
                width: cardWidth,
                child: _MetricCard(data: c),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 18, color: data.iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatReportCurrency(data.value),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: data.valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final CashierCashSession session;

  String get _initials {
    final name = (session.userName ?? 'U').trim();
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final open = session.isOpen;
    final badgeColor = open ? AppTheme.warning : AppTheme.accent;
    final whenLabel = open
        ? 'Started at ${formatReportTime(session.startedAt)}'
        : 'Closed at ${formatReportTime(session.endedAt)}';
    final details = open
        ? 'Open · in hand ${formatReportCurrency(session.amountInHand)}'
            ' · taken ${formatReportCurrency(session.cashOutTotal)}'
        : 'Closed · counted ${formatReportCurrency(session.countedAmount ?? 0)}'
            ' · expected ${formatReportCurrency(session.expectedClosingAmount)}'
            ' · var ${formatReportCurrency(session.variance ?? 0)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: badgeColor.withValues(alpha: 0.14),
            child: Text(
              _initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.userName ?? 'User #${session.userId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        open ? 'OPEN' : 'CLOSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            whenLabel,
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

class _MovementsTable extends StatelessWidget {
  const _MovementsTable({required this.movements});

  final List<CashierCashMovement> movements;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _TableHeader('TYPE')),
                Expanded(flex: 2, child: _TableHeader('AMOUNT')),
                Expanded(flex: 2, child: _TableHeader('BY')),
                Expanded(flex: 3, child: _TableHeader('DATE & TIME', alignEnd: true)),
              ],
            ),
          ),
          for (var i = 0; i < movements.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFE2E8F0)),
            _MovementRow(movement: movements[i]),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label, {this.alignEnd = false});

  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final CashierCashMovement movement;

  bool get _isOut =>
      movement.type == 'cash_out' ||
      movement.type == 'shift_close' ||
      movement.type.contains('out');

  @override
  Widget build(BuildContext context) {
    final color = _isOut ? AppTheme.danger : AppTheme.accent;
    final icon = _isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final by = movement.userName ??
        movement.createdByName ??
        'User #${movement.userId}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    movement.type,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatReportCurrency(movement.amount),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              by,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatReportDateTime(movement.createdAt),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
