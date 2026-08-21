import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

export '../print_unit_helper.dart';
export '../../../services/standard_pdf_direct_print_service.dart';

/// Abstract base class for standard (A4/A5) PDF receipt layouts.
///
/// Each theme (classic, modern, minimal, etc.) implements this interface
/// to provide its own visual PDF layout while using the same data.
///
/// Usage:
/// ```dart
/// final layout = StandardPdfLayoutFactory.getLayout(activeTheme);
/// await layout.generateAndPrintPdf(params);
/// ```
abstract class StandardPdfLayout {
  /// Unique identifier for this layout theme
  /// Examples: "classic", "modern", "minimal"
  String get layoutId;

  /// Display name for this layout (for UI purposes)
  String get displayName;

  /// Generate a full PDF, save to file, and open/share it.
  ///
  /// This method handles the complete PDF workflow:
  /// - Building the PDF document
  /// - Saving to the epos directory
  /// - Opening (Windows) or sharing (mobile) the PDF
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params);

  /// Build a PDF document without saving/opening.
  ///
  /// Returns the PDF document. The caller is responsible for
  /// saving/opening/sharing the PDF. Used by `generatePDFForSharing`.
  Future<pw.Document> buildPdfDocument(ReceiptLayoutParams params);
}
