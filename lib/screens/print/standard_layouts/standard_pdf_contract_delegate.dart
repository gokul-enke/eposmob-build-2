import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

import 'contract_standard_pdf_layout.dart';

/// Compatibility adapter for callers that explicitly need the normalized
/// standard PDF contract renderer.
///
/// The production factory now returns each concrete standard PDF layout, so
/// the concrete classes no longer consult this adapter. It remains available
/// for integrations that intentionally request the shared contract renderer.
class StandardPdfContractDelegate {
  StandardPdfContractDelegate._();

  /// Retained for source compatibility with the former guarded renderers.
  /// Concrete layout classes no longer consult this flag.
  static bool get enabled => true;

  static Future<void> generateAndPrintPdf(
    ReceiptLayoutParams params, {
    required String layoutId,
    required String displayName,
  }) {
    return ContractStandardPdfLayout(
      layoutId: layoutId,
      displayName: displayName,
    ).generateAndPrintPdf(params);
  }

  static Future<pw.Document> buildPdfDocument(
    ReceiptLayoutParams params, {
    required String layoutId,
    required String displayName,
  }) {
    return ContractStandardPdfLayout(
      layoutId: layoutId,
      displayName: displayName,
    ).buildPdfDocument(params);
  }
}
