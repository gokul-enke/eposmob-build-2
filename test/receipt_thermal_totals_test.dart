import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/layouts/premium_receipt_layout.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

void main() {
  testWidgets('Premium totals reserve the measured Arabic text height',
      (tester) async {
    final loader = FontLoader(ArabicPrinterHelper.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await loader.load();
    const label = 'المبلغ الإجمالي';
    const size = 30.0;
    final painter = TextPainter(
      text: const TextSpan(text: label, style: TextStyle(
        fontFamily: ArabicPrinterHelper.fontFamily, fontSize: size)),
      textDirection: TextDirection.rtl,
    )..layout();
    final row = BoxedTotalsRow(items: [
      BoxedLineItem(label: label, value: '40.00'),
      BoxedLineItem(isSeparator: true),
      BoxedLineItem(label: label, value: '10.00'),
    ]);
    expect(row.calculateHeight(576, size, TextDirection.rtl),
        greaterThanOrEqualTo(30 + 12 + 2 * (painter.height + 8)));
    painter.dispose();
  });
}
