import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/shop.dart';
import '../../data/models/user.dart';
import '../../data/services/settings_service.dart';
import '../session/auth_session.dart';

/// Branch header fields for thermal bill receipts (cached locally).
class ReceiptBranchInfo {
  const ReceiptBranchInfo({
    required this.branchId,
    required this.name,
    this.shopName = '',
    this.address = '',
    this.phone,
    this.gstin,
  });

  final int branchId;
  final String name;
  final String shopName;
  final String address;
  final String? phone;
  final String? gstin;

  Map<String, dynamic> toJson() => {
        'branch_id': branchId,
        'name': name,
        'shop_name': shopName,
        'address': address,
        if (phone != null) 'phone': phone,
        if (gstin != null) 'gstin': gstin,
      };

  factory ReceiptBranchInfo.fromJson(Map<String, dynamic> j) {
    return ReceiptBranchInfo(
      branchId: (j['branch_id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      shopName: j['shop_name']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      phone: j['phone']?.toString(),
      gstin: j['gstin']?.toString(),
    );
  }
}

/// Loads branch name / address / phone / GSTIN from the logged-in branch
/// and keeps a local copy for offline bill printing.
abstract final class ReceiptBranchStore {
  static const _prefsKey = 'receipt_branch_info_v2';

  static Future<ReceiptBranchInfo?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ReceiptBranchInfo.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(ReceiptBranchInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(info.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove('receipt_branch_info_v1');
  }

  static ReceiptBranchInfo? fromBranch(Branch branch) {
    if (branch.id <= 0) return null;
    return ReceiptBranchInfo(
      branchId: branch.id,
      name: branch.name.trim(),
      address: _joinAddress([
        branch.address,
        branch.city,
        branch.state,
        branch.pincode,
      ]),
      phone: branch.phone?.trim(),
      gstin: _cleanGstin(branch.gstin),
    );
  }

  static ReceiptBranchInfo? fromBranchLite(BranchLite? branch) {
    if (branch == null || branch.id <= 0) return null;
    return ReceiptBranchInfo(
      branchId: branch.id,
      name: branch.name.trim(),
      address: branch.formattedAddress,
      phone: branch.phone?.trim(),
      gstin: _cleanGstin(branch.gstin),
    );
  }

  /// Fetch `/branches`, cache the **logged-in** branch, fall back to session lite.
  static Future<ReceiptBranchInfo?> sync({
    required BranchService branches,
    required AuthSession auth,
  }) async {
    final branchId = auth.currentBranchId;
    ReceiptBranchInfo? cached;

    if (branchId != null) {
      try {
        final list = await branches.list();
        final match = list.where((b) => b.id == branchId).firstOrNull;
        if (match != null) {
          cached = fromBranch(match);
        }
      } catch (_) {
        // Offline / no permission — keep previous cache or session fallback.
      }
    }

    cached ??= fromBranchLite(auth.currentBranch);
    cached = _mergeShopFallback(cached, auth.currentShop, branchId);

    if (cached != null) {
      await save(cached);
    }
    return cached;
  }

  /// Header for the logged-in user's current branch (never another branch).
  static Future<ReceiptBranchInfo> resolveForPrint(AuthSession auth) async {
    final branchId = auth.currentBranchId;
    final session = fromBranchLite(auth.currentBranch);
    final cached = await load();

    ReceiptBranchInfo? info;
    if (session != null && session.name.isNotEmpty) {
      info = session;
    } else if (cached != null &&
        (branchId == null || cached.branchId == branchId) &&
        cached.name.trim().isNotEmpty) {
      info = cached;
    }

    info = _mergeShopFallback(info, auth.currentShop, branchId) ??
        ReceiptBranchInfo(
          branchId: branchId ?? 0,
          name: auth.currentShop?.name.trim().isNotEmpty == true
              ? auth.currentShop!.name.trim()
              : 'Maran Veterinary Hospital',
          shopName: auth.currentShop?.name.trim() ?? '',
          address: auth.currentShop?.formattedAddress ?? '',
          phone: auth.currentShop?.phone,
          gstin: _cleanGstin(auth.currentShop?.gstin),
        );

    await save(info);
    return info;
  }

  static ReceiptBranchInfo? _mergeShopFallback(
    ReceiptBranchInfo? cached,
    ShopLite? shop,
    int? branchId,
  ) {
    if (cached != null) {
      final name = cached.name.isNotEmpty ? cached.name : (shop?.name ?? '');
      final address = cached.address.trim().isNotEmpty
          ? cached.address
          : (shop?.formattedAddress ?? '');
      final phone = (cached.phone?.trim().isNotEmpty == true)
          ? cached.phone
          : shop?.phone;
      final gstin = _cleanGstin(cached.gstin) ?? _cleanGstin(shop?.gstin);
      return ReceiptBranchInfo(
        branchId: cached.branchId,
        name: name,
        shopName: shop?.name.trim() ?? cached.shopName,
        address: address,
        phone: phone,
        gstin: gstin,
      );
    }
    if (shop != null && shop.id > 0) {
      return ReceiptBranchInfo(
        branchId: branchId ?? 0,
        name: shop.name,
        shopName: shop.name.trim(),
        address: shop.formattedAddress,
        phone: shop.phone,
        gstin: _cleanGstin(shop.gstin),
      );
    }
    return null;
  }

  static String _joinAddress(List<String?> parts) {
    return parts
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim())
        .join(', ');
  }

  static String? _cleanGstin(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
