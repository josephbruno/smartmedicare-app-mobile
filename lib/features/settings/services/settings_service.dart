import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../data/json_helpers.dart';
import '../models/settings_model.dart';

/// Service for managing shop settings and app configuration.
class SettingsService {
  final ApiClient _apiClient;
  late final SharedPreferences _prefs;

  SettingsService(this._apiClient);

  /// Initialize SharedPreferences (call once at app startup)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============ SHOP SETTINGS ============

  /// Get current shop settings.
  Future<ShopSettings> getShopSettings() async {
    try {
      final response = await _apiClient.get('/settings/shop');
      return ShopSettings.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update shop settings.
  Future<ShopSettings> updateShopSettings({
    required String name,
    String? logo,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? email,
    String? website,
    String? gstin,
    String? panNumber,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? currency,
    String? timezone,
  }) async {
    try {
      final response = await _apiClient.put(
        '/settings/shop',
        data: {
          'name': name,
          if (logo != null) 'logo': logo,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (pincode != null) 'pincode': pincode,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (website != null) 'website': website,
          if (gstin != null) 'gstin': gstin,
          if (panNumber != null) 'pan_number': panNumber,
          if (bankName != null) 'bank_name': bankName,
          if (accountNumber != null) 'account_number': accountNumber,
          if (ifscCode != null) 'ifsc_code': ifscCode,
          if (currency != null) 'currency': currency,
          if (timezone != null) 'timezone': timezone,
        },
      );

      return ShopSettings.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ NOTIFICATION SETTINGS ============

  /// Get notification settings.
  Future<NotificationSettings> getNotificationSettings() async {
    try {
      final response = await _apiClient.get('/settings/notifications');
      return NotificationSettings.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update notification settings.
  Future<NotificationSettings> updateNotificationSettings({
    bool? emailNotifications,
    bool? smsNotifications,
    bool? pushNotifications,
    bool? appointmentReminders,
    bool? vaccinationReminders,
    bool? lowStockAlerts,
    bool? paymentReminders,
    int? appointmentReminderMinutes,
    bool? dailyReports,
    String? dailyReportTime,
    bool? weeklyReports,
    String? weeklyReportDay,
    bool? monthlyReports,
  }) async {
    try {
      final response = await _apiClient.put(
        '/settings/notifications',
        data: {
          if (emailNotifications != null) 'email_notifications': emailNotifications,
          if (smsNotifications != null) 'sms_notifications': smsNotifications,
          if (pushNotifications != null) 'push_notifications': pushNotifications,
          if (appointmentReminders != null) 'appointment_reminders': appointmentReminders,
          if (vaccinationReminders != null) 'vaccination_reminders': vaccinationReminders,
          if (lowStockAlerts != null) 'low_stock_alerts': lowStockAlerts,
          if (paymentReminders != null) 'payment_reminders': paymentReminders,
          if (appointmentReminderMinutes != null)
            'appointment_reminder_minutes': appointmentReminderMinutes,
          if (dailyReports != null) 'daily_reports': dailyReports,
          if (dailyReportTime != null) 'daily_report_time': dailyReportTime,
          if (weeklyReports != null) 'weekly_reports': weeklyReports,
          if (weeklyReportDay != null) 'weekly_report_day': weeklyReportDay,
          if (monthlyReports != null) 'monthly_reports': monthlyReports,
        },
      );

      return NotificationSettings.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ APP PREFERENCES (Local) ============

  /// Get app preferences from local storage.
  AppPreferences getAppPreferences() {
    final id = _prefs.getInt('app_pref_id') ?? 0;
    final theme = _prefs.getString('app_theme') ?? 'system';
    final language = _prefs.getString('app_language') ?? 'en';
    final dateFormat = _prefs.getString('app_date_format') ?? 'dd/MM/yyyy';
    final timeFormat = _prefs.getString('app_time_format') ?? '24h';
    final fontSize = _prefs.getDouble('app_font_size') ?? 14.0;
    final autoLock = _prefs.getBool('app_auto_lock') ?? true;
    final autoLockMinutes = _prefs.getInt('app_auto_lock_minutes') ?? 5;
    final biometricAuth = _prefs.getBool('app_biometric_auth') ?? false;
    final compactMode = _prefs.getBool('app_compact_mode') ?? false;
    final advancedMode = _prefs.getBool('app_advanced_mode') ?? false;
    final defaultBranch = _prefs.getString('app_default_branch') ?? '0';

    return AppPreferences(
      id: id,
      theme: theme,
      language: language,
      dateFormat: dateFormat,
      timeFormat: timeFormat,
      fontSize: fontSize,
      autoLock: autoLock,
      autoLockMinutes: autoLockMinutes,
      biometricAuth: biometricAuth,
      compactMode: compactMode,
      advancedMode: advancedMode,
      defaultBranch: defaultBranch,
    );
  }

  /// Update app preferences in local storage.
  Future<void> updateAppPreferences({
    String? theme,
    String? language,
    String? dateFormat,
    String? timeFormat,
    double? fontSize,
    bool? autoLock,
    int? autoLockMinutes,
    bool? biometricAuth,
    bool? compactMode,
    bool? advancedMode,
    String? defaultBranch,
  }) async {
    if (theme != null) await _prefs.setString('app_theme', theme);
    if (language != null) await _prefs.setString('app_language', language);
    if (dateFormat != null) await _prefs.setString('app_date_format', dateFormat);
    if (timeFormat != null) await _prefs.setString('app_time_format', timeFormat);
    if (fontSize != null) await _prefs.setDouble('app_font_size', fontSize);
    if (autoLock != null) await _prefs.setBool('app_auto_lock', autoLock);
    if (autoLockMinutes != null) await _prefs.setInt('app_auto_lock_minutes', autoLockMinutes);
    if (biometricAuth != null) await _prefs.setBool('app_biometric_auth', biometricAuth);
    if (compactMode != null) await _prefs.setBool('app_compact_mode', compactMode);
    if (advancedMode != null) await _prefs.setBool('app_advanced_mode', advancedMode);
    if (defaultBranch != null) await _prefs.setString('app_default_branch', defaultBranch);
  }

  // ============ USER MANAGEMENT ============

  /// Get all users in the shop.
  Future<List<Map<String, dynamic>>> getShopUsers() async {
    try {
      final response = await _apiClient.get('/settings/users');
      final data = response.data as Map<String, dynamic>;
      return (data['data'] ?? data['users'] ?? []) as List<Map<String, dynamic>>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Create a new user.
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    bool isActive = true,
  }) async {
    try {
      final response = await _apiClient.post(
        '/settings/users',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          if (phone != null) 'phone': phone,
          'is_active': isActive,
        },
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update user.
  Future<Map<String, dynamic>> updateUser({
    required int userId,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.put(
        '/settings/users/$userId',
        data: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (role != null) 'role': role,
          if (isActive != null) 'is_active': isActive,
        },
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Delete user.
  Future<void> deleteUser(int userId) async {
    try {
      await _apiClient.delete('/settings/users/$userId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Reset user password.
  Future<void> resetUserPassword(int userId, String newPassword) async {
    try {
      await _apiClient.post(
        '/settings/users/$userId/reset-password',
        data: {'password': newPassword},
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ ROLE MANAGEMENT ============

  /// Get all roles.
  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await _apiClient.get('/settings/roles');
      final data = response.data as Map<String, dynamic>;
      return (data['data'] ?? data['roles'] ?? []) as List<Map<String, dynamic>>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Assign role to user.
  Future<void> assignRoleToUser(int userId, String role) async {
    try {
      await _apiClient.post(
        '/settings/users/$userId/assign-role',
        data: {'role': role},
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ SYSTEM HEALTH ============

  /// Get system health status.
  Future<SystemHealth> getSystemHealth() async {
    try {
      final response = await _apiClient.get('/settings/health');
      final data = response.data as Map<String, dynamic>;

      return SystemHealth(
        databaseStatus: data['database_status']?.toString() ?? 'unknown',
        syncStatus: data['sync_status']?.toString() ?? 'unknown',
        lastSyncTime: data['last_sync_time'] != null
            ? DateTime.parse(data['last_sync_time'] as String)
            : DateTime.now(),
        totalStorageUsed: intOrNull(data['total_storage_used']) ?? 0,
        totalStorageAvailable: intOrNull(data['total_storage_available']) ?? 0,
        cacheSize: intOrNull(data['cache_size']) ?? 0,
        offlineDataCount: intOrNull(data['offline_data_count']) ?? 0,
        appVersion: data['app_version']?.toString() ?? '1.0.0',
        lastBackup: data['last_backup'] != null
            ? DateTime.parse(data['last_backup'] as String)
            : DateTime.now(),
        warnings: (data['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Clear app cache.
  Future<void> clearCache() async {
    try {
      await _apiClient.post('/settings/cache/clear');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Optimize database.
  Future<void> optimizeDatabase() async {
    try {
      await _apiClient.post('/settings/database/optimize');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
