import 'package:shared_preferences/shared_preferences.dart';

/// Local USB thermal printer command language for this PC.
enum PrintLanguage {
  /// XPrinter XP-470B (Branch 1) — TSPL, 70 mm labels.
  tspl,

  /// Retsol RTP 80 (Branch 2) — ESC/POS, 80 mm roll.
  escpos,
}

/// A5 page orientation for visit-summary PDFs on this PC.
enum SummaryPageOrientation {
  portrait,
  landscape,
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
  static const _directSummaryPrintKey = 'visit_summary_direct_print';
  static const _autoPrintSummaryKey = 'visit_summary_auto_print';
  static const _summaryPrinterNameKey = 'visit_summary_printer_name';
  static const _summaryOrientationKey = 'visit_summary_page_orientation';

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

  /// When true, visit summary PDFs go to [getSummaryPrinterName] with no dialog.
  static Future<bool> getDirectSummaryPrint() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_directSummaryPrintKey) ?? true;
  }

  static Future<void> setDirectSummaryPrint(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_directSummaryPrintKey, value);
  }

  /// When true, completing a visit prints the summary immediately.
  static Future<bool> getAutoPrintSummary() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_autoPrintSummaryKey) ?? false;
  }

  static Future<void> setAutoPrintSummary(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoPrintSummaryKey, value);
  }

  /// Windows/macOS/Linux queue for A5 visit-summary PDFs (not the thermal RAW queue).
  static Future<String> getSummaryPrinterName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_summaryPrinterNameKey) ?? '';
  }

  static Future<void> setSummaryPrinterName(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_summaryPrinterNameKey, value.trim());
  }

  /// A5 orientation for visit summaries. Defaults to portrait.
  static Future<SummaryPageOrientation> getSummaryPageOrientation() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_summaryOrientationKey) ==
            SummaryPageOrientation.landscape.name
        ? SummaryPageOrientation.landscape
        : SummaryPageOrientation.portrait;
  }

  static Future<void> setSummaryPageOrientation(
    SummaryPageOrientation value,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_summaryOrientationKey, value.name);
  }
}
