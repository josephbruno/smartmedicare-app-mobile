import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/expense.dart';

/// Expenses — mirrors `frontend/src/pages/expense/ExpenseListPage.vue`:
/// date range + category + "Manage categories" drawer + Add, four KPIs,
/// category tabs, search, payment-mode filter, sortable table.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  int? _categoryId;
  String? _mode;
  String? _dateFrom;
  String? _dateTo;
  String _sortBy = 'date';
  bool _sortAsc = false;
  int _reloadToken = 0;
  PaginationMetaView _meta = const PaginationMetaView();
  List<ExpenseCategory> _categories = [];

  static const _modeLabels = {
    'cash': 'Cash',
    'upi': 'UPI',
    'card': 'Card',
    'bank_transfer': 'Bank Transfer',
    'cheque': 'Cheque',
    'other': 'Other',
  };
  static final _fmt2 = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await context.read<AppServices>().expenses.categories();
      if (mounted) setState(() => _categories = list);
    } catch (_) {}
  }

  void _reload() => setState(() => _reloadToken++);

  void _setCategory(int? id) {
    _categoryId = id;
    _reload();
  }

  void _onSort(String key) {
    if (_sortBy == key) {
      _sortAsc = !_sortAsc;
    } else {
      _sortBy = key;
      _sortAsc = false;
    }
    _reload();
  }

  Future<void> _openForm([Expense? expense]) async {
    final bool? saved;
    if (useCenteredFormDialog(context)) {
      saved = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => _ExpenseFormHost(asDialog: true, expense: expense),
      );
    } else {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ExpenseFormHost(asDialog: false, expense: expense),
      );
    }
    if (saved == true && mounted) {
      AppMessenger.success(context, expense == null ? 'Expense saved successfully' : 'Expense updated');
      _reload();
    }
  }

  Future<void> _delete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense'),
        content: Text('Delete ${e.expenseNumber}? This cannot be undone.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().expenses.delete(e.id);
      if (!mounted) return;
      AppMessenger.success(context, 'Expense deleted');
      _reload();
    } catch (err) {
      if (mounted) AppMessenger.error(context, 'Failed to delete expense: $err');
    }
  }

  /// Right-side drawer (web `ExpenseCategoriesDrawer`).
  Future<void> _manageCategories(bool canCreate) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x730F172A),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) {
        final w = MediaQuery.sizeOf(ctx).width;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            child: SizedBox(
              width: w < 480 ? w : 440,
              height: double.infinity,
              child: SafeArea(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                    child: Row(children: [
                      const Expanded(
                        child: Text('Manage Expense Categories',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTokens.text1)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ]),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Categories group your expenses in reports and filters. Deactivate one to hide it from new expenses without losing history.',
                      style: TextStyle(fontSize: 13, color: AppTokens.text3),
                    ),
                  ),
                  Expanded(child: ExpenseCategoriesTab(canCreate: canCreate)),
                ]),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    );
    if (mounted) {
      await _loadCategories();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.expensesCreate);
    final canEdit = auth.hasPermission(AppPermissions.expensesEdit);
    final canDelete = auth.hasPermission(AppPermissions.expensesDelete);
    final top = (_meta.meta?.raw['summary'] is Map) ? (_meta.meta!.raw['summary'] as Map)['top_category'] : null;
    final hasChange = (_meta.meta?.raw['summary'] is Map) && (_meta.meta!.raw['summary'] as Map)['change'] != null;
    final activeCats = _categories.where((c) => c.isActive).toList();
    final tabCats = activeCats.take(6).toList();
    final moreCats = activeCats.skip(6).toList();

    Widget chip(String label, bool active, VoidCallback onTap, {Color? dot}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            selected: active,
            onSelected: (_) => onTap(),
            showCheckmark: false,
            selectedColor: AppTokens.primaryLight,
            side: BorderSide(color: active ? AppTokens.primary : AppTokens.border),
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              if (dot != null) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? AppTokens.primary : AppTokens.text2)),
            ]),
          ),
        );

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Expenses',
        subtitle:
            'Manage and track all clinic expenses in one place${auth.currentBranch != null ? ' · ${auth.currentBranch!.name}' : ''}.',
        icon: Icons.account_balance_wallet_outlined,
        breadcrumbs: const [Crumb('Finance'), Crumb('Expenses')],
        actions: [
          OutlinedButton.icon(
            onPressed: () => _manageCategories(canCreate),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('Manage categories'),
          ),
          if (canCreate) FilledButton(onPressed: () => _openForm(), child: const Text('Add Expense')),
        ],
        kpis: [
          KpiData(
            label: 'Total Expenses',
            value: '₹${_fmt2.format(_meta.summaryNum('total_amount'))}',
            icon: Icons.account_balance_wallet_outlined,
            tone: KpiTone.red,
            sub: hasChange ? 'vs previous period' : 'selected filters',
          ),
          KpiData(
            label: 'This Period',
            value: '${_meta.summaryNum('count').toInt()}',
            icon: Icons.receipt_long_outlined,
            sub: 'Total expenses',
          ),
          KpiData(
            label: 'Avg. Expense',
            value: '₹${_fmt2.format(_meta.summaryNum('avg_amount'))}',
            icon: Icons.analytics_outlined,
            tone: KpiTone.purple,
            sub: 'per expense',
          ),
          KpiData(
            label: 'Top Category',
            value: top is Map ? '${top['name'] ?? '—'}' : '—',
            icon: Icons.emoji_events_outlined,
            tone: KpiTone.orange,
            sub: top is Map
                ? '₹${_fmt2.format((top['amount'] as num?) ?? 0)} (${top['share'] ?? 0}%)'
                : null,
          ),
        ],
        filters: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilterCard(
            searchController: _search,
            searchHint: 'Search expenses...',
            onSearchChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                if (!mounted) return;
                _appliedSearch = v.trim();
                _reload();
              });
            },
            filters: [
              FilterSelect<int>(
                hint: 'All Categories',
                options: {for (final c in _categories) c.id: c.name},
                value: _categoryId,
                onChanged: _setCategory,
              ),
              FilterSelect<String>(
                hint: 'All payment modes',
                options: _modeLabels,
                value: _mode,
                onChanged: (v) {
                  _mode = v;
                  _reload();
                },
              ),
            ],
            trailing: [
              DateRangeFilter(
                from: _dateFrom,
                to: _dateTo,
                onChanged: (f, t) {
                  _dateFrom = f;
                  _dateTo = t;
                  _reload();
                },
              ),
            ],
            onReset: () {
              _search.clear();
              _appliedSearch = '';
              _categoryId = null;
              _mode = null;
              _dateFrom = null;
              _dateTo = null;
              _reload();
            },
            resetEnabled: _appliedSearch.isNotEmpty || _categoryId != null || _mode != null || _dateFrom != null,
          ),
          // Category tabs (All · first six · More ▾).
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                chip('All', _categoryId == null, () => _setCategory(null)),
                for (final c in tabCats)
                  chip(c.name, _categoryId == c.id, () => _setCategory(c.id), dot: _parseColor(c.color)),
                if (moreCats.isNotEmpty)
                  PopupMenuButton<int>(
                    onSelected: _setCategory,
                    itemBuilder: (_) => [for (final c in moreCats) PopupMenuItem(value: c.id, child: Text(c.name))],
                    child: chip(
                      moreCats.any((c) => c.id == _categoryId)
                          ? moreCats.firstWhere((c) => c.id == _categoryId).name
                          : 'More ▾',
                      moreCats.any((c) => c.id == _categoryId),
                      () {},
                    ),
                  ),
              ]),
            ),
          ),
        ]),
        body: AppPaginatedTable<Expense>(
          key: ValueKey('expenses-$_reloadToken'),
          perPage: 15,
          emptyMessage: 'No expenses found',
          loadPage: ({required page, required perPage}) => services.expenses.listPaginated(
            page: page,
            perPage: perPage,
            search: _appliedSearch,
            filters: {
              'category_id': _categoryId,
              'payment_mode': _mode,
              'date_from': _dateFrom,
              'date_to': _dateTo,
              'sort_by': _sortBy,
              'sort_dir': _sortAsc ? 'asc' : 'desc',
            },
          ),
          onLoaded: (m) {
            if (mounted) setState(() => _meta = PaginationMetaView(m));
          },
          sortKey: _sortBy,
          sortAsc: _sortAsc,
          onSort: _onSort,
          onRowTap: canEdit ? _openForm : null,
          columns: [
            TableColumnDef(label: 'Date', flex: 1, minWidth: 110, sortKey: 'date', cellBuilder: (_, e) => Text(e.expenseDate)),
            TableColumnDef(
              label: 'Expense #',
              flex: 1.2,
              minWidth: 120,
              cellBuilder: (_, e) =>
                  Text(e.expenseNumber, style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w600)),
            ),
            TableColumnDef(
              label: 'Description',
              flex: 2.2,
              minWidth: 200,
              cellBuilder: (_, e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.description ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ((e.referenceNumber ?? '').isNotEmpty)
                    Text('Ref: ${e.referenceNumber}', style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                ],
              ),
            ),
            TableColumnDef(
              label: 'Category',
              flex: 1.4,
              minWidth: 140,
              cellBuilder: (_, e) => e.category == null
                  ? const Text('—', style: TextStyle(color: AppTokens.text3))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: _parseColor(e.category!.color) ?? AppTokens.placeholder, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(e.category!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
            ),
            TableColumnDef(
              label: 'Mode',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, e) => StatusPill(_modeLabels[e.paymentMode] ?? (e.paymentMode ?? '—'), tone: PillTone.grey),
            ),
            TableColumnDef(
              label: 'Amount (₹)',
              flex: 1.1,
              minWidth: 110,
              align: TextAlign.right,
              sortKey: 'amount',
              cellBuilder: (_, e) => Text('₹${_fmt2.format(e.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, e) => Row(mainAxisSize: MainAxisSize.min, children: [
                if (canEdit) TableIconButton(icon: Icons.edit_outlined, tooltip: 'Edit', onPressed: () => _openForm(e)),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  TableIconButton(
                      icon: Icons.delete_outline, tooltip: 'Delete', plain: true, color: AppTokens.error, onPressed: () => _delete(e)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

Color? _parseColor(String? hex) {
  if (hex == null || !hex.startsWith('#') || (hex.length != 7)) return null;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class ExpenseCategoriesTab extends StatefulWidget {
  const ExpenseCategoriesTab({super.key, required this.canCreate});

  final bool canCreate;

  @override
  State<ExpenseCategoriesTab> createState() => _ExpenseCategoriesTabState();
}

class _ExpenseCategoriesTabState extends State<ExpenseCategoriesTab> {
  List<ExpenseCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<AppServices>().expenses.categories();
      if (mounted) setState(() => _categories = list);
    } catch (e) {
      if (mounted) {
        AppMessenger.error(context, 'Failed to load categories: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({ExpenseCategory? category}) async {
    final isEdit = category != null;
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    var isActive = category?.isActive ?? true;

    Widget buildFields(void Function(VoidCallback) setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: appFormFieldDecoration('Name *', hint: 'e.g. Utilities'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: isActive,
            onChanged: (v) => setLocal(() => isActive = v),
          ),
        ],
      );
    }

    final title = isEdit ? 'Edit Category' : 'Add Category';
    final bool? saved;
    if (useCenteredFormDialog(context)) {
      saved = await showAppAlertForm<bool>(
        context: context,
        title: title,
        icon: Icons.category_outlined,
        content: StatefulBuilder(
          builder: (ctx, setLocal) => buildFields(setLocal),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      );
    } else {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => AppFormBottomSheetShell(
            title: title,
            icon: Icons.category_outlined,
            onClose: () => Navigator.pop(ctx, false),
            body: buildFields(setSheet),
            footer: AppFormFooter(
              primaryLabel: isEdit ? 'Save' : 'Add',
              onCancel: () => Navigator.pop(ctx, false),
              onSubmit: () => Navigator.pop(ctx, true),
            ),
          ),
        ),
      );
    }

    if (saved != true || !mounted) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      AppMessenger.error(context, 'Name is required');
      return;
    }

    final body = <String, dynamic>{
      'name': name,
      'is_active': isActive,
    };

    try {
      final svc = context.read<AppServices>().expenses;
      if (isEdit) {
        await svc.updateCategory(category.id, body);
      } else {
        await svc.createCategory(body);
      }
      if (!mounted) return;
      AppMessenger.success(
        context,
        isEdit ? 'Category updated successfully' : 'Category created successfully',
      );
      await _load();
    } catch (e) {
      if (mounted) {
        AppMessenger.error(context, 'Failed to save category: $e');
      }
    }
  }

  Future<void> _delete(ExpenseCategory category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'This action cannot be undone. Categories with expenses cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<AppServices>().expenses.deleteCategory(category.id);
      if (!mounted) return;
      AppMessenger.success(context, 'Category deleted successfully');
      await _load();
    } catch (e) {
      if (mounted) {
        AppMessenger.error(context, 'Failed to delete category: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthSession>().hasPermission(AppPermissions.expensesEdit);
    final canDelete =
        context.watch<AuthSession>().hasPermission(AppPermissions.expensesDelete);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (widget.canCreate)
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category'),
                ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _categories.isEmpty && !_loading
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('No expense categories yet')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = _categories[i];
                      return ListTile(
                        title: Text(
                          c.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          c.expensesCount == 1
                              ? '1 expense'
                              : '${c.expensesCount} expenses',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!c.isActive)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Text(
                                  'Inactive',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (canEdit)
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openForm(category: c),
                              ),
                            if (canDelete)
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.danger,
                                ),
                                onPressed: () => _delete(c),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseFormHost extends StatefulWidget {
  const _ExpenseFormHost({required this.asDialog, this.expense});

  final bool asDialog;

  /// When set, the form edits this expense.
  final Expense? expense;

  @override
  State<_ExpenseFormHost> createState() => _ExpenseFormHostState();
}

class _ExpenseFormHostState extends State<_ExpenseFormHost> {
  static final _ymd = DateFormat('yyyy-MM-dd');
  static final _display = DateFormat('d MMM yyyy');

  static const _paymentModes = [
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('card', 'Card'),
    ('bank_transfer', 'Bank Transfer'),
    ('other', 'Other'),
  ];

  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();

  List<ExpenseCategory> _categories = [];
  int? _categoryId;
  String _paymentMode = 'cash';
  DateTime _date = DateTime.now();
  bool _loadingCategories = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _description.text = e.description ?? '';
      _amount.text = e.amount.toStringAsFixed(2);
      _reference.text = e.referenceNumber ?? '';
      _categoryId = e.category?.id;
      _paymentMode = e.paymentMode ?? 'cash';
      _date = DateTime.tryParse((e.rawDate ?? '').length >= 10 ? e.rawDate!.substring(0, 10) : '') ?? _date;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await context.read<AppServices>().expenses.categories();
      if (!mounted) return;
      setState(() {
        _categories = list.where((c) => c.isActive).toList();
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
      AppMessenger.error(context, 'Failed to load categories: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _close([bool saved = false]) => Navigator.pop(context, saved);

  Future<void> _submit() async {
    final description = _description.text.trim();
    final amount = double.tryParse(_amount.text.trim()) ?? 0;

    if (description.isEmpty) {
      AppMessenger.error(context, 'Description is required');
      return;
    }
    if (_categoryId == null) {
      AppMessenger.error(context, 'Category is required');
      return;
    }
    if (amount <= 0) {
      AppMessenger.error(context, 'Amount must be greater than 0');
      return;
    }

    setState(() => _saving = true);
    try {
      final svc = context.read<AppServices>().expenses;
      final body = <String, dynamic>{
        'title': description,
        'description': description,
        'category_id': _categoryId,
        'amount': amount,
        'expense_date': _ymd.format(_date),
        'payment_mode': _paymentMode,
        'reference_number':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      };
      final editing = widget.expense;
      editing == null ? await svc.create(body) : await svc.update(editing.id, body);
      if (!mounted) return;
      // Success toast is shown by the parent after the dialog closes,
      // so it isn't cleared when this route is popped.
      _close(true);
    } catch (e) {
      if (mounted) {
        AppMessenger.error(context, 'Failed to save expense: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget get _fields => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: appFormFieldDecoration(
              'Description *',
              hint: 'What was the expense for?',
            ),
          ),
          const SizedBox(height: 16),
          AppDropdownButtonFormField<int>(
            value: _categoryId,
            decoration: appFormFieldDecoration('Category *'),
            hint: Text(_loadingCategories ? 'Loading…' : 'Select category'),
            items: _categories
                .map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                )
                .toList(),
            onChanged: _loadingCategories
                ? null
                : (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: appFormFieldDecoration('Amount (₹) *', hint: '0.00'),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: appFormFieldDecoration('Date *'),
              child: Row(
                children: [
                  Expanded(child: Text(_display.format(_date))),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppDropdownButtonFormField<String>(
            value: _paymentMode,
            decoration: appFormFieldDecoration('Payment Mode'),
            items: _paymentModes
                .map(
                  (m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _paymentMode = v);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reference,
            decoration: appFormFieldDecoration(
              'Reference Number',
              hint: 'Receipt / bill no.',
            ),
          ),
        ],
      );

  Widget get _footer => AppFormFooter(
        primaryLabel: 'Save Expense',
        saving: _saving,
        onCancel: () => _close(),
        onSubmit: _submit,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) {
      return AppFormDialogShell(
        title: widget.expense == null ? 'Add Expense' : 'Edit Expense',
        icon: Icons.payments_outlined,
        onClose: () => _close(),
        body: _fields,
        footer: _footer,
      );
    }

    return AppFormBottomSheetShell(
      title: widget.expense == null ? 'Add Expense' : 'Edit Expense',
      icon: Icons.payments_outlined,
      onClose: () => _close(),
      body: _fields,
      footer: _footer,
    );
  }
}
