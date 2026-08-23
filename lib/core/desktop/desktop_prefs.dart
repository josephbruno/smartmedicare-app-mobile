import 'package:shared_preferences/shared_preferences.dart';

/// Local USB thermal printer command language for this PC.
enum PrintLanguage {
  /// XPrinter XP-470B (Branch 1) — TSPL, 70 mm labels.
  tspl,

  /// Retsol RTP 80 (Branch 2) — ESC/POS, 80 mm roll.
  escpos,
}

/// Desktop / POS preferences persisted locally.
class DesktopPrefs {
  DesktopPrefs._();

  static const _autoPrintKey = 'pos_auto_print_receipt';
  static const _notificationSoundKey = 'desktop_notification_sound';
  static const _directPrintKey = 'pos_direct_thermal_print';
  static const _printerNameKey = 'pos_thermal_printer_name';
  static const _escposPrinterNameKey = 'pos_escpos_printer_name';
  static const _printLanguageKey = 'pos_print_language';
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

  /// When true on Windows/Linux, send raw bytes to the selected USB printer (no dialog).
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

  /// Windows queue for the Retsol RTP 80 (ESC/POS). Separate from the TSPL name
  /// so Branch 1 and Branch 2 PCs can keep both printers configured.
  static Future<String> getEscPosPrinterName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_escposPrinterNameKey) ?? '';
  }

  static Future<void> setEscPosPrinterName(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_escposPrinterNameKey, value.trim());
  }

  /// Command language for direct USB print on this computer.
  static Future<PrintLanguage> getPrintLanguage() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_printLanguageKey) == PrintLanguage.escpos.name
        ? PrintLanguage.escpos
        : PrintLanguage.tspl;
  }

  static Future<void> setPrintLanguage(PrintLanguage value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_printLanguageKey, value.name);
  }

  /// Saved printer name for the active print language.
  static Future<String> getActivePrinterName() async {
    final language = await getPrintLanguage();
    return language == PrintLanguage.escpos
        ? getEscPosPrinterName()
        : getThermalPrinterName();
  }

  static Future<void> setActivePrinterName(String value) async {
    final language = await getPrintLanguage();
    if (language == PrintLanguage.escpos) {
      await setEscPosPrinterName(value);
    } else {
      await setThermalPrinterName(value);
    }
  }

  /// Receipt width in mm. TSPL stock is 70 mm; ESC/POS RTP 80 is 80 mm.
  static Future<int> getThermalPaperWidthMm() async {
    final language = await getPrintLanguage();
    return language == PrintLanguage.escpos ? 80 : 70;
  }

  static Future<void> setThermalPaperWidthMm(int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_paperWidthKey, value);
  }
}
