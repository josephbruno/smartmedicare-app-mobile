import 'package:shared_preferences/shared_preferences.dart';

/// Desktop / POS preferences persisted locally.
class DesktopPrefs {
  DesktopPrefs._();

  static const _autoPrintKey = 'pos_auto_print_receipt';
  static const _notificationSoundKey = 'desktop_notification_sound';

  static Future<bool> getAutoPrintReceipt() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_autoPrintKey) ?? false;
  }

  static Future<void> setAutoPrintReceipt(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoPrintKey, value);
  }

  static Future<bool> getNotificationSound() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_notificationSoundKey) ?? true;
  }

  static Future<void> setNotificationSound(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_notificationSoundKey, value);
  }
}
