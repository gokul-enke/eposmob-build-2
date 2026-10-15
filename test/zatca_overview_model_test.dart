import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/dashboard_api.dart';
import 'package:pos_machine/providers/dashboard_provider.dart';

void main() {
  group('ZatcaOverview.fromJson', () {
    test('parses the documented response fields', () {
      final overview = ZatcaOverview.fromJson({
        'success_zatca': 12,
        'not_sent': 3,
        'failed': 2,
        'warning': 1,
        'voucher_success': 9,
        'voucher_not_sent': 4,
        'voucher_failed': 3,
        'voucher_warning': 2,
      });

      expect(overview.successZatca, 12);
      expect(overview.notSent, 3);
      expect(overview.failed, 2);
      expect(overview.warning, 1);
      expect(overview.voucherSuccess, 9);
      expect(overview.voucherNotSent, 4);
      expect(overview.voucherFailed, 3);
      expect(overview.voucherWarning, 2);
    });

    test('accepts numeric strings and safely defaults invalid values', () {
      final overview = ZatcaOverview.fromJson({
        'success_zatca': '8',
        'not_sent': null,
        'failed': 'invalid',
        'warning': 4.0,
        'voucher_success': '7',
        'voucher_not_sent': null,
        'voucher_failed': 'invalid',
        'voucher_warning': 3.0,
      });

      expect(overview.successZatca, 8);
      expect(overview.notSent, 0);
      expect(overview.failed, 0);
      expect(overview.warning, 4);
      expect(overview.voucherSuccess, 7);
      expect(overview.voucherNotSent, 0);
      expect(overview.voucherFailed, 0);
      expect(overview.voucherWarning, 3);
    });

    test('keeps older invoice-only responses compatible', () {
      final overview = ZatcaOverview.fromJson({
        'success_zatca': 12,
        'not_sent': 3,
        'failed': 2,
        'warning': 1,
      });

      expect(overview.successZatca, 12);
      expect(overview.notSent, 3);
      expect(overview.failed, 2);
      expect(overview.warning, 1);
      expect(overview.voucherSuccess, 0);
      expect(overview.voucherNotSent, 0);
      expect(overview.voucherFailed, 0);
      expect(overview.voucherWarning, 0);
    });
  });

  group('DashboardProvider.zatcaOverviewQuery', () {
    for (final period in ['today', 'week', 'month']) {
      test('sends the $period period', () {
        expect(
          DashboardProvider.zatcaOverviewQuery(period),
          {'period': period},
        );
      });
    }

    test('maps year to a custom current-year date range', () {
      expect(
        DashboardProvider.zatcaOverviewQuery(
          'year',
          now: DateTime(2026, 9, 14),
        ),
        {
          'period': 'custom',
          'start_date': '01-01-2026',
          'end_date': '14-09-2026',
        },
      );
    });

    test('normalizes casing and whitespace', () {
      expect(
        DashboardProvider.zatcaOverviewQuery('  MoNtH  '),
        {'period': 'month'},
      );
    });

    test('rejects unsupported periods', () {
      expect(
        () => DashboardProvider.zatcaOverviewQuery('day'),
        throwsArgumentError,
      );
    });
  });
}
