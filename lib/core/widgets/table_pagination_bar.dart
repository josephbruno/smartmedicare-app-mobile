import 'package:flutter/material.dart';

import '../responsive/desktop_layout_helper.dart';
import '../theme/app_theme.dart';
import '../../data/models/api_response.dart';
import 'app_dropdown.dart';

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

    Widget pageBtn({
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        iconSize: 18,
        icon: Icon(icon),
      );
    }

    final pageControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pageBtn(
          tooltip: 'Previous page',
          icon: Icons.chevron_left_rounded,
          onPressed: current > 1 ? () => onPageChanged(current - 1) : null,
        ),
        Text(
          compact ? '$current / $last' : 'Page $current of $last',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        pageBtn(
          tooltip: 'Next page',
          icon: Icons.chevron_right_rounded,
          onPressed: current < last ? () => onPageChanged(current + 1) : null,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: 4,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              total == 0
                  ? 'No records'
                  : compact
                      ? '$from–$to of $total'
                      : 'Showing $from–$to of $total',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!compact && onPerPageChanged != null) ...[
            const Text(
              'Rows',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 6),
            AppDropdownButton<int>(
              value: perPageOptions.contains(perPage)
                  ? perPage
                  : perPageOptions.first,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              items: perPageOptions
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
              onChanged: (v) {
                if (v != null) onPerPageChanged!(v);
              },
            ),
            const SizedBox(width: 8),
          ],
          pageControls,
        ],
      ),
    );
  }
}
