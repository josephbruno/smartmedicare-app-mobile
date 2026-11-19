import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/receipt_branch_store.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/ist.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../data/models/shop.dart';
import '../../../data/models/dashboard_data.dart';
import '../../../data/models/report_data.dart';
import '../../subscription/plan_guard.dart';
import 'dashboard_widgets.dart';

/// Phone dashboard (< 600px): context chips, hero banner, 2×2 KPI tiles,
/// monthly sales summary donut, sales trend chart and quick actions.
class MobileDashboard extends StatelessWidget {
  const MobileDashboard({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContextRow(data: data, auth: auth),
        const SizedBox(height: 14),
        _HeroBanner(veterinary: auth.isVeterinary),
        const SizedBox(height: 14),
        _KpiGrid(data: data),
        const SizedBox(height: 14),
        _SalesSummaryCard(data: data),
        const SizedBox(height: 14),
        const _SalesTrendCard(),
        const SizedBox(height: 14),
        _QuickActionsCard(auth: auth),
      ],
    );
  }
}

// ── Formatting ───────────────────────────────────────────────────────────────

String _money(num v) =>
    v.abs() < 1000 ? '₹${v.round()}' : formatDashboardPrice(v);

const _cardRadius = 16.0;
const _cardBorder = Color(0xFFE4EAF2);

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_cardRadius),
      border: Border.all(color: _cardBorder),
      boxShadow: const [
        BoxShadow(
            color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
      ],
    );

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppTokens.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTokens.text1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

// ── Branch + date chips ──────────────────────────────────────────────────────

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.data, required this.auth});

  final DashboardData data;
  final AuthSession auth;

  @override
  Widget build(BuildContext context) {
    final branchCount = data.branches?.length ?? 0;
    final branchLabel = branchCount > 1
        ? 'All branches ($branchCount)'
        : (auth.currentBranch?.name ?? 'Main Branch');
    final canReports = auth.hasPermission(AppPermissions.reportsView);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _Chip(
            icon: Icons.apartment_rounded,
            label: branchLabel,
            showChevron: auth.canSwitchBranch,
            onTap: auth.canSwitchBranch ? () => _pickBranch(context) : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _Chip(
            icon: Icons.calendar_today_outlined,
            label: DateFormat('MMM d, y').format(nowIst()),
            showChevron: canReports,
            onTap: canReports ? () => context.go('/reports/sales') : null,
          ),
        ),
      ],
    );
  }

  Future<void> _pickBranch(BuildContext context) async {
    final services = context.read<AppServices>();
    List<Branch> branches;
    try {
      branches = await services.branches.list();
    } catch (e) {
      if (context.mounted) {
        AppMessenger.error(context, 'Could not load branches: $e');
      }
      return;
    }
    if (!context.mounted || branches.isEmpty) return;
    final currentId = auth.currentBranchId;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Switch branch',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final b in branches)
              ListTile(
                leading: Icon(
                  b.id == currentId
                      ? Icons.check_circle_rounded
                      : Icons.storefront_outlined,
                  color:
                      b.id == currentId ? AppTokens.primary : AppTokens.text3,
                ),
                title: Text(b.name),
                onTap: () => Navigator.of(ctx).pop(b.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == currentId || !context.mounted) return;
    try {
      await auth.switchBranch(picked);
      if (!context.mounted) return;
      await ReceiptBranchStore.sync(branches: services.branches, auth: auth);
      if (context.mounted) {
        AppMessenger.success(context, 'Branch switched successfully');
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.error(context, 'Failed to switch branch: $e');
      }
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: AppTokens.text2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.text1,
                      ),
                    ),
                  ),
                  if (showChevron)
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppTokens.text2),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Hero banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.veterinary});

  final bool veterinary;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_cardRadius),
      child: SizedBox(
        height: 132,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0B2E6B),
                      Color(0xFF0B5ED7),
                      Color(0xFF3B82F6)
                    ],
                    stops: [0, 0.6, 1],
                  ),
                ),
              ),
            ),
            // Red diagonal accent.
            Positioned.fill(child: CustomPaint(painter: _AccentPainter())),
            Positioned(
              right: -6,
              bottom: 0,
              top: 6,
              child: veterinary
                  ? Image.asset(
                      'assets/branding/clinic-hero-transparent.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : const Padding(
                      padding: EdgeInsets.only(right: 18),
                      child: Icon(Icons.medical_services_rounded,
                          size: 92, color: Color(0x33FFFFFF)),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 150, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Business Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Here's what's happening with your clinic today.",
                    style: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.38, size.height)
      ..lineTo(size.width * 0.70, size.height * 0.42)
      ..lineTo(size.width * 0.62, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00E11D48), Color(0xCCE11D48)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── KPI tiles ────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _KpiTile(
        title: 'Today Sales',
        value: _money(data.todaySalesTotal),
        subtitle:
            '${data.todaySalesCount} ${data.todaySalesCount == 1 ? 'bill' : 'bills'}',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF2563EB),
        tint: const Color(0xFFEAF2FF),
      ),
      _KpiTile(
        title: 'Monthly Sales',
        value: _money(data.monthlySalesTotal),
        subtitle: 'This month',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF7C3AED),
        tint: const Color(0xFFF3EDFF),
      ),
      _KpiTile(
        title: 'Low Stock',
        value: '${data.lowStockCount}',
        subtitle: data.lowStockCount > 0 ? 'Reorder needed' : 'All healthy',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD97706),
        tint: const Color(0xFFFFF6E5),
        onTap: () => context.go('/stock-alerts'),
      ),
      _KpiTile(
        title: 'Dues',
        value: _money(data.outstandingDues),
        subtitle: 'Unpaid balance',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF059669),
        tint: const Color(0xFFE8F8F1),
      ),
    ];
    return Column(
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 12),
          Expanded(child: tiles[1]),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: 12),
          Expanded(child: tiles[3]),
        ]),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tint,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: tint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: color.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: AppTokens.text1,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTokens.text2,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (onTap != null)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chevron_right_rounded,
                                  size: 18, color: color),
                            ),
                        ],
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

// ── Sales summary (monthly collected vs due) ────────────────────────────────

class _SalesSummaryCard extends StatelessWidget {
  const _SalesSummaryCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final m = data.monthlySales;
    final total = m.total;
    // Paid/due come from the API; fall back to total-as-collected if absent.
    final due = m.due.clamp(0, total).toDouble();
    final paid = (m.paid > 0 ? m.paid : total - due).clamp(0, total).toDouble();
    final rows = [
      ('Collected', paid, const Color(0xFF2563EB)),
      ('Due', due, const Color(0xFFF59E0B)),
    ];
    String pct(double v) => total <= 0 ? '0%' : '${(v / total * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
              icon: Icons.bar_chart_rounded, title: 'Sales Summary'),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: total > 0 && due > 0 && paid > 0 ? 2 : 0,
                        centerSpaceRadius: 38,
                        sections: total <= 0
                            ? [
                                PieChartSectionData(
                                  value: 1,
                                  color: const Color(0xFFE2E8F0),
                                  radius: 18,
                                  showTitle: false,
                                ),
                              ]
                            : [
                                for (final r in rows)
                                  if (r.$2 > 0)
                                    PieChartSectionData(
                                      value: r.$2,
                                      color: r.$3,
                                      radius: 18,
                                      showTitle: false,
                                    ),
                              ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(
                            _money(total),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTokens.text1,
                            ),
                          ),
                        ),
                        const Text('Monthly',
                            style: TextStyle(
                                fontSize: 11, color: AppTokens.text3)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: r.$3, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(r.$1,
                                  style: const TextStyle(
                                      fontSize: 13.5, color: AppTokens.text2)),
                            ),
                            Text(_money(r.$2),
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.text1)),
                            SizedBox(
                              width: 46,
                              child: Text(
                                pct(r.$2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTokens.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Invoices',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppTokens.text3)),
                          ),
                          Text('${m.count}',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTokens.text2)),
                          const SizedBox(width: 46),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sales trend (7D / 30D / 3M) ─────────────────────────────────────────────

class _SalesTrendCard extends StatefulWidget {
  const _SalesTrendCard();

  @override
  State<_SalesTrendCard> createState() => _SalesTrendCardState();
}

class _SalesTrendCardState extends State<_SalesTrendCard> {
  static const _ranges = [('7D', 7), ('30D', 30), ('3M', 90)];

  int _days = 7;
  bool _loading = true;
  String? _error;
  List<({DateTime day, double total})> _series = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await context.read<AppServices>().reports.salesTrend(days: _days);
      if (!mounted) return;
      setState(() {
        _series = _fillDays(res, _days);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load sales trend';
        _loading = false;
      });
    }
  }

  /// One value per IST day for the range (missing days = 0); multi-branch
  /// series are summed per day.
  static List<({DateTime day, double total})> _fillDays(
      SalesTrendData res, int days) {
    final byDay = <String, double>{};
    void add(SalesTrendPoint p) {
      if (p.date.length < 10) return;
      final key = p.date.substring(0, 10);
      byDay[key] = (byDay[key] ?? 0) + p.total;
    }

    if (res.multiBranch) {
      for (final b in res.branches) {
        b.points.forEach(add);
      }
    } else {
      res.points.forEach(add);
    }
    final today = nowIst();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final fmt = DateFormat('yyyy-MM-dd');
    return [
      for (var i = 0; i < days; i++)
        () {
          final d = start.add(Duration(days: i));
          return (day: d, total: byDay[fmt.format(d)] ?? 0.0);
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.show_chart_rounded,
            title: 'Sales Trend',
            trailing: _RangeToggle(
              ranges: _ranges,
              selected: _days,
              onChanged: (d) {
                if (d == _days) return;
                _days = d;
                _load();
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 180, child: _chart()),
        ],
      ),
    );
  }

  Widget _chart() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text('$_error — retry'),
        ),
      );
    }
    final total = _series.fold<double>(0, (s, e) => s + e.total);
    if (total <= 0) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 34, color: Color(0xFFCBD5E1)),
            SizedBox(height: 6),
            Text('No sales in this period',
                style: TextStyle(color: AppTokens.placeholder, fontSize: 13)),
          ],
        ),
      );
    }

    final maxY = _niceMax(_series.map((e) => e.total).reduce(math.max));
    final n = _series.length;
    final labelEvery = n <= 7 ? 1 : (n <= 30 ? 6 : 15);
    final fmt = DateFormat(n <= 7 ? 'MMM d' : 'd MMM');
    const line = Color(0xFF2563EB);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFEFF3F8), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY / 4,
              getTitlesWidget: (v, meta) => Text(
                _axisMoney(v),
                style: const TextStyle(fontSize: 10.5, color: AppTokens.text3),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= n || v != i.toDouble()) {
                  return const SizedBox.shrink();
                }
                // Label every Nth day, always including the last day.
                final show = i == n - 1 ||
                    (i % labelEvery == 0 && (n - 1 - i) >= labelEvery ~/ 2 + 1);
                if (!show) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fmt.format(_series[i].day),
                      style: const TextStyle(
                          fontSize: 10, color: AppTokens.text3)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTokens.text1,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat('d MMM').format(_series[s.x.round()].day)}\n${_money(s.y)}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < n; i++)
                FlSpot(i.toDouble(), _series[i].total),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: line,
            barWidth: 2.5,
            dotData: FlDotData(
              show: n <= 31,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: n <= 7 ? 4 : 2.5,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: line,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  line.withValues(alpha: 0.28),
                  line.withValues(alpha: 0.02)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _niceMax(double v) {
    if (v <= 0) return 1000;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      final candidate = m * exp;
      if (candidate >= v * 1.1) return candidate;
    }
    return 10 * exp;
  }

  static String _axisMoney(double v) {
    if (v == 0) return '0';
    if (v >= 100000) {
      return '${(v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1)}L';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
    }
    return v.round().toString();
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({
    required this.ranges,
    required this.selected,
    required this.onChanged,
  });

  final List<(String, int)> ranges;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTokens.bgTertiary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, days) in ranges)
              GestureDetector(
                onTap: () => onChanged(days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: days == selected
                        ? AppTokens.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: days == selected ? Colors.white : AppTokens.text2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

// ── Quick actions ────────────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.auth});

  final AuthSession auth;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      if (auth.hasPermission(AppPermissions.invoicesCreate))
        _QuickAction(
          icon: Icons.point_of_sale_rounded,
          label: 'New Sale',
          color: const Color(0xFF2563EB),
          tint: const Color(0xFFEAF2FF),
          onTap: () => context.go('/pos'),
        ),
      if (auth.hasPermission(AppPermissions.productsCreate))
        _QuickAction(
          icon: Icons.add_box_rounded,
          label: 'Add Product',
          color: const Color(0xFF16A34A),
          tint: const Color(0xFFE8F8EE),
          onTap: () async {
            if (await ensurePlanAllows(context, limitResource: 'products') &&
                context.mounted) {
              context.go('/products/new');
            }
          },
        ),
      if (auth.hasPermission(AppPermissions.inventoryTransfer))
        _QuickAction(
          icon: Icons.swap_horiz_rounded,
          label: 'Stock Transfer',
          color: const Color(0xFFD97706),
          tint: const Color(0xFFFFF6E5),
          onTap: () => context.go('/stock-transfers/new'),
        ),
      if (auth.hasPermission(AppPermissions.emrVisitsCreate))
        _QuickAction(
          icon: Icons.event_available_rounded,
          label: 'New Visit',
          color: const Color(0xFF7C3AED),
          tint: const Color(0xFFF3EDFF),
          onTap: () => context.go('/emr/visits/new'),
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.bolt_rounded, title: 'Quick Actions'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: tint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
