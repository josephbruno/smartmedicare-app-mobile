import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/app_config.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/emr.dart';
import '../visit_billing_queue_notifier.dart';

/// Desktop panel: visits waiting for cashier billing.
class VisitBillingQueuePanel extends StatefulWidget {
  const VisitBillingQueuePanel({
    super.key,
    this.compact = false,
    this.maxHeight,
  });

  final bool compact;
  final double? maxHeight;

  @override
  State<VisitBillingQueuePanel> createState() => _VisitBillingQueuePanelState();
}

class _VisitBillingQueuePanelState extends State<VisitBillingQueuePanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePolling());
  }

  void _ensurePolling() {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('emr.visits.bill') &&
        !auth.hasPermission('emr.visits.view')) {
      return;
    }
    final queue = context.read<VisitBillingQueueNotifier>();
    queue.startPolling(context.read<AppServices>().emr);
  }

  void _billVisit(PetVisit visit) {
    if (AppConfig.isCashierPlatform && context.read<AuthSession>().hasPermission('emr.visits.bill')) {
      context.push('/pos?visit_id=${visit.id}');
      return;
    }
    context.push('/emr/visits/${visit.id}');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    if (!auth.hasPermission('emr.visits.bill') && !auth.hasPermission('emr.visits.view')) {
      return const SizedBox.shrink();
    }

    final queue = context.watch<VisitBillingQueueNotifier>();
    final visits = queue.readyForBilling;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long_outlined, size: widget.compact ? 16 : 18, color: AppTheme.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ready to bill',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: widget.compact ? 13 : 14,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (visits.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${visits.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                    fontSize: 12,
                  ),
                ),
              ),
            IconButton(
              icon: queue.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh queue',
              onPressed: queue.loading ? null : () => queue.refresh(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (queue.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(queue.error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
          ),
        const SizedBox(height: 8),
        if (visits.isEmpty && !queue.loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: widget.compact ? 8 : 16),
            child: Text(
              'No visits waiting for billing',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: widget.compact ? 12 : 13),
            ),
          )
        else
          ...visits.take(widget.compact ? 5 : 20).map((v) => _VisitQueueTile(
                visit: v,
                compact: widget.compact,
                onBill: () => _billVisit(v),
                canBill: auth.hasPermission('emr.visits.bill') && AppConfig.isCashierPlatform,
              )),
        if (visits.length > (widget.compact ? 5 : 20))
          TextButton(
            onPressed: () => context.push('/emr/visits'),
            child: Text('View all ${visits.length} visits'),
          ),
      ],
    );

    if (widget.maxHeight != null) {
      return Material(
        color: AppTheme.accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: widget.maxHeight,
            child: SingleChildScrollView(child: content),
          ),
        ),
      );
    }

    return Material(
      color: AppTheme.accent.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: content,
      ),
    );
  }
}

class _VisitQueueTile extends StatelessWidget {
  const _VisitQueueTile({
    required this.visit,
    required this.compact,
    required this.onBill,
    required this.canBill,
  });

  final PetVisit visit;
  final bool compact;
  final VoidCallback onBill;
  final bool canBill;

  @override
  Widget build(BuildContext context) {
    final petName = visit.pet?.name ?? 'Pet #${visit.petId}';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: canBill ? onBill : () => context.push('/emr/visits/${visit.id}'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 8 : 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 13 : 14,
                      ),
                    ),
                    Text(
                      '${visit.visitNumber} · ${visit.visitDate}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    if (visit.doctor != null)
                      Text(
                        'Dr. ${visit.doctor!.name}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (canBill)
                FilledButton.tonal(
                  onPressed: onBill,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, compact ? 32 : 36),
                    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                  ),
                  child: Text(compact ? 'Bill' : 'Bill at POS', style: const TextStyle(fontSize: 12)),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
