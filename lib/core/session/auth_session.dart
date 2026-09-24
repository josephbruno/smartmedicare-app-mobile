import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../app_config.dart';
import '../services/permission_service.dart';
import '../services/receipt_branch_store.dart';
import '../../data/services/emr_visit_catalog_cache.dart';

const _kTokenKey = 'auth_token';
const _kUserJsonKey = 'auth_user_json';
const _kBranchIdKey = 'auth_branch_id';
const _kBiometricPinKey = 'biometric_unlock_pin';
const _kBiometricEnabledKey = 'app_biometric_auth';

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
  bool _biometricEnabled = false;

  String? get token => _token;
  User? get user => _user;
  int? get currentBranchId => _currentBranchId ?? _user?.branchId;

  bool get hasStoredSession =>
      (_token != null && _token!.isNotEmpty) && _user != null;

  bool get isUnlocked => _isUnlocked;

  bool get hasPinSet => _user?.hasPin ?? false;

  /// User preference: unlock with fingerprint / Face ID when the device allows it.
  bool get biometricEnabled => _biometricEnabled;

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

  String get clinicType => currentShop?.clinicType ?? 'veterinary';

  String get facilityType => currentShop?.facilityType ?? 'clinic';

  bool get isVeterinary => clinicType == 'veterinary';

  bool get isHuman => clinicType == 'human';

  bool hasCapability(String capability) =>
      currentShop?.hasCapability(capability) ?? false;

  String get patientLabel => isVeterinary ? 'Pet / Patient' : 'Patient';

  String get patientsLabel => isVeterinary ? 'Pets / Patients' : 'Patients';

  String get responsiblePartyLabel =>
      isVeterinary ? 'Owner' : 'Responsible Party';

  String get responsiblePartiesLabel =>
      isVeterinary ? 'Owners' : 'Responsible Parties';

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

  /// Local printer setup on this PC (POS thermal + visit summary PDF).
  bool get canAccessPrinterSettings {
    if (hasPermission(AppPermissions.shopManage)) return true;
    if (hasRole(AppRoles.cashier) &&
        AppConfig.isCashierPlatform &&
        hasPermission(AppPermissions.invoicesCreate)) {
      return true;
    }
    return AppConfig.isDesktopPlatform &&
        hasPermission(AppPermissions.emrVisitsEdit);
  }

  /// First settings screen the user is allowed to open.
  String? get settingsRoute {
    if (hasPermission(AppPermissions.shopManage)) return '/settings';
    // Cashier desktops: local USB TSPL printer config (no shop.manage needed).
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
    _biometricEnabled = prefs.getBool(_kBiometricEnabledKey) ?? false;
    _isUnlocked = false;
    await AppDatabase.useShop(_user?.shopId);
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
    if (_biometricEnabled) {
      await _storeBiometricPin(pin);
    }
    notifyListeners();
  }

  Future<void> verifyPin(String pin) async {
    await _repository!.verifyPin(pin);
    _isUnlocked = true;
    if (_biometricEnabled) {
      await _storeBiometricPin(pin);
    }
    if (needsPermissionRefresh) {
      await fetchMe();
    }
    notifyListeners();
  }

  /// Whether a PIN is stored for biometric unlock (enabled preference + pin present).
  Future<bool> canUnlockWithBiometrics() async {
    if (!_biometricEnabled) return false;
    final pin = await _secure.read(key: _kBiometricPinKey);
    return pin != null && pin.length == 6;
  }

  /// After device biometrics succeed, re-verify the stored PIN with the API.
  Future<void> unlockWithStoredBiometricPin() async {
    final pin = await _secure.read(key: _kBiometricPinKey);
    if (pin == null || pin.length != 6) {
      throw StateError(
        'Biometric unlock is not set up yet. Enter your PIN once.',
      );
    }
    await verifyPin(pin);
  }

  /// Enable fingerprint / Face ID unlock. [pin] must be the current valid PIN
  /// so it can be stored for subsequent biometric unlocks.
  Future<void> enableBiometricUnlock(String pin) async {
    if (pin.length != 6) {
      throw ArgumentError('PIN must be 6 digits');
    }
    await _repository!.verifyPin(pin);
    await _storeBiometricPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabledKey, true);
    _biometricEnabled = true;
    _isUnlocked = true;
    notifyListeners();
  }

  Future<void> disableBiometricUnlock() async {
    await _secure.delete(key: _kBiometricPinKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabledKey, false);
    _biometricEnabled = false;
    notifyListeners();
  }

  /// Turn on the preference and cache [pin] after a successful unlock/set.
  Future<void> rememberPinForBiometrics(String pin) async {
    if (pin.length != 6) return;
    await _storeBiometricPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabledKey, true);
    _biometricEnabled = true;
    notifyListeners();
  }

  Future<void> _storeBiometricPin(String pin) async {
    await _secure.write(key: _kBiometricPinKey, value: pin);
  }

  /// Self-service password change for the current account. Other devices are
  /// signed out; the current session token remains valid.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _repository!.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  /// Self-service PIN change/setup for the current account.
  Future<void> changePin({String? currentPin, required String newPin}) async {
    final updated =
        await _repository!.changePin(currentPin: currentPin, newPin: newPin);
    _user = updated;
    await _persistUserJson();
    if (_biometricEnabled) {
      await _storeBiometricPin(newPin);
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

  /// Background refresh (plan, validity, permissions) that never signs the user out.
  Future<void> refreshMe() async {
    if (_token == null || _token!.isEmpty || _repository == null) return;
    try {
      _user = await _repository!.me();
      await _persistUserJson();
      notifyListeners();
    } catch (_) {
      // Offline or transient failure: keep the cached session.
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
    await AppDatabase.useShop(user.shopId);
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
    await _secure.delete(key: _kBiometricPinKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserJsonKey);
    await prefs.remove(_kBranchIdKey);
    await ReceiptBranchStore.clear();
    EmrVisitCatalogCache.clear();
    await AppDatabase.useShop(null);
    notifyListeners();
  }
}
