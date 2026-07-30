import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inventory.dart';
import '../../core/widgets/app_dropdown.dart';
class StockAgeingScreen extends StatefulWidget {
  const StockAgeingScreen({super.key});

  @override
  State<StockAgeingScreen> createState() => _StockAgeingScreenState();
}

class _StockAgeingScreenState extends State<StockAgeingScreen> {
  static const _productColWidth = 180.0;
  static const _dayColWidth = 48.0;
  static const _rowHeight = 56.0;
  static const _headerHeight = 52.0;

  static const _border = Color(0xFFE4E9F0);
  static const _headerBg = Color(0xFFF5F7FA);
  static const _todayBg = Color(0xFFF0FAF5);
  static const _todayHeaderBg = Color(0xFFE8F5E9);
  static const _todayBorder = Color(0xFF18A058);
  static const _weekendBg = Color(0xFFFAFAFA);
  static const _lowStockBg = Color(0xFFFFF3CD);
  static const _lowStockFg = Color(0xFFAD6800);
  static const _missingFg = Color(0xFFB0B8C8);
  static const _metaFg = Color(0xFF8B98B8);

  late final List<_MonthOption> _monthOptions;
  late String _selectedMonth;

  List<MonthlyAgeingRow> _rows = [];
  List<String> _dateRange = [];
  String _monthLabel = '';
  bool _loading = false;
  String? _error;
  int? _boundBranchId;

  final _hHeader = ScrollController();
  final _hBody = ScrollController();
  final _vLeft = ScrollController();
  final _vRight = ScrollController();
  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    _monthOptions = _buildMonthOptions();
    _selectedMonth = _monthOptions.first.value;
    _monthLabel = _monthOptions.first.label;
    _hHeader.addListener(_onHHeader);
    _hBody.addListener(_onHBody);
    _vLeft.addListener(_onVLeft);
    _vRight.addListener(_onVRight);
    _load();
  }

  void _syncBranchScope(int? branchId) {
    if (_boundBranchId == branchId) return;
    final previous = _boundBranchId;
    _boundBranchId = branchId;
    if (previous == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _hHeader.removeListener(_onHHeader);
    _hBody.removeListener(_onHBody);
    _vLeft.removeListener(_onVLeft);
    _vRight.removeListener(_onVRight);
    _hHeader.dispose();
    _hBody.dispose();
    _vLeft.dispose();
    _vRight.dispose();
    super.dispose();
  }

  List<_MonthOption> _buildMonthOptions() {
    final now = DateTime.now();
    final opts = <_MonthOption>[];
    for (var i = 0; i < 13; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      opts.add(_MonthOption(
        value: DateFormat('yyyy-MM').format(d),
        label: DateFormat('MMMM yyyy').format(d),
      ));
    }
    return opts;
  }

  void _onHHeader() {
    if (_syncingH || !_hBody.hasClients) return;
    _syncingH = true;
    _hBody.jumpTo(_hHeader.offset);
    _syncingH = false;
  }

  void _onHBody() {
    if (_syncingH || !_hHeader.hasClients) return;
    _syncingH = true;
    _hHeader.jumpTo(_hBody.offset);
    _syncingH = false;
  }

  void _onVLeft() {
    if (_syncingV || !_vRight.hasClients) return;
    _syncingV = true;
    _vRight.jumpTo(_vLeft.offset);
    _syncingV = false;
  }

  void _onVRight() {
    if (_syncingV || !_vLeft.hasClients) return;
    _syncingV = true;
    _vLeft.jumpTo(_vRight.offset);
    _syncingV = false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<AppServices>().inventory.monthlySnapshot(
            month: _selectedMonth,
          );
      if (!mounted) return;
      setState(() {
        _rows = result.rows;
        _dateRange = result.dateRange;
        _monthLabel = result.monthLabel.isNotEmpty
            ? result.monthLabel
            : _monthOptions
                .firstWhere(
                  (o) => o.value == _selectedMonth,
                  orElse: () => _MonthOption(value: _selectedMonth, label: _selectedMonth),
                )
                .label;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _isToday(String date) => date == _todayKey;

  bool _isWeekend(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
  }

  String _fmtDay(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return '';
    return DateFormat('EEE').format(d);
  }

  String _fmtShortDate(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    return DateFormat('dd MMM').format(d);
  }

  String _stockLabel(MonthlyAgeingRow row, String date) {
    final qty = row.stockOn(date);
    if (qty == null) return '-';
    if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
    return qty.toString();
  }

  bool _isLowStock(MonthlyAgeingRow row, String date) {
    final qty = row.stockOn(date);
    if (qty == null) return false;
    return qty > 0 && row.reorderLevel > 0 && qty <= row.reorderLevel;
  }

  @override
  Widget build(BuildContext context) {
    _syncBranchScope(context.select<AuthSession, int?>((s) => s.currentBranchId));
    return ResponsiveBuilder(
      mobileBuilder: (_) => _buildScaffold(compact: true),
      tabletBuilder: (_) => _buildScaffold(compact: false),
      desktopBuilder: (_) => _buildScaffold(compact: false, padded: true),
    );
  }

  Widget _buildScaffold({required bool compact, bool padded = false}) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(compact: compact),
        Expanded(child: _buildBody(compact: compact)),
      ],
    );

    if (padded) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: body,
        ),
      );
    }
    return body;
  }

  Widget _buildHeader({required bool compact}) {
    Widget monthDropdown({required bool expanded}) {
      final dropdown = DropdownButtonHideUnderline(
        child: AppDropdownButton<String>(
          value: _selectedMonth,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          items: _monthOptions
              .map(
                (o) => DropdownMenuItem(
                  value: o.value,
                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => _monthOptions
              .map(
                (o) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(o.label, overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              )
              .toList(),
          onChanged: _loading
              ? null
              : (v) {
                  if (v == null) return;
                  setState(() => _selectedMonth = v);
                  _load();
                },
        ),
      );

      final field = InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
        ),
        child: dropdown,
      );

      if (expanded) return field;
      return SizedBox(width: 160, child: field);
    }

    final refreshButton = OutlinedButton.icon(
      onPressed: _loading ? null : _load,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh'),
    );

    final monthLabel = Text(
      _monthLabel,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _todayBorder,
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 16, compact ? 12 : 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Daily Stock Count',
            style: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'End-of-day stock count for each product',
            style: TextStyle(fontSize: 12, color: _metaFg),
          ),
          const SizedBox(height: 12),
          if (compact) ...[
            monthDropdown(expanded: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [monthLabel, refreshButton],
            ),
          ] else
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                monthDropdown(expanded: false),
                monthLabel,
                refreshButton,
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBody({required bool compact}) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading stock data…', style: TextStyle(color: _metaFg)),
          ],
        ),
      );
    }

    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'No inventory data found for this branch.',
          style: TextStyle(color: _metaFg, fontSize: 14),
        ),
      );
    }

    final productWidth = compact ? 140.0 : _productColWidth;
    final dayWidth = compact ? 40.0 : _dayColWidth;
    final datesWidth = _dateRange.length * dayWidth;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 8, compact ? 8 : 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            children: [
              SizedBox(
                height: _headerHeight,
                child: Row(
                  children: [
                    _productHeader(productWidth),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hHeader,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: datesWidth,
                          height: _headerHeight,
                          child: Row(
                            children: [
                              for (final date in _dateRange)
                                _dayHeader(date, dayWidth),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 2, color: _border),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: productWidth,
                      child: ListView.builder(
                        controller: _vLeft,
                        itemExtent: _rowHeight,
                        itemCount: _rows.length,
                        itemBuilder: (_, i) => _productCell(_rows[i], productWidth),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hBody,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: datesWidth,
                          child: ListView.builder(
                            controller: _vRight,
                            itemExtent: _rowHeight,
                            itemCount: _rows.length,
                            itemBuilder: (_, i) => SizedBox(
                              width: datesWidth,
                              height: _rowHeight,
                              child: Row(
                                children: [
                                  for (final date in _dateRange)
                                    _dayCell(_rows[i], date, dayWidth),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productHeader(double width) {
    return Container(
      width: width,
      height: _headerHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(right: BorderSide(color: Color(0xFFD4DBE8), width: 2)),
      ),
      child: const Text(
        'Product',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: Color(0xFF6B7A96),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _dayHeader(String date, double width) {
    final today = _isToday(date);
    final weekend = _isWeekend(date);
    return Container(
      width: width,
      height: _headerHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: today
            ? _todayHeaderBg
            : weekend
                ? _weekendBg
                : _headerBg,
        border: Border(
          right: BorderSide(color: today ? _todayBorder : const Color(0xFFE8ECF0)),
          left: today ? const BorderSide(color: _todayBorder, width: 2) : BorderSide.none,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _fmtDay(date),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: today ? _todayBorder : const Color(0xFF6B7A96),
                  height: 1.1,
                ),
              ),
              Text(
                _fmtShortDate(date),
                style: TextStyle(
                  fontSize: 9,
                  color: today ? _todayBorder : _metaFg,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productCell(MonthlyAgeingRow row, double width) {
    final metaParts = <String>[
      if (row.sku != null && row.sku!.isNotEmpty) row.sku!,
      if (row.categoryName != null && row.categoryName!.isNotEmpty) row.categoryName!,
    ];
    return Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFD4DBE8), width: 2),
          bottom: BorderSide(color: Color(0xFFF0F2F5)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF1A1F2E),
              height: 1.2,
            ),
          ),
          if (metaParts.isNotEmpty)
            Text(
              metaParts.join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: _metaFg, height: 1.2),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(MonthlyAgeingRow row, String date, double width) {
    final today = _isToday(date);
    final weekend = _isWeekend(date);
    final missing = !row.hasSnapshot(date);
    final low = _isLowStock(row, date);

    Color? bg;
    if (low) {
      bg = _lowStockBg;
    } else if (today) {
      bg = _todayBg;
    } else if (weekend) {
      bg = _weekendBg;
    }

    Color fg = const Color(0xFF1A1F2E);
    FontWeight weight = FontWeight.w500;
    if (missing) {
      fg = _missingFg;
    } else if (low) {
      fg = _lowStockFg;
      weight = FontWeight.w700;
    }

    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: const BorderSide(color: Color(0xFFF0F2F5)),
          right: BorderSide(color: today ? _todayBorder : const Color(0xFFF0F2F5)),
          left: today ? const BorderSide(color: _todayBorder, width: 2) : BorderSide.none,
        ),
      ),
      child: Text(
        _stockLabel(row, date),
        style: TextStyle(
          fontSize: 12,
          fontWeight: weight,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MonthOption {
  const _MonthOption({required this.value, required this.label});

  final String value;
  final String label;
}
