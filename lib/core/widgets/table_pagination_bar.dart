import 'package:flutter/material.dart';

import '../responsive/desktop_layout_helper.dart';
import '../theme/app_theme.dart';
import '../../data/models/api_response.dart';

class TablePaginationBar extends StatelessWidget {
  const TablePaginationBar({
    super.key,
    required this.meta,
    required this.perPage,
    required this.onPageChanged,
    this.onPerPageChanged,
    this.perPageOptions = const [10, 20, 50],
  });

  final PaginationMeta? meta;
  final int perPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPerPageChanged;
  final List<int> perPageOptions;

  @override
  Widget build(BuildContext context) {
    final m = meta;
    final current = m?.currentPage ?? 1;
    final last = m?.lastPage ?? 1;
    final total = m?.total ?? 0;
    final from = total == 0 ? 0 : ((current - 1) * perPage) + 1;
    final to = total == 0 ? 0 : (from + perPage - 1).clamp(0, total);
    final compact = ResponsiveLayout.isMobile(context);

    final pageControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous page',
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          onPressed: current > 1 ? () => onPageChanged(current - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          '$current / $last',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          onPressed: current < last ? () => onPageChanged(current + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: compact
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    total == 0 ? 'No records' : '$from–$to of $total',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                pageControls,
              ],
            )
          : Row(
              children: [
                Text(
                  total == 0 ? 'No records' : 'Showing $from–$to of $total',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (onPerPageChanged != null) ...[
                  const Text('Rows', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: perPageOptions.contains(perPage) ? perPage : perPageOptions.first,
                    underline: const SizedBox.shrink(),
                    items: perPageOptions
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onPerPageChanged!(v);
                    },
                  ),
                  const SizedBox(width: 16),
                ],
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: current > 1 ? () => onPageChanged(current - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  'Page $current of $last',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: current < last ? () => onPageChanged(current + 1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
    );
  }
}
