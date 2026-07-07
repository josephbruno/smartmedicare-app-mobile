import 'package:flutter/material.dart';

/// Column definition for [AppPaginatedTable].
class TableColumnDef<T> {
  const TableColumnDef({
    required this.label,
    required this.cellBuilder,
    this.flex = 1,
    this.minWidth,
    this.align = TextAlign.left,
  });

  final String label;
  final double flex;
  final double? minWidth;
  final TextAlign align;
  final Widget Function(BuildContext context, T item) cellBuilder;
}
