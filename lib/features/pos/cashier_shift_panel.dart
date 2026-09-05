import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/messaging/app_messenger.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/cashier_cash_session.dart';

String _shiftRupees(double value) {
  if (value == value.roundToDouble()) {
    return '₹${value.toStringAsFixed(0)}';
  }
  return '₹${value.toStringAsFixed(2)}';
}

/// Compact POS bar: amount in hand, shift start/end, day close.
class CashierShiftPanel extends StatelessWidget {
  const CashierShiftPanel({
    super.key,
    required this.session,
    required this.dayStatus,
    required this.dayClosed,
    required this.loading,
    required this.onRefresh,
    this.suggestedOpening,
    this.openBranchSessions = const [],
    this.compact = false,
  });

  final CashierCashSession? session;
  final CashierDayStatus? dayStatus;
  final bool dayClosed;
  final bool loading;
  final Future<void> Function() onRefresh;
  final CashierSuggestedOpening? suggestedOpening;
  final List<CashierOpenBranchSession> openBranchSessions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canView = auth.hasPermission(AppPermissions.cashierShiftView);
    if (!canView) return const SizedBox.shrink();

    final canStart = auth.hasPermission(AppPermissions.cashierShiftStart);
    final canEnd = auth.hasPermission(AppPermissions.cashierShiftEnd);
    final canMove = auth.hasPermission(AppPermissions.cashierCashMove);
    final canDayClose = auth.hasPermission(AppPermissions.cashierDayClose);
    final open = session?.isOpen == true;

    final bg = open
        ? AppTheme.accent.withValues(alpha: 0.08)
        : (dayClosed
            ? AppTheme.textSecondary.withValues(alpha: 0.08)
            : const Color(0xFFFFF7ED));

    final headFs = compact ? 9.0 : 10.0;
    final valueFs = compact ? 12.0 : 13.0;
    final actionIconSize = compact ? 18.0 : 20.0;
    final iconBox = compact ? 34.0 : 36.0;

    final statusColor = open
        ? AppTheme.accent
        : (dayClosed ? AppTheme.textSecondary : AppTheme.warning);
    final statusTooltip = open
        ? 'Shift open'
        : (dayClosed ? 'Day closed' : 'Shift not started');
    final statusIconData = open
        ? Icons.circle
        : (dayClosed ? Icons.event_busy_rounded : Icons.circle_outlined);

    final metrics = <_ShiftMetric>[
      if (open) ...[
        _ShiftMetric(
          label: 'In hand',
          value: _shiftRupees(session!.amountInHand),
          emphasize: true,
          flex: 2,
        ),
        _ShiftMetric(
          label: 'Opening',
          value: _shiftRupees(session!.openingAmount),
        ),
        _ShiftMetric(
          label: 'Cash in',
          value: _shiftRupees(session!.cashCollected),
        ),
        if (session!.cashOutTotal > 0)
          _ShiftMetric(
            label: 'Taken',
            value: _shiftRupees(session!.cashOutTotal),
          ),
      ] else if (dayClosed) ...[
        const _ShiftMetric(label: 'Shifts', value: 'None today', flex: 2),
      ] else ...[
        _ShiftMetric(
          label: 'Available',
          value: suggestedOpening?.hasSuggestion == true
              ? _shiftRupees(suggestedOpening!.amount!)
              : '—',
          emphasize: true,
          flex: 2,
        ),
        _ShiftMetric(
          label: 'Note',
          value: suggestedOpening?.label ?? 'Enter opening cash',
          flex: 2,
        ),
      ],
    ];

    Widget metricContent(_ShiftMetric m) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            m.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: headFs,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              m.value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: valueFs,
                fontWeight: m.emphasize ? FontWeight.w700 : FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    Widget metricCell(_ShiftMetric m, {bool isLast = false}) {
      return Expanded(
        flex: m.flex,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: metricContent(m),
        ),
      );
    }

    Widget iconBoxWidget({
      required String tooltip,
      required IconData icon,
      required Color color,
      required Color background,
      VoidCallback? onPressed,
      double? glyphSize,
    }) {
      final child = SizedBox(
        width: iconBox,
        height: iconBox,
        child: Icon(icon, size: glyphSize ?? actionIconSize, color: color),
      );
      return Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          child: onPressed == null
              ? child
              : InkWell(
                  onTap: loading ? null : onPressed,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                ),
        ),
      );
    }

    final statusChip = iconBoxWidget(
      tooltip: statusTooltip,
      icon: statusIconData,
      color: statusColor,
      background: statusColor.withValues(alpha: 0.12),
      glyphSize: compact ? 14 : 16,
    );

    final actionButtons = <Widget>[
      if (!open && !dayClosed && canStart)
        iconBoxWidget(
          tooltip: 'Start shift',
          icon: Icons.play_arrow_rounded,
          color: Colors.white,
          background: AppTheme.primary,
          onPressed: () => _startShift(context),
        ),
      if (open && canMove)
        iconBoxWidget(
          tooltip: 'Take from drawer',
          icon: Icons.money_off_csred_rounded,
          color: AppTheme.danger,
          background: AppTheme.danger.withValues(alpha: 0.12),
          onPressed: () => _takeFromDrawer(context),
        ),
      if (open && canEnd)
        iconBoxWidget(
          tooltip: 'End shift',
          icon: Icons.stop_circle_outlined,
          color: AppTheme.primary,
          background: AppTheme.primary.withValues(alpha: 0.12),
          onPressed: () => _endShift(context),
        ),
      if (canDayClose)
        iconBoxWidget(
          tooltip: dayClosed ? 'Day status' : 'Day close',
          icon: Icons.calendar_today_outlined,
          color: AppTheme.primary,
          background: Colors.white,
          onPressed: () => _showDayClose(context),
        ),
    ];

    Widget actionsRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusChip,
          if (loading) ...[
            const SizedBox(width: 6),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else ...[
            for (final btn in actionButtons) ...[
              const SizedBox(width: 6),
              btn,
            ],
          ],
        ],
      );
    }

    Widget metricsBox() {
      if (metrics.isEmpty) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < metrics.length; i++)
                metricCell(metrics[i], isLast: i == metrics.length - 1),
            ],
          ),
        ),
      );
    }

    final bar = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: open
              ? AppTheme.accent.withValues(alpha: 0.25)
              : (dayClosed ? const Color(0xFFE2E8F0) : const Color(0xFFFED7AA)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (metrics.isNotEmpty) metricsBox(),
                  SizedBox(height: metrics.isNotEmpty ? 8 : 0),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionsRow(),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final actionCount = 1 + (loading ? 1 : actionButtons.length);
                  final actionW = 8 + actionCount * (iconBox + 6);
                  final needsStack = metrics.isNotEmpty &&
                      constraints.maxWidth < (metrics.length * 100 + actionW);

                  if (needsStack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        metricsBox(),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: actionsRow(),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      if (metrics.isNotEmpty)
                        Expanded(child: metricsBox())
                      else
                        const Spacer(),
                      const SizedBox(width: 8),
                      actionsRow(),
                    ],
                  );
                },
              ),
      ),
    );

    return bar;
  }

  Future<void> _startShift(BuildContext context) async {
    final auth = context.read<AuthSession>();
    final myUserId = auth.user?.id;

    List<CashierOpenBranchSession> openOnBranch = openBranchSessions;
    try {
      final current = await context.read<AppServices>().cashierCash.current();
      openOnBranch = current.openBranchSessions;
      await onRefresh();
    } catch (_) {
      // Fall back to last known openBranchSessions from the panel.
    }
    if (!context.mounted) return;

    final blockers = openOnBranch
        .where((s) => myUserId == null || s.userId != myUserId)
        .toList();
    if (blockers.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _ShiftBlockedDialog(sessions: blockers),
      );
      return;
    }

    final suggestion = suggestedOpening;
    final prefill = suggestion?.amount;
    final amountCtrl = TextEditingController(
      text: prefill != null ? prefill.toStringAsFixed(2) : '',
    );
    final notesCtrl = TextEditingController();

    final summary = <_DialogMetric>[
      if (suggestion?.previousShiftAmount != null)
        _DialogMetric(
          label: 'Prev shift',
          value: '₹${suggestion!.previousShiftAmount!.toStringAsFixed(0)}',
        ),
      if (suggestion?.lastDayCloseAmount != null)
        _DialogMetric(
          label: 'Last close',
          value: '₹${suggestion!.lastDayCloseAmount!.toStringAsFixed(0)}',
        ),
      if (suggestion?.hasSuggestion == true)
        _DialogMetric(
          label: 'Suggested',
          value: '₹${suggestion!.amount!.toStringAsFixed(0)}',
          emphasize: true,
          color: AppTheme.accent,
        ),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CashShiftDialog(
        icon: Icons.play_circle_filled_rounded,
        iconColor: AppTheme.primary,
        title: 'Start shift',
        subtitle: 'Enter the opening cash float in the drawer.',
        summary: summary,
        amountController: amountCtrl,
        notesController: notesCtrl,
        amountLabel: 'Opening amount in hand',
        notesLabel: 'Notes (optional)',
        confirmLabel: 'Start shift',
        confirmColor: AppTheme.primary,
      ),
    );
    if (ok != true || !context.mounted) {
      amountCtrl.dispose();
      notesCtrl.dispose();
      return;
    }
    final amount = double.tryParse(amountCtrl.text.trim());
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (amount == null || amount < 0) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Enter a valid opening amount.'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    try {
      await context.read<AppServices>().cashierCash.start(
            openingAmount: amount,
            notes: notes.isEmpty ? null : notes,
          );
      if (context.mounted) {
        AppMessenger.show(context, const SnackBar(content: Text('Shift started.')));
        await onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.show(
          context,
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _endShift(BuildContext context) async {
    final session = this.session;
    if (session == null || !session.isOpen) return;

    final amountCtrl = TextEditingController(
      text: session.amountInHand.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController();

    final summary = <_DialogMetric>[
      _DialogMetric(
        label: 'Expected',
        value: '₹${session.amountInHand.toStringAsFixed(2)}',
        emphasize: true,
        color: AppTheme.primary,
      ),
      _DialogMetric(
        label: 'Opening',
        value: '₹${session.openingAmount.toStringAsFixed(0)}',
      ),
      _DialogMetric(
        label: 'Cash in',
        value: '₹${session.cashCollected.toStringAsFixed(0)}',
      ),
      if (session.cashOutTotal > 0)
        _DialogMetric(
          label: 'Taken',
          value: '₹${session.cashOutTotal.toStringAsFixed(0)}',
          color: AppTheme.danger,
        ),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CashShiftDialog(
        icon: Icons.stop_circle_outlined,
        iconColor: AppTheme.primary,
        title: 'End shift',
        subtitle: 'Count the drawer and confirm the closing amount.',
        summary: summary,
        amountController: amountCtrl,
        notesController: notesCtrl,
        amountLabel: 'Counted amount in hand',
        notesLabel: 'Notes (optional)',
        confirmLabel: 'End shift',
        confirmColor: AppTheme.primary,
        expectedAmount: session.amountInHand,
        showVariance: true,
      ),
    );
    if (ok != true || !context.mounted) {
      amountCtrl.dispose();
      notesCtrl.dispose();
      return;
    }
    final amount = double.tryParse(amountCtrl.text.trim());
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (amount == null || amount < 0) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Enter a valid counted amount.'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    try {
      final closed = await context.read<AppServices>().cashierCash.end(
            sessionId: session.id,
            countedAmount: amount,
            notes: notes.isEmpty ? null : notes,
          );
      if (context.mounted) {
        final v = closed.variance ?? 0;
        final sign = v >= 0 ? '+' : '';
        AppMessenger.show(
          context,
          SnackBar(
            content: Text(
              'Shift ended. Variance $sign₹${v.toStringAsFixed(2)}',
            ),
          ),
        );
        await onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.show(
          context,
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _takeFromDrawer(BuildContext context) async {
    final session = this.session;
    if (session == null || !session.isOpen) return;

    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CashShiftDialog(
        icon: Icons.money_off_csred_rounded,
        iconColor: AppTheme.danger,
        title: 'Take from drawer',
        subtitle: 'Logged against you for this branch. Notes are required.',
        summary: [
          _DialogMetric(
            label: 'In hand now',
            value: '₹${session.amountInHand.toStringAsFixed(2)}',
            emphasize: true,
            color: AppTheme.accent,
          ),
        ],
        amountController: amountCtrl,
        notesController: notesCtrl,
        amountLabel: 'Amount taken',
        notesLabel: 'Notes (required)',
        notesHint: 'e.g. Bank deposit / Owner handover',
        notesRequired: true,
        confirmLabel: 'Confirm take',
        confirmColor: AppTheme.danger,
      ),
    );
    if (ok != true || !context.mounted) {
      amountCtrl.dispose();
      notesCtrl.dispose();
      return;
    }
    final amount = double.tryParse(amountCtrl.text.trim());
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (amount == null || amount <= 0) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Enter a valid amount.'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    if (notes.length < 2) {
      AppMessenger.show(
        context,
        const SnackBar(
          content: Text('Notes are required for drawer cash takeaway.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    try {
      await context.read<AppServices>().cashierCash.recordMovement(
            sessionId: session.id,
            type: 'cash_out',
            amount: amount,
            notes: notes,
          );
      if (context.mounted) {
        AppMessenger.show(
          context,
          SnackBar(content: Text('Took ₹${amount.toStringAsFixed(2)} from drawer.')),
        );
        await onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.show(
          context,
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _showDayClose(BuildContext context) async {
    late final CashierDayStatus day;
    try {
      day = dayStatus ?? await context.read<AppServices>().cashierCash.dayStatus();
    } catch (e) {
      if (context.mounted) {
        AppMessenger.show(
          context,
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final notesCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(day.isClosed ? 'Day status' : 'Day close'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Date ${day.businessDate}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sessions ${day.sessionsCount}'
                    ' · Open ${day.openSessions}'
                    ' · Cash ₹${day.totals.cashCollected.toStringAsFixed(0)}'
                    ' · Taken ₹${day.totals.cashOutTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ...day.sessions.map((s) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.userName ?? 'User #${s.userId}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: Text(
                        s.isOpen
                            ? 'Open · in hand ₹${s.amountInHand.toStringAsFixed(2)}'
                                '${s.cashOutTotal > 0 ? ' · taken ₹${s.cashOutTotal.toStringAsFixed(0)}' : ''}'
                            : 'Closed · counted ₹${(s.countedAmount ?? 0).toStringAsFixed(2)}'
                                ' · taken ₹${s.cashOutTotal.toStringAsFixed(0)}'
                                ' · var ₹${(s.variance ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        s.isOpen ? 'OPEN' : 'CLOSED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: s.isOpen ? AppTheme.warning : AppTheme.accent,
                        ),
                      ),
                    );
                  }),
                  if (day.movements.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Branch drawer log',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    ...day.movements.map((m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${m.userName ?? 'User'} · ${m.type} ₹${m.amount.toStringAsFixed(0)}'
                          '${(m.notes ?? '').isNotEmpty ? ' — ${m.notes}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      );
                    }),
                  ],
                  if (!day.isClosed && day.canClose) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Day close notes (who took remaining cash)',
                      ),
                    ),
                  ],
                  if (!day.isClosed && !day.canClose)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'End all open cashier shifts before day close.',
                        style: TextStyle(color: AppTheme.danger, fontSize: 12),
                      ),
                    ),
                  if (day.isClosed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Closed · counted ₹${day.totals.countedAmount.toStringAsFixed(2)}'
                        ' · variance ₹${day.totals.variance.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            if (!day.isClosed && day.canClose)
              FilledButton(
                onPressed: () async {
                  try {
                    final notes = notesCtrl.text.trim();
                    await context.read<AppServices>().cashierCash.dayClose(
                          notes: notes.isEmpty ? null : notes,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      AppMessenger.show(context, const SnackBar(content: Text('Day closed.')));
                      await onRefresh();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppMessenger.show(
                        context,
                        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
                      );
                    }
                  }
                },
                child: const Text('Confirm day close'),
              ),
          ],
        );
      },
    );
    notesCtrl.dispose();
  }
}

class _ShiftMetric {
  const _ShiftMetric({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.flex = 1,
  });

  final String label;
  final String value;
  final bool emphasize;
  final int flex;
}

class _DialogMetric {
  const _DialogMetric({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? color;
}

/// Explains why Start shift is blocked when another cashier is still open.
class _ShiftBlockedDialog extends StatelessWidget {
  const _ShiftBlockedDialog({required this.sessions});

  final List<CashierOpenBranchSession> sessions;

  static String _formatInHand(double amount) {
    final whole = amount == amount.roundToDouble();
    return whole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  static String? _startedLabel(String? startedAt) {
    if (startedAt == null || startedAt.trim().isEmpty) return null;
    final raw = startedAt.trim();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Started $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width * 0.42).clamp(360.0, 460.0);
    final names = sessions.map((s) => s.displayName).toSet().toList();
    final askLabel = names.length == 1
        ? 'Ask ${names.first} to end their shift before you can start yours.'
        : 'Ask ${names.join(', ')} to end their shifts before you can start yours.';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      color: AppTheme.warning,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift already open',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Only one cashier shift can be open on this branch.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.28)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppTheme.warning.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        askLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                sessions.length == 1 ? 'Open shift' : 'Open shifts',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.36),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    for (var i = 0; i < sessions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _BlockedSessionTile(session: sessions[i]),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedSessionTile extends StatelessWidget {
  const _BlockedSessionTile({required this.session});

  final CashierOpenBranchSession session;

  @override
  Widget build(BuildContext context) {
    final started = _ShiftBlockedDialog._startedLabel(session.startedAt);
    final inHand = _ShiftBlockedDialog._formatInHand(session.amountInHand);
    final initial = session.displayName.isNotEmpty
        ? session.displayName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  started ?? 'Shift in progress',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'In hand',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹$inHand',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared smart dialog for start / end / take cash actions.
class _CashShiftDialog extends StatefulWidget {
  const _CashShiftDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.amountController,
    required this.notesController,
    required this.amountLabel,
    required this.notesLabel,
    required this.confirmLabel,
    required this.confirmColor,
    this.notesHint,
    this.notesRequired = false,
    this.expectedAmount,
    this.showVariance = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<_DialogMetric> summary;
  final TextEditingController amountController;
  final TextEditingController notesController;
  final String amountLabel;
  final String notesLabel;
  final String? notesHint;
  final bool notesRequired;
  final String confirmLabel;
  final Color confirmColor;
  final double? expectedAmount;
  final bool showVariance;

  @override
  State<_CashShiftDialog> createState() => _CashShiftDialogState();
}

class _CashShiftDialogState extends State<_CashShiftDialog> {
  @override
  void initState() {
    super.initState();
    if (widget.showVariance) {
      widget.amountController.addListener(_onAmountChanged);
    }
  }

  @override
  void dispose() {
    if (widget.showVariance) {
      widget.amountController.removeListener(_onAmountChanged);
    }
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  double? get _variance {
    final expected = widget.expectedAmount;
    if (expected == null) return null;
    final counted = double.tryParse(widget.amountController.text.trim());
    if (counted == null) return null;
    return counted - expected;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width * 0.42).clamp(360.0, 460.0);
    final variance = _variance;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (widget.summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.summary.length; i++) ...[
                          if (i > 0)
                            const VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Color(0xFFE2E8F0),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.summary[i].label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.summary[i].value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: widget.summary[i].emphasize
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: widget.summary[i].color ??
                                          AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: widget.amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.amountLabel,
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.confirmColor, width: 1.5),
                      ),
                    ),
                  ),
                  if (widget.showVariance && variance != null) ...[
                    const SizedBox(height: 10),
                    _VarianceBanner(variance: variance),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: widget.notesController,
                    maxLines: widget.notesRequired ? 2 : 1,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                    decoration: InputDecoration(
                      labelText: widget.notesLabel,
                      hintText: widget.notesHint,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.confirmColor, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.confirmColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VarianceBanner extends StatelessWidget {
  const _VarianceBanner({required this.variance});

  final double variance;

  @override
  Widget build(BuildContext context) {
    final matched = variance.abs() < 0.005;
    final over = variance > 0;
    final color = matched
        ? AppTheme.accent
        : (over ? AppTheme.warning : AppTheme.danger);
    final label = matched
        ? 'Counted amount matches expected'
        : (over
            ? 'Over by ₹${variance.toStringAsFixed(2)}'
            : 'Short by ₹${(-variance).toStringAsFixed(2)}');
    final icon = matched
        ? Icons.check_circle_rounded
        : (over ? Icons.trending_up_rounded : Icons.trending_down_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            '${over && !matched ? '+' : ''}${variance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
