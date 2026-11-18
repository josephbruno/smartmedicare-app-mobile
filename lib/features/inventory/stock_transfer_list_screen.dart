import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_page.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/stock_transfer.dart';

class StockTransferListScreen extends StatefulWidget {
  const StockTransferListScreen({super.key});

  @override
  State<StockTransferListScreen> createState() =>
      _StockTransferListScreenState();
}

class _StockTransferListScreenState extends State<StockTransferListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _direction = 'request';

  static const _tabDirections = ['request', 'outgoing', 'incoming'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() => _direction = _tabDirections[_tabs.index]);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _otherBranchLabel() {
    switch (_direction) {
      case 'outgoing':
        return 'To';
      default:
        return 'From';
    }
  }

  String _otherBranchName(StockTransfer t) {
    return _direction == 'outgoing'
        ? (t.toBranchName ?? '—')
        : (t.fromBranchName ?? '—');
  }

  static const _directionCards = [
    ('request', 'Transfer Requests', 'Stock this branch has requested from other branches', Icons.call_split, KpiTone.blue),
    ('outgoing', 'Outgoing Transfers', 'Requests other branches sent to this branch — approve and dispatch', Icons.send_outlined, KpiTone.green),
    ('incoming', 'Incoming Transfers', 'Approved stock on its way to this branch — receive it here', Icons.download_outlined, KpiTone.purple),
  ];

  PillTone _statusTone(String s) => switch (s) {
        'received' || 'accepted' => PillTone.green,
        'approved' || 'dispatched' => PillTone.blue,
        'requested' || 'pending' => PillTone.amber,
        'rejected' || 'cancelled' => PillTone.red,
        _ => PillTone.grey,
      };

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate = context.watch<AuthSession>().hasPermission(AppPermissions.inventoryTransfer);

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Stock Transfers',
        subtitle: 'Request, approve, dispatch and receive stock between branches.',
        icon: Icons.swap_horiz,
        breadcrumbs: const [Crumb('Inventory'), Crumb('Stock Transfers')],
        actions: [
          if (canCreate)
            FilledButton(
              onPressed: () async {
                await context.push('/stock-transfers/new');
                if (mounted) setState(() {});
              },
              child: const Text('New Request'),
            ),
        ],
        // Direction cards act as tabs (web `st-dir` cards).
        filters: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth < 768 ? 1 : 3;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (i, d) in _directionCards.indexed)
                SizedBox(
                  width: w,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        _tabs.index = i;
                        setState(() => _direction = d.$1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: _direction == d.$1 ? AppTokens.primary : Colors.transparent, width: 2),
                        ),
                        child: KpiCard(data: KpiData(label: d.$2, value: '', icon: d.$4, tone: d.$5, sub: d.$3)),
                      ),
                    ),
                  ),
                ),
            ]);
          }),
        ),
        body: AppPaginatedTable<StockTransfer>(
          key: ValueKey(_direction),
          perPage: 10,
          emptyMessage: 'No transfers found',
          loadPage: ({required page, required perPage}) => services.inventory.listTransfersPaginated(
            page: page,
            perPage: perPage,
            direction: _direction,
          ),
          onRowTap: (t) => context.push('/stock-transfers/${t.id}'),
          columns: [
            TableColumnDef(
              label: 'Transfer #',
              flex: 1.3,
              minWidth: 130,
              cellBuilder: (c, t) =>
                  Text(t.transferNumber, style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w600)),
            ),
            TableColumnDef(
              label: _otherBranchLabel(),
              flex: 1.6,
              minWidth: 160,
              cellBuilder: (c, t) => Row(children: [
                const Icon(Icons.business_outlined, size: 16, color: AppTokens.text3),
                const SizedBox(width: 8),
                Flexible(child: Text(_otherBranchName(t), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            TableColumnDef(
              label: 'Items',
              flex: 0.7,
              minWidth: 80,
              cellBuilder: (c, t) => Text('${t.items.length}'),
            ),
            TableColumnDef(
              label: 'Status',
              flex: 1.1,
              minWidth: 120,
              cellBuilder: (c, t) {
                final label = t.status.replaceAll('_', ' ');
                return StatusPill(label.isEmpty ? '—' : '${label[0].toUpperCase()}${label.substring(1)}', tone: _statusTone(t.status));
              },
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 0.8,
              minWidth: 90,
              cellBuilder: (c, t) => TableIconButton(
                icon: Icons.visibility_outlined,
                tooltip: 'View details',
                onPressed: () => context.push('/stock-transfers/${t.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
