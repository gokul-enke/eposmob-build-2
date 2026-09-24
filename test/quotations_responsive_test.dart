import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/sales/widgets/quotations_responsive.dart';

void main() {
  group('quotation list layout', () {
    test('uses cards when available content is narrower than the table', () {
      expect(quotationsUseCards(774), isTrue);
      expect(quotationsUseCards(899), isTrue);
    });

    test('uses the table when its minimum width is available', () {
      expect(quotationsUseCards(900), isFalse);
      expect(quotationsUseCards(1600), isFalse);
    });
  });
}
