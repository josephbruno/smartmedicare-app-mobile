import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/customer.dart';
import '../../data/models/emr.dart';
import '../../data/models/invoice.dart';
import '../../data/models/product.dart';
import '../../core/utils/gst_utils.dart';

const _kCartDraft = 'pos_cart_draft';

/// POS cart + held bills (port of [frontend/src/stores/cart.ts]).
class PosCartNotifier extends ChangeNotifier {
  PosCartNotifier() {
    _loadDraft();
  }

  final List<CartItem> items = [];
  Customer? customer;
  int discountType = 0;
  double discountValue = 0;
  bool isIgst = false;
  double loyaltyPointsToRedeem = 0;
  final List<CartPayment> payments = [];
  String notes = '';
  final List<HeldBill> heldBills = [];
  int? pendingVisitId;

  double get subtotal =>
      items.fold(0.0, (s, i) => s + i.taxableAmount);

  double get discountAmount {
    if (discountType == 1) {
      return (subtotal * discountValue / 100 * 100).round() / 100;
    }
    if (discountType == 2) return discountValue;
    return 0;
  }

  double get taxableAfterDiscount => subtotal - discountAmount;

  double get totalGst =>
      items.fold(0.0, (s, i) => s + i.cgstAmount + i.sgstAmount);

  double get grandTotal {
    final raw = taxableAfterDiscount + totalGst;
    return raw.roundToDouble();
  }

  double get roundOff {
    final raw = taxableAfterDiscount + totalGst;
    return ((grandTotal - raw) * 100).round() / 100;
  }

  double get totalPaid =>
      payments.fold(0.0, (s, p) => s + p.amount);

  double get changeAmount =>
      (totalPaid - grandTotal) > 0 ? (totalPaid - grandTotal) : 0;

  double get dueAmount =>
      (grandTotal - totalPaid) > 0 ? (grandTotal - totalPaid) : 0;

  int get itemCount =>
      items.fold(0, (s, i) => s + i.quantity);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCartDraft,
      jsonEncode({
        'items': items.map((e) => _cartItemToJson(e)).toList(),
        'customer': customer?.toJson(),
        'discountType': discountType,
        'discountValue': discountValue,
        'payments': payments.map((e) => e.toJson()).toList(),
        'notes': notes,
        'heldBills': heldBills.map((h) => h.toJson()).toList(),
      }),
    );
  }

  void _loadDraft() {
    SharedPreferences.getInstance().then((prefs) {
      final raw = prefs.getString(_kCartDraft);
      if (raw == null || raw.isEmpty) return;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        items.clear();
        if (m['items'] is List) {
          for (final e in m['items'] as List) {
            if (e is Map) {
              items.add(_cartItemFromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
        if (m['customer'] is Map) {
          customer = Customer.fromJson(
            Map<String, dynamic>.from(m['customer'] as Map),
          );
        }
        discountType = (m['discountType'] as num?)?.toInt() ?? 0;
        discountValue = (m['discountValue'] as num?)?.toDouble() ?? 0;
        payments.clear();
        if (m['payments'] is List) {
          for (final e in m['payments'] as List) {
            if (e is Map) {
              final p = Map<String, dynamic>.from(e);
              payments.add(CartPayment(
                mode: p['mode']?.toString() ?? 'cash',
                amount: (p['amount'] as num?)?.toDouble() ?? 0,
                reference: p['reference']?.toString(),
                upiId: p['upi_id']?.toString(),
              ));
            }
          }
        }
        notes = m['notes']?.toString() ?? '';
        heldBills.clear();
        if (m['heldBills'] is List) {
          for (final e in m['heldBills'] as List) {
            if (e is Map) heldBills.add(HeldBill.fromJson(Map<String, dynamic>.from(e)));
          }
        }
        notifyListeners();
      } catch (_) {}
    });
  }

  /// Returns added | incremented | stock_exceeded | out_of_stock
  String addProduct(
    Product product, {
    int quantity = 1,
    int? batchId,
    double? unitPriceOverride,
    String? nameOverride,
    bool mergeExisting = true,
    bool isServiceCharge = false,
  }) {
    final availableStock = product.currentStock ?? 0;
    final trackInventory = product.trackInventory && !product.isService;
    if (trackInventory && availableStock <= 0) return 'out_of_stock';

    CartItem? existing;
    if (mergeExisting) {
      for (final i in items) {
        // Never merge a normal line into a service-charge line (or vice versa),
        // even when product_id matches — visit consultation vs treatment can share a product.
        if (i.productId == product.id &&
            i.batchId == batchId &&
            i.isServiceCharge == isServiceCharge) {
          existing = i;
          break;
        }
      }
    }

    if (existing != null) {
      final idx = items.indexOf(existing);
      existing.availableStock = trackInventory ? availableStock : 99999;
      existing.trackInventory = trackInventory;
      final desired = existing.quantity + quantity;
      if (trackInventory && desired > availableStock.floor()) {
        updateQuantity(idx, availableStock.floor());
        notifyListeners();
        _persist();
        return 'stock_exceeded';
      }
      updateQuantity(idx, desired);
      notifyListeners();
      _persist();
      return 'incremented';
    }

    final cappedQty = trackInventory
        ? (quantity > availableStock.floor()
            ? availableStock.floor()
            : quantity)
        : quantity;
    final unitPrice = unitPriceOverride ?? product.sellingPrice;
    final gstRate = product.gstRate;
    final gstType = product.gstType;
    final unitPriceTaxable = gstType == 'inclusive'
        ? GstUtils.getTaxableFromInclusive(unitPrice, gstRate)
        : unitPrice;
    final taxable = (unitPriceTaxable * cappedQty * 100).round() / 100;
    final gst = GstUtils.calculateGST(taxable, gstRate);
    final lineTotal = gstType == 'inclusive'
        ? unitPrice * cappedQty
        : taxable + gst;

    items.add(CartItem(
      productId: product.id,
      productName: nameOverride ?? product.name,
      barcode: product.barcode,
      hsnCode: product.hsnCode,
      batchId: batchId,
      quantity: cappedQty,
      unitPrice: unitPrice,
      mrp: product.mrp,
      unitPriceTaxable: unitPriceTaxable,
      discountPercent: 0,
      discountAmount: 0,
      taxableAmount: taxable,
      gstType: gstType,
      gstRate: gstRate,
      cgstRate: isIgst ? 0 : gstRate / 2,
      sgstRate: isIgst ? 0 : gstRate / 2,
      cgstAmount: isIgst ? 0 : gst / 2,
      sgstAmount: isIgst ? 0 : gst / 2,
      totalAmount: lineTotal,
      availableStock: trackInventory ? availableStock : 99999,
      trackInventory: trackInventory,
      isServiceCharge: isServiceCharge,
    ));
    notifyListeners();
    _persist();
    return 'added';
  }

  void updateUnitPrice(int index, double newPrice) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    if (newPrice < 0) return;
    item.unitPrice = newPrice;
    final unitPriceTaxable = item.gstType == 'inclusive'
        ? GstUtils.getTaxableFromInclusive(newPrice, item.gstRate)
        : newPrice;
    item.unitPriceTaxable = unitPriceTaxable;
    updateQuantity(index, item.quantity);
  }

  void updateQuantity(int index, int newQty) {
    final item = items[index];
    final trackInventory = item.trackInventory;
    final availableStock = item.availableStock;
    final maxQty = trackInventory ? availableStock : 99999;
    final safeQty = (newQty.abs() < 1 ? 1 : newQty).floor();
    final capped = safeQty > maxQty ? maxQty.toInt() : safeQty;
    final unitPriceTaxable = item.unitPriceTaxable ?? item.unitPrice;
    final gstType = item.gstType;
    final taxable = (unitPriceTaxable *
            capped *
            (1 - item.discountPercent / 100) *
            100)
        .round() /
        100;
    final gst = GstUtils.calculateGST(taxable, item.gstRate);
    final grossLine = item.unitPrice * capped;
    final lineTotal = gstType == 'inclusive'
        ? (grossLine * (1 - item.discountPercent / 100) * 100).round() / 100
        : taxable + gst;

    item.quantity = capped;
    item.discountAmount =
        (item.unitPrice * capped * item.discountPercent / 100 * 100).round() /
            100;
    item.taxableAmount = taxable;
    item.cgstAmount = isIgst ? 0 : gst / 2;
    item.sgstAmount = isIgst ? 0 : gst / 2;
    item.totalAmount = lineTotal;
    notifyListeners();
    _persist();
  }

  void removeItem(int index) {
    items.removeAt(index);
    notifyListeners();
    _persist();
  }

  void setCustomer(Customer? c) {
    customer = c;
    notifyListeners();
    _persist();
  }

  void addPayment(String mode, double amount,
      {String? reference, String? upiId}) {
    payments.add(CartPayment(
      mode: mode,
      amount: amount,
      reference: reference,
      upiId: upiId,
    ));
    notifyListeners();
    _persist();
  }

  void clear({bool wipeDraft = true}) {
    items.clear();
    customer = null;
    discountType = 0;
    discountValue = 0;
    loyaltyPointsToRedeem = 0;
    payments.clear();
    notes = '';
    pendingVisitId = null;
    notifyListeners();
    if (wipeDraft) {
      SharedPreferences.getInstance().then((p) => p.remove(_kCartDraft));
    }
  }

  /// Loads billable treatments/medicines from a visit record into the cart.
  Future<VisitCartLoadResult> loadFromVisit(
    PetVisit visit,
    Future<Product?> Function(int productId) fetchProduct, {
    Future<Product?> Function()? fetchDefaultServiceProduct,
  }) async {
    clear(wipeDraft: true);
    pendingVisitId = visit.id;
    notes = 'Visit ${visit.visitNumber}';

    final skipped = <String>[];
    var linesAdded = 0;

    Future<void> addLine({
      required int? productId,
      Product? embedded,
      required String label,
      required double quantity,
      required double unitPrice,
      bool isServiceCharge = false,
      bool mergeExisting = true,
    }) async {
      Product? product = embedded;
      final resolvedId = productId ?? product?.id;
      // Always refresh from catalog/API — visit-embedded products often omit
      // current_stock (inventory not eager-loaded), which falsely looks like 0.
      if (resolvedId != null && resolvedId > 0) {
        product = await fetchProduct(resolvedId) ?? product;
      }
      if (product == null) {
        skipped.add(label);
        return;
      }
      if (resolvedId == null || resolvedId <= 0) {
        skipped.add(label);
        return;
      }
      final qty = quantity.abs() < 1 ? 1 : quantity.round();
      // Keep visit unit_price as-is (including 0); do not fall back to catalog price.
      final price = unitPrice;
      final result = addProduct(
        product,
        quantity: qty,
        unitPriceOverride: price,
        nameOverride: label,
        mergeExisting: mergeExisting,
        isServiceCharge: isServiceCharge,
        // Do not use a fake/negative batch id — invoices API rejects it.
        batchId: null,
      );
      if (result == 'out_of_stock') {
        skipped.add('$label (out of stock)');
        return;
      }
      linesAdded++;
    }

    if (visit.serviceCharge > 0) {
      Product? serviceProduct = visit.serviceChargeProduct;
      if (serviceProduct == null &&
          visit.serviceChargeProductId != null &&
          visit.serviceChargeProductId! > 0) {
        serviceProduct = await fetchProduct(visit.serviceChargeProductId!);
      }
      if (serviceProduct == null && fetchDefaultServiceProduct != null) {
        serviceProduct = await fetchDefaultServiceProduct();
      }
      // If visit linked a non-consultation service (e.g. Microchipping), prefer a
      // consultation catalog item so consultation and treatments stay distinct.
      if (serviceProduct != null &&
          !_looksLikeConsultationProduct(serviceProduct) &&
          fetchDefaultServiceProduct != null) {
        final preferred = await fetchDefaultServiceProduct();
        if (preferred != null && _looksLikeConsultationProduct(preferred)) {
          serviceProduct = preferred;
        }
      }
      await addLine(
        productId: serviceProduct?.id ?? visit.serviceChargeProductId,
        embedded: serviceProduct,
        label: _serviceChargeLabel(serviceProduct),
        quantity: 1,
        unitPrice: visit.serviceCharge,
        isServiceCharge: true,
        mergeExisting: false,
      );
    }

    for (final t in visit.treatments ?? const <VisitTreatment>[]) {
      await addLine(
        productId: t.productId,
        embedded: t.product,
        label: t.treatmentName,
        quantity: t.quantity,
        unitPrice: t.unitPrice,
        // Keep each visit line distinct; do not collapse into service charge / peers.
        mergeExisting: false,
      );
    }

    for (final m in visit.medicines ?? const <VisitMedicine>[]) {
      await addLine(
        productId: m.productId,
        embedded: m.product,
        label: m.medicineName,
        quantity: m.quantity,
        unitPrice: m.unitPrice,
        mergeExisting: false,
      );
    }

    notifyListeners();
    _persist();
    return VisitCartLoadResult(linesAdded: linesAdded, skipped: skipped);
  }

  static bool _looksLikeConsultationProduct(Product product) {
    final name = product.name.toLowerCase();
    final barcode = (product.barcode ?? '').toUpperCase();
    final sku = (product.sku ?? '').toUpperCase();
    return name.contains('consult') ||
        name.contains('service charge') ||
        barcode == 'SVC-CONSULT' ||
        barcode == 'EMR-CONS' ||
        sku == 'SVC-CONSULT' ||
        sku == 'EMR-CONS';
  }

  static String _serviceChargeLabel(Product? product) {
    if (product == null) return 'Service charge';
    if (_looksLikeConsultationProduct(product)) return product.name;
    return 'Service charge';
  }

  String holdBill() {
    final id = 'hold-${DateTime.now().millisecondsSinceEpoch}';
    heldBills.add(HeldBill(
      id: id,
      items: items.map(_cartItemClone).toList(),
      customer: customer,
      discountType: discountType,
      discountValue: discountValue,
      createdAt: DateTime.now().toIso8601String(),
    ));
    clear(wipeDraft: false);
    notifyListeners();
    _persist();
    return id;
  }

  void restoreHeldBill(String id) {
    HeldBill? held;
    for (final b in heldBills) {
      if (b.id == id) {
        held = b;
        break;
      }
    }
    if (held == null) return;
    items.clear();
    items.addAll(held.items.map(_cartItemClone));
    customer = held.customer;
    discountType = held.discountType;
    discountValue = held.discountValue;
    heldBills.removeWhere((b) => b.id == id);
    notifyListeners();
    _persist();
  }

  Map<String, dynamic> buildCreateInvoicePayload({
    required String invoiceDate,
    String type = 'tax_invoice',
    String? offlineId,
  }) {
    return {
      if (customer != null) 'customer_id': customer!.id,
      if (pendingVisitId != null) 'pet_visit_id': pendingVisitId,
      'type': type,
      'invoice_date': invoiceDate,
      'discount_type': discountType,
      'discount_value': discountValue,
      'is_igst': isIgst,
      if (notes.isNotEmpty) 'notes': notes,
      if (offlineId != null) 'offline_id': offlineId,
      if (loyaltyPointsToRedeem > 0)
        'loyalty_points_redeemed': loyaltyPointsToRedeem.round(),
      'items': items.map((e) => e.toJson()).toList(),
      'payments': payments.map((e) => e.toJson()).toList(),
    };
  }

  void setLoyaltyPointsToRedeem(double points) {
    loyaltyPointsToRedeem = points < 0 ? 0 : points;
    notifyListeners();
  }
}

class VisitCartLoadResult {
  const VisitCartLoadResult({required this.linesAdded, required this.skipped});

  final int linesAdded;
  final List<String> skipped;

  bool get success => linesAdded > 0;
}

class HeldBill {
  HeldBill({
    required this.id,
    required this.items,
    this.customer,
    required this.discountType,
    required this.discountValue,
    required this.createdAt,
  });

  final String id;
  final List<CartItem> items;
  final Customer? customer;
  final int discountType;
  final double discountValue;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((e) => _cartItemToJson(e)).toList(),
        if (customer != null) 'customer': customer!.toJson(),
        'discountType': discountType,
        'discountValue': discountValue,
        'created_at': createdAt,
      };

  factory HeldBill.fromJson(Map<String, dynamic> j) {
    final list = <CartItem>[];
    if (j['items'] is List) {
      for (final e in j['items'] as List) {
        if (e is Map) {
          list.add(_cartItemFromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    Customer? c;
    if (j['customer'] is Map) {
      c = Customer.fromJson(Map<String, dynamic>.from(j['customer'] as Map));
    }
    return HeldBill(
      id: j['id']?.toString() ?? '',
      items: list,
      customer: c,
      discountType: (j['discountType'] as num?)?.toInt() ?? 0,
      discountValue: (j['discountValue'] as num?)?.toDouble() ?? 0,
      createdAt: j['created_at']?.toString() ?? '',
    );
  }
}

Map<String, dynamic> _cartItemToJson(CartItem e) => e.toJson();

CartItem _cartItemFromJson(Map<String, dynamic> j) => CartItem(
      productId: (j['product_id'] as num?)?.toInt() ?? 0,
      productName: j['product_name']?.toString() ?? '',
      barcode: j['barcode']?.toString(),
      hsnCode: j['hsn_code']?.toString(),
      batchId: (j['batch_id'] as num?)?.toInt(),
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (j['unit_price'] as num?)?.toDouble() ?? 0,
      mrp: (j['mrp'] as num?)?.toDouble() ?? 0,
      unitPriceTaxable: (j['unit_price_taxable'] as num?)?.toDouble(),
      discountPercent: (j['discount_percent'] as num?)?.toDouble() ?? 0,
      discountAmount: (j['discount_amount'] as num?)?.toDouble() ?? 0,
      taxableAmount: (j['taxable_amount'] as num?)?.toDouble() ?? 0,
      gstType: j['gst_type']?.toString() ?? 'exclusive',
      gstRate: (j['gst_rate'] as num?)?.toDouble() ?? 0,
      cgstRate: (j['cgst_rate'] as num?)?.toDouble() ?? 0,
      sgstRate: (j['sgst_rate'] as num?)?.toDouble() ?? 0,
      cgstAmount: (j['cgst_amount'] as num?)?.toDouble() ?? 0,
      sgstAmount: (j['sgst_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
      availableStock: (j['available_stock'] as num?)?.toDouble() ?? 99999,
      trackInventory: j['track_inventory'] as bool? ?? false,
      isServiceCharge: j['is_service_charge'] as bool? ?? false,
    );

CartItem _cartItemClone(CartItem e) => _cartItemFromJson(_cartItemToJson(e));
