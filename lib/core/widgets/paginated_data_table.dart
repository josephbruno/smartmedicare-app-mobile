import 'package:flutter/material.dart';

import '../responsive/desktop_layout_helper.dart';
import '../theme/app_theme.dart';
import '../../data/models/api_response.dart';
import 'table_column_def.dart';
import 'table_pagination_bar.dart';

/// Client-side pagination for APIs that return full lists.
({List<T> items, PaginationMeta meta}) paginateList<T>(
  List<T> all, {
  required int page,
  required int perPage,
}) {
  final total = all.length;
  final lastPage = total == 0 ? 1 : (total / perPage).ceil();
  final start = (page - 1) * perPage;
  if (start >= total) {
    return (
      items: <T>[],
      meta: PaginationMeta(
        total: total,
        perPage: perPage,
        currentPage: page,
        lastPage: lastPage,
      ),
    );
  }
  final end = start + perPage > total ? total : start + perPage;
  return (
    items: all.sublist(start, end),
    meta: PaginationMeta(
      total: total,
      perPage: perPage,
      currentPage: page,
      lastPage: lastPage,
    ),
  );
}

typedef PaginatedLoad<T> = Future<({List<T> items, PaginationMeta? meta})> Function({
  required int page,
  required int perPage,
});

/// Computes min content width and effective table width for responsive layouts.
class ResponsiveTableMetrics {
  ResponsiveTableMetrics({
    required this.availableWidth,
    required this.tableWidth,
    required this.needsHorizontalScroll,
    required this.horizontalPadding,
  });

  final double availableWidth;
  final double tableWidth;
  final bool needsHorizontalScroll;
  final double horizontalPadding;

  static ResponsiveTableMetrics fromColumns(
    BuildContext context, {
    required List<TableColumnDef<dynamic>> columns,
    required double maxWidth,
  }) {
    final padding = _horizontalPadding(context);
    final available = (maxWidth - padding * 2).clamp(0.0, double.infinity);
    final minWidth = _minWidthForColumns(context, columns);
    final tableWidth = available >= minWidth ? available : minWidth;

    return ResponsiveTableMetrics(
      availableWidth: available,
      tableWidth: tableWidth,
      needsHorizontalScroll: tableWidth > available,
      horizontalPadding: padding,
    );
  }

  static double _horizontalPadding(BuildContext context) {
    if (ResponsiveLayout.isMobile(context)) return 8;
    if (ResponsiveLayout.isTablet(context)) return 12;
    return 16;
  }

  static double _baseColumnMin(BuildContext context) {
    if (ResponsiveLayout.isMobile(context)) return 68;
    if (ResponsiveLayout.isTablet(context)) return 84;
    return 96;
  }

  static double _minWidthForColumns(
    BuildContext context,
    List<TableColumnDef<dynamic>> columns,
  ) {
    final base = _baseColumnMin(context);
    return columns.fold<double>(
      0,
      (sum, c) => sum + (c.minWidth ?? base * c.flex),
    );
  }

  static ResponsiveTableMetrics fromFlexWidths(
    BuildContext context, {
    required List<double> flexes,
    required double maxWidth,
  }) {
    final padding = _horizontalPadding(context);
    final available = (maxWidth - padding * 2).clamp(0.0, double.infinity);
    final base = _baseColumnMin(context);
    final minWidth = flexes.fold<double>(0, (sum, f) => sum + base * f);
    final tableWidth = available >= minWidth ? available : minWidth;

    return ResponsiveTableMetrics(
      availableWidth: available,
      tableWidth: tableWidth,
      needsHorizontalScroll: tableWidth > available,
      horizontalPadding: padding,
    );
  }
}

/// Wraps a table so it fills the viewport width or scrolls horizontally when needed.
class ResponsiveTableContainer extends StatelessWidget {
  const ResponsiveTableContainer({
    super.key,
    required this.metrics,
    required this.child,
  });

  final ResponsiveTableMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final table = SizedBox(
      width: metrics.tableWidth,
      child: child,
    );

    if (metrics.needsHorizontalScroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: table,
      );
    }

    return SizedBox(width: metrics.availableWidth, child: table);
  }
}

/// Paginated data table with loading, error, and empty states.
class AppPaginatedTable<T> extends StatefulWidget {
  const AppPaginatedTable({
    super.key,
    required this.loadPage,
    required this.columns,
    this.onRowTap,
    this.perPage = 20,
    this.emptyMessage = 'No records found',
    this.header,
    this.showPerPageSelector = true,
  });

  final PaginatedLoad<T> loadPage;
  final List<TableColumnDef<T>> columns;
  final void Function(T item)? onRowTap;
  final int perPage;
  final String emptyMessage;
  final Widget? header;
  final bool showPerPageSelector;

  @override
  State<AppPaginatedTable<T>> createState() => AppPaginatedTableState<T>();
}

class AppPaginatedTableState<T> extends State<AppPaginatedTable<T>> {
  List<T> _items = [];
  PaginationMeta? _meta;
  bool _loading = true;
  String? _error;
  int _page = 1;
  late int _perPage;

  @override
  void initState() {
    super.initState();
    _perPage = widget.perPage;
    _fetch();
  }

  Future<void> refresh() => _fetch(page: _page);

  Future<void> _fetch({int? page}) async {
    final nextPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
      _page = nextPage;
    });
    try {
      final result = await widget.loadPage(page: nextPage, perPage: _perPage);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _meta = result.meta;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onPerPageChanged(int value) {
    setState(() => _perPage = value);
    _fetch(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _fetch(page: _page), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyMessage,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = ResponsiveTableMetrics.fromColumns(
                      context,
                      columns: widget.columns.cast<TableColumnDef<dynamic>>(),
                      maxWidth: constraints.maxWidth,
                    );

                    return RefreshIndicator(
                      onRefresh: () => _fetch(page: _page),
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: metrics.horizontalPadding,
                                vertical: 8,
                              ),
                              child: ResponsiveTableContainer(
                                metrics: metrics,
                                child: _buildTable(context, metrics.tableWidth),
                              ),
                            ),
                          ),
                          if (_loading)
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        TablePaginationBar(
          meta: _meta,
          perPage: _perPage,
          onPageChanged: (p) => _fetch(page: p),
          onPerPageChanged: widget.showPerPageSelector ? _onPerPageChanged : null,
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context, double tableWidth) {
    return SizedBox(
      width: tableWidth,
      child: Table(
        columnWidths: {
          for (var i = 0; i < widget.columns.length; i++)
            i: FlexColumnWidth(widget.columns[i].flex),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFE2E8F0)),
          verticalInside: BorderSide(color: Color(0xFFE2E8F0)),
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade50),
            children: widget.columns
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      c.label.toUpperCase(),
                      textAlign: c.align,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          ..._items.map((item) {
            return TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: widget.columns.map((c) {
                final cell = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Align(
                    alignment: c.align == TextAlign.right
                        ? Alignment.centerRight
                        : c.align == TextAlign.center
                            ? Alignment.center
                            : Alignment.centerLeft,
                    child: c.cellBuilder(context, item),
                  ),
                );
                if (widget.onRowTap == null) return cell;
                return InkWell(
                  onTap: () => widget.onRowTap!(item),
                  child: cell,
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}
