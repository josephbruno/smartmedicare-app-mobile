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

    // Web pager (`cl-pager`): ‹ 1 … 4 5 6 … 12 ›, 34px boxes, active = blue.
    Widget box({
      required Widget child,
      VoidCallback? onTap,
      bool active = false,
      String? tooltip,
    }) {
      final w = Material(
        color: active ? AppTheme.primary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: active ? AppTheme.primary : const Color(0xFFE2E8F0)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: compact ? 30 : 34, minHeight: compact ? 30 : 34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Opacity(
                  opacity: onTap == null && !active ? 0.45 : 1,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 13,
                      color: active ? Colors.white : const Color(0xFF334155),
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: IconTheme.merge(
                      data: const IconThemeData(
                          size: 18, color: Color(0xFF334155)),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return tooltip == null ? w : Tooltip(message: tooltip, child: w);
    }

    // Window of page numbers around the current page.
    final pages = <int?>[]; // null = gap
    final window = compact ? 0 : 1;
    for (var p = 1; p <= last; p++) {
      if (p == 1 || p == last || (p - current).abs() <= window) {
        pages.add(p);
      } else if (pages.isNotEmpty && pages.last != null) {
        pages.add(null);
      }
    }

    final pageControls = Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        box(
          tooltip: 'Previous page',
          onTap: current > 1 ? () => onPageChanged(current - 1) : null,
          child: const Icon(Icons.chevron_left_rounded),
        ),
        for (final p in pages)
          p == null
              ? const Text('…', style: TextStyle(color: AppTheme.textSecondary))
              : box(
                  active: p == current,
                  onTap: p == current ? null : () => onPageChanged(p),
                  child: Text('$p'),
                ),
        box(
          tooltip: 'Next page',
          onTap: current < last ? () => onPageChanged(current + 1) : null,
          child: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 12,
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
                fontSize: compact ? 12 : 13,
                color: const Color(0xFF475569),
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
