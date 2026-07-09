import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/emr.dart';

class VisitRecordCard extends StatelessWidget {
  const VisitRecordCard({
    super.key,
    required this.visit,
    required this.onTap,
    required this.statusColor,
  });

  final PetVisit visit;
  final VoidCallback onTap;
  final Color statusColor;

  static String statusLabel(String status) {
    switch (status) {
      case 'bill_on_hold':
        return 'On hold';
      case 'open':
        return 'Open';
      case 'completed':
        return 'Completed';
      case 'billed':
        return 'Billed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = statusLabel(visit.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4, color: statusColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pets_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                visit.visitNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            _StatusBadge(label: label, color: statusColor),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _DetailField(
                                    icon: Icons.pets_outlined,
                                    label: 'Pet',
                                    value: visit.pet?.name ?? '—',
                                  ),
                                  const SizedBox(height: 8),
                                  _DetailField(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Doctor',
                                    value: visit.doctor?.name ?? '—',
                                  ),
                                  const SizedBox(height: 8),
                                  _DetailField(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Date',
                                    value: visit.visitDate,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  _DetailField(
                                    icon: Icons.medical_services_outlined,
                                    label: 'Type',
                                    value: visit.visitType,
                                  ),
                                  const SizedBox(height: 8),
                                  _DetailField(
                                    icon: Icons.flag_outlined,
                                    label: 'Status',
                                    value: label.toLowerCase(),
                                    valueColor: statusColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
