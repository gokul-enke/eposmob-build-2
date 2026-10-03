import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/customer_report.dart';

import '../support/report_fixtures.dart';

void main() {
  test('counts accept integer strings; money preserves precision', () {
    final row = CustomerReportPage.parse(
            customerReportResponse(1, [customerGroup('42')]), 1)
        .rows
        .single;
    expect(row.id, '42');
    expect(row.count, 3);
    expect(row.debit, 12.125);
  });

  test('same names with distinct IDs remain distinct', () {
    expect(
        CustomerReportPage.parse(
                customerReportResponse(1, [customerGroup(1), customerGroup(2)]),
                1)
            .rows
            .length,
        2);
  });

  for (final bad in ['NaN', 'Infinity', 'invalid', null]) {
    test('rejects invalid money $bad', () {
      final row = customerGroup(1)..['total_debit'] = bad;
      expect(
          () => CustomerReportPage.parse(customerReportResponse(1, [row]), 1),
          throwsFormatException);
    });
  }

  test('rejects a wrong page and duplicate normalized IDs', () {
    expect(
        () => CustomerReportPage.parse(
            customerReportResponse(1, [customerGroup(1)]), 2),
        throwsFormatException);
    expect(
        () => CustomerReportPage.parse(
            customerReportResponse(1, [customerGroup(1), customerGroup('1')]),
            1),
        throwsFormatException);
  });

  test('rejects a failed response', () {
    expect(() => CustomerReportPage.parse({'status': 'error'}, 1),
        throwsFormatException);
  });
}
