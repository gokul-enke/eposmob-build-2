import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/report_period.dart';
import 'package:pos_machine/features/reports/domain/report_values.dart';
import '../../../test_support/app_translations.dart';

/// The generic report pieces: Date Range options, value readers and the
/// strings of the shared filter widgets.
void main() {
  group('ReportPeriod', () {
    // Wednesday 14 Oct 2026, mid-afternoon.
    final now = DateTime(2026, 10, 14, 15, 30);
    String r(ReportPeriod p) {
      final range = p.approximateRange(now);
      return '${reportApiDate(range.from!)} → ${reportApiDate(range.to!)}';
    }

    test('approximate ranges prefill Custom with whole days', () {
      expect(r(ReportPeriod.today), '2026-10-14 → 2026-10-14');
      expect(r(ReportPeriod.thisWeek), '2026-10-12 → 2026-10-18');
      expect(r(ReportPeriod.thisMonth), '2026-10-01 → 2026-10-31');
      expect(r(ReportPeriod.lastMonth), '2026-09-01 → 2026-09-30');
      expect(r(ReportPeriod.last3Months), '2026-07-14 → 2026-10-14');
      expect(ReportPeriod.custom.approximateRange(now).isEmpty, isTrue);
      expect(ReportPeriod.lastMonth.approximateRange(DateTime(2026, 1, 9)).from,
          DateTime(2025, 12));
    });

    test('API date format', () {
      expect(reportApiDate(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });
  });

  test('amount and text readers', () {
    expect(reportInt('42'), 42);
    expect(reportInt(' x '), isNull);
    expect(reportAmount('1,250.50'), 1250.5);
    expect(reportAmount('NaN'), isNull);
    expect(reportAmount(double.infinity), isNull);
    expect(
        reportText([
          ' a ',
          null,
          '',
          {'name': 'b'}
        ]),
        'a, b');
    expect(reportText('  '), isNull);
    expect(reportField({'a': ' ', 'b': 'x'}, const ['a', 'b']), 'x');
  });

  test('report strings exist in English, Arabic and Malayalam', () {
    for (final section in [
      'report_period',
      'report_filters',
      'order_sales_report',
      'discount_sale_report'
    ]) {
      final en = translationSection('en', section).keys.toSet();
      for (final lang in ['ar', 'ml']) {
        final other = translationSection(lang, section);
        expect(other.keys.toSet(), en, reason: '$lang.$section');
        expect(other.values.where((v) => '$v'.trim().isEmpty), isEmpty,
            reason: '$lang.$section');
      }
    }
    final periods = translationSection('en', 'report_period');
    for (final period in ReportPeriod.values) {
      expect(periods, contains(period.labelKey.split('.').last));
    }
    for (final lang in ['en', 'ar', 'ml']) {
      final nav = translationSection(lang, 'nav');
      expect(nav, contains('sales_report'));
      expect(nav, contains('discount_sale_report'));
      // The shared section was split into the two reports' own sections.
      expect(() => translationSection(lang, 'order_report'), throwsA(anything));
    }
  });
}
