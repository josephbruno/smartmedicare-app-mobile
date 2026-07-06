import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import 'quick_visit_sheet.dart';

class VisitListScreen extends StatefulWidget {
  const VisitListScreen({super.key});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  late Future<List<PetVisit>> _future;
  late Future<List<PatientAppointment>> _todayFuture;
  String _statusFilter = 'all';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final query = <String, dynamic>{'per_page': 50};
    if (_statusFilter != 'all') query['status'] = _statusFilter;
    if (_search.text.trim().length >= 2) query['search'] = _search.text.trim();
    _future = context.read<AppServices>().emr.listVisits(query: query);
    _todayFuture = context.read<AppServices>().emr.todayAppointments();
  }

  void _refresh() => setState(_load);

  Color _statusColor(String status) {
    switch (status) {
      case 'billed':
      case 'completed':
        return AppTheme.accent;
      case 'open':
        return AppTheme.primary;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AuthSession>().hasPermission('emr.visits.create');

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/emr/visits/new'),
              icon: const Icon(Icons.add),
              label: const Text('New visit'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Visit Records',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (canCreate)
                  OutlinedButton.icon(
                    onPressed: () => showQuickVisitSheet(context, onSaved: _refresh),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Quick visit'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search visits...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onSubmitted: (_) => setState(_load),
              onChanged: (v) {
                if (v.isEmpty || v.length >= 2) setState(_load);
              },
            ),
          ),
          FutureBuilder<List<PatientAppointment>>(
            future: _todayFuture,
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's appointments",
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: snap.data!.map((a) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.pets, size: 16),
                              label: Text('${a.pet?.name ?? 'Pet'} ${a.displayTime}'),
                              onPressed: canCreate
                                  ? () => context.push(
                                        '/emr/visits/new?appointment_id=${a.id}',
                                      )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (final s in ['all', 'open', 'billed', 'completed', 'cancelled'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(s == 'all' ? 'All' : s),
                      selected: _statusFilter == s,
                      onSelected: (_) {
                        setState(() {
                          _statusFilter = s;
                          _load();
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<PetVisit>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text('${snap.error}')),
                        ),
                      ],
                    );
                  }
                  final visits = snap.data ?? [];
                  if (visits.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No visits found')),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: visits.length,
                    itemBuilder: (context, i) {
                      final v = visits[i];
                      final diag = v.diagnoses?.isNotEmpty == true
                          ? v.diagnoses!.first.diagnosisName
                          : null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => context.push('/emr/visits/${v.id}'),
                          title: Text(
                            v.pet?.name ?? 'Pet #${v.petId}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              v.visitNumber,
                              v.visitDate,
                              v.visitType,
                              if (diag != null) diag,
                            ].join(' · '),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(v.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              v.status,
                              style: TextStyle(
                                color: _statusColor(v.status),
                                fontSize: 12,
                              ),
                            ),
                          ),
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
