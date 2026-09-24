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
    this.settings,
    this.clinicType = 'veterinary',
    this.facilityType = 'clinic',
    this.capabilities = const [],
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
  final ShopSettings? settings;
  final String clinicType;
  final String facilityType;
  final List<String> capabilities;

  bool hasCapability(String capability) => capabilities.contains(capability);

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
        clinicType: j['clinic_type']?.toString() ?? 'veterinary',
        facilityType: j['facility_type']?.toString() ?? 'clinic',
        capabilities: (j['capabilities'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [],
        settings: j['settings'] is Map
            ? ShopSettings.fromJson(
                Map<String, dynamic>.from(j['settings'] as Map))
            : null,
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
    this.currency = 'INR',
    this.timezone = 'Asia/Kolkata',
    this.invoicePrefix = 'INV',
    this.invoiceStartNumber = 1,
    this.enableLoyalty = false,
    this.loyaltyEarnPerAmount = 100,
    this.loyaltyRedeemPerPoint = 0.25,
    this.loyaltyRedemptionMinPoints = 100,
    this.loyaltyMaxRedeemPercent = 10,
    this.enableGst = true,
    this.defaultGstRate = 18,
    this.thermalWidth = 80,
    this.showMrpOnInvoice = true,
  });

  final String currency;
  final String timezone;
  final String invoicePrefix;
  final int invoiceStartNumber;
  final bool enableLoyalty;

  /// ₹ spent to earn 1 point (maps to loyalty_programs.earn_per_amount).
  final double loyaltyEarnPerAmount;

  /// ₹ value of 1 point when redeeming.
  final double loyaltyRedeemPerPoint;
  final int loyaltyRedemptionMinPoints;
  final double loyaltyMaxRedeemPercent;
  final bool enableGst;
  final double defaultGstRate;
  final int thermalWidth;
  final bool showMrpOnInvoice;

  factory ShopSettings.fromJson(Map<String, dynamic> j) {
    double earn = (j['loyalty_earn_per_amount'] as num?)?.toDouble() ?? 0;
    if (earn <= 0) {
      final ppr = (j['loyalty_points_per_rupee'] as num?)?.toDouble() ?? 0;
      earn = ppr > 0 ? (1 / ppr) : 100;
    }
    return ShopSettings(
      currency: j['currency']?.toString() ?? 'INR',
      timezone: j['timezone']?.toString() ?? 'Asia/Kolkata',
      invoicePrefix: j['invoice_prefix']?.toString() ?? 'INV',
      invoiceStartNumber: (j['invoice_start_number'] as num?)?.toInt() ?? 1,
      enableLoyalty: j['enable_loyalty'] as bool? ?? false,
      loyaltyEarnPerAmount: earn,
      loyaltyRedeemPerPoint:
          (j['loyalty_redeem_per_point'] as num?)?.toDouble() ?? 0.25,
      loyaltyRedemptionMinPoints:
          (j['loyalty_redemption_min_points'] as num?)?.toInt() ?? 100,
      loyaltyMaxRedeemPercent:
          (j['loyalty_max_redeem_percent'] as num?)?.toDouble() ?? 10,
      enableGst: j['enable_gst'] as bool? ?? true,
      defaultGstRate: (j['default_gst_rate'] as num?)?.toDouble() ?? 18,
      thermalWidth: (j['thermal_width'] as num?)?.toInt() ?? 80,
      showMrpOnInvoice: j['show_mrp_on_invoice'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'timezone': timezone,
        'invoice_prefix': invoicePrefix,
        'invoice_start_number': invoiceStartNumber,
        'enable_loyalty': enableLoyalty,
        'loyalty_earn_per_amount': loyaltyEarnPerAmount,
        'loyalty_redeem_per_point': loyaltyRedeemPerPoint,
        'loyalty_redemption_min_points': loyaltyRedemptionMinPoints,
        'loyalty_max_redeem_percent': loyaltyMaxRedeemPercent,
        'enable_gst': enableGst,
        'default_gst_rate': defaultGstRate,
        'thermal_width': thermalWidth,
        'show_mrp_on_invoice': showMrpOnInvoice,
      };

  ShopSettings copyWith({
    bool? enableLoyalty,
    double? loyaltyEarnPerAmount,
    double? loyaltyRedeemPerPoint,
    int? loyaltyRedemptionMinPoints,
    double? loyaltyMaxRedeemPercent,
  }) =>
      ShopSettings(
        currency: currency,
        timezone: timezone,
        invoicePrefix: invoicePrefix,
        invoiceStartNumber: invoiceStartNumber,
        enableLoyalty: enableLoyalty ?? this.enableLoyalty,
        loyaltyEarnPerAmount: loyaltyEarnPerAmount ?? this.loyaltyEarnPerAmount,
        loyaltyRedeemPerPoint:
            loyaltyRedeemPerPoint ?? this.loyaltyRedeemPerPoint,
        loyaltyRedemptionMinPoints:
            loyaltyRedemptionMinPoints ?? this.loyaltyRedemptionMinPoints,
        loyaltyMaxRedeemPercent:
            loyaltyMaxRedeemPercent ?? this.loyaltyMaxRedeemPercent,
        enableGst: enableGst,
        defaultGstRate: defaultGstRate,
        thermalWidth: thermalWidth,
        showMrpOnInvoice: showMrpOnInvoice,
      );
}
