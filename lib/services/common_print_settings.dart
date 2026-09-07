import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

/// Settings shared by every standard PDF (A4/A5) profile in Printer Settings.
///
/// The value is an additional safe margin. Existing layout margins remain in
/// place, so the default value of zero preserves the current output exactly.
/// Thermal paper is fixed-width with its own non-printable edge handled by
/// the printer itself, so this margin is not applied to thermal output.
class CommonPrintSettings {
  CommonPrintSettings._();

  static const String marginPreferenceKey = 'common_print_margin_mm';
  static const double defaultMarginMm = 0.0;
  static const double minMarginMm = 0.0;
  static const double maxMarginMm = 10.0;

  /// Controls whether standard PDF jobs use the printer driver's saved
  /// media configuration instead of the A4/A5 format requested by the PDF.
  ///
  /// This is intentionally separate from barcode printing. Barcode printing
  /// has its own driver-specific setting and continues to pass `true`
  /// directly to the native print path.
  static const String usePrinterSettingsPreferenceKey =
      'common_use_printer_settings';
  static const bool defaultUsePrinterSettings = false;

  static Future<bool> loadUsePrinterSettings() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(usePrinterSettingsPreferenceKey) ??
        defaultUsePrinterSettings;
  }

  static Future<bool> saveUsePrinterSettings(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setBool(usePrinterSettingsPreferenceKey, value);
  }

  static Future<bool> resetUsePrinterSettings() =>
      saveUsePrinterSettings(defaultUsePrinterSettings);

  /// Loads the one margin profile shared by Billing, Quotation, Kitchen,
  /// Barcode and PDF Sharing settings.
  static Future<double> loadMarginMm() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.get(marginPreferenceKey);
    if (stored is num) {
      return normalizeMarginMm(stored.toDouble());
    }
    return defaultMarginMm;
  }

  static Future<bool> saveMarginMm(double marginMm) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setDouble(
      marginPreferenceKey,
      normalizeMarginMm(marginMm),
    );
  }

  static Future<bool> resetMarginMm() => saveMarginMm(defaultMarginMm);

  static double normalizeMarginMm(double value) {
    if (!value.isFinite) return defaultMarginMm;
    return value.clamp(minMarginMm, maxMarginMm).toDouble();
  }

  /// Adds the common all-sides margin to a layout's existing PDF margin.
  ///
  /// This changes the content safe area, not the A4/A5 page size. That keeps
  /// the selected paper format intact while preventing edge content from
  /// being sent into the printer's non-printable area.
  static pw.EdgeInsets addToPdfMargins(
    pw.EdgeInsets baseMargins,
    double marginMm,
  ) {
    final extra = normalizeMarginMm(marginMm) * PdfPageFormat.mm;
    return pw.EdgeInsets.only(
      left: baseMargins.left + extra,
      right: baseMargins.right + extra,
      top: baseMargins.top + extra,
      bottom: baseMargins.bottom + extra,
    );
  }

  static Future<pw.EdgeInsets> resolvePdfMargins(
    pw.EdgeInsets baseMargins,
  ) async {
    return addToPdfMargins(baseMargins, await loadMarginMm());
  }
}
