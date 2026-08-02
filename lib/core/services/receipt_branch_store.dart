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
    this.address = '',
    this.phone,
  });

  final int branchId;
  final String name;
  final String address;
  final String? phone;

  Map<String, dynamic> toJson() => {
        'branch_id': branchId,
        'name': name,
        'address': address,
        if (phone != null) 'phone': phone,
      };

  factory ReceiptBranchInfo.fromJson(Map<String, dynamic> j) {
    return ReceiptBranchInfo(
      branchId: (j['branch_id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      phone: j['phone']?.toString(),
    );
  }
}

/// Loads branch name / address / phone from the API and keeps a local copy
/// for offline bill printing.
abstract final class ReceiptBranchStore {
  static const _prefsKey = 'receipt_branch_info_v1';

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
  }

  static ReceiptBranchInfo? fromBranch(Branch branch) {
    if (branch.id <= 0) return null;
    final address = [
      branch.address,
      branch.city,
      branch.state,
      branch.pincode,
    ]
        .where((p) => p != null && p.trim().isNotEmpty)
        .map((p) => p!.trim())
        .join(', ');
    return ReceiptBranchInfo(
      branchId: branch.id,
      name: branch.name.trim(),
      address: address,
      phone: branch.phone?.trim(),
    );
  }

  static ReceiptBranchInfo? fromBranchLite(BranchLite? branch) {
    if (branch == null || branch.id <= 0) return null;
    return ReceiptBranchInfo(
      branchId: branch.id,
      name: branch.name.trim(),
      address: branch.formattedAddress,
      phone: branch.phone?.trim(),
    );
  }

  /// Fetch `/branches`, cache the current branch, fall back to session lite.
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

    // Shop fallback when branch has empty name/address.
    final shop = auth.currentShop;
    if (cached != null && shop != null) {
      final name = cached.name.isNotEmpty ? cached.name : shop.name;
      final address = cached.address.trim().isNotEmpty
          ? cached.address
          : shop.formattedAddress;
      final phone = (cached.phone?.trim().isNotEmpty == true)
          ? cached.phone
          : shop.phone;
      cached = ReceiptBranchInfo(
        branchId: cached.branchId,
        name: name,
        address: address,
        phone: phone,
      );
    } else if (cached == null && shop != null && shop.id > 0) {
      cached = ReceiptBranchInfo(
        branchId: branchId ?? 0,
        name: shop.name,
        address: shop.formattedAddress,
        phone: shop.phone,
      );
    }

    if (cached != null) {
      await save(cached);
    }
    return cached;
  }

  /// Prefer local cache for [branchId], else sync, else session fields.
  static Future<ReceiptBranchInfo> resolveForPrint(AuthSession auth) async {
    final branchId = auth.currentBranchId;
    final cached = await load();
    if (cached != null &&
        (branchId == null || cached.branchId == branchId) &&
        cached.name.trim().isNotEmpty) {
      return cached;
    }

    final fromSession = fromBranchLite(auth.currentBranch);
    if (fromSession != null && fromSession.name.isNotEmpty) {
      final shop = auth.currentShop;
      final merged = ReceiptBranchInfo(
        branchId: fromSession.branchId,
        name: fromSession.name,
        address: fromSession.address.trim().isNotEmpty
            ? fromSession.address
            : (shop?.formattedAddress ?? ''),
        phone: (fromSession.phone?.trim().isNotEmpty == true)
            ? fromSession.phone
            : shop?.phone,
      );
      await save(merged);
      return merged;
    }

    final shop = auth.currentShop;
    return ReceiptBranchInfo(
      branchId: branchId ?? 0,
      name: shop?.name.trim().isNotEmpty == true
          ? shop!.name.trim()
          : 'Maran Veterinary Hospital',
      address: shop?.formattedAddress ?? '',
      phone: shop?.phone,
    );
  }
}
