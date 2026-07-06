import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().customers.list();
  }

  void _refresh() {
    setState(() {
      _future = context.read<AppServices>().customers.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/customers/new'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: FutureBuilder<List<Customer>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Loading customers directory...', style: TextStyle(color: AppTheme.textSecondary)),
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
                    const Text('Failed to load customers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
                  ],
                ),
              ),
            );
          }

          final list = snap.data ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: list.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
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
                              child: Icon(Icons.people_alt_rounded, size: 48, color: AppTheme.primary.withOpacity(0.4)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No customers yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap the "+" button below to add your first customer.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      final cu = list[idx];
                      final initials = cu.name.isNotEmpty ? cu.name.substring(0, 1).toUpperCase() : 'C';
                      final petCount = cu.pets?.length ?? 0;
                      final balance = cu.outstandingBalance ?? 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          onTap: () => context.go('/customers/${cu.id}'),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Left initial circular container
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Middle Customer Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            cu.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!cu.isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.danger.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'INACTIVE',
                                                style: TextStyle(
                                                  color: AppTheme.danger,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            cu.phone,
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          if (cu.email != null && cu.email!.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.mail_outline_rounded, size: 14, color: AppTheme.textSecondary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                cu.email!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Pets & Location Badge Row
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.background,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.pets_rounded, size: 12, color: AppTheme.textSecondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  petCount > 0 ? '$petCount ${petCount == 1 ? "Pet" : "Pets"}' : 'No pets',
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (cu.city != null && cu.city!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.background,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    cu.city!,
                                                    style: const TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Right Outstanding Balance
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (balance > 0) ...[
                                      const Text(
                                        'BALANCE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.danger,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${balance.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppTheme.danger,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ] else ...[
                                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
