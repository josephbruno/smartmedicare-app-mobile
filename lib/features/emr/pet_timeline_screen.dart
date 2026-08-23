import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
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
  String? _typeFilter;

  static const _allTypes = [
    'visit',
    'vaccination',
    'deworming',
    'surgery',
    'lab_report',
    'document',
    'note',
  ];

  static const _filterDec = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final query = <String, dynamic>{};
    if (_typeFilter != null) {
      query['types'] = _typeFilter;
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

  Widget _typeFilterDropdown() {
    return SizedBox(
      width: 200,
      child: AppDropdownButtonFormField<String?>(
        value: _typeFilter,
        isDense: true,
        decoration: _filterDec.copyWith(labelText: 'Type'),
        items: [
          const DropdownMenuItem(value: null, child: Text('All types')),
          for (final t in _allTypes)
            DropdownMenuItem(
              value: t,
              child: Text(t.replaceAll('_', ' ')),
            ),
        ],
        onChanged: (v) {
          setState(() {
            _typeFilter = v;
            _reload();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canViewHub = auth.hasPermission('emr.visits.view');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Pet timeline')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: canViewHub
                ? EmrPetHub(
                    petId: widget.petId,
                    trailing: _typeFilterDropdown(),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _typeFilterDropdown(),
                  ),
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
