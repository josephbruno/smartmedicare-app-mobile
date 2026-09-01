import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
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

  Color _statusColor(String s) {
    switch (s) {
      case 'received':
      case 'accepted':
        return AppTheme.accent;
      case 'approved':
      case 'dispatched':
        return AppTheme.primary;
      case 'requested':
      case 'pending':
        return AppTheme.warning;
      case 'rejected':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
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

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final canCreate = context.watch<AuthSession>().hasPermission(AppPermissions.inventoryTransfer);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Stock Transfers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () async {
                      await context.push('/stock-transfers/new');
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Request'),
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Request'),
              Tab(text: 'Outgoing'),
              Tab(text: 'Incoming'),
            ],
          ),
          Expanded(
            child: AppPaginatedTable<StockTransfer>(
              key: ValueKey(_direction),
              headerFontSize: 9,
              cellFontSize: 12,
              loadPage: ({required page, required perPage}) =>
                  services.inventory.listTransfersPaginated(
                    page: page,
                    perPage: perPage,
                    direction: _direction,
                  ),
              onRowTap: (t) => context.push('/stock-transfers/${t.id}'),
              columns: [
                TableColumnDef(
                  label: 'Transfer #',
                  flex: 1.2,
                  cellBuilder: (c, t) => Text(
                    t.transferNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TableColumnDef(
                  label: _otherBranchLabel(),
                  flex: 1.3,
                  cellBuilder: (c, t) => Text(_otherBranchName(t)),
                ),
                TableColumnDef(
                  label: 'Items',
                  flex: 0.7,
                  align: TextAlign.center,
                  cellBuilder: (c, t) => Text('${t.items.length}'),
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 1.1,
                  align: TextAlign.center,
                  cellBuilder: (c, t) {
                    final color = _statusColor(t.status);
                    return Text(
                      t.status,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
