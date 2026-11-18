import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_tokens.dart';
import 'app_date_range_picker.dart';
import 'app_dropdown.dart';
import '../utils/ist.dart';

/// Building blocks that mirror the web app's page anatomy
/// (`frontend/src/pages/customers/CustomerListPage.vue`, `cl-*` classes):
///
///   breadcrumbs → header (icon tile, title, subtitle, actions)
///   → KPI cards → filter card → table card
///
/// Use [WebPageScaffold] for a whole page or the pieces individually.

const _ink = Color(0xFF0F172A);
const _muted = AppTokens.text3;
const _line = AppTokens.border;
const _blueSoft = Color(0xFFEAF2FF);

bool _isNarrow(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppTokens.bpTablet;

// ─────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────

/// White card with the web's 1px border, radius 14 and soft shadow (`cl-card`).
class WebCard extends StatelessWidget {
  const WebCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Breadcrumbs
// ─────────────────────────────────────────────────────────────────────────

class Crumb {
  const Crumb(this.label, {this.path});
  final String label;

  /// Route to open on tap. Null → plain (non-link) crumb.
  final String? path;
}

/// `Home › Group › Current` trail (`cl-crumbs`). "Home" is always prepended.
class PageBreadcrumbs extends StatelessWidget {
  const PageBreadcrumbs({super.key, required this.items});

  /// Crumbs after Home; the last one is rendered as the current page.
  final List<Crumb> items;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _link(context, const Crumb('Home', path: '/dashboard'), home: true),
    ];
    for (var i = 0; i < items.length; i++) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.chevron_right_rounded, size: 14, color: _muted),
      ));
      final last = i == items.length - 1;
      children.add(last
          ? Text(items[i].label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _ink))
          : _link(context, items[i]));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }

  Widget _link(BuildContext context, Crumb c, {bool home = false}) {
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (home) ...[
          const Icon(Icons.home_outlined, size: 15, color: AppTokens.primary),
          const SizedBox(width: 6),
        ],
        Text(c.label,
            style: const TextStyle(fontSize: 14, color: AppTokens.primary)),
      ],
    );
    if (c.path == null) return text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => context.go(c.path!), child: text),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────

/// Icon tile + title + subtitle on the left, actions on the right
/// (`cl-header`). Under 768px the actions wrap to a full-width row and
/// share it equally, like the web's mobile rule.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final narrow = _isNarrow(context);
    final tile = narrow ? 48.0 : 64.0;

    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTokens.primary, size: tile / 2),
          ),
          SizedBox(width: narrow ? 12 : 18),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: narrow ? 22 : AppTokens.font3xl,
                      fontWeight: FontWeight.w700,
                      color: _ink)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!,
                      style: TextStyle(
                          fontSize: narrow ? 13 : 15,
                          color: AppTokens.menuIcon)),
                ),
            ],
          ),
        ),
      ],
    );

    if (actions.isEmpty) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 14), child: heading);
    }

    if (narrow) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: 12),
            // Up to two actions share a row; more wrap two per row.
            LayoutBuilder(builder: (context, c) {
              final perRow = actions.length == 1 ? 1 : 2;
              final w = (c.maxWidth - 10 * (perRow - 1)) / perRow;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final a in actions) SizedBox(width: w, child: a),
                ],
              );
            }),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 16),
          Wrap(spacing: 12, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// KPI cards
// ─────────────────────────────────────────────────────────────────────────

enum KpiTone { blue, sky, purple, orange, green, red }

({Color bg, Color fg}) _toneColors(KpiTone t) => switch (t) {
      KpiTone.blue => (bg: const Color(0xFFDBE8FD), fg: const Color(0xFF2563EB)),
      KpiTone.sky => (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8)),
      KpiTone.purple =>
        (bg: const Color(0xFFF3E8FF), fg: const Color(0xFF9333EA)),
      KpiTone.orange =>
        (bg: const Color(0xFFFFEDD5), fg: const Color(0xFFF59E0B)),
      KpiTone.green => (bg: const Color(0xFFDCFCE7), fg: AppTokens.success),
      KpiTone.red => (bg: const Color(0xFFFEE2E2), fg: AppTokens.error),
    };

class KpiData {
  const KpiData({
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
    this.subUp = false,
    this.tone = KpiTone.blue,
    this.series = const [],
  });

  final String label;
  final String value;
  final IconData icon;
  final String? sub;

  /// Green, bold sub-line (positive trend).
  final bool subUp;
  final KpiTone tone;

  /// Optional sparkline values (at least 2 points to draw).
  final List<double> series;
}

/// One KPI tile (`cl-kpi`): icon tile, label, big value, sub-line, sparkline.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.data});

  final KpiData data;

  @override
  Widget build(BuildContext context) {
    final c = _toneColors(data.tone);
    final narrow = _isNarrow(context);
    final tiny = MediaQuery.sizeOf(context).width < 400;
    final tile = tiny ? 36.0 : narrow ? 44.0 : 66.0;
    return WebCard(
      padding: EdgeInsets.symmetric(
          horizontal: tiny ? 10 : narrow ? 14 : 18, vertical: narrow ? 12 : 16),
      // Web: min-height 104 incl. padding. Grows with text scale.
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: narrow ? 64 : 72),
        child: Stack(
          children: [
            // No room for the sparkline in 2-up phone tiles.
            if (data.series.length >= 2 && !narrow)
              Positioned(
                right: 0,
                bottom: 0,
                width: 88,
                height: 44,
                child: _Sparkline(values: data.series, color: c.fg),
              ),
            Row(
              children: [
                Container(
                  width: tile,
                  height: tile,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(data.icon, color: c.fg, size: tile / 2),
                ),
                SizedBox(width: tiny ? 8 : narrow ? 12 : 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppTokens.text2)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(data.value,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: tiny ? 20 : narrow ? 22 : 28,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                      ),
                      if (data.sub != null)
                        Text(data.sub!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: data.subUp ? AppTokens.success : _muted,
                              fontWeight:
                                  data.subUp ? FontWeight.w600 : FontWeight.w400,
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: values.reduce((a, b) => a < b ? a : b),
          maxY: values.reduce((a, b) => a > b ? a : b) + 0.0001,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              color: color,
              barWidth: 1.6,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive KPI grid: `repeat(auto-fit, minmax(240px, 1fr))`, gap 12.
/// On phones it falls back to 2 columns so 4 KPIs fit in two rows.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items});

  final List<KpiData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        const gap = 12.0;
        final w = constraints.maxWidth;
        var cols = ((w + gap) / (240 + gap)).floor().clamp(1, items.length);
        if (w < AppTokens.bpTablet && items.length > 1) cols = 2;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final k in items)
              SizedBox(width: itemW, child: KpiCard(data: k)),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filters
// ─────────────────────────────────────────────────────────────────────────

/// Search field + filter controls + Reset button (`cl-filters`).
///
/// [filters] are placed at 170px wide on desktop and share rows on phones.
class FilterCard extends StatelessWidget {
  const FilterCard({
    super.key,
    this.searchController,
    this.searchHint = 'Search...',
    this.onSearchChanged,
    this.filters = const [],
    this.onReset,
    this.resetEnabled = true,
    this.trailing = const [],
  });

  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget> filters;
  final VoidCallback? onReset;
  final bool resetEnabled;

  /// Extra controls placed before Reset (e.g. date-range picker).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final narrow = _isNarrow(context);
    final search = onSearchChanged == null && searchController == null
        ? null
        : TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: searchController == null
                  ? null
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController!,
                      builder: (context, v, _) => v.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                searchController!.clear();
                                onSearchChanged?.call('');
                              },
                            ),
                    ),
            ),
          );

    final reset = onReset == null
        ? null
        : OutlinedButton.icon(
            onPressed: resetEnabled ? onReset : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset'),
          );

    if (narrow) {
      return WebCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (search != null) search,
            if (filters.isNotEmpty || trailing.isNotEmpty) ...[
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, c) {
                final half = (c.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final f in filters) SizedBox(width: half, child: f),
                    // Date ranges and extra tools get the full row on phones.
                    for (final t in trailing) SizedBox(width: c.maxWidth, child: t),
                  ],
                );
              }),
            ],
            if (reset != null) ...[const SizedBox(height: 10), reset],
          ],
        ),
      );
    }

    return WebCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (search != null)
            Flexible(
              flex: 3,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: search,
              ),
            ),
          for (final f in filters) ...[
            const SizedBox(width: 12),
            SizedBox(width: 170, child: f),
          ],
          for (final t in trailing) ...[const SizedBox(width: 12), t],
          const Spacer(),
          if (reset != null) ...[
            const SizedBox(width: 12),
            SizedBox(width: 110, child: reset),
          ],
        ],
      ),
    );
  }
}

/// Clearable filter dropdown (`n-select clearable placeholder="All …"`).
/// The first entry (null) shows [hint]; picking it clears the filter.
class FilterSelect<T> extends StatelessWidget {
  const FilterSelect({
    super.key,
    required this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String hint;
  final Map<T, String> options;
  final T? value;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppDropdownButtonFormField<T?>(
      value: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(hintText: hint),
      hint: Text(hint),
      items: [
        DropdownMenuItem<T?>(value: null, child: Text(hint, overflow: TextOverflow.ellipsis)),
        for (final e in options.entries)
          DropdownMenuItem<T?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

/// "Start Date → End Date" range field (`n-date-picker type="daterange"`).
/// Values are `yyyy-MM-dd` (IST calendar dates).
class DateRangeFilter extends StatelessWidget {
  const DateRangeFilter({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
    this.width = 260,
  });

  final String? from;
  final String? to;
  final void Function(String? from, String? to) onChanged;
  final double width;

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final label = from == null
        ? 'Start Date → End Date'
        : '${formatDateIst(from)} → ${formatDateIst(to ?? from)}';
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final today = nowIst();
          final range = await showAppDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(today.year + 1, 12, 31),
            initialDateRange: from == null
                ? null
                : DateTimeRange(start: DateTime.parse(from!), end: DateTime.parse(to ?? from!)),
          );
          if (range != null) onChanged(_ymd(range.start), _ymd(range.end));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.date_range_outlined, size: 18),
            suffixIcon: from == null
                ? null
                : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => onChanged(null, null)),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: from == null ? AppTokens.placeholder : AppTokens.text1)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Table bits
// ─────────────────────────────────────────────────────────────────────────

enum PillTone { green, amber, red, blue, purple, grey }

/// Rounded status pill (`cl-status`, `cl-pets`).
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.green, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.green => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      PillTone.amber => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      PillTone.red => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      PillTone.blue => (_blueSoft, AppTokens.primary),
      PillTone.purple => (const Color(0xFFF3E8FF), AppTokens.purple),
      PillTone.grey => (AppTokens.bgTertiary, AppTokens.placeholder),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Square row-action button (`cl-icon-btn`). [plain] = white / grey icon.
class TableIconButton extends StatelessWidget {
  const TableIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.plain = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool plain;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: plain ? Colors.white : const Color(0xFFF4F8FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 34,
          child: Icon(icon,
              size: 16,
              color: color ?? (plain ? AppTokens.text2 : AppTokens.primary)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Initials avatar used in person columns (`cl-avatar`).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 38});

  final String name;
  final double size;

  static const _palette = [
    (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
    (Color(0xFFF3E8FF), Color(0xFF7C3AED)),
    (Color(0xFFDCFCE7), Color(0xFF15803D)),
    (Color(0xFFFFEDD5), Color(0xFFC2410C)),
    (Color(0xFFFCE7F3), Color(0xFFBE185D)),
  ];

  @override
  Widget build(BuildContext context) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p[0].toUpperCase()).join();
    final (bg, fg) = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(initials,
          style: TextStyle(
              fontSize: size * 0.34, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Forms
// ─────────────────────────────────────────────────────────────────────────

/// Numbered form section (`section-step` + title + description) followed by
/// [children] laid out in a [columns]-wide grid (1 column on phones).
class WebFormSection extends StatelessWidget {
  const WebFormSection({
    super.key,
    required this.step,
    required this.title,
    this.description,
    required this.children,
    this.columns = 2,
    this.trailing = const [],
  });

  final int step;
  final String title;
  final String? description;
  final List<Widget> children;
  final int columns;

  /// Extra full-width rows after the grid (e.g. a 3-column address row).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppTokens.primary, shape: BoxShape.circle),
                child: Text('$step',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.text1)),
                    if (description != null)
                      Text(description!,
                          style: const TextStyle(
                              fontSize: 13, color: AppTokens.text3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FormGrid(columns: columns, children: children),
          for (final t in trailing) ...[const SizedBox(height: 16), t],
        ],
      ),
    );
  }
}

/// Simple responsive grid: [columns] across, collapsing to 1 under 768px.
class FormGrid extends StatelessWidget {
  const FormGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.gap = 16,
    this.minColumnWidth = 260,
  });

  final List<Widget> children;
  final int columns;
  final double gap;

  /// Columns drop until each is at least this wide (phones → fewer columns).
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final fit = ((c.maxWidth + gap) / (minColumnWidth + gap)).floor();
      final cols = fit.clamp(1, columns);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

/// Label above a field (Naive `label-placement="top"`), red `*` when required.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, required this.child, this.required = false});

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(TextSpan(
            text: label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTokens.text1),
            children: [
              if (required)
                const TextSpan(
                    text: ' *', style: TextStyle(color: AppTokens.error)),
            ],
          )),
        ),
        child,
      ],
    );
  }
}

/// Input prefix "addon" box (`n-input-group-label`) with an icon and/or text.
Widget inputAddon({IconData? icon, String? text}) {
  return Container(
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      color: Color(0xFFF8FAFC),
      border: Border(right: BorderSide(color: AppTokens.border)),
      borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 16, color: AppTokens.text3),
        if (icon != null && text != null) const SizedBox(width: 8),
        if (text != null)
          Text(text,
              style: const TextStyle(fontSize: 14, color: AppTokens.text2)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Page scaffold
// ─────────────────────────────────────────────────────────────────────────

/// Standard page frame: breadcrumbs, header, KPIs, filters, then [body]
/// inside a card that fills the remaining height (table pages), or a
/// scrollable column when [scrollable] is true (detail / form pages).
class WebPageScaffold extends StatelessWidget {
  const WebPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.icon,
    this.breadcrumbs = const [],
    this.actions = const [],
    this.kpis = const [],
    this.filters,
    this.scrollable = false,
    this.bodyInCard = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Crumbs after "Home". When empty, `[title]` is used.
  final List<Crumb> breadcrumbs;
  final List<Widget> actions;
  final List<KpiData> kpis;
  final Widget? filters;
  final Widget body;
  final bool scrollable;

  /// Wrap [body] in a [WebCard] (table card). Disable for custom layouts.
  final bool bodyInCard;

  @override
  Widget build(BuildContext context) {
    final narrow = _isNarrow(context);
    final pad = narrow ? 12.0 : 16.0;
    final head = <Widget>[
      if (!narrow)
        PageBreadcrumbs(
            items: breadcrumbs.isEmpty ? [Crumb(title)] : breadcrumbs),
      PageHeader(
          title: title, subtitle: subtitle, icon: icon, actions: actions),
      KpiGrid(items: kpis),
      if (filters != null) filters!,
    ];

    final card = bodyInCard && !(narrow && !scrollable)
        ? WebCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: body)
        : body;

    if (scrollable) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...head, card],
        ),
      );
    }

    // Table pages. On phones (and short windows) the header, KPIs and
    // filters scroll away and the list gets the whole screen; NestedScrollView
    // hands the drag over to the list's own (primary) scroll view.
    return LayoutBuilder(builder: (context, constraints) {
      if (narrow || constraints.maxHeight < 700) {
        return NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
              sliver: SliverList(delegate: SliverChildListDelegate(head)),
            ),
          ],
          body: Padding(
            padding: EdgeInsets.fromLTRB(narrow ? 0 : pad, 0, narrow ? 0 : pad, narrow ? 0 : pad),
            child: card,
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...head, Expanded(child: card)],
        ),
      );
    });
  }
}
