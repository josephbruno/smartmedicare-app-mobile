import '../../../data/json_helpers.dart';

/// Shop settings configuration
class ShopSettings {
  final int id;
  final String name;
  final String? logo;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final String? email;
  final String? website;
  final String? gstin;
  final String? panNumber;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String currency; // INR, USD, etc.
  final String timezone; // Asia/Kolkata
  final String? businessType;
  final String? industry;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShopSettings({
    required this.id,
    required this.name,
    this.logo,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.email,
    this.website,
    this.gstin,
    this.panNumber,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.currency = 'INR',
    this.timezone = 'Asia/Kolkata',
    this.businessType,
    this.industry,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ShopSettings.fromJson(Map<String, dynamic> j) {
    return ShopSettings(
      id: intOrNull(j['id']) ?? 0,
      name: j['name']?.toString() ?? '',
      logo: j['logo']?.toString(),
      address: j['address']?.toString(),
      city: j['city']?.toString(),
      state: j['state']?.toString(),
      pincode: j['pincode']?.toString(),
      phone: j['phone']?.toString(),
      email: j['email']?.toString(),
      website: j['website']?.toString(),
      gstin: j['gstin']?.toString(),
      panNumber: j['pan_number']?.toString(),
      bankName: j['bank_name']?.toString(),
      accountNumber: j['account_number']?.toString(),
      ifscCode: j['ifsc_code']?.toString(),
      currency: j['currency']?.toString() ?? 'INR',
      timezone: j['timezone']?.toString() ?? 'Asia/Kolkata',
      businessType: j['business_type']?.toString(),
      industry: j['industry']?.toString(),
      isActive: j['is_active'] as bool? ?? true,
      createdAt: j['created_at'] != null ? DateTime.parse(j['created_at'] as String) : DateTime.now(),
      updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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
        'currency': currency,
        'timezone': timezone,
        if (businessType != null) 'business_type': businessType,
        if (industry != null) 'industry': industry,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

/// Notification preferences
class NotificationSettings {
  final int id;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool pushNotifications;
  final bool appointmentReminders;
  final bool vaccinationReminders;
  final bool lowStockAlerts;
  final bool paymentReminders;
  final int appointmentReminderMinutes; // minutes before appointment
  final bool dailyReports;
  final String dailyReportTime; // HH:mm format
  final bool weeklyReports;
  final String weeklyReportDay; // Monday, Tuesday, etc.
  final bool monthlyReports;
  final bool enableSoundNotifications;
  final bool enableVibration;

  NotificationSettings({
    required this.id,
    this.emailNotifications = true,
    this.smsNotifications = true,
    this.pushNotifications = true,
    this.appointmentReminders = true,
    this.vaccinationReminders = true,
    this.lowStockAlerts = true,
    this.paymentReminders = true,
    this.appointmentReminderMinutes = 30,
    this.dailyReports = false,
    this.dailyReportTime = '08:00',
    this.weeklyReports = false,
    this.weeklyReportDay = 'Monday',
    this.monthlyReports = false,
    this.enableSoundNotifications = true,
    this.enableVibration = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> j) {
    return NotificationSettings(
      id: intOrNull(j['id']) ?? 0,
      emailNotifications: j['email_notifications'] as bool? ?? true,
      smsNotifications: j['sms_notifications'] as bool? ?? true,
      pushNotifications: j['push_notifications'] as bool? ?? true,
      appointmentReminders: j['appointment_reminders'] as bool? ?? true,
      vaccinationReminders: j['vaccination_reminders'] as bool? ?? true,
      lowStockAlerts: j['low_stock_alerts'] as bool? ?? true,
      paymentReminders: j['payment_reminders'] as bool? ?? true,
      appointmentReminderMinutes: intOrNull(j['appointment_reminder_minutes']) ?? 30,
      dailyReports: j['daily_reports'] as bool? ?? false,
      dailyReportTime: j['daily_report_time']?.toString() ?? '08:00',
      weeklyReports: j['weekly_reports'] as bool? ?? false,
      weeklyReportDay: j['weekly_report_day']?.toString() ?? 'Monday',
      monthlyReports: j['monthly_reports'] as bool? ?? false,
      enableSoundNotifications: j['enable_sound_notifications'] as bool? ?? true,
      enableVibration: j['enable_vibration'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email_notifications': emailNotifications,
        'sms_notifications': smsNotifications,
        'push_notifications': pushNotifications,
        'appointment_reminders': appointmentReminders,
        'vaccination_reminders': vaccinationReminders,
        'low_stock_alerts': lowStockAlerts,
        'payment_reminders': paymentReminders,
        'appointment_reminder_minutes': appointmentReminderMinutes,
        'daily_reports': dailyReports,
        'daily_report_time': dailyReportTime,
        'weekly_reports': weeklyReports,
        'weekly_report_day': weeklyReportDay,
        'monthly_reports': monthlyReports,
        'enable_sound_notifications': enableSoundNotifications,
        'enable_vibration': enableVibration,
      };
}

/// App preferences and theme settings
class AppPreferences {
  final int id;
  final String theme; // light, dark, system
  final String language; // en, hi, etc.
  final String dateFormat; // dd/MM/yyyy
  final String timeFormat; // 12h, 24h
  final double fontSize;
  final bool autoLock;
  final int autoLockMinutes;
  final bool biometricAuth;
  final bool compactMode;
  final bool advancedMode; // Show advanced features
  final String defaultBranch;

  AppPreferences({
    required this.id,
    this.theme = 'system',
    this.language = 'en',
    this.dateFormat = 'dd/MM/yyyy',
    this.timeFormat = '24h',
    this.fontSize = 14.0,
    this.autoLock = true,
    this.autoLockMinutes = 5,
    this.biometricAuth = false,
    this.compactMode = false,
    this.advancedMode = false,
    this.defaultBranch = '0',
  });

  factory AppPreferences.fromJson(Map<String, dynamic> j) {
    return AppPreferences(
      id: intOrNull(j['id']) ?? 0,
      theme: j['theme']?.toString() ?? 'system',
      language: j['language']?.toString() ?? 'en',
      dateFormat: j['date_format']?.toString() ?? 'dd/MM/yyyy',
      timeFormat: j['time_format']?.toString() ?? '24h',
      fontSize: (numOrNull(j['font_size']) ?? 14.0).toDouble(),
      autoLock: j['auto_lock'] as bool? ?? true,
      autoLockMinutes: intOrNull(j['auto_lock_minutes']) ?? 5,
      biometricAuth: j['biometric_auth'] as bool? ?? false,
      compactMode: j['compact_mode'] as bool? ?? false,
      advancedMode: j['advanced_mode'] as bool? ?? false,
      defaultBranch: j['default_branch']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'theme': theme,
        'language': language,
        'date_format': dateFormat,
        'time_format': timeFormat,
        'font_size': fontSize,
        'auto_lock': autoLock,
        'auto_lock_minutes': autoLockMinutes,
        'biometric_auth': biometricAuth,
        'compact_mode': compactMode,
        'advanced_mode': advancedMode,
        'default_branch': defaultBranch,
      };
}

/// System health & monitoring
class SystemHealth {
  final String databaseStatus; // healthy, warning, critical
  final String syncStatus; // synced, syncing, failed
  final DateTime lastSyncTime;
  final int totalStorageUsed;
  final int totalStorageAvailable;
  final int cacheSize;
  final int offlineDataCount;
  final String appVersion;
  final DateTime lastBackup;
  final List<String> warnings;

  SystemHealth({
    required this.databaseStatus,
    required this.syncStatus,
    required this.lastSyncTime,
    required this.totalStorageUsed,
    required this.totalStorageAvailable,
    required this.cacheSize,
    required this.offlineDataCount,
    required this.appVersion,
    required this.lastBackup,
    required this.warnings,
  });

  double get storageUsagePercent => (totalStorageUsed / totalStorageAvailable) * 100;
  bool get isHealthy => databaseStatus == 'healthy' && syncStatus != 'failed' && warnings.isEmpty;
}
