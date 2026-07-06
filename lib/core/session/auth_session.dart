import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

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

  bool get isShopOwner => _user?.roles.contains('shop_owner') ?? false;

  BranchLite? get currentBranch => _user?.branch;

  ShopLite? get currentShop => _user?.shop;

  bool hasPermission(String permission) {
    if (isSuperAdmin) return true;
    return _user?.permissions.contains(permission) ?? false;
  }

  bool hasRole(String role) => _user?.roles.contains(role) ?? false;

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

  Future<void> login(String email, String password) async {
    final pair = await _repository!.login(email, password);
    await _setAuth(pair.user, pair.token);
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
    notifyListeners();
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
