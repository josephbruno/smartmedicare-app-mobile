import 'package:flutter_test/flutter_test.dart';
import 'package:maran/data/json_helpers.dart';
import 'package:maran/data/models/dashboard_data.dart';
import 'package:maran/data/models/emr.dart';
import 'package:maran/data/models/inventory.dart';
import 'package:maran/data/models/invoice.dart';
import 'package:maran/data/models/product.dart';
import 'package:maran/data/models/treatment_under.dart';

void main() {
  group('formatApiDate', () {
    test('parses ISO date at UTC midnight', () {
      expect(formatApiDate('2026-06-26T00:00:00.000000Z'), '2026-06-26');
    });

    test('keeps plain date', () {
      expect(formatApiDate('2026-06-26'), '2026-06-26');
    });

    test('uses local calendar day for IST midnight serialized as UTC', () {
      // 2026-08-23 00:00 Asia/Kolkata == 2026-08-22 18:30 UTC
      final local = DateTime.parse('2026-08-22T18:30:00.000000Z').toLocal();
      final expected =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      expect(formatApiDate('2026-08-22T18:30:00.000000Z'), expected);
    });
  });

  group('formatApiTime', () {
    test('trims seconds', () {
      expect(formatApiTime('09:30:00'), '09:30');
    });
  });

  group('DashboardData', () {
    test('parses reports/dashboard payload', () {
      final data = DashboardData.fromJson({
        'today_sales': {
          'total': 12500,
          'count': 8,
          'paid': 10000,
          'due': 2500,
          'by_mode': {'cash': 6000, 'upi': 4000},
        },
        'monthly_sales': {'total': 240000, 'count': 120},
        'low_stock_count': 3,
        'dead_stock_value': 1500,
        'today_appointments': {'count': 2, 'list': []},
        'upcoming_vaccines': 4,
        'outstanding_dues': 3200,
        'alerts_count': 1,
        'branches': [
          {
            'branch_id': 1,
            'branch_name': 'Main',
            'branch_code': 'MAIN',
            'today_sales': 12500,
            'monthly_sales': 240000,
            'stock_value': 85000,
            'low_stock_count': 3,
          },
        ],
        'branch_count': 1,
        'multi_branch': true,
      });

      expect(data.todaySales.total, 12500);
      expect(data.todaySales.paid, 10000);
      expect(data.monthlySales.count, 120);
      expect(data.outstandingDues, 3200);
      expect(data.todayAppointments.count, 2);
      expect(data.branches?.single.branchName, 'Main');
      expect(data.branches?.single.stockValue, 85000);
    });
  });

  group('PatientAppointment', () {
    test('merges top-level customer into pet', () {
      final appt = PatientAppointment.fromJson({
        'id': 10,
        'pet_id': 5,
        'customer_id': 2,
        'appointment_type': 'consultation',
        'appointment_date': '2026-06-26T00:00:00.000000Z',
        'appointment_time': '10:30:00',
        'status': 'scheduled',
        'pet': {'id': 5, 'name': 'Bruno', 'species': 'Dog'},
        'customer': {'id': 2, 'name': 'John Doe', 'phone': '9876543210'},
        'doctor': {'id': 7, 'name': 'Dr. Smith'},
      });

      expect(appt.displayDate, '2026-06-26');
      expect(appt.displayTime, '10:30');
      expect(appt.pet?.customerName, 'John Doe');
      expect(appt.customer?.phone, '9876543210');
      expect(appt.doctor?.name, 'Dr. Smith');
    });
  });

  group('PetReminder', () {
    test('parses reminder with nested pet and customer', () {
      final reminder = PetReminder.fromJson({
        'id': 1,
        'reminder_type': 'vaccination',
        'due_date': '2026-07-01',
        'title': 'Rabies booster',
        'message': 'Due soon',
        'status': 'pending',
        'pet': {'id': 5, 'name': 'Bruno'},
        'customer': {'id': 2, 'name': 'John Doe', 'phone': '9876543210'},
      });

      expect(reminder.displayDueDate, '2026-07-01');
      expect(reminder.pet?.customerName, 'John Doe');
      expect(reminder.customer?.name, 'John Doe');
    });
  });

  group('Invoice', () {
    test('parses list resource with customer lite', () {
      final inv = Invoice.fromJson({
        'id': 42,
        'invoice_number': 'INV-00042',
        'type': 'tax_invoice',
        'status': 'partial',
        'invoice_date': '2026-06-26',
        'total_amount': 1500,
        'paid_amount': 500,
        'due_amount': 1000,
        'share_token': 'abc',
        'customer': {'id': 3, 'name': 'Jane', 'phone': '9000000000'},
      });

      expect(inv.displayDate, '2026-06-26');
      expect(inv.isUnpaid, isTrue);
      expect(inv.customer?.name, 'Jane');
      expect(inv.dueAmount, 1000);
    });

    test('parses detail resource with items and payments', () {
      final inv = Invoice.fromJson({
        'id': 1,
        'invoice_number': 'INV-00001',
        'type': 'tax_invoice',
        'status': 'paid',
        'invoice_date': '2026-06-01',
        'subtotal': 1000,
        'total_gst': 180,
        'total_amount': 1180,
        'paid_amount': 1180,
        'due_amount': 0,
        'items': [
          {
            'id': 1,
            'product_id': 9,
            'product_name': 'Dog Food',
            'product_type': 'product',
            'quantity': 2,
            'unit_price': 500,
            'total_amount': 1000,
          },
        ],
        'payments': [
          {
            'id': 1,
            'payment_mode': 'cash',
            'amount': 1180,
            'payment_date': '2026-06-01',
            'notes': '{"tendered_amount":1500,"change_return":320}',
          },
        ],
      });

      expect(inv.items?.single.productName, 'Dog Food');
      expect(inv.items?.single.productType, 'product');
      expect(inv.items?.single.productTypeLabel, 'Product');
      expect(inv.payments?.single.paymentMode, 'cash');
      expect(inv.payments?.single.tenderedAmount, 1500);
      expect(inv.payments?.single.changeReturn, 320);
      expect(inv.payments?.single.hasCashTenderDetail, isTrue);
      expect(inv.cashReceivedTotal, 1500);
      expect(inv.changeReturnTotal, 320);
      expect(inv.hasChangeReturn, isTrue);
      expect(inv.hasCashPaymentSummary, isTrue);
      expect(inv.totalGst, 180);
    });

    test('exact cash / upi leave cash summary empty', () {
      final exactCash = Invoice.fromJson({
        'id': 2,
        'invoice_number': 'INV-00002',
        'type': 'tax_invoice',
        'status': 'paid',
        'invoice_date': '2026-06-01',
        'total_amount': 500,
        'paid_amount': 500,
        'due_amount': 0,
        'payments': [
          {
            'id': 1,
            'payment_mode': 'cash',
            'amount': 500,
            'payment_date': '2026-06-01',
          },
        ],
      });
      expect(exactCash.cashReceivedTotal, isNull);
      expect(exactCash.changeReturnTotal, isNull);
      expect(exactCash.hasCashPaymentSummary, isFalse);

      final upi = Invoice.fromJson({
        'id': 3,
        'invoice_number': 'INV-00003',
        'type': 'tax_invoice',
        'status': 'paid',
        'invoice_date': '2026-06-01',
        'total_amount': 500,
        'paid_amount': 500,
        'due_amount': 0,
        'payments': [
          {
            'id': 1,
            'payment_mode': 'upi',
            'amount': 500,
            'payment_date': '2026-06-01',
          },
        ],
      });
      expect(upi.hasCashPaymentSummary, isFalse);

      final partial = Invoice.fromJson({
        'id': 4,
        'invoice_number': 'INV-00004',
        'type': 'tax_invoice',
        'status': 'partial',
        'invoice_date': '2026-06-01',
        'total_amount': 1000,
        'paid_amount': 400,
        'due_amount': 600,
        'payments': [
          {
            'id': 1,
            'payment_mode': 'cash',
            'amount': 400,
            'payment_date': '2026-06-01',
          },
        ],
      });
      expect(partial.hasBalanceDue, isTrue);
      expect(partial.hasCashPaymentSummary, isTrue);
      expect(partial.cashReceivedTotal, isNull);
    });
  });

  group('Inventory', () {
    test('parses inventory row with computed available quantity', () {
      final item = InventoryItem.fromJson({
        'id': 7,
        'product_id': 12,
        'branch_id': 1,
        'quantity': 20,
        'reserved_quantity': 5,
        'product': {'id': 12, 'name': 'Shampoo', 'selling_price': 250},
      });

      expect(item.availableQuantity, 15);
      expect(item.product?.name, 'Shampoo');
    });

    test('parses stock ageing row', () {
      final row = StockAgeingItem.fromJson({
        'inventory_id': 3,
        'product_id': 12,
        'name': 'Shampoo',
        'current_stock': 8,
        'stock_value': 1200,
        'days_since_last_sale': 45,
        'category': {'id': 1, 'name': 'Grooming'},
        'unit': {'id': 1, 'abbreviation': 'pcs'},
      });

      expect(row.inventoryId, 3);
      expect(row.categoryName, 'Grooming');
      expect(row.daysSinceLastSale, 45);
    });

    test('parses monthly snapshot row', () {
      final row = MonthlyAgeingRow.fromJson({
        'product_id': 12,
        'name': 'Dog Bone',
        'sku': 'DOG-B-001',
        'reorder_level': 5,
        'purchase_price': 40,
        'selling_price': 80,
        'current_stock': 3,
        'opening_stock': 3,
        'closing_stock': 3,
        'total_sold': 0,
        'daily_stock': {'2026-07-21': 3},
        'is_dead_stock': true,
        'category': {'name': 'Dog Food'},
        'unit': {'abbreviation': 'pcs'},
      });

      expect(row.productId, 12);
      expect(row.categoryName, 'Dog Food');
      expect(row.hasSnapshot('2026-07-21'), isTrue);
      expect(row.stockOn('2026-07-21'), 3);
      expect(row.hasSnapshot('2026-07-01'), isFalse);
    });
  });

  group('Product', () {
    test('parses POS resource with current stock', () {
      final product = Product.fromJson({
        'id': 5,
        'name': 'Treats',
        'selling_price': 120,
        'mrp': 150,
        'gst_rate': 18,
        'gst_type': 'inclusive',
        'track_inventory': true,
        'current_stock': 12,
      });

      expect(product.gstType, 'inclusive');
      expect(product.currentStock, 12);
    });

    test('parses API decimal fields sent as strings', () {
      final product = Product.fromJson({
        'id': '5',
        'name': 'Dog Food',
        'purchase_price': '80.00',
        'selling_price': '120.50',
        'mrp': '150.00',
        'gst_rate': '18.00',
        'reorder_level': '10',
        'current_stock': '12.5',
      });

      expect(product.id, 5);
      expect(product.sellingPrice, 120.5);
      expect(product.gstRate, 18);
      expect(product.reorderLevel, 10);
      expect(product.currentStock, 12.5);
    });

    test('derives current stock from nested inventory rows', () {
      final product = Product.fromJson({
        'id': 1289,
        'name': 'Zipvit 30ml',
        'track_inventory': true,
        'inventory': [
          {'quantity': 40},
          {'quantity': 60},
        ],
      });

      expect(product.currentStock, 100);
    });

    test('parses treatment under category on medicine products', () {
      final product = Product.fromJson({
        'id': 9,
        'name': 'Amoxicillin',
        'is_medicine': true,
        'treatment_under_category': 'antibiotics',
        'selling_price': 40,
      });

      expect(product.isMedicine, isTrue);
      expect(product.treatmentUnderCategory, 'antibiotics');
    });
  });

  group('TreatmentUnderCategory', () {
    test('falls back to unique for unmapped visit lines', () {
      expect(TreatmentUnderCategory.forVisit(), 'unique');
      expect(
        TreatmentUnderCategory.forVisit(fromProduct: 'fluids'),
        'fluids',
      );
    });

    test('groups medicines by category', () {
      final groups = TreatmentUnderCategory.groupBy(
        [
          VisitMedicine(medicineName: 'Amox', treatmentUnderCategory: 'antibiotics'),
          VisitMedicine(medicineName: 'RL', treatmentUnderCategory: 'fluids'),
          VisitMedicine(medicineName: 'Cef', treatmentUnderCategory: 'antibiotics'),
        ],
        (m) => m.treatmentUnderCategory,
      );

      expect(groups.map((e) => e.key).toList(), ['antibiotics', 'fluids']);
      expect(groups.first.value.map((m) => m.medicineName).toList(), ['Amox', 'Cef']);
    });
  });

  group('VisitMedicine', () {
    test('reads treatment under from line or nested product', () {
      final fromLine = VisitMedicine.fromJson({
        'medicine_name': 'Meloxicam',
        'treatment_under_category': 'nsaids',
        'quantity': 1,
        'unit_price': 20,
      });
      expect(fromLine.treatmentUnderCategory, 'nsaids');

      final fromProduct = VisitMedicine.fromJson({
        'medicine_name': 'Isoflurane',
        'product': {
          'id': 3,
          'name': 'Isoflurane',
          'treatment_under_category': 'anesthetics',
          'selling_price': 90,
        },
      });
      expect(fromProduct.treatmentUnderCategory, 'anesthetics');
    });
  });
}
