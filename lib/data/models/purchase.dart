class Supplier {
  Supplier({
    required this.id,
    required this.name,
    this.companyName,
    this.email,
    required this.phone,
    this.gstin,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? companyName;
  final String? email;
  final String phone;
  final String? gstin;
  final bool isActive;

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        companyName: j['company_name']?.toString(),
        email: j['email']?.toString(),
        phone: j['phone']?.toString() ?? '',
        gstin: j['gstin']?.toString(),
        isActive: j['is_active'] as bool? ?? true,
      );
}

class Purchase {
  Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.status,
    required this.purchaseDate,
    required this.totalAmount,
    this.supplier,
  });

  final int id;
  final String purchaseNumber;
  final int supplierId;
  final String status;
  final String purchaseDate;
  final double totalAmount;
  final Supplier? supplier;

  factory Purchase.fromJson(Map<String, dynamic> j) {
    Supplier? s;
    if (j['supplier'] is Map) {
      s = Supplier.fromJson(Map<String, dynamic>.from(j['supplier'] as Map));
    }
    return Purchase(
      id: (j['id'] as num?)?.toInt() ?? 0,
      purchaseNumber: j['purchase_number']?.toString() ?? '',
      supplierId: (j['supplier_id'] as num?)?.toInt() ?? 0,
      status: j['status']?.toString() ?? 'draft',
      purchaseDate: j['purchase_date']?.toString() ?? '',
      totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
      supplier: s,
    );
  }
}
