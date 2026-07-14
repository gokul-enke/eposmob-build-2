import 'package:pdf/widgets.dart' as pw;
import 'receipt_layout_params.dart';

export '../print_unit_helper.dart';

/// Abstract base class for receipt layouts.
///
/// Each theme (classic, modern, minimal, etc.) implements this interface
/// to provide its own visual layout while using the same data.
///
/// Usage:
/// ```dart
/// final layout = ReceiptLayoutFactory.getLayout(billDocumentConfig.activeTheme);
/// await layout.printThermal(params);
/// ```
abstract class ReceiptLayout {
  /// Unique identifier for this layout theme
  /// Examples: "classic", "modern", "minimal"
  String get layoutId;

  /// Display name for this layout (for UI purposes)
  String get displayName;

  /// Build and print a thermal receipt (58mm or 80mm)
  ///
  /// This method handles the complete printing process including:
  /// - Connecting to printer
  /// - Generating receipt content (text or image-based)
  /// - Sending to printer
  /// - Disconnecting
  Future<void> printThermal(ReceiptLayoutParams params);

  /// Build a PDF document for standard printing (A4, A5)
  ///
  /// Returns the PDF document. The caller is responsible for
  /// saving/opening/sharing the PDF.
  Future<pw.Document> buildPdf(ReceiptLayoutParams params);

  /// Build and print using text-based ESC/POS commands (for non-Arabic receipts)
  ///
  /// This is an optional method for layouts that support native ESC/POS printing.
  /// Default implementation delegates to printThermal.
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    // Default implementation uses image-based printing
    await printThermal(params);
  }
}

/// Configuration for layout spacing
/// Different themes can have different spacing configurations
class LayoutSpacing {
  final double sectionGap;
  final double itemGap;
  final double headerBottomMargin;
  final double footerTopMargin;
  final double dividerHeight;

  const LayoutSpacing({
    this.sectionGap = 10.0,
    this.itemGap = 5.0,
    this.headerBottomMargin = 15.0,
    this.footerTopMargin = 15.0,
    this.dividerHeight = 1.0,
  });

  /// Compact spacing for minimal theme
  static const compact = LayoutSpacing(
    sectionGap: 5.0,
    itemGap: 2.0,
    headerBottomMargin: 8.0,
    footerTopMargin: 8.0,
    dividerHeight: 0.5,
  );

  /// Normal spacing for classic theme
  static const normal = LayoutSpacing();

  /// Relaxed spacing for modern theme
  static const relaxed = LayoutSpacing(
    sectionGap: 15.0,
    itemGap: 8.0,
    headerBottomMargin: 20.0,
    footerTopMargin: 20.0,
    dividerHeight: 1.0,
  );
}

/// Configuration for font scales
/// Different themes can emphasize different elements
class FontScales {
  final double header;
  final double subheader;
  final double body;
  final double small;
  final double netTotal;

  const FontScales({
    this.header = 2.0,
    this.subheader = 1.2,
    this.body = 1.0,
    this.small = 0.8,
    this.netTotal = 1.5,
  });

  /// Default font scales
  static const normal = FontScales();

  /// Compact font scales for minimal theme
  static const compact = FontScales(
    header: 1.5,
    subheader: 1.0,
    body: 0.9,
    small: 0.7,
    netTotal: 1.2,
  );

  /// Large font scales for emphasis
  static const large = FontScales(
    header: 2.5,
    subheader: 1.4,
    body: 1.1,
    small: 0.9,
    netTotal: 1.8,
  );
}
