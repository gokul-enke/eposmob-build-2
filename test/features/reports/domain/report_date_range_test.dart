import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/report_date_range.dart';

void main() {
  test('formats both ends for the API', () {
    final range = ReportDateRange(
        from: DateTime(2026, 9, 1, 10, 30), to: DateTime(2026, 9, 30, 22));
    expect(range.apiFrom, '2026-09-01 10:30:00');
    expect(range.apiTo, '2026-09-30 22:00:00');
    expect(range.isInverted, isFalse);
  });

  test('From after To is inverted; open ends are not', () {
    expect(
        ReportDateRange(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 1))
            .isInverted,
        isTrue);
    expect(ReportDateRange(from: DateTime(2026, 10, 2)).isInverted, isFalse);
    expect(ReportDateRange.empty.isEmpty, isTrue);
  });

  test('copyWith can clear one end', () {
    final range = ReportDateRange(from: DateTime(2026), to: DateTime(2027));
    final cleared = range.copyWith(from: () => null);
    expect(cleared.from, isNull);
    expect(cleared.to, DateTime(2027));
    expect(cleared, ReportDateRange(to: DateTime(2027)));
  });
}
