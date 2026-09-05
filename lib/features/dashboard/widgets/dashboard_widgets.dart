import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/responsive/desktop_layout_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard_data.dart';

/// Compact INR for dashboard cards: ₹1K, ₹0.5K, ₹1L, ₹0.5L (never the full amount).
String formatDashboardPrice(num value) {
  final n = value.toDouble();
  if (n == 0) return '₹0';
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  final useLakh = abs >= 100000;
  final scaled = useLakh ? abs / 100000 : abs / 1000;
  final suffix = useLakh ? 'L' : 'K';
  final rounded = (scaled * 10).round() / 10;
  final body = rounded == rounded.truncateToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return '$sign₹$body$suffix';
}

/// Shared color palette used for branch cards and donut segments.
const List<Color> kChartPalette = [
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // violet
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFF0EA5E9), // sky
  Color(0xFFEC4899), // pink
  Color(0xFFEF4444), // red
];

/// Soft pastel fill derived from an accent color (mild card highlight).
Color mildCardFill(Color color, {double strength = 0.10}) =>
    Color.alphaBlend(color.withValues(alpha: strength), Colors.white);

/// Soft border tint matching [mildCardFill].
Color mildCardBorder(Color color, {double strength = 0.28}) =>
    color.withValues(alpha: strength);

/// Generates a deterministic, plausible-looking trend series for a sparkline.
///
/// NOTE: this is placeholder data. The `/reports/dashboard` API returns only
/// point-in-time totals, so until a time-series endpoint exists these curves
/// are derived from the metric's current value purely for visual purposes.
List<double> syntheticTrend(num seed, {int points = 10}) {
  final base = seed <= 0 ? 1.0 : seed.toDouble();
  final rnd = math.Random((base * 37).round().abs() + points * 7 + 3);
  final out = <double>[];
  double v = base * (0.55 + rnd.nextDouble() * 0.25);
  for (var i = 0; i < points; i++) {
    final drift = (rnd.nextDouble() - 0.42) * base * 0.18;
    v = (v + drift).clamp(base * 0.15, base * 1.5);
    out.add(v);
  }
  out[points - 1] = base * (0.85 + rnd.nextDouble() * 0.3);
  return out;
}

/// A tiny line chart used inside stat cards.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.filled = true,
  });

  final List<double> data;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();
    final spots = <FlSpot>[
      for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
    ];
    final minY = data.reduce(math.min);
    final maxY = data.reduce(math.max);
    final pad = (maxY - minY).abs() * 0.2 + 0.001;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 2.4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: filled,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A KPI card with an icon badge, value, subtitle and a trailing sparkline.
class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<double>? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth.isFinite && constraints.maxWidth < 190;
        final showTrend = !compact && trend != null && trend!.length >= 2;
        final radius = compact ? 14.0 : 18.0;

        final card = Container(
          padding: EdgeInsets.all(compact ? 12 : 20),
          decoration: BoxDecoration(
            color: mildCardFill(color),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: mildCardBorder(color), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: compact ? 8 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 10 : 12,
                        letterSpacing: compact ? 0.15 : 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.all(compact ? 6 : 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(compact ? 8 : 10),
                    ),
                    child: Icon(icon, color: color, size: compact ? 15 : 18),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 14),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: compact ? 18 : 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: compact ? 11 : 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showTrend)
                    SizedBox(
                      width: 84,
                      height: 34,
                      child: Sparkline(data: trend!, color: color),
                    ),
                ],
              ),
            ],
          ),
        );

        if (onTap == null) return card;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: card,
          ),
        );
      },
    );
  }
}

/// A single datum for the sales-summary donut.
class DonutDatum {
  const DonutDatum({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
}

/// A donut chart with a centered total and a legend, used for "Sales Summary".
///
/// Prefer [fillHeight] from the parent instead of measuring constraints — toggling
/// [Expanded] via [LayoutBuilder] under [IntrinsicHeight] can trip
/// `!semantics.parentDataDirty` in debug.
class SalesSummaryCard extends StatelessWidget {
  const SalesSummaryCard({
    super.key,
    required this.data,
    required this.centerValue,
    this.centerCaption = 'Total (Monthly)',
    this.onViewReport,
    this.fillHeight = false,
  });

  final List<DonutDatum> data;
  final String centerValue;
  final String centerCaption;
  final VoidCallback? onViewReport;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final chartData = data.where((d) => d.value > 0).toList();
    final total = data.fold<double>(0, (s, d) => s + d.value);
    final hasData = total > 0 && chartData.isNotEmpty;
    final accent = hasData ? chartData.first.color : AppTheme.primary;

    // fl_chart: section.radius = ring thickness; outer = centerSpaceRadius + radius.
    final mobile = ResponsiveLayout.isMobile(context);
    final chartSize = mobile ? 148.0 : 188.0;
    final holeRadius = mobile ? 42.0 : 54.0;
    final ringThickness = mobile ? 22.0 : 28.0;

    Widget chartBlock() {
      return SizedBox(
        width: chartSize,
        height: chartSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: chartData.length > 1 ? 2 : 0,
                centerSpaceRadius: holeRadius,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (final d in chartData)
                    PieChartSectionData(
                      value: d.value,
                      color: d.color,
                      radius: ringThickness,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerValue,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mobile ? 'Monthly' : centerCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final legend = <Widget>[
      for (final d in data)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: d.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: d.color.withValues(alpha: 0.35),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                formatDashboardPrice(d.value),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                total > 0
                    ? '${(d.value / total * 100).toStringAsFixed(0)}%'
                    : '0%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: d.color,
                ),
              ),
            ],
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 14 : 20),
      decoration: BoxDecoration(
        color: mildCardFill(accent, strength: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mildCardBorder(accent, strength: 0.22), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.donut_large_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sales Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            fillHeight
                ? const Expanded(
                    child: Center(
                      child: Text('No sales yet', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text('No sales yet', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
          else ...[
            if (fillHeight)
              Expanded(child: Center(child: chartBlock()))
            else
              Center(child: chartBlock()),
            const SizedBox(height: 12),
            ...legend,
          ],
          if (onViewReport != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewReport,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Detailed Sales Report'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.4)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact action tile for the "Quick Actions" row.
class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = ResponsiveLayout.isMobile(context);
    return Material(
      color: mildCardFill(color),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(mobile ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: mildCardBorder(color), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(mobile ? 8 : 11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: mobile ? 20 : 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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

/// An illustrated branch performance card for "Performance by Branch".
///
/// Prefer [fillHeight] from the parent instead of measuring constraints — toggling
/// [Spacer] via [LayoutBuilder] under [IntrinsicHeight] can trip
/// `!semantics.parentDataDirty` in debug.
class BranchPerformanceCard extends StatelessWidget {
  const BranchPerformanceCard({
    super.key,
    required this.branch,
    required this.color,
    this.onView,
    this.fillHeight = false,
  });

  final BranchDashboardStat branch;
  final Color color;
  final VoidCallback? onView;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final mobile = ResponsiveLayout.isMobile(context);
    final iconSize = mobile ? 40.0 : 52.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 14 : 18),
      decoration: BoxDecoration(
        color: mildCardFill(color),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mildCardBorder(color), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.55)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(Icons.storefront_rounded, color: Colors.white, size: mobile ? 20 : 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      branch.branchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (branch.branchCode != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${branch.branchCode}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            branch.lowStockCount > 0
                ? '${branch.lowStockCount} low-stock items · stock value ${formatDashboardPrice(branch.stockValue)}'
                : 'Stock value ${formatDashboardPrice(branch.stockValue)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _metric('TODAY', formatDashboardPrice(branch.todaySales), AppTheme.textPrimary)),
              Container(width: 1.5, height: 30, color: mildCardBorder(color, strength: 0.2)),
              const SizedBox(width: 14),
              Expanded(child: _metric('MONTHLY', formatDashboardPrice(branch.monthlySales), color)),
            ],
          ),
          if (fillHeight) const Spacer(),
          if (onView != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onView,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  foregroundColor: color,
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: valueColor),
          ),
        ),
      ],
    );
  }
}

/// A small section header ("Business Overview", "Quick Actions", etc.).
class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleRow = Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );

    if (trailing == null) return titleRow;

    if (ResponsiveLayout.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          const SizedBox(height: 10),
          trailing!,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleRow),
        const SizedBox(width: 12),
        trailing!,
      ],
    );
  }
}
