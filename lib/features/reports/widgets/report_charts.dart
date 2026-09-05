import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/widgets/dashboard_widgets.dart';
import '../report_formatters.dart';

class ChartDatum {
  const ChartDatum({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

class ReportSectionCard extends StatelessWidget {
  const ReportSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.height,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          if (height != null)
            SizedBox(height: height, child: child)
          else
            child,
        ],
      ),
    );
  }
}

class ReportKpiCard extends StatelessWidget {
  const ReportKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mildCardFill(color),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mildCardBorder(color)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportEmptyChart extends StatelessWidget {
  const ReportEmptyChart({super.key, this.message = 'No data for this period'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

/// Grouped or single-series bar chart.
class ReportBarChart extends StatelessWidget {
  const ReportBarChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 240,
    /// When set (and length matches [labels]), each bar uses its own color
    /// instead of the series color — useful for category breakdowns.
    this.barColors,
  });

  final List<String> labels;
  final List<({String name, Color color, List<double> values})> series;
  final double height;
  final List<Color>? barColors;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || series.isEmpty) {
      return const ReportEmptyChart();
    }

    final maxY = series
        .expand((s) => s.values)
        .fold<double>(0, (m, v) => math.max(m, v));
    final top = maxY <= 0 ? 1.0 : maxY * 1.15;
    final usePerBar = barColors != null &&
        barColors!.length >= labels.length &&
        series.length == 1;
    final showLegend = series.length > 1;
    final barWidth = series.length > 1
        ? (labels.length <= 2 ? 14.0 : 10.0)
        : (labels.length <= 2 ? 28.0 : 18.0);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: top,
                alignment: labels.length <= 3
                    ? BarChartAlignment.center
                    : BarChartAlignment.spaceAround,
                groupsSpace: labels.length <= 3 ? 28 : 12,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        _formatAxisValue(v),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    maxContentWidth: 180,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final seriesName = (rodIndex >= 0 && rodIndex < series.length)
                          ? series[rodIndex].name
                          : '';
                      final label = (groupIndex >= 0 && groupIndex < labels.length)
                          ? labels[groupIndex]
                          : '';
                      final title = seriesName.isEmpty ? label : seriesName;
                      return BarTooltipItem(
                        '$title\n${formatReportCurrency(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < labels.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        for (var s = 0; s < series.length; s++)
                          BarChartRodData(
                            toY: i < series[s].values.length ? series[s].values[i] : 0,
                            color: usePerBar ? barColors![i] : series[s].color,
                            width: barWidth,
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (showLegend) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in series) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(width: 14),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Multi-series line chart for sales trends.
class ReportLineChart extends StatelessWidget {
  const ReportLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 240,
  });

  final List<String> labels;
  final List<({String name, Color color, List<double> values})> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || series.isEmpty) {
      return const ReportEmptyChart();
    }

    final maxY = series
        .expand((s) => s.values)
        .fold<double>(0, (m, v) => math.max(m, v));
    final top = maxY <= 0 ? 1.0 : maxY * 1.15;

    final chartHeight = series.length > 1 ? height - 30 : height;

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: top,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      _formatAxisValue(v),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: labels.length > 8 ? (labels.length / 6).ceilToDouble() : 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[i],
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tooltipBorderRadius: BorderRadius.circular(8),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => const Color(0xFF0F172A),
                  getTooltipItems: (spots) {
                    return [
                      for (final s in spots)
                        LineTooltipItem(
                          '${(s.barIndex >= 0 && s.barIndex < series.length) ? series[s.barIndex].name : ''}\n${formatReportCurrency(s.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                    ];
                  },
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < s.values.length; i++) FlSpot(i.toDouble(), s.values[i]),
                    ],
                    isCurved: true,
                    color: s.color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: series.length == 1,
                      color: s.color.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 12,
              children: [
                for (final s in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(s.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Donut chart with legend (payment modes, GST slabs).
class ReportDonutChart extends StatelessWidget {
  const ReportDonutChart({
    super.key,
    required this.data,
    required this.centerLabel,
    required this.centerValue,
    this.height = 220,
  });

  final List<ChartDatum> data;
  final String centerLabel;
  final String centerValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (s, d) => s + d.value);
    if (total <= 0) return const ReportEmptyChart();

    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 48,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: [
                      for (var i = 0; i < data.length; i++)
                        PieChartSectionData(
                          value: data[i].value <= 0 ? 0.0001 : data[i].value,
                          color: data[i].color,
                          radius: 24,
                          showTitle: false,
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerLabel, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    Text(
                      centerValue,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = data[i];
                final pct = total > 0 ? d.value / total * 100 : 0;
                return Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      formatReportPercent(pct.toDouble()),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatReportCurrency(d.value),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Full pie chart (CGST / SGST / IGST split).
class ReportPieChart extends StatelessWidget {
  const ReportPieChart({
    super.key,
    required this.data,
    this.height = 220,
  });

  final List<ChartDatum> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (s, d) => s + d.value);
    if (total <= 0) return const ReportEmptyChart();

    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 0,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (var i = 0; i < data.length; i++)
                    PieChartSectionData(
                      value: data[i].value <= 0 ? 0.0001 : data[i].value,
                      color: data[i].color,
                      radius: 56,
                      title: data[i].value / total >= 0.08
                          ? '${(data[i].value / total * 100).toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in data)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: d.color, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d.label, style: const TextStyle(fontSize: 12))),
                        Text(
                          formatReportCurrency(d.value),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar chart for tax slabs / HSN breakdown.
class ReportHorizontalBarChart extends StatelessWidget {
  const ReportHorizontalBarChart({
    super.key,
    required this.data,
    this.height = 220,
  });

  final List<ChartDatum> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const ReportEmptyChart();
    final max = data.fold<double>(0, (m, d) => math.max(m, d.value));
    if (max <= 0) return const ReportEmptyChart();

    return SizedBox(
      height: height,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = data[i];
          final pct = d.value / max;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatReportCurrency(d.value),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: d.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Color chartColorAt(int index) => kChartPalette[index % kChartPalette.length];

String _formatAxisValue(double value) {
  if (value == 0) return '₹0';
  final absValue = value.abs();
  if (absValue >= 1000000) {
    return '₹${(value / 1000000).toStringAsFixed(1)}M';
  } else if (absValue >= 100000) {
    return '₹${(value / 100000).toStringAsFixed(1)}L';
  } else if (absValue >= 1000) {
    return '₹${(value / 1000).toStringAsFixed(1)}K';
  }
  return '₹${value.toStringAsFixed(0)}';
}
