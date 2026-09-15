import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/dashboard_provider.dart';

void main() {
  group('DashboardProvider.executiveSalesGraphQuery', () {
    for (final period in ['today', 'week', 'month']) {
      test('$period sends only the preset period', () {
        expect(
          DashboardProvider.executiveSalesGraphQuery(period),
          {'period': period},
        );
      });
    }

    test('normalizes preset period casing and whitespace', () {
      expect(
        DashboardProvider.executiveSalesGraphQuery('  ToDaY  '),
        {'period': 'today'},
      );
    });

    test('year sends only a dynamic dd-MM-yyyy date range', () {
      expect(
        DashboardProvider.executiveSalesGraphQuery(
          'year',
          now: DateTime(2026, 9, 14),
        ),
        {
          'start_date': '01-01-2026',
          'end_date': '14-09-2026',
        },
      );
    });

    test('rejects unsupported periods', () {
      expect(
        () => DashboardProvider.executiveSalesGraphQuery('day'),
        throwsArgumentError,
      );
    });
  });
}
