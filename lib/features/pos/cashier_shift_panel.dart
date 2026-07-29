import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/messaging/app_messenger.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/cashier_cash_session.dart';

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
    this.compact = false,
  });

  final CashierCashSession? session;
  final CashierDayStatus? dayStatus;
  final bool dayClosed;
  final bool loading;
  final Future<void> Function() onRefresh;
  final CashierSuggestedOpening? suggestedOpening;
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

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: open
              ? AppTheme.accent.withValues(alpha: 0.25)
              : (dayClosed ? const Color(0xFFE2E8F0) : const Color(0xFFFED7AA)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          open
                              ? Icons.account_balance_wallet_rounded
                              : (dayClosed
                                  ? Icons.lock_clock_rounded
                                  : Icons.play_circle_filled_rounded),
                          size: compact ? 18 : 20,
                          color: open
                              ? AppTheme.accent
                              : (dayClosed ? AppTheme.textSecondary : AppTheme.warning),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            open
                                ? 'Shift open · Amount in hand'
                                : (dayClosed ? 'Day closed' : 'Shift not started'),
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      open
                          ? '₹${session!.amountInHand.toStringAsFixed(2)}'
                          : (dayClosed
                              ? 'No new shifts today'
                              : (suggestedOpening?.hasSuggestion == true
                                  ? 'Available ₹${suggestedOpening!.amount!.toStringAsFixed(2)}'
                                  : 'Enter opening cash to begin')),
                      style: TextStyle(
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (!open && !dayClosed && suggestedOpening?.label != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          suggestedOpening!.label!,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    if (open)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Opening ₹${session!.openingAmount.toStringAsFixed(0)}'
                          ' · Cash in ₹${session!.cashCollected.toStringAsFixed(0)}'
                          '${session!.cashOutTotal > 0 ? ' · Taken ₹${session!.cashOutTotal.toStringAsFixed(0)}' : ''}',
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      tooltip: 'Refresh cash',
                      onPressed: () => onRefresh(),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppTheme.primary.withValues(alpha: 0.85),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (!open && !dayClosed) ...[
                    const SizedBox(height: 4),
                    const _ShiftPanelIllustration(),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (!open && !dayClosed && canStart)
                FilledButton.icon(
                  onPressed: loading ? null : () => _startShift(context),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Start Shift'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 14 : 16,
                      vertical: compact ? 10 : 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              if (open && canMove)
                OutlinedButton.icon(
                  onPressed: loading ? null : () => _takeFromDrawer(context),
                  icon: const Icon(Icons.money_off_csred_rounded, size: 18),
                  label: const Text('Take from drawer'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                ),
              if (open && canEnd)
                FilledButton.tonalIcon(
                  onPressed: loading ? null : () => _endShift(context),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('End shift'),
                ),
              if (canDayClose)
                OutlinedButton.icon(
                  onPressed: loading ? null : () => _showDayClose(context),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(dayClosed ? 'Day Status' : 'Day Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.4),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 14 : 16,
                      vertical: compact ? 10 : 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startShift(BuildContext context) async {
    final suggestion = suggestedOpening;
    final prefill = suggestion?.amount;
    final amountCtrl = TextEditingController(
      text: prefill != null ? prefill.toStringAsFixed(2) : '',
    );
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the cash amount currently in hand (opening float).',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (suggestion != null &&
                (suggestion.previousShiftAmount != null ||
                    suggestion.lastDayCloseAmount != null)) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available cash reference',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (suggestion.previousShiftAmount != null)
                      Text(
                        'Previous shift: ₹${suggestion.previousShiftAmount!.toStringAsFixed(2)}'
                        '${suggestion.previousShiftDate != null ? ' · ${suggestion.previousShiftDate}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    if (suggestion.lastDayCloseAmount != null) ...[
                      if (suggestion.previousShiftAmount != null) const SizedBox(height: 4),
                      Text(
                        'Last day close: ₹${suggestion.lastDayCloseAmount!.toStringAsFixed(2)}'
                        '${suggestion.lastDayCloseDate != null ? ' · ${suggestion.lastDayCloseDate}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if ((suggestion.lastDayCloseNotes ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            suggestion.lastDayCloseNotes!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                    if (suggestion.hasSuggestion) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Opening field prefilled with ₹${suggestion.amount!.toStringAsFixed(2)}'
                        '${suggestion.label != null ? ' (${suggestion.label})' : ''}. Edit if needed.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Opening amount in hand (₹)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
        ],
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expected in hand: ₹${session.amountInHand.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Opening ₹${session.openingAmount.toStringAsFixed(2)}'
              ' + cash ₹${session.cashCollected.toStringAsFixed(2)}'
              '${session.cashInTotal > 0 ? ' + in ₹${session.cashInTotal.toStringAsFixed(2)}' : ''}'
              '${session.cashOutTotal > 0 ? ' − taken ₹${session.cashOutTotal.toStringAsFixed(2)}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Counted amount in hand (₹)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End shift')),
        ],
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
      builder: (ctx) => AlertDialog(
        title: const Text('Take cash from drawer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'In hand now: ₹${session.amountInHand.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Logged against you for this branch. Notes are required.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount taken (₹)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (required)',
                hintText: 'e.g. Bank deposit / Owner handover',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm take'),
          ),
        ],
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

/// Compact decorative graphic for the idle shift card (receipt + coins).
class _ShiftPanelIllustration extends StatelessWidget {
  const _ShiftPanelIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 4,
            top: 2,
            child: Icon(Icons.auto_awesome, size: 12, color: AppTheme.warning.withValues(alpha: 0.7)),
          ),
          Positioned(
            left: 8,
            top: 0,
            child: Container(
              width: 40,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    width: 22,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: List.generate(
                          3,
                          (i) => Container(
                            margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                            height: 2,
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Row(
              children: [
                _coin(16),
                Transform.translate(
                  offset: const Offset(-6, -4),
                  child: _coin(14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coin(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
        ),
        border: Border.all(color: const Color(0xFFD97706), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warning.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
