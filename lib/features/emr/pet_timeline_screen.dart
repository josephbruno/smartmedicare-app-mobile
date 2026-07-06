import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import 'emr_pet_hub.dart';

class PetTimelineScreen extends StatefulWidget {
  const PetTimelineScreen({super.key, required this.petId});

  final int petId;

  @override
  State<PetTimelineScreen> createState() => _PetTimelineScreenState();
}

class _PetTimelineScreenState extends State<PetTimelineScreen> {
  late Future<TimelineResponse> _future;
  final Set<String> _typeFilters = {};

  static const _allTypes = [
    'visit',
    'vaccination',
    'deworming',
    'surgery',
    'lab_report',
    'document',
    'note',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final query = <String, dynamic>{};
    if (_typeFilters.isNotEmpty) {
      query['types'] = _typeFilters.join(',');
    }
    _future = context.read<AppServices>().emr.getTimeline(widget.petId, query: query);
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'visit':
        return Icons.medical_services_outlined;
      case 'vaccination':
        return Icons.vaccines_outlined;
      case 'deworming':
        return Icons.medication_outlined;
      case 'surgery':
        return Icons.healing_outlined;
      case 'lab_report':
        return Icons.biotech_outlined;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.sticky_note_2_outlined;
    }
  }

  void _openEvent(TimelineEvent event) {
    final meta = event.id;
    switch (event.type) {
      case 'visit':
        final visitId = int.tryParse(meta.split('-').last);
        if (visitId != null) context.push('/emr/visits/$visitId');
        break;
      case 'deworming':
        context.push('/emr/pets/${widget.petId}/deworming');
        break;
      case 'surgery':
        context.push('/emr/pets/${widget.petId}/surgeries');
        break;
      case 'lab_report':
        context.push('/emr/pets/${widget.petId}/lab-reports');
        break;
      case 'document':
        context.push('/emr/pets/${widget.petId}/documents');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pet timeline')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: _allTypes.map((t) {
                final selected = _typeFilters.contains(t);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t.replaceAll('_', ' ')),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _typeFilters.remove(t);
                        } else {
                          _typeFilters.add(t);
                        }
                        _reload();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          if (auth.hasPermission('emr.visits.view'))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmrPetHub(petId: widget.petId),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: FutureBuilder<TimelineResponse>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return ListView(
                      children: [Center(child: Text('${snap.error}'))],
                    );
                  }
                  final data = snap.data!;
                  final events = data.timeline;
                  if (events.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No timeline events')),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      final e = events[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(_iconForType(e.type), color: AppTheme.primary),
                          title: Text(e.title),
                          subtitle: Text(
                            [e.date, e.subtitle, e.status]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                          ),
                          onTap: () => _openEvent(e),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
