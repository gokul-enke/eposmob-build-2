import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/layouts/common/layout_rows.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

void main() {
  testWidgets('return headings and dense numeric rows keep empty gutters at both receipt widths',
      (tester) async {
    final loader = FontLoader(ArabicPrinterHelper.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await loader.load();
    for (final width in [384, 576]) {
      for (final bilingual in [false, true]) {
       for (final kind in ['headers', 'extended_headers', 'values']) {
        final extra = kind != 'headers';
        final weights = [0.15, 0.15, 0.12, 0.15, if (extra) ...[0.15, 0.15], 0.15, 0.25, 0.08];
        final labels = kind == 'values'
            ? ['1200.50', '480.20', '2.5', '480.20', '18%', '0090121', '500.00', '', '']
            : ['الإجمالي', 'السعر', 'الكمية', 'سعر الوحدة', if (extra) ...['نسبة الضريبة', 'رمز الصنف'], 'MRP', 'الوصف', '#'];
        final english = ['TOTAL', 'RATE', 'QTY', 'UNIT PRICE', if (extra) ...['TAX RATE', 'HSN'], 'MRP', 'DESCRIPTION', 'SL#'];
        final total = weights.reduce((a, b) => a + b);
        final columns = [
          for (var i = 0; i < weights.length; i++)
            ReceiptTableColumn(bilingual && kind != 'values' ? '${labels[i]}\n${english[i]}' : labels[i],
              weight: weights[i] / total, align: TextAlign.right, isBold: true),
        ];
        final row = MultiLineReceiptTableRow(columns);
        const fontSize = 30.0;
        final height = row.calculateHeight(width.toDouble(), fontSize, TextDirection.rtl).ceil();
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
              Paint()..color = Colors.white);
          row.render(canvas, 0, width.toDouble(), fontSize, TextDirection.rtl);
          final picture = recorder.endRecording();
          final image = await picture.toImage(width, height);
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          var boundary = 0.0;
          for (final column in columns.take(columns.length - 1)) {
            boundary += width * column.weight;
            // Check the central four pixels of the eight-pixel cell gutter.
            for (var x = boundary.ceil() - 2; x <= boundary.floor() + 1; x++) {
              for (var y = 0; y < height; y++) {
                final offset = (y * width + x) * 4;
                expect(bytes.getUint8(offset), greaterThanOrEqualTo(250),
                    reason: '$width bilingual=$bilingual ink at gutter ($x,$y)');
              }
            }
          }
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final output = File('build/receipt_header_spacing/${width}_${bilingual ? 'both' : 'ar'}_$kind.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(png.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        });
       }
      }
    }
  });
}
