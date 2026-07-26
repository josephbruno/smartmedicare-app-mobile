import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/emr.dart';
import 'widgets/appointment_week_calendar.dart';

class PatientAppointmentListScreen extends StatefulWidget {
  const PatientAppointmentListScreen({super.key});

  @override
  State<PatientAppointmentListScreen> createState() => _PatientAppointmentListScreenState();
}

class _PatientAppointmentListScreenState extends State<PatientAppointmentListScreen> {
  bool _calendarView = false;
  String _statusFilter = 'all';
  final _search = TextEditingController();
  DateTime _weekStartDate = DateTime(
    mondayOfWeek(DateTime.now()).year,
    mondayOfWeek(DateTime.now()).month,
    mondayOfWeek(DateTime.now()).day,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openAppointment(PatientAppointment a) {
    if (a.visitId != null) {
      context.push('/emr/visits/${a.visitId}');
    } else {
      context.push('/emr/appointments/${a.id}/edit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate =
        context.watch<AuthSession>().hasPermission(AppPermissions.patientAppointmentsCreate);
    final desktop = useWebLikeShell(context);
    final search = _search.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    if (desktop)
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('List'), icon: Icon(Icons.list)),
                          ButtonSegment(value: true, label: Text('Week'), icon: Icon(Icons.calendar_view_week)),
                        ],
                        selected: {_calendarView},
                        onSelectionChanged: (s) => setState(() => _calendarView = s.first),
                      ),
                    const Spacer(),
                    if (!_calendarView)
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search…',
                            isDense: true,
                            prefixIcon: Icon(Icons.search, size: 20),
                          ),
                          onSubmitted: (_) => setState(() {}),
                        ),
                      ),
                    if (canCreate) ...[
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => context.push('/emr/appointments/new'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New appointment'),
                      ),
                    ],
                  ],
                ),
                if (!_calendarView) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled']
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(s == 'all' ? 'All' : s.replaceAll('_', ' ')),
                                selected: _statusFilter == s,
                                onSelected: (_) => setState(() => _statusFilter = s),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _calendarView
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppointmentWeekCalendar(
                      weekStart: _weekStartDate,
                      onWeekChanged: (d) => setState(() {
                        _weekStartDate = DateTime(d.year, d.month, d.day);
                      }),
                      onAppointmentTap: _openAppointment,
                    ),
                  )
                : AppPaginatedTable<PatientAppointment>(
                    key: ValueKey('$_statusFilter-$search'),
                    loadPage: ({required page, required perPage}) =>
                        services.emr.listAppointmentsPaginated(
                          page: page,
                          perPage: perPage,
                          status: _statusFilter == 'all' ? null : _statusFilter,
                          search: search.length >= 2 ? search : null,
                        ),
                    onRowTap: _openAppointment,
                    columns: const [
                      TableColumnDef(label: 'Appt #', flex: 1, cellBuilder: _numberCell),
                      TableColumnDef(label: 'Pet', flex: 1.2, cellBuilder: _petCell),
                      TableColumnDef(label: 'Owner', flex: 1.3, cellBuilder: _ownerCell),
                      TableColumnDef(label: 'Doctor', flex: 1.2, cellBuilder: _doctorCell),
                      TableColumnDef(label: 'Date', flex: 1, cellBuilder: _dateCell),
                      TableColumnDef(label: 'Time', flex: 0.8, cellBuilder: _timeCell),
                      TableColumnDef(label: 'Status', flex: 0.9, align: TextAlign.center, cellBuilder: _statusCell),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _numberCell(BuildContext context, PatientAppointment a) => Text(
        a.appointmentNumber ?? '#${a.id}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _petCell(BuildContext context, PatientAppointment a) =>
      Text(a.pet?.name ?? '—');

  static Widget _ownerCell(BuildContext context, PatientAppointment a) =>
      Text(a.customer?.name ?? '—');

  static Widget _doctorCell(BuildContext context, PatientAppointment a) =>
      Text(a.doctor?.name ?? '—');

  static Widget _dateCell(BuildContext context, PatientAppointment a) =>
      Text(a.displayDate);

  static Widget _timeCell(BuildContext context, PatientAppointment a) =>
      Text(a.displayTime);

  static Widget _statusCell(BuildContext context, PatientAppointment a) => Text(
        a.status,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      );
}
