import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/sales_return/widgets/sales_return_responsive.dart';

void main() {
  group('sales return item layout', () {
    test('uses cards when the available content width is below table minimum', () {
      expect(salesReturnUseItemCards(774), isTrue);
      expect(salesReturnUseItemCards(959), isTrue);
    });

    test('uses the table when its minimum width is available', () {
      expect(salesReturnUseItemCards(960), isFalse);
      expect(salesReturnUseItemCards(1600), isFalse);
    });
  });
}
