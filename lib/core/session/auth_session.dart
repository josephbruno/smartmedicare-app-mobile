import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../app_config.dart';
import '../services/permission_service.dart';

const _kTokenKey = 'auth_token';
const _kUserJsonKey = 'auth_user_json';
const _kBranchIdKey = 'auth_branch_id';

/// Session + permission state (replaces Pinia auth store).
/// Call [bindRepository] after [ApiClient] and [AuthRepository] are wired.
class AuthSession extends ChangeNotifier {
  AuthSession();

  AuthRepository? _repository;

  void bindRepository(AuthRepository repository) {
    _repository = repository;
  }

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  String? _token;
  User? _user;
  int? _currentBranchId;
  bool _isUnlocked = false;

  String? get token => _token;
  User? get user => _user;
  int? get currentBranchId => _currentBranchId ?? _user?.branchId;

  bool get hasStoredSession =>
      (_token != null && _token!.isNotEmpty) && _user != null;

  bool get isUnlocked => _isUnlocked;

  bool get hasPinSet => _user?.hasPin ?? false;

  /// Full app access: stored credentials and PIN verified (or fresh login).
  bool get isAuthenticated => hasStoredSession && _isUnlocked;

  bool get isSuperAdmin => _user?.roles.contains('super_admin') ?? false;

  bool get isShopOwner => isSuperAdmin;

  /// True when cached user is missing permission names (stale session data).
  bool get needsPermissionRefresh {
    if (_user == null || _token == null || _token!.isEmpty) return false;
    if (isSuperAdmin) return false;
    return _user!.permissions.isEmpty;
  }

  BranchLite? get currentBranch => _user?.branch;

  ShopLite? get currentShop => _user?.shop;

  bool hasPermission(String permission) {
    if (isSuperAdmin) return true;
    final perms = _user?.permissions ?? [];
    if (perms.contains(permission)) return true;
    // Stale cached sessions may have roles but an empty permissions list.
    if (perms.isEmpty && hasRole(AppRoles.cashier)) {
      return AppRoles.cashierPermissions.contains(permission);
    }
    if (perms.isEmpty && hasRole(AppRoles.doctor)) {
      return AppRoles.doctorPermissions.contains(permission);
    }
    return false;
  }

  bool hasRole(String role) => _user?.roles.contains(role) ?? false;

  /// Cashier role is allowed only on Windows/Linux desktop app.
  bool get cashierPlatformAllowed =>
      !hasRole(AppRoles.cashier) || AppConfig.isCashierPlatform;

  /// Default landing route after login or when access is denied.
  String get homeRoute {
    if (hasRole(AppRoles.cashier)) {
      if (hasPermission(AppPermissions.invoicesCreate)) return '/pos';
      if (hasPermission(AppPermissions.invoicesView)) return '/invoices';
      if (hasPermission(AppPermissions.customersView)) return '/customers';
    }
    // Doctors land on the clinical dashboard (open visits / holds / shortcuts).
    return '/dashboard';
  }

  bool get canAccessSettings => settingsRoute != null;

  /// First settings screen the user is allowed to open.
  String? get settingsRoute {
    if (hasPermission(AppPermissions.shopManage)) return '/settings';
    // Cashier desktops: local USB ESC/POS printer config (no shop.manage needed).
    if (hasRole(AppRoles.cashier) &&
        AppConfig.isCashierPlatform &&
        hasPermission(AppPermissions.invoicesCreate)) {
      return '/settings/printer';
    }
    if (hasPermission(AppPermissions.usersView)) return '/settings/users';
    if (hasPermission(AppPermissions.doctorsManage)) return '/settings/doctors';
    if (hasPermission(AppPermissions.branchManage)) return '/settings/branches';
    return null;
  }

  Future<void> restore() async {
    _token = await _secure.read(key: _kTokenKey);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserJsonKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    }
    final b = prefs.getString(_kBranchIdKey);
    if (b != null && b.isNotEmpty) {
      _currentBranchId = int.tryParse(b);
    }
    _isUnlocked = false;
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    final pair = await _repository!.login(login, password);
    await _setAuth(pair.user, pair.token);
    if (needsPermissionRefresh) {
      await fetchMe();
    }
    if (pair.user.hasPin) {
      _isUnlocked = true;
      notifyListeners();
    }
  }

  Future<void> register(Map<String, dynamic> body) async {
    final pair = await _repository!.register(body);
    await _setAuth(pair.user, pair.token);
  }

  Future<void> setPin(String pin) async {
    final updated = await _repository!.setPin(pin);
    _user = updated;
    await _persistUserJson();
    _isUnlocked = true;
    notifyListeners();
  }

  Future<void> verifyPin(String pin) async {
    await _repository!.verifyPin(pin);
    _isUnlocked = true;
    if (needsPermissionRefresh) {
      await fetchMe();
    }
    notifyListeners();
  }

  /// Refreshes profile from API when permissions are missing from cache.
  Future<void> refreshProfileIfNeeded() async {
    if (needsPermissionRefresh) {
      await fetchMe();
    }
  }

  Future<void> fetchMe() async {
    if (_token == null || _token!.isEmpty || _repository == null) return;
    try {
      _user = await _repository!.me();
      await _persistUserJson();
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  Future<void> switchBranch(int branchId) async {
    final u = await _repository!.switchBranch(branchId);
    _user = u;
    _currentBranchId = branchId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBranchIdKey, branchId.toString());
    await _persistUserJson();
    notifyListeners();
  }

  Future<void> _setAuth(User user, String token) async {
    _user = user;
    _token = token;
    _currentBranchId = user.branchId;
    _isUnlocked = false;
    await _secure.write(key: _kTokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    if (user.branchId != null) {
      await prefs.setString(_kBranchIdKey, user.branchId.toString());
    }
    await _persistUserJson();
    notifyListeners();
  }

  Future<void> _persistUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user == null) {
      await prefs.remove(_kUserJsonKey);
    } else {
      await prefs.setString(_kUserJsonKey, jsonEncode(_user!.toJson()));
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null && _repository != null) {
        await _repository!.logout();
      }
    } catch (_) {}
    _user = null;
    _token = null;
    _currentBranchId = null;
    _isUnlocked = false;
    await _secure.delete(key: _kTokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserJsonKey);
    await prefs.remove(_kBranchIdKey);
    notifyListeners();
  }
}
