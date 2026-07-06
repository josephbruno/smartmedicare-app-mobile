class ShopLite {
  ShopLite({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    this.currency,
    this.timezone,
  });

  final int id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? currency;
  final String? timezone;

  factory ShopLite.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return ShopLite(id: 0, name: '');
    }
    return ShopLite(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      slug: j['slug']?.toString(),
      logoUrl: j['logo_url']?.toString(),
      currency: j['currency']?.toString(),
      timezone: j['timezone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (slug != null) 'slug': slug,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (currency != null) 'currency': currency,
        if (timezone != null) 'timezone': timezone,
      };
}

class BranchLite {
  BranchLite({
    required this.id,
    required this.name,
    this.code,
    this.isMain,
    this.isActive,
  });

  final int id;
  final String name;
  final String? code;
  final bool? isMain;
  final bool? isActive;

  factory BranchLite.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return BranchLite(id: 0, name: '');
    }
    return BranchLite(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      code: j['code']?.toString(),
      isMain: j['is_main'] as bool?,
      isActive: j['is_active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (code != null) 'code': code,
        if (isMain != null) 'is_main': isMain,
        if (isActive != null) 'is_active': isActive,
      };
}

class User {
  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.shopId,
    this.branchId,
    required this.isActive,
    this.hasPin = false,
    required this.language,
    required this.roles,
    required this.permissions,
    this.shop,
    this.branch,
    this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final int? shopId;
  final int? branchId;
  final bool isActive;
  final bool hasPin;
  final String language;
  final List<String> roles;
  final List<String> permissions;
  final ShopLite? shop;
  final BranchLite? branch;
  final String? createdAt;

  factory User.fromJson(Map<String, dynamic> j) {
    List<String> listOf(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return User(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString(),
      avatarUrl: j['avatar_url']?.toString(),
      shopId: (j['shop_id'] as num?)?.toInt(),
      branchId: (j['branch_id'] as num?)?.toInt(),
      isActive: j['is_active'] as bool? ?? true,
      hasPin: j['has_pin'] as bool? ?? false,
      language: j['language']?.toString() ?? 'en',
      roles: listOf(j['roles']),
      permissions: listOf(j['permissions']),
      shop: j['shop'] is Map
          ? ShopLite.fromJson(Map<String, dynamic>.from(j['shop'] as Map))
          : null,
      branch: j['branch'] is Map
          ? BranchLite.fromJson(Map<String, dynamic>.from(j['branch'] as Map))
          : null,
      createdAt: j['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (shopId != null) 'shop_id': shopId,
        if (branchId != null) 'branch_id': branchId,
        'is_active': isActive,
        'has_pin': hasPin,
        'language': language,
        'roles': roles,
        'permissions': permissions,
        if (shop != null) 'shop': shop!.toJson(),
        if (branch != null) 'branch': branch!.toJson(),
        if (createdAt != null) 'created_at': createdAt,
      };
}
