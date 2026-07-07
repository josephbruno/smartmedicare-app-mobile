import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/emr.dart';

/// Week grid of appointments for desktop (no extra package).
class AppointmentWeekCalendar extends StatefulWidget {
  const AppointmentWeekCalendar({
    super.key,
    required this.weekStart,
    required this.onWeekChanged,
    required this.onAppointmentTap,
  });

  final DateTime weekStart;
  final ValueChanged<DateTime> onWeekChanged;
  final ValueChanged<PatientAppointment> onAppointmentTap;

  @override
  State<AppointmentWeekCalendar> createState() => _AppointmentWeekCalendarState();
}

class _AppointmentWeekCalendarState extends State<AppointmentWeekCalendar> {
  late Future<List<PatientAppointment>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AppointmentWeekCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) _load();
  }

  void _load() {
    final start = widget.weekStart;
    final end = start.add(const Duration(days: 6));
    final fmt = DateFormat('yyyy-MM-dd');
    _future = context.read<AppServices>().emr.listAppointmentsPaginated(
          page: 1,
          perPage: 100,
          dateFrom: fmt.format(start),
          dateTo: fmt.format(end),
        ).then((r) => r.items);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => widget.weekStart.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => widget.onWeekChanged(
                widget.weekStart.subtract(const Duration(days: 7)),
              ),
            ),
            Expanded(
              child: Text(
                '${DateFormat('d MMM').format(days.first)} – ${DateFormat('d MMM yyyy').format(days.last)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => widget.onWeekChanged(
                widget.weekStart.add(const Duration(days: 7)),
              ),
            ),
            TextButton(
              onPressed: () {
                final now = DateTime.now();
                final monday = now.subtract(Duration(days: now.weekday - 1));
                widget.onWeekChanged(DateTime(monday.year, monday.month, monday.day));
              },
              child: const Text('Today'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<PatientAppointment>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snap.data!;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: days.map((day) {
                  final dayStr = DateFormat('yyyy-MM-dd').format(day);
                  final dayAppts = all.where((a) => a.appointmentDate == dayStr).toList()
                    ..sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isToday(day)
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('EEE').format(day),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isToday(day) ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isToday(day) ? AppTheme.primary : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView(
                              children: dayAppts.map((a) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    onTap: () => widget.onAppointmentTap(a),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.displayTime.length >= 5
                                                ? a.displayTime.substring(0, 5)
                                                : a.displayTime,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            a.pet?.name ?? 'Pet',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            a.status,
                                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

DateTime mondayOfWeek(DateTime date) {
  return date.subtract(Duration(days: date.weekday - 1));
}
