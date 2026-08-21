import 'package:pdf/widgets.dart' as pw;

import 'receipt_layout_params.dart';
import '../standard_layouts/new_classic_standad_pdf_layout.dart';

/// Shared non-empty PDF path for thermal layout adapters.
///
/// Thermal themes historically returned an empty `pw.Document`, which made
/// A4/A5 sharing silently produce a blank file when a caller used the layout
/// interface directly. The maintained New Classic PDF renderer already owns
/// the complete document data mapping, so all thermal themes use it as the
/// contract-safe PDF fallback until they receive a distinct PDF skin.
Future<pw.Document> buildContractReceiptPdf(ReceiptLayoutParams params) {
  return NewClassicStandardPdfLayout().buildPdfDocument(params);
}
