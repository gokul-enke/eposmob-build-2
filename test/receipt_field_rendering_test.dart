import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/layouts/receipt_text_line.dart';
import 'package:pos_machine/screens/print/standard_layouts/pdf_bidi_text.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

void main() {
  test('field boundaries preserve mixed captions and literal punctuation', () {
    const line = ReceiptTextLine.field('Tel Phone عربي', '9845243437');
    expect(line.label, 'Tel Phone عربي');
    expect(line.value, '9845243437');
    const address =
        ReceiptTextLine.field('Address: عنوان', 'https://example.test:8080');
    expect(address.value, 'https://example.test:8080');
    expect(const ReceiptTextLine.text('Terms: عربي 123').hasLabel, isFalse);
  });

  testWidgets(
      'paint mixed fields and long values without clipping on narrow paper',
      (tester) async {
    final loader = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await loader.load();
    final output = Directory('build/receipt_field_rendering')
      ..createSync(recursive: true);
    const fields = [
      ReceiptTextLine.field('Tel Phone عربي', '9845243437'),
      ReceiptTextLine.field('VAT عربي', '31223766400003'),
      ReceiptTextLine.field('CR عربي', '7036220940'),
      ReceiptTextLine.field('Address عنوان', 'Al Hamra, Street 42'),
      ReceiptTextLine.field('IBAN عربي', 'SA0380000000608010167519'),
      ReceiptTextLine.field('Date تاريخ', '29-09-2026 12:50 PM'),
      ReceiptTextLine.field('رقم الفاتورة: ', 'ORD-000015', separator: ''),
      ReceiptTextLine.field('Arabic عربي\nEnglish label', '42'),
      ReceiptTextLine.field('Comment تعليق',
          'Long business value that must wrap across several lines on narrow paper'),
    ];
    // Compare the actual painted phone digits to a standalone LTR phone.
    // This catches the original bug even when extracted PDF text looks valid.
    await tester.runAsync(() async {
      final baseline = await ArabicPrinterHelper.renderReceiptToImage(rows: [
        TextRow('9845243437',
            align: TextAlign.left, textDirectionOverride: TextDirection.ltr)
      ], width: 576);
      final mixed = await ArabicPrinterHelper.renderReceiptToImage(
          rows: [FieldTextRow(fields.first, align: TextAlign.left)],
          width: 576);
      var lastInkX = 0;
      for (var y = 0; y < baseline.height; y++) {
        for (var x = 0; x < baseline.width; x++) {
          if (baseline.getPixel(x, y).r < 200) {
            lastInkX = x > lastInkX ? x : lastInkX;
          }
        }
      }
      expect(lastInkX, greaterThan(50));
      expect(mixed.height, greaterThanOrEqualTo(baseline.height));
      for (var y = 0; y < baseline.height; y++) {
        for (var x = 0; x <= lastInkX; x++) {
          expect(mixed.getPixel(x, y).r, baseline.getPixel(x, y).r,
              reason: 'Mixed caption must not move or reorder phone digits');
        }
      }
    });
    for (final width in [240.0, 384.0, 576.0]) {
      final rows = fields
          .map((line) => FieldTextRow(line, align: TextAlign.left))
          .toList();
      final tall = rows.last.calculateHeight(width, 24, TextDirection.rtl);
      expect(tall, greaterThan(24));
      await tester.runAsync(() async {
        final image = await ArabicPrinterHelper.renderReceiptToImage(
            rows: rows, width: width, fontSize: 24);
        expect(image.width, width.toInt());
        expect(image.height, greaterThan(200));
        File('${output.path}/thermal_${width.toInt()}.png')
            .writeAsBytesSync(img.encodePng(image));
      });
    }
    final font = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final document = pw.Document();
    document.addPage(pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => pw.Column(children: [
              for (final line in fields)
                pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Container(
                        width: double.infinity,
                        child: pdfReceiptLine(line,
                            style: const pw.TextStyle(fontSize: 12)))),
            ])));
    await tester.runAsync(() async {
      File('${output.path}/mixed_fields.pdf')
          .writeAsBytesSync(await document.save());
    });
  });
}
