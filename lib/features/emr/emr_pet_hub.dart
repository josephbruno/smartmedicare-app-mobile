import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';

/// Quick navigation to pet-centric EMR modules (matches web timeline hub links).
class EmrPetHub extends StatelessWidget {
  const EmrPetHub({super.key, required this.petId, this.petName});

  final int petId;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final links = <_HubLink>[
      if (auth.hasPermission('emr.visits.view'))
        _HubLink('Timeline', Icons.timeline_outlined, '/emr/pets/$petId/timeline'),
      if (auth.hasPermission('emr.deworming.view'))
        _HubLink('Deworming', Icons.medication_outlined, '/emr/pets/$petId/deworming'),
      if (auth.hasPermission('emr.surgeries.view'))
        _HubLink('Surgeries', Icons.healing_outlined, '/emr/pets/$petId/surgeries'),
      if (auth.hasPermission('emr.lab_reports.view'))
        _HubLink('Lab reports', Icons.biotech_outlined, '/emr/pets/$petId/lab-reports'),
      if (auth.hasPermission('emr.documents.view'))
        _HubLink('Documents', Icons.folder_outlined, '/emr/pets/$petId/documents'),
      if (auth.hasPermission('emr.visits.create'))
        _HubLink('New visit', Icons.add_circle_outline, '/emr/visits/new?pet_id=$petId'),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (petName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              petName!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: links
              .map(
                (l) => ActionChip(
                  avatar: Icon(l.icon, size: 18, color: AppTheme.primary),
                  label: Text(l.label),
                  onPressed: () => context.push(l.path),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _HubLink {
  const _HubLink(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
