import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().products.list();
  }

  void _refresh() {
    setState(() {
      _future = context.read<AppServices>().products.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/products/new'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Loading products directory...', style: TextStyle(color: AppTheme.textSecondary)),
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
                    const Text('Failed to load products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                              child: Icon(Icons.inventory_2_rounded, size: 48, color: AppTheme.primary.withOpacity(0.4)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No products catalogued',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap the "+" button below to add your first product.',
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
                      final p = list[idx];
                      final isLowStock = p.trackInventory && (p.currentStock ?? 0) <= p.reorderLevel;
                      final outOfStock = p.trackInventory && (p.currentStock ?? 0) <= 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          onTap: () => context.go('/products/${p.id}/edit'),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Product icon
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    p.isService ? Icons.cut_rounded : Icons.pets_rounded,
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Central product metadata
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!p.isActive)
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
                                          if (p.sku != null && p.sku!.isNotEmpty) ...[
                                            Text(
                                              'SKU: ${p.sku}',
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 3,
                                              height: 3,
                                              decoration: const BoxDecoration(color: AppTheme.textSecondary, shape: BoxShape.circle),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            p.categoryName ?? 'Uncategorized',
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Stock details
                                      if (p.trackInventory)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: outOfStock
                                                ? AppTheme.danger.withOpacity(0.1)
                                                : isLowStock
                                                    ? AppTheme.warning.withOpacity(0.1)
                                                    : AppTheme.accent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            outOfStock
                                                ? 'OUT OF STOCK'
                                                : isLowStock
                                                    ? 'LOW STOCK: ${p.currentStock?.toInt()}'
                                                    : 'STOCK: ${p.currentStock?.toInt()}',
                                            style: TextStyle(
                                              color: outOfStock
                                                  ? AppTheme.danger
                                                  : isLowStock
                                                      ? AppTheme.warning
                                                      : AppTheme.accent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'SERVICE/INFINITE',
                                            style: TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Pricing details
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${p.sellingPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    if (p.mrp > p.sellingPrice) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'MRP ₹${p.mrp.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
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
