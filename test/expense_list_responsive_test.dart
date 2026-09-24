import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/transactions/widgets/expense_list_responsive.dart';

void main() {
  group('expense list layout', () {
    test('uses cards when available content is narrower than the table', () {
      expect(expenseListUseCards(774), isTrue);
      expect(expenseListUseCards(879), isTrue);
    });

    test('uses the table when its minimum width is available', () {
      expect(expenseListUseCards(880), isFalse);
      expect(expenseListUseCards(1600), isFalse);
    });
  });
}
