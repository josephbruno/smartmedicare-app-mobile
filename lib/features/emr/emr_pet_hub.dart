import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import 'pet_visit_summary_screen.dart';

/// Quick navigation to pet-centric EMR modules (matches web timeline hub links).
class EmrPetHub extends StatelessWidget {
  const EmrPetHub({super.key, required this.petId, this.petName});

  final int petId;
  final String? petName;

  void _openVisitSummary(BuildContext context) {
    final router = GoRouter.of(context);
    // namedLocation throws when the route is missing (e.g. GoRouter built
    // before Visit summary was added and the app was only hot-reloaded).
    try {
      final loc = router.namedLocation(
        'PetVisitSummary',
        pathParameters: {'petId': '$petId'},
      );
      context.push(loc);
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PetVisitSummaryScreen(petId: petId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final links = <_HubLink>[
      if (auth.hasPermission('emr.visits.view'))
        _HubLink('Timeline', Icons.timeline_outlined, '/emr/pets/$petId/timeline'),
      if (auth.hasPermission('emr.visits.view'))
        _HubLink(
          'Visit summary',
          Icons.description_outlined,
          '/emr/pets/$petId/visit-summary',
          onTap: () => _openVisitSummary(context),
        ),
      if (auth.hasPermission('emr.deworming.view'))
        _HubLink('Deworming', Icons.medication_outlined, '/emr/pets/$petId/deworming'),
      if (auth.hasPermission('emr.surgeries.view'))
        _HubLink('Surgeries', Icons.healing_outlined, '/emr/pets/$petId/surgeries'),
      if (auth.hasPermission('emr.lab_reports.view'))
        _HubLink('Lab reports', Icons.biotech_outlined, '/emr/pets/$petId/lab-reports'),
      if (auth.hasPermission('emr.documents.view'))
        _HubLink('Documents', Icons.folder_outlined, '/emr/pets/$petId/documents'),
      if (auth.hasPermission('emr.visits.create'))
        _HubLink(
          'New visit',
          Icons.add_circle_outline,
          '/emr/visits/new?pet_id=$petId',
          primary: true,
        ),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    final title = petName != null && petName!.isNotEmpty
        ? 'More for $petName'
        : 'Pet records';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.apps_outlined, size: 17, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: links.map((l) {
              final onPressed = l.onTap ?? () => context.push(l.path);
              if (l.primary) {
                return FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(l.icon, size: 16),
                  label: Text(l.label),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
              return OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(l.icon, size: 16, color: AppTheme.primary),
                label: Text(l.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  backgroundColor: const Color(0xFFF8FAFC),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HubLink {
  const _HubLink(
    this.label,
    this.icon,
    this.path, {
    this.primary = false,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final String path;
  final bool primary;
  final VoidCallback? onTap;
}
