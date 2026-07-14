import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/layouts/premium2_bilingual_receipt_layout.dart';

void main() {
  testWidgets('bilingual totals reserve height for both label lines',
      (tester) async {
    const width = 576.0;
    const fontSize = 24.0;

    final singleLine = BoxedTotalsRow(items: [
      BoxedLineItem(
        label: 'إجمالي السعر الأقصى',
        value: '40.78',
        isBold: true,
        scale: 1.1,
        currencySymbol: 'ر.س',
      ),
    ]);
    final bilingual = BoxedTotalsRow(items: [
      BoxedLineItem(
        label: 'إجمالي السعر الأقصى\nMRP Total',
        value: '40.78',
        isBold: true,
        scale: 1.1,
        currencySymbol: 'ر.س',
      ),
    ]);

    final singleHeight = singleLine.calculateHeight(
      width,
      fontSize,
      TextDirection.rtl,
    );
    final bilingualHeight = bilingual.calculateHeight(
      width,
      fontSize,
      TextDirection.rtl,
    );

    expect(bilingualHeight, greaterThan(singleHeight + 10));
  });
}
