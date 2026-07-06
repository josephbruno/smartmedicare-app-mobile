import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/invoice.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  late Future<InvoiceListResult> _future;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().billing.list();
  }

  void _refresh() {
    setState(() {
      _future = context.read<AppServices>().billing.list();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppTheme.accent;
      case 'pending':
      case 'unpaid':
        return AppTheme.warning;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<InvoiceListResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Loading invoices...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                    const SizedBox(height: 16),
                    const Text('Failed to load invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
                  ],
                ),
              ),
            );
          }

          final result = snap.data!;
          final rawList = result.items;
          final summary = result.summary;

          final filteredList = rawList.where((inv) {
            if (_selectedFilter == 'all') return true;
            if (_selectedFilter == 'unpaid') return inv.isUnpaid;
            return inv.status.toLowerCase() == _selectedFilter;
          }).toList();

          return Column(
            children: [
              if (summary != null)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Total',
                          value: '₹${summary.totalAmount.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Paid',
                          value: '₹${summary.paidAmount.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Due',
                          value: '₹${summary.dueAmount.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                ),
              // Top filter chips row
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All Bills',
                              count: rawList.length,
                              selected: _selectedFilter == 'all',
                              onSelected: () => setState(() => _selectedFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Paid',
                              count: rawList.where((e) => e.status == 'paid').length,
                              selected: _selectedFilter == 'paid',
                              onSelected: () => setState(() => _selectedFilter = 'paid'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Unpaid',
                              count: rawList.where((e) => e.isUnpaid).length,
                              selected: _selectedFilter == 'unpaid',
                              onSelected: () => setState(() => _selectedFilter = 'unpaid'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Cancelled',
                              count: rawList.where((e) => e.status == 'cancelled').length,
                              selected: _selectedFilter == 'cancelled',
                              onSelected: () => setState(() => _selectedFilter = 'cancelled'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0), height: 1),

              // Invoice List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _future;
                  },
                  child: filteredList.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.primary.withOpacity(0.4)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedFilter == 'all' ? 'No invoices created yet' : 'No $Uri.decodeComponent(_selectedFilter) invoices',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Create bills via the POS tab to see them listed here.',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, idx) {
                            final inv = filteredList[idx];
                            final statusColor = _getStatusColor(inv.status);
                            final customerName = inv.customer?.name ?? 'Walk-in Customer';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x02000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: () => context.go('/invoices/${inv.id}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Left Visual Icon
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.description_rounded,
                                            color: AppTheme.primary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Central Metadata
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    inv.invoiceNumber,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      color: AppTheme.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  // Styled Status Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      inv.status.toUpperCase(),
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    customerName,
                                                    style: const TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Icon(Icons.calendar_month_outlined, size: 14, color: AppTheme.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    inv.displayDate,
                                                    style: const TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right Price and Chevron
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${inv.totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.2) : AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.background,
      selectedColor: AppTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
      ),
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
