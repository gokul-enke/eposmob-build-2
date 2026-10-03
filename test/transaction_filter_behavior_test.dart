import 'package:pos_machine/features/expenses/domain/expense_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/transactions/proforma_invoice_list.dart';

void main() {
  group('Proforma responsive filters', () {
    test('uses the mobile filter layout below the desktop breakpoint', () {
      expect(useProformaMobileLayout(699), isTrue);
    });

    test('uses the desktop filter layout at and above the breakpoint', () {
      expect(useProformaMobileLayout(proformaMobileBreakpoint), isFalse);
      expect(useProformaMobileLayout(899), isFalse);
      expect(useProformaMobileLayout(1200), isFalse);
    });
  });

  group('Expense active-filter indicator', () {
    test('does not mark empty or All selections as active', () {
      expect(
        isMeaningfulExpenseFilterSelection(null, allLabel: 'All'),
        isFalse,
      );
      expect(
        isMeaningfulExpenseFilterSelection('All', allLabel: 'All'),
        isFalse,
      );
      expect(
        isMeaningfulExpenseFilterSelection('الكل', allLabel: 'الكل'),
        isFalse,
      );
    });

    test('marks a real selection as active', () {
      expect(
        isMeaningfulExpenseFilterSelection('Pending', allLabel: 'All'),
        isTrue,
      );
    });
  });
}
