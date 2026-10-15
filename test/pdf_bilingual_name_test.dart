import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/standard_layouts/pdf_bidi_text.dart';

void main() {
  final font = pw.Font.ttf(File('assets/fonts/NotoSansArabic-Regular.ttf')
      .readAsBytesSync()
      .buffer
      .asByteData());
  final style = pw.TextStyle(font: font, fontSize: 8);

  /// Lays the name out in a table cell of [cellWidth] points and returns
  /// the rendered height.
  Future<double> nameHeight(List<String> names, double cellWidth) async {
    final name = pdfBilingualName(names,
        style: style,
        twoLines: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [for (final n in names) pdfText(n, style: style)],
        ));
    final doc = pw.Document()
      ..addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Table(
          tableWidth: pw.TableWidth.min,
          columnWidths: {0: pw.FixedColumnWidth(cellWidth)},
          children: [
            pw.TableRow(children: [name])
          ],
        ),
      ));
    await doc.save();
    return name.box!.height;
  }

  // Height of one text line in this font (a single-language name).
  Future<double> oneLine() => nameHeight(['Coffee'], 200);

  test('short bilingual name in a wide cell prints on one line', () async {
    final height = await nameHeight(['قهوة', 'Coffee'], 200);
    expect(height, closeTo(await oneLine(), 0.5));
  });

  test('bilingual name that does not fit falls back to two lines', () async {
    final height = await nameHeight(
        ['قهوة عربية مختصة محمصة', 'Specialty Roasted Arabic Coffee'], 80);
    expect(height, greaterThanOrEqualTo(2 * await oneLine()));
  });

  test('single-language name keeps the layout rendering', () async {
    final fallback = pw.SizedBox();
    expect(pdfBilingualName(['Coffee'], twoLines: fallback), same(fallback));
  });
}
