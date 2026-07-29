import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/expense.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _expensesReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refreshExpenses({String? successMessage}) {
    if (!mounted) return;
    setState(() => _expensesReloadToken++);
    if (successMessage != null) {
      AppMessenger.success(context, successMessage);
    }
  }

  Future<void> _openCreateExpense() async {
    final bool? saved;
    if (useCenteredFormDialog(context)) {
      saved = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => const _ExpenseFormHost(asDialog: true),
      );
    } else {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _ExpenseFormHost(asDialog: false),
      );
    }

    if (saved == true) {
      _refreshExpenses(successMessage: 'Expense saved successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate =
        context.watch<AuthSession>().hasPermission(AppPermissions.expensesCreate);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Categories'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ExpensesTab(
                  reloadToken: _expensesReloadToken,
                  canCreate: canCreate,
                  onAdd: _openCreateExpense,
                ),
                ExpenseCategoriesTab(canCreate: canCreate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({
    required this.reloadToken,
    required this.canCreate,
    required this.onAdd,
  });

  final int reloadToken;
  final bool canCreate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Expense'),
                ),
            ],
          ),
        ),
        Expanded(
          child: AppPaginatedTable<Expense>(
            key: ValueKey('expenses-$reloadToken'),
            loadPage: ({required page, required perPage}) =>
                services.expenses.listPaginated(page: page, perPage: perPage),
            columns: const [
              TableColumnDef(label: 'Expense #', flex: 1.2, cellBuilder: _numberCell),
              TableColumnDef(label: 'Category', flex: 1.5, cellBuilder: _categoryCell),
              TableColumnDef(label: 'Date', flex: 1, cellBuilder: _dateCell),
              TableColumnDef(label: 'Description', flex: 2, cellBuilder: _descCell),
              TableColumnDef(
                label: 'Amount',
                flex: 1,
                align: TextAlign.right,
                cellBuilder: _amountCell,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _numberCell(BuildContext context, Expense e) => Text(
        e.expenseNumber,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );

  static Widget _categoryCell(BuildContext context, Expense e) =>
      Text(e.category?.name ?? '—');

  static Widget _dateCell(BuildContext context, Expense e) => Text(e.expenseDate);

  static Widget _descCell(BuildContext context, Expense e) => Text(
        e.description ?? '—',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _amountCell(BuildContext context, Expense e) => Text(
        '₹${e.amount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
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
                        title: Text(c.name),
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
  const _ExpenseFormHost({required this.asDialog});

  final bool asDialog;

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
      await context.read<AppServices>().expenses.create({
        'title': description,
        'description': description,
        'category_id': _categoryId,
        'amount': amount,
        'expense_date': _ymd.format(_date),
        'payment_mode': _paymentMode,
        'reference_number':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      });
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
        title: 'Add Expense',
        icon: Icons.payments_outlined,
        onClose: () => _close(),
        body: _fields,
        footer: _footer,
      );
    }

    return AppFormBottomSheetShell(
      title: 'Add Expense',
      icon: Icons.payments_outlined,
      onClose: () => _close(),
      body: _fields,
      footer: _footer,
    );
  }
}
