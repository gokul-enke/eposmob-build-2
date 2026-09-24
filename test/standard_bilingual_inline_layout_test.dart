import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/layouts/common/layout_rows.dart';

void main() {
  test('bilingual labels use one space and no visible separator', () {
    final label = inlineBilingualLabel('العميل:\nCustomer:');

    expect(label, '\u2067العميل:\u2069 \u2066Customer:\u2069');
    expect(label, isNot(contains('\n')));
    expect(label, isNot(contains('/')));
  });

  test('boxed totals normalize bilingual labels to a single row', () {
    final item = StandardBoxedLineItem(
      label: 'المجموع الفرعي\nSUBTOTAL',
      value: '11.93',
    );

    expect(item.label, '\u2067المجموع الفرعي\u2069 \u2066SUBTOTAL\u2069');
    expect(item.label, isNot(contains('\n')));
    expect(item.label, isNot(contains('/')));
  });

  test('customer labels remove trailing colons from both languages', () {
    final label = inlineBilingualLabel(
      withoutTrailingLabelColons('العميل:\nCustomer:'),
    );

    expect(label, '\u2067العميل\u2069 \u2066Customer\u2069');
    expect(label, isNot(contains(':')));
  });

  test('customer balance labels use one bilingual row', () {
    final label = inlineBilingualLabel('الرصيد الحالي\nE-CURRENT-BAL');

    expect(label, '\u2067الرصيد الحالي\u2069 \u2066E-CURRENT-BAL\u2069');
    expect(label, isNot(contains('\n')));
  });
}
