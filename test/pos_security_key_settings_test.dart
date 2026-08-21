import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_app_settings.dart';

void main() {
  test('parses the clear-cart authentication setting and its key value', () {
    final settings = AppSettings.fromJson({
      'data': [
        {
          'code': 'POS_AUTHENTICATE_CLEARCART',
          'status': '1',
          'value': '0427',
        },
      ],
    });

    expect(settings.posAuthenticateClearCart, isTrue);
    expect(settings.posAuthenticateClearCartKey, '0427');
  });

  test('does not expose a disabled clear-cart key', () {
    final settings = AppSettings.fromJson({
      'data': [
        {
          'code': 'POS_AUTHENTICATE_CLEARCART',
          'status': false,
          'value': '0427',
        },
      ],
    });

    expect(settings.posAuthenticateClearCart, isFalse);
    expect(settings.posAuthenticateClearCartKey, isEmpty);
  });
}
