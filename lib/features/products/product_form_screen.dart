import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/product.dart';
import '../../core/widgets/app_dropdown.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _hsn = TextEditingController();
  final _description = TextEditingController();
  final _purchase = TextEditingController(text: '0');
  final _selling = TextEditingController(text: '0');
  final _mrp = TextEditingController(text: '0');
  final _reorder = TextEditingController(text: '5');

  int? _categoryId;
  int? _brandId;
  int? _unitId;
  double _gstRate = 5;
  String _gstType = 'exclusive';
  bool _trackInventory = true;
  bool _hasBatch = false;
  bool _hasExpiry = false;
  bool _isPetFood = false;
  bool _isService = false;
  bool _isMedicine = false;
  bool _isActive = true;

  String get _productType {
    if (_isService) return 'service';
    if (_isMedicine) return 'medicine';
    return 'product';
  }

  void _setProductType(String type) {
    setState(() {
      _isService = type == 'service';
      _isMedicine = type == 'medicine';
      if (_isService) {
        _trackInventory = false;
      } else if (_isMedicine && !_trackInventory) {
        _trackInventory = true;
      }
    });
  }

  List<Category> _categories = [];
  List<Brand> _brands = [];
  List<Unit> _units = [];

  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.productId != null;

  static const _gstRates = <double>[0, 5, 12, 18, 28];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final products = context.read<AppServices>().products;
      final results = await Future.wait([
        products.listCategories(),
        products.listBrands(),
        products.listUnits(),
      ]);
      if (!mounted) return;
      _categories = (results[0] as List<Category>).where((c) => c.isActive).toList();
      _brands = (results[1] as List<Brand>).where((b) => b.isActive).toList();
      _units = (results[2] as List<Unit>).where((u) => u.isActive).toList();

      final id = widget.productId;
      if (id != null) {
        final p = await products.get(id);
        if (!mounted) return;
        _applyProduct(p);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.error(context, '$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProduct(Product p) {
    _name.text = p.name;
    _sku.text = p.sku ?? '';
    _barcode.text = p.barcode ?? '';
    _hsn.text = p.hsnCode ?? '';
    _description.text = p.description ?? '';
    _purchase.text = _fmtNum(p.purchasePrice);
    _selling.text = _fmtNum(p.sellingPrice);
    _mrp.text = _fmtNum(p.mrp);
    _reorder.text = p.reorderLevel.toString();
    _categoryId = p.categoryId;
    _brandId = p.brandId;
    _unitId = p.unitId;
    _gstRate = _gstRates.contains(p.gstRate) ? p.gstRate : 5;
    _gstType = p.gstType == 'inclusive' ? 'inclusive' : 'exclusive';
    _trackInventory = p.trackInventory;
    _hasBatch = p.hasBatch;
    _hasExpiry = p.hasExpiry;
    _isPetFood = p.isPetFood;
    _isService = p.isService;
    _isMedicine = p.isMedicine;
    _isActive = p.isActive;
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _hsn.dispose();
    _description.dispose();
    _purchase.dispose();
    _selling.dispose();
    _mrp.dispose();
    _reorder.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) =>
      appFormFieldDecoration(label, hint: hint);

  Widget _twoCol(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  String? _nullIfEmpty(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppMessenger.error(context, 'Product name is required.');
      _tabs.animateTo(0);
      return;
    }

    final purchase = double.tryParse(_purchase.text.trim());
    final selling = double.tryParse(_selling.text.trim());
    final mrp = double.tryParse(_mrp.text.trim());
    if (purchase == null || purchase < 0) {
      AppMessenger.error(context, 'Enter a valid purchase price.');
      _tabs.animateTo(1);
      return;
    }
    if (selling == null || selling < 0) {
      AppMessenger.error(context, 'Enter a valid selling price.');
      _tabs.animateTo(1);
      return;
    }
    if (mrp == null || mrp < 0) {
      AppMessenger.error(context, 'Enter a valid MRP.');
      _tabs.animateTo(1);
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'sku': _nullIfEmpty(_sku.text),
        'barcode': _nullIfEmpty(_barcode.text),
        'hsn_code': _nullIfEmpty(_hsn.text),
        'description': _nullIfEmpty(_description.text),
        'category_id': _categoryId,
        'brand_id': _brandId,
        'unit_id': _unitId,
        'purchase_price': purchase,
        'selling_price': selling,
        'mrp': mrp,
        'gst_rate': _gstRate,
        'gst_type': _gstType,
        'reorder_level': int.tryParse(_reorder.text.trim()) ?? 0,
        'track_inventory': _trackInventory,
        'has_batch': _trackInventory && _hasBatch,
        'has_expiry': _trackInventory && _hasExpiry,
        'is_pet_food': _isPetFood,
        'is_service': _isService,
        'is_medicine': _isMedicine,
        'product_type': _productType,
        'is_active': _isActive,
      };

      final svc = context.read<AppServices>().products;
      if (_isEdit) {
        await svc.update(widget.productId!, body);
        if (mounted) AppMessenger.success(context, 'Product updated');
      } else {
        await svc.create(body);
        if (mounted) AppMessenger.success(context, 'Product created');
      }
      if (mounted && context.canPop()) {
        context.pop();
      } else if (mounted) {
        context.go('/products');
      }
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildBasicTab({required bool wide}) {
    final nameField = TextField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: _dec('Product Name *', hint: 'Enter product name'),
    );
    final skuField = TextField(
      controller: _sku,
      textInputAction: TextInputAction.next,
      decoration: _dec('SKU / Product Code', hint: 'e.g. PF-001'),
    );
    final barcodeField = TextField(
      controller: _barcode,
      textInputAction: TextInputAction.next,
      decoration: _dec('Barcode / EAN', hint: 'Scan or enter barcode'),
    );
    final hsnField = TextField(
      controller: _hsn,
      inputFormatters: [LengthLimitingTextInputFormatter(8)],
      textInputAction: TextInputAction.next,
      decoration: _dec('HSN Code', hint: 'HSN code for GST'),
    );
    final unitField = AppDropdownButtonFormField<int?>(
      value: _units.any((u) => u.id == _unitId) ? _unitId : null,
      decoration: _dec('Unit', hint: 'Select unit'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Select unit')),
        ..._units.map(
          (u) => DropdownMenuItem(
            value: u.id,
            child: Text('${u.name} (${u.abbreviation})'),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _unitId = v),
    );
    final categoryField = AppDropdownButtonFormField<int?>(
      value: _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
      decoration: _dec('Category', hint: 'Select category'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Select category')),
        ..._categories.map(
          (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
        ),
      ],
      onChanged: (v) => setState(() => _categoryId = v),
    );
    final brandField = AppDropdownButtonFormField<int?>(
      value: _brands.any((b) => b.id == _brandId) ? _brandId : null,
      decoration: _dec('Brand', hint: 'Select brand'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Select brand')),
        ..._brands.map(
          (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
        ),
      ],
      onChanged: (v) => setState(() => _brandId = v),
    );
    final descField = TextField(
      controller: _description,
      maxLines: 2,
      decoration: _dec('Description', hint: 'Optional description'),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _sectionTitle('BASIC INFO'),
        nameField,
        const SizedBox(height: 12),
        if (wide) ...[
          _twoCol(skuField, barcodeField),
          const SizedBox(height: 12),
          _twoCol(hsnField, unitField),
          const SizedBox(height: 12),
          _twoCol(categoryField, brandField),
        ] else ...[
          skuField,
          const SizedBox(height: 12),
          barcodeField,
          const SizedBox(height: 12),
          hsnField,
          const SizedBox(height: 12),
          unitField,
          const SizedBox(height: 12),
          categoryField,
          const SizedBox(height: 12),
          brandField,
        ],
        const SizedBox(height: 12),
        descField,
        const SizedBox(height: 16),
        Text('Product type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'product', label: Text('Product'), icon: Icon(Icons.inventory_2_outlined, size: 16)),
            ButtonSegment(value: 'medicine', label: Text('Medicine'), icon: Icon(Icons.medication_outlined, size: 16)),
            ButtonSegment(value: 'service', label: Text('Service'), icon: Icon(Icons.miscellaneous_services_outlined, size: 16)),
          ],
          selected: {_productType},
          onSelectionChanged: (s) => _setProductType(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          _productType == 'medicine'
              ? 'Medicines track stock and are used on visit prescriptions.'
              : _productType == 'service'
                  ? 'Services have no stock and can be billed on visits directly.'
                  : 'Standard sellable product.',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pet food'),
          value: _isPetFood,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _isPetFood = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          subtitle: Text(_isActive ? 'Visible in POS & catalogs' : 'Hidden from sales'),
          value: _isActive,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }

  Widget _buildPricingTab({required bool wide}) {
    final purchaseField = TextField(
      controller: _purchase,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: _dec('Purchase Price (₹) *', hint: '0.00'),
    );
    final sellingField = TextField(
      controller: _selling,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: _dec('Selling Price (₹) *', hint: '0.00'),
    );
    final mrpField = TextField(
      controller: _mrp,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: _dec('MRP (₹) *', hint: '0.00'),
    );
    final gstField = AppDropdownButtonFormField<double>(
      value: _gstRate,
      decoration: _dec('GST Rate (%)'),
      items: _gstRates
          .map((r) => DropdownMenuItem(value: r, child: Text('${r.toInt()}%')))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _gstRate = v);
      },
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _sectionTitle('PRICING & TAX'),
        if (wide) ...[
          _twoCol(purchaseField, sellingField),
          const SizedBox(height: 12),
          _twoCol(mrpField, gstField),
        ] else ...[
          purchaseField,
          const SizedBox(height: 12),
          sellingField,
          const SizedBox(height: 12),
          mrpField,
          const SizedBox(height: 12),
          gstField,
        ],
        const SizedBox(height: 16),
        Text('GST Type', style: Theme.of(context).inputDecorationTheme.labelStyle),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'exclusive',
              label: Text('Exclusive'),
              tooltip: 'GST added on top',
            ),
            ButtonSegment(
              value: 'inclusive',
              label: Text('Inclusive'),
              tooltip: 'Price includes GST',
            ),
          ],
          selected: {_gstType},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _gstType = s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return AppTheme.textSecondary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return AppTheme.primary;
              return Colors.white;
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _gstType == 'inclusive'
              ? 'Price includes GST'
              : 'GST added on top of selling price',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _sectionTitle('INVENTORY'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Track inventory'),
          subtitle: Text(
            _trackInventory ? 'Yes — track stock' : 'No — unlimited stock',
          ),
          value: _trackInventory,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() {
            _trackInventory = v;
            if (!v) {
              _hasBatch = false;
              _hasExpiry = false;
            }
          }),
        ),
        if (_trackInventory) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _reorder,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec('Reorder Level', hint: 'Alert below this quantity'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Has batch tracking'),
            value: _hasBatch,
            activeColor: AppTheme.primary,
            onChanged: (v) => setState(() => _hasBatch = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Has expiry date'),
            value: _hasExpiry,
            activeColor: AppTheme.primary,
            onChanged: (v) => setState(() => _hasExpiry = v),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppConfig.usesLargeUiScale ||
        MediaQuery.sizeOf(context).width >= AppConfig.mobileCompactBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Product' : 'Add Product'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Basic Info'),
            Tab(text: 'Pricing & Tax'),
            Tab(text: 'Inventory'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildBasicTab(wide: wide),
                      _buildPricingTab(wide: wide),
                      _buildInventoryTab(),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/products');
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              fixedSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              fixedSize: const Size.fromHeight(48),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_isEdit ? 'Update Product' : 'Create Product'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
