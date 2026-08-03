import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';

class ReminderDashboardScreen extends StatefulWidget {
  const ReminderDashboardScreen({super.key});

  @override
  State<ReminderDashboardScreen> createState() =>
      _ReminderDashboardScreenState();
}

class _ReminderDashboardScreenState extends State<ReminderDashboardScreen> {
  late Future<ReminderSummary> _summaryFuture;
  late Future<List<PetReminder>> _dueFuture;
  final _search = TextEditingController();
  String _typeFilter = 'all';
  String _statusFilter = 'pending';

  static const _types = <(String, String)>[
    ('all', 'All types'),
    ('vaccination', 'Vaccination'),
    ('deworming', 'Deworming'),
    ('followup', 'Follow-up'),
  ];

  static const _statuses = <(String, String)>[
    ('pending', 'Pending'),
    ('sent', 'Sent'),
    ('all', 'All status'),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final emr = context.read<AppServices>().emr;
    final query = <String, dynamic>{'per_page': 50};
    if (_statusFilter != 'all') query['status'] = _statusFilter;
    if (_typeFilter != 'all') query['type'] = _typeFilter;
    _dueFuture = emr.dueReminders(query: query);
    _summaryFuture = _dueFuture.then((_) => emr.reminderDashboard());
  }

  void _applyFilters({String? type, String? status}) {
    setState(() {
      if (type != null) _typeFilter = type;
      if (status != null) _statusFilter = status;
      _reload();
    });
  }

  List<PetReminder> _filterLocally(List<PetReminder> items) {
    final q = _search.text.trim().toLowerCase();
    if (q.length <= 2) return items;
    return items.where((r) {
      final pet = r.pet?.name.toLowerCase() ?? '';
      final owner = r.customer?.name.toLowerCase() ?? '';
      final title = r.title.toLowerCase();
      final message = r.message.toLowerCase();
      final phone = r.customer?.phone?.toLowerCase() ?? '';
      return pet.contains(q) ||
          owner.contains(q) ||
          title.contains(q) ||
          message.contains(q) ||
          phone.contains(q);
    }).toList();
  }

  Future<void> _sendNow(PetReminder r) async {
    try {
      await context.read<AppServices>().emr.sendReminderNow(r.id);
      if (mounted) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Reminder sent')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _dismiss(PetReminder r) async {
    try {
      await context.read<AppServices>().emr.dismissReminder(r.id);
      if (mounted) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Reminder dismissed')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = _search.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              'Reminders',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Vaccination, deworming, and follow-up alerts',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<ReminderSummary>(
              future: _summaryFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 96,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snap.hasError) {
                  return _ErrorBanner(message: '${snap.error}');
                }
                final s = snap.data!;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = 12.0;
                    final cols = constraints.maxWidth >= 1100
                        ? 5
                        : constraints.maxWidth >= 760
                            ? 3
                            : 2;
                    final w =
                        (constraints.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: w,
                          child: _SummaryCard(
                            label: 'Vaccination',
                            count: s.vaccinationDue,
                            caption: 'Due',
                            icon: Icons.vaccines_outlined,
                            color: const Color(0xFF3B82F6),
                            selected: _typeFilter == 'vaccination',
                            onTap: () => _applyFilters(
                              type: _typeFilter == 'vaccination'
                                  ? 'all'
                                  : 'vaccination',
                              status: 'pending',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: _SummaryCard(
                            label: 'Deworming',
                            count: s.dewormingDue,
                            caption: 'Due',
                            icon: Icons.medication_outlined,
                            color: const Color(0xFF8B5CF6),
                            selected: _typeFilter == 'deworming',
                            onTap: () => _applyFilters(
                              type: _typeFilter == 'deworming'
                                  ? 'all'
                                  : 'deworming',
                              status: 'pending',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: _SummaryCard(
                            label: 'Follow-up',
                            count: s.followupDue,
                            caption: 'Due',
                            icon: Icons.event_note_outlined,
                            color: const Color(0xFF38BDF8),
                            selected: _typeFilter == 'followup',
                            onTap: () => _applyFilters(
                              type: _typeFilter == 'followup'
                                  ? 'all'
                                  : 'followup',
                              status: 'pending',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: _SummaryCard(
                            label: 'Overdue',
                            count: s.overdue,
                            caption: 'Due',
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFEF4444),
                            selected: false,
                            onTap: () => _applyFilters(
                              type: 'all',
                              status: 'pending',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: _SummaryCard(
                            label: 'Sent today',
                            count: s.sentToday,
                            caption: 'Today',
                            icon: Icons.mark_email_read_outlined,
                            color: const Color(0xFF10B981),
                            selected: _statusFilter == 'sent',
                            onTap: () =>
                                _applyFilters(type: 'all', status: 'sent'),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            _FilterBar(
              searchController: _search,
              searchText: search,
              typeFilter: _typeFilter,
              statusFilter: _statusFilter,
              types: _types,
              statuses: _statuses,
              onSearchChanged: () => setState(() {}),
              onTypeChanged: (v) => _applyFilters(type: v),
              onStatusChanged: (v) => _applyFilters(status: v),
              onApply: () => setState(_reload),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Text(
                  'Due reminders',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                FutureBuilder<List<PetReminder>>(
                  future: _dueFuture,
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final count = _filterLocally(snap.data!).length;
                    return Text(
                      '$count shown',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<PetReminder>>(
              future: _dueFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snap.hasError) {
                  return _ErrorBanner(message: '${snap.error}');
                }
                final items = _filterLocally(snap.data ?? []);
                if (items.isEmpty) {
                  return _EmptyState(
                    searching: search.length > 2,
                    statusFilter: _statusFilter,
                  );
                }
                return Column(
                  children: [
                    for (final r in items) ...[
                      _ReminderCard(
                        reminder: r,
                        onSend:
                            r.status == 'pending' ? () => _sendNow(r) : null,
                        onDismiss:
                            r.status == 'pending' ? () => _dismiss(r) : null,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.searchText,
    required this.typeFilter,
    required this.statusFilter,
    required this.types,
    required this.statuses,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onApply,
  });

  final TextEditingController searchController;
  final String searchText;
  final String typeFilter;
  final String statusFilter;
  final List<(String, String)> types;
  final List<(String, String)> statuses;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    const fieldStyle = TextStyle(fontSize: 13, height: 1.2);
    const hintStyle = TextStyle(fontSize: 13, color: AppTheme.textSecondary);

    final searchField = TextField(
      controller: searchController,
      style: fieldStyle,
      decoration: InputDecoration(
        hintText: 'Search pet, owner, or phone number…',
        hintStyle: hintStyle,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        helperText: searchText.isNotEmpty && searchText.length <= 2
            ? 'Type more than 2 characters to filter'
            : null,
        helperStyle: const TextStyle(fontSize: 11),
        helperMaxLines: 1,
        suffixIcon: searchText.isNotEmpty
            ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      onChanged: (_) => onSearchChanged(),
    );

    final typeDropdown = DropdownButtonFormField<String>(
      value: typeFilter,
      isExpanded: true,
      isDense: true,
      style: fieldStyle.copyWith(color: AppTheme.textPrimary),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      decoration: _dropdownDecoration('Type'),
      items: [
        for (final (value, label) in types)
          DropdownMenuItem(
            value: value,
            child: Text(label, style: fieldStyle, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onTypeChanged(v);
      },
    );

    final statusDropdown = DropdownButtonFormField<String>(
      value: statusFilter,
      isExpanded: true,
      isDense: true,
      style: fieldStyle.copyWith(color: AppTheme.textPrimary),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      decoration: _dropdownDecoration('Status'),
      items: [
        for (final (value, label) in statuses)
          DropdownMenuItem(
            value: value,
            child: Text(label, style: fieldStyle, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onStatusChanged(v);
      },
    );

    final applyBtn = SizedBox(
      height: 40,
      width: 42,
      child: FilledButton(
        onPressed: onApply,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: const Icon(Icons.filter_alt_rounded, size: 18),
      ),
    );

    // Desktop text scaling can clip dense dropdown labels — keep filter bar compact.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1).clamp(0.9, 1.05),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: searchField),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: typeDropdown),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: statusDropdown),
                  const SizedBox(width: 10),
                  applyBtn,
                ],
              )
            : Column(
                children: [
                  searchField,
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: typeDropdown),
                      const SizedBox(width: 10),
                      Expanded(child: statusDropdown),
                      const SizedBox(width: 10),
                      applyBtn,
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      floatingLabelStyle: const TextStyle(fontSize: 12, color: AppTheme.primary),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final int count;
  final String caption;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$count',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1.05,
                            ),
                          ),
                          TextSpan(
                            text: '  $caption',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    this.onSend,
    this.onDismiss,
  });

  final PetReminder reminder;
  final VoidCallback? onSend;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final typeColor = _colorForType(reminder.reminderType);
    final pet = reminder.pet?.name ?? 'Pet';
    final owner = reminder.customer?.name;
    final phone = reminder.customer?.phone;
    final meta = [
      pet,
      if (owner != null && owner.isNotEmpty) owner,
      if (phone != null && phone.isNotEmpty) phone,
    ].join(' · ');
    final dueLabel = _formatDue(reminder.dueDate);
    final createdLabel = _formatCreated(reminder.createdAt);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final left = Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconForType(reminder.reminderType),
              color: typeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Due on $dueLabel',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (reminder.message.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    reminder.message,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                if (!wide) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusPill(status: reminder.status),
                      if (createdLabel != null)
                        Text(
                          'Created on $createdLabel',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final rightMeta = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _StatusPill(status: reminder.status),
        if (createdLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            'Created on $createdLabel',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onSend != null)
          FilledButton.icon(
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Send now', style: TextStyle(fontSize: 12.5)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        if (onSend != null && onDismiss != null) const SizedBox(height: 6),
        if (onDismiss != null)
          OutlinedButton.icon(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 14),
            label: const Text('Dismiss', style: TextStyle(fontSize: 12.5)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              minimumSize: const Size(120, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(width: 16),
                SizedBox(width: 160, child: rightMeta),
                const SizedBox(width: 16),
                SizedBox(width: 140, child: actions),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [left]),
                if (onSend != null || onDismiss != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onSend != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onSend,
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Send now'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      if (onSend != null && onDismiss != null)
                        const SizedBox(width: 8),
                      if (onDismiss != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onDismiss,
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Dismiss'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  static String _formatDue(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String? _formatCreated(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('dd MMM yyyy hh:mm a').format(dt.toLocal());
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'vaccination':
        return Icons.vaccines_outlined;
      case 'deworming':
        return Icons.medication_outlined;
      case 'followup':
      case 'surgery_followup':
        return Icons.event_note_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color _colorForType(String type) {
    switch (type) {
      case 'vaccination':
        return const Color(0xFF3B82F6);
      case 'deworming':
        return const Color(0xFF8B5CF6);
      case 'followup':
      case 'surgery_followup':
        return const Color(0xFF38BDF8);
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    final color = pending ? const Color(0xFFF59E0B) : AppTheme.accent;
    final label = pending
        ? 'Pending'
        : status.isEmpty
            ? 'Unknown'
            : '${status[0].toUpperCase()}${status.substring(1)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.statusFilter,
  });

  final bool searching;
  final String statusFilter;

  @override
  Widget build(BuildContext context) {
    final title = searching
        ? 'No reminders match your search'
        : statusFilter == 'pending'
            ? 'No pending reminders'
            : 'No reminders found';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            searching ? Icons.search_off_rounded : Icons.task_alt_rounded,
            size: 36,
            color: AppTheme.textSecondary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
      ),
      child: Text(message, style: const TextStyle(color: AppTheme.danger)),
    );
  }
}
