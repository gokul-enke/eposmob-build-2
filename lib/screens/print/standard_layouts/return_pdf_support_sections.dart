import 'package:pdf/widgets.dart' as pw;

import '../layouts/receipt_layout_params.dart';
import '../layouts/receipt_sections.dart';
import 'pdf_bidi_text.dart';

/// Content that remains applicable to return-only documents even when a
/// theme's sales totals panel is omitted. Callers exclude sections already
/// rendered elsewhere in their layout to keep each field printed once.
List<pw.Widget> buildReturnPdfSupportSections({
  required ReceiptLayoutParams params,
  required pw.TextStyle style,
  required pw.TextStyle headingStyle,
  required String qrData,
  bool includeComment = true,
  bool includeBank = true,
  bool includeQr = true,
}) {
  if (!params.isReturnOnly) return const [];
  final bankRows = includeBank ? params.bankDetailRows : <(String, String)>[];
  final comment = includeComment ? params.commentText : '';
  return [
    if (comment.isNotEmpty) ...[
      pw.SizedBox(height: 4),
      pdfText(comment, style: style),
    ],
    if (bankRows.isNotEmpty) ...[
      pw.SizedBox(height: 4),
      pdfText(params.bankDetailsHeading, style: headingStyle),
      for (final row in bankRows) pdfText('${row.$1}: ${row.$2}', style: style),
    ],
    if (includeQr && params.isVisible('showQRCode') && qrData.isNotEmpty) ...[
      pw.SizedBox(height: 4),
      if (params.qrCaption.isNotEmpty)
        pw.Center(child: pdfText(params.qrCaption, style: style)),
      pw.Center(
          child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: qrData,
        width: 64,
        height: 64,
      )),
    ],
  ];
}
