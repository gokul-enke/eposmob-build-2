import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_app_settings.dart';

Map<String, dynamic> _settingsJson(List<Map<String, dynamic>> settings) {
  return {'data': settings};
}

Map<String, dynamic> _setting(
  String code,
  dynamic status, {
  dynamic value = '',
}) {
  return {'code': code, 'status': status, 'value': value};
}

void main() {
  group('AppSettings.defaultDashboardPeriod', () {
    test('uses today when no dashboard property is active', () {
      final settings = AppSettings.fromJson(_settingsJson(const []));

      expect(settings.defaultDashboardPeriod, 'today');
    });

    final cases = <String, String>{
      'TODAY': 'today',
      'WEEK': 'week',
      'MONTH': 'month',
      'YEAR': 'year',
    };

    for (final entry in cases.entries) {
      test('${entry.key} value selects ${entry.value}', () {
        final settings = AppSettings.fromJson(
          _settingsJson([
            _setting(
              'DASHBOARD_DEFAULT_PERIOD',
              true,
              value: entry.key,
            ),
          ]),
        );

        expect(settings.defaultDashboardPeriod, entry.value);
      });
    }

    test('normalizes lowercase, mixed case, and surrounding whitespace', () {
      for (final value in ['year', 'Year', '  yEaR  ']) {
        final settings = AppSettings.fromJson(
          _settingsJson([
            _setting('DASHBOARD_DEFAULT_PERIOD', true, value: value),
          ]),
        );

        expect(settings.defaultDashboardPeriod, 'year');
      }
    });

    test('accepts active status returned as 1 or a true string', () {
      final numericStatus = AppSettings.fromJson(
        _settingsJson([
          _setting('DASHBOARD_DEFAULT_PERIOD', 1, value: 'MONTH'),
        ]),
      );
      final stringStatus = AppSettings.fromJson(
        _settingsJson([
          _setting('DASHBOARD_DEFAULT_PERIOD', 'true', value: 'WEEK'),
        ]),
      );

      expect(numericStatus.defaultDashboardPeriod, 'month');
      expect(stringStatus.defaultDashboardPeriod, 'week');
    });

    test('uses today when the property is inactive', () {
      final settings = AppSettings.fromJson(
        _settingsJson([
          _setting('DASHBOARD_DEFAULT_PERIOD', false, value: 'YEAR'),
        ]),
      );

      expect(settings.defaultDashboardPeriod, 'today');
    });

    test('uses today when the property value is empty or invalid', () {
      for (final value in ['', 'DAILY', null]) {
        final settings = AppSettings.fromJson(
          _settingsJson([
            _setting('DASHBOARD_DEFAULT_PERIOD', true, value: value),
          ]),
        );

        expect(settings.defaultDashboardPeriod, 'today');
      }
    });
  });
}
