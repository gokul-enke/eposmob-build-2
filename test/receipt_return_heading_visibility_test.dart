import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';

void main() {
  test('serial visibility cannot reveal a hidden product or its variants', () {
    for (final name in ['Coffee (Large)', 'قهوة (كبير)', 'Coffee قهوة (Large)']) {
      String heading(bool serial, bool particulars) =>
          ReceiptSections.returnItemHeading(name: name, number: 12,
              showSerial: serial, showParticulars: particulars);
      expect(heading(true, false), '12.');
      expect(heading(false, true), name);
      expect(heading(true, true), '12. $name');
      expect(heading(false, false), isEmpty);
    }
  });

  test('missing product name does not add spacing to serial-only content', () {
    expect(ReceiptSections.returnItemHeading(name: '  ', number: 1,
        showSerial: true, showParticulars: true), '1.');
  });
}
