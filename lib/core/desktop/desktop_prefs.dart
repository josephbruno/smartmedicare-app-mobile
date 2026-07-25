import 'package:shared_preferences/shared_preferences.dart';

/// Desktop / POS preferences persisted locally.
class DesktopPrefs {
  DesktopPrefs._();

  static const _autoPrintKey = 'pos_auto_print_receipt';
  static const _notificationSoundKey = 'desktop_notification_sound';
  static const _directPrintKey = 'pos_direct_thermal_print';
  static const _printerNameKey = 'pos_thermal_printer_name';
  static const _paperWidthKey = 'pos_thermal_paper_width_mm';

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

  /// When true on Windows, print ESC/POS raw to the selected USB printer (no dialog).
  static Future<bool> getDirectThermalPrint() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_directPrintKey) ?? true;
  }

  static Future<void> setDirectThermalPrint(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_directPrintKey, value);
  }

  static Future<String> getThermalPrinterName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_printerNameKey) ?? '';
  }

  static Future<void> setThermalPrinterName(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_printerNameKey, value.trim());
  }

  /// 58 or 80 (mm).
  static Future<int> getThermalPaperWidthMm() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_paperWidthKey) ?? 80;
    return v == 58 ? 58 : 80;
  }

  static Future<void> setThermalPaperWidthMm(int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_paperWidthKey, value == 58 ? 58 : 80);
  }
}
