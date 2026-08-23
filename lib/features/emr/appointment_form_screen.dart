import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import '../../core/widgets/app_dropdown.dart';
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key, this.appointmentId});

  final int? appointmentId;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _complaint = TextEditingController();
  final _notes = TextEditingController();

  PetSearchResult? _selectedPet;
  DoctorLite? _selectedDoctor;
  List<DoctorLite> _doctors = [];
  List<PetSearchResult> _petResults = [];

  String _appointmentType = 'consultation';
  String _status = 'scheduled';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int _duration = 30;

  bool _loading = false;
  bool _saving = false;
  bool _searchingPets = false;

  bool get _isEdit => widget.appointmentId != null;

  static const _types = [
    'consultation',
    'followup',
    'surgery',
    'wellness',
    'emergency',
    'vaccination',
    'deworming',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final auth = context.read<AuthSession>();
    try {
      final isAdmin =
          auth.hasRole(AppRoles.superAdmin) || auth.hasRole(AppRoles.branchManager);

      if (_isEdit) {
        final appt =
            await context.read<AppServices>().emr.getAppointment(widget.appointmentId!);
        _applyAppointment(appt);
      }

      if (isAdmin) {
        _doctors = [];
        _selectedDoctor = null;
      } else {
        _doctors = await context.read<AppServices>().emr.listDoctors();
        final user = auth.user;
        if (user != null && auth.hasRole(AppRoles.doctor)) {
          final fromList = _doctors.where((d) => d.id == user.id).firstOrNull;
          final me = fromList ??
              DoctorLite(
                id: user.id,
                name: user.name.trim().isNotEmpty ? user.name : 'Doctor #${user.id}',
              );
          _doctors = [me];
          _selectedDoctor = me;
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyAppointment(PatientAppointment appt) {
    _selectedPet = appt.pet ??
        PetSearchResult(
          id: appt.petId,
          customerId: appt.customerId,
          name: 'Pet #${appt.petId}',
          customerName: appt.customer?.name,
        );
    if (appt.doctor != null) _selectedDoctor = appt.doctor;
    _appointmentType = appt.appointmentType;
    _status = appt.status;
    _date = DateTime.tryParse(appt.appointmentDate) ?? DateTime.now();
    if (appt.appointmentTime.length >= 5) {
      final parts = appt.appointmentTime.substring(0, 5).split(':');
      _time = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    _complaint.text = appt.chiefComplaint ?? '';
    _notes.text = appt.notes ?? '';
  }

  Future<void> _searchPets(String q) async {
    if (q.length < 2) {
      setState(() => _petResults = []);
      return;
    }
    setState(() => _searchingPets = true);
    try {
      final results = await context.read<AppServices>().emr.searchPets(q);
      if (mounted) setState(() => _petResults = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searchingPets = false);
    }
  }

  Future<void> _save() async {
    if (_selectedPet == null) {
      AppMessenger.show(context,
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }

    setState(() => _saving = true);
    final emr = context.read<AppServices>().emr;
    final timeStr =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    final body = <String, dynamic>{
      'pet_id': _selectedPet!.id,
      'customer_id': _selectedPet!.customerId,
      if (_selectedDoctor != null) 'doctor_id': _selectedDoctor!.id,
      'appointment_type': _appointmentType,
      'appointment_date':
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
      'appointment_time': timeStr,
      'duration_minutes': _duration,
      'status': _status,
      if (_complaint.text.trim().isNotEmpty) 'chief_complaint': _complaint.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };

    try {
      if (_isEdit) {
        await emr.updateAppointment(widget.appointmentId!, body);
      } else {
        await emr.createAppointment(body);
      }
      if (mounted) {
        AppMessenger.show(context,
          SnackBar(content: Text(_isEdit ? 'Appointment updated' : 'Appointment created')),
        );
        context.go('/emr/appointments');
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _complaint.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_isEdit ? 'Edit appointment' : 'New appointment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedPet == null) ...[
            TextField(
              decoration: InputDecoration(
                labelText: 'Search patient',
                suffixIcon: _searchingPets
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
              ),
              onChanged: _searchPets,
            ),
            ..._petResults.map(
              (p) => ListTile(
                title: Text(p.displayLabel),
                onTap: () => setState(() {
                  _selectedPet = p;
                  _petResults = [];
                }),
              ),
            ),
          ] else
            Card(
              color: AppTheme.primary.withValues(alpha: 0.06),
              child: ListTile(
                leading: const Icon(Icons.pets, color: AppTheme.primary),
                title: Text(_selectedPet!.name),
                subtitle: Text(_selectedPet!.displayLabel),
                trailing: _isEdit
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _selectedPet = null),
                      ),
              ),
            ),
          const SizedBox(height: 12),
          AppDropdownButtonFormField<String>(
            value: _appointmentType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Appointment type'),
            items: _types
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _appointmentType = v ?? 'consultation'),
          ),
          if (_isEdit) ...[
            const SizedBox(height: 12),
            AppDropdownButtonFormField<String>(
              value: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'no_show', child: Text('No show')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
            ),
          ],
          const SizedBox(height: 12),
          if (_doctors.isNotEmpty || _selectedDoctor != null)
            Builder(
              builder: (context) {
                final auth = context.watch<AuthSession>();
                final isAdmin = auth.hasRole(AppRoles.superAdmin) ||
                    auth.hasRole(AppRoles.branchManager);
                if (isAdmin) return const SizedBox.shrink();
                final locked = auth.hasRole(AppRoles.doctor) &&
                    auth.user != null &&
                    _selectedDoctor?.id == auth.user!.id &&
                    _doctors.length == 1;
                if (locked) {
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Doctor',
                      suffixIcon: Icon(Icons.lock_outline, size: 18),
                    ),
                    child: Text(
                      _selectedDoctor?.name ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                }
                return AppDropdownButtonFormField<int>(
                  value: _selectedDoctor?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Doctor'),
                  selectedItemBuilder: (context) => [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('— None —', overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                    ..._doctors.map(
                      (d) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          d.displayLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    ..._doctors.map(
                      (d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(
                          d.displayLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (id) => setState(() {
                    _selectedDoctor =
                        id == null ? null : _doctors.firstWhere((d) => d.id == id);
                  }),
                );
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    '${_date.year.toString().padLeft(4, '0')}-'
                    '${_date.month.toString().padLeft(2, '0')}-'
                    '${_date.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _complaint,
            decoration: const InputDecoration(labelText: 'Chief complaint'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? 'Update' : 'Create appointment'),
          ),
        ],
      ),
    );
  }
}
