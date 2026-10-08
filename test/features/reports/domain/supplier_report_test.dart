import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/supplier_report.dart';

void main() {
  Map<String, dynamic> group(dynamic id, {String? name}) => {
        'supplier_id': id,
        'supplier_name': name,
        'total_debit': '125.25',
        'total_credit': 50,
        'balance': '-75.25',
        'transactions': [{}, {}],
      };
  test('groups by ID, retains numeric strings, ordering and ledger balance',
      () {
    final result = SupplierReportPage.parse({
      'data': {
        'data': [group(7, name: 'Same'), group('8', name: 'Same')],
        'current_page': '2',
        'last_page': 4.0,
      }
    });
    expect(result.rows.keys, ['7', '8']);
    expect(result.page, 2);
    expect(result.pages, 4);
    final row = result.rows['7']!;
    expect(row.totalDebit, 125.25);
    expect(row.totalCredit, 50);
    expect(row.balance, -75.25);
    expect(row.transactionCount, 2);
  });
  test('legacy groups keep one page and unknown names remain presentation data',
      () {
    final result = SupplierReportPage.parse({
      'data': [null, group(''), group(7)]
    });
    expect(result.rows.keys, ['7']);
    expect(result.rows['7']!.displayName, isNull);
    expect(result.page, 1);
    expect(result.pages, 1);
    expect(SupplierReportPage.parse({'data': []}).rows, isEmpty);
  });
  test('retains last group for a repeated ID and rejects malformed envelopes',
      () {
    final result = SupplierReportPage.parse({
      'data': [group(7, name: 'Old'), group('7', name: 'New')]
    });
    expect(result.rows.length, 1);
    expect(result.rows['7']!.displayName, 'New');
    expect(() => SupplierReportPage.parse({'data': {}}), throwsFormatException);
  });
  test('date validation allows open bounds and rejects inverted ranges', () {
    expect(const SupplierReportQuery().isDateRangeValid, isTrue);
    expect(const SupplierReportQuery(fromDate: '2026-10-01').isDateRangeValid,
        isTrue);
    expect(
        const SupplierReportQuery(fromDate: '2026-10-02', toDate: '2026-10-01')
            .isDateRangeValid,
        isFalse);
  });
}
