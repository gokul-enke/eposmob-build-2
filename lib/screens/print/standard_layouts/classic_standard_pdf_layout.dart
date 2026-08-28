import 'package:pdf/widgets.dart' as pw;

import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'standard_pdf_layout.dart';
import 'contract_standard_pdf_layout.dart';

/// Classic standard PDF layout - the default A4/A5 PDF design.
///
/// Classic intentionally remains the normalized contract renderer baseline.
/// Other registered themes provide their own concrete PDF builders.
class ClassicStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'classic';

  @override
  String get displayName => 'Classic';

  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    await const ContractStandardPdfLayout(
      layoutId: 'classic',
      displayName: 'Classic',
    ).generateAndPrintPdf(params);
  }

  @override
  Future<pw.Document> buildPdfDocument(ReceiptLayoutParams params) async {
    return const ContractStandardPdfLayout(
      layoutId: 'classic',
      displayName: 'Classic',
    ).buildPdfDocument(params);
  }
}
