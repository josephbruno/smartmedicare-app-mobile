class Shop {
  Shop({
    required this.id,
    required this.name,
    this.slug,
    this.phone,
    this.email,
    this.gstin,
    this.address,
    this.logoUrl,
    required this.currency,
    required this.timezone,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? slug;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? address;
  final String? logoUrl;
  final String currency;
  final String timezone;
  final bool isActive;

  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        slug: j['slug']?.toString(),
        phone: j['phone']?.toString(),
        email: j['email']?.toString(),
        gstin: j['gstin']?.toString(),
        address: j['address']?.toString(),
        logoUrl: j['logo_url']?.toString(),
        currency: j['currency']?.toString() ?? 'INR',
        timezone: j['timezone']?.toString() ?? 'Asia/Kolkata',
        isActive: j['is_active'] as bool? ?? true,
      );
}

class BranchSettings {
  BranchSettings({this.invoiceEditCodeConfigured = false});

  final bool invoiceEditCodeConfigured;

  factory BranchSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null) return BranchSettings();
    return BranchSettings(
      invoiceEditCodeConfigured:
          j['invoice_edit_code_configured'] as bool? ?? false,
    );
  }
}

class Branch {
  Branch({
    required this.id,
    required this.shopId,
    required this.name,
    this.code,
    this.phone,
    this.email,
    this.gstin,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.settings,
    required this.isMain,
    required this.isActive,
  });

  final int id;
  final int shopId;
  final String name;
  final String? code;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final BranchSettings? settings;
  final bool isMain;
  final bool isActive;

  String get formattedAddress {
    final parts = [address, city, state, pincode]
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim())
        .toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  bool get invoiceEditCodeConfigured =>
      settings?.invoiceEditCodeConfigured ?? false;

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        id: (j['id'] as num?)?.toInt() ?? 0,
        shopId: (j['shop_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        code: j['code']?.toString(),
        phone: j['phone']?.toString(),
        email: j['email']?.toString(),
        gstin: j['gstin']?.toString(),
        address: j['address']?.toString(),
        city: j['city']?.toString(),
        state: j['state']?.toString(),
        pincode: j['pincode']?.toString(),
        settings: j['settings'] is Map
            ? BranchSettings.fromJson(
                Map<String, dynamic>.from(j['settings'] as Map),
              )
            : null,
        isMain: j['is_main'] as bool? ?? false,
        isActive: j['is_active'] as bool? ?? true,
      );
}

class ShopSettings {
  ShopSettings({
    required this.currency,
    required this.timezone,
    required this.invoicePrefix,
    required this.invoiceStartNumber,
    required this.enableLoyalty,
    required this.enableGst,
    required this.defaultGstRate,
  });

  final String currency;
  final String timezone;
  final String invoicePrefix;
  final int invoiceStartNumber;
  final bool enableLoyalty;
  final bool enableGst;
  final double defaultGstRate;

  factory ShopSettings.fromJson(Map<String, dynamic> j) => ShopSettings(
        currency: j['currency']?.toString() ?? 'INR',
        timezone: j['timezone']?.toString() ?? 'Asia/Kolkata',
        invoicePrefix: j['invoice_prefix']?.toString() ?? 'INV',
        invoiceStartNumber:
            (j['invoice_start_number'] as num?)?.toInt() ?? 1,
        enableLoyalty: j['enable_loyalty'] as bool? ?? false,
        enableGst: j['enable_gst'] as bool? ?? true,
        defaultGstRate: (j['default_gst_rate'] as num?)?.toDouble() ?? 18,
      );
}
