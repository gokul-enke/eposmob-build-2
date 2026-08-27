import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

/// Settings shared by every receipt/document profile in Printer Settings.
///
/// The value is an additional safe margin. Existing layout margins remain in
/// place, so the default value of zero preserves the current output exactly.
class CommonPrintSettings {
  CommonPrintSettings._();

  static const String marginPreferenceKey = 'common_print_margin_mm';
  static const double defaultMarginMm = 0.0;
  static const double minMarginMm = 0.0;
  static const double maxMarginMm = 10.0;

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

  /// Converts millimetres to pixels for the raster thermal widths used by
  /// this app. The returned value is a horizontal/vertical inset on the
  /// already selected paper width.
  static int thermalMarginPixels({
    required double width,
    required double marginMm,
  }) {
    final safeWidth = width.clamp(1.0, double.infinity).toDouble();
    final paperWidthMm = _paperWidthMmForRasterWidth(safeWidth);
    final pixels = safeWidth * normalizeMarginMm(marginMm) / paperWidthMm;
    final maxInset = ((safeWidth - 1) / 2).floor();
    return pixels.round().clamp(0, maxInset);
  }

  static double _paperWidthMmForRasterWidth(double width) {
    if (width >= 700) return 112.0;
    if (width >= 480) return 80.0;
    return 58.0;
  }
}
