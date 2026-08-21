import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

import 'contract_standard_pdf_layout.dart';

/// Direct-entry guard for the historical standard PDF classes.
///
/// Factory routing covers normal production selection, but these classes are
/// public and are still used by integrations/tests that construct a theme
/// directly.  Their methods delegate here so no caller can accidentally
/// re-enable one of the old partial PDF contracts.
class StandardPdfContractDelegate {
  StandardPdfContractDelegate._();

  /// Runtime guard keeps historical implementation bodies reachable for
  /// source-level reference while ensuring production calls use the contract.
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
