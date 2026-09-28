import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_app_settings.dart';

AppSettings _parse(List<Map<String, dynamic>> settings) =>
    AppSettings.fromJson({'data': settings});

Map<String, dynamic> _offlineFirst(dynamic status) =>
    {'code': 'OFFLINE_FIRST_SALES', 'status': status, 'value': ''};

void main() {
  group('AppSettings.offlineFirstSales', () {
    test('keeps offline-first when the tenant has no such setting', () {
      expect(_parse(const []).offlineFirstSales, isTrue);
    });

    test('a disabled status switches the tenant to online-first', () {
      for (final status in [false, 'false', '0', 0]) {
        expect(
          _parse([_offlineFirst(status)]).offlineFirstSales,
          isFalse,
          reason: 'status $status',
        );
      }
    });

    test('an enabled status keeps offline-first', () {
      for (final status in [true, 'true', '1', 1]) {
        expect(
          _parse([_offlineFirst(status)]).offlineFirstSales,
          isTrue,
          reason: 'status $status',
        );
      }
    });

    test('survives a toJson/fromJson round trip', () {
      final onlineFirst = _parse([_offlineFirst(false)]);
      expect(
        AppSettings.fromJson(onlineFirst.toJson()).offlineFirstSales,
        isFalse,
      );
    });
  });
}
