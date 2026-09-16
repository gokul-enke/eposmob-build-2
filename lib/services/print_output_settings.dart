import 'package:shared_preferences/shared_preferences.dart';

/// Stores the selected output mode independently from a physical printer.
///
/// A physical printer selection is intentionally kept when Open PDF is
/// selected so switching back to a printer does not require another scan.
class PrintOutputSettings {
  PrintOutputSettings._();

  static const String _openPdfSuffix = '_open_pdf_output';

  static String preferenceKey(String printerPreferenceKey) =>
      '$printerPreferenceKey$_openPdfSuffix';

  static bool isStandardPdfPaperSize(String? paperSize) {
    final normalized = paperSize?.trim().toUpperCase();
    return normalized == 'A4' || normalized == 'A5';
  }

  /// Resolves a target-specific choice, optionally inheriting the default
  /// target when the target has not been configured yet.
  static Future<bool> shouldOpenPdfForTarget(
    String printerPreferenceKey, {
    String? fallbackPrinterPreferenceKey,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();

    bool? read(String targetKey) {
      final key = preferenceKey(targetKey);
      if (!prefs.containsKey(key)) return null;
      return prefs.getBool(key) ?? false;
    }

    return read(printerPreferenceKey) ??
        (fallbackPrinterPreferenceKey == null
            ? false
            : read(fallbackPrinterPreferenceKey) ?? false);
  }

  static Future<void> setOpenPdfForTarget(
    String printerPreferenceKey, {
    required bool selected,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final saved = await prefs.setBool(
      preferenceKey(printerPreferenceKey),
      selected,
    );
    if (!saved) {
      throw StateError('Could not save PDF output setting');
    }
  }

  static Future<void> clearForTarget(
    String printerPreferenceKey, {
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(preferenceKey(printerPreferenceKey));
  }
}
