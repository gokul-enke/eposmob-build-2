import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_app_settings.dart';

void main() {
  test('WhatsApp action is hidden until explicitly enabled', () {
    final settings = AppSettings.fromJson({'data': []});
    expect(settings.showConfirmWhatsappButton, isFalse);
    expect(settings.showConfirmOrderButton, isTrue);
    expect(settings.showConfirmOrderAndPrintButton, isTrue);
  });

  for (final status in [true, 'true', '1', 1, false, 'false', '0', 0]) {
    test('parses and caches WhatsApp button status $status', () {
      final settings = AppSettings.fromJson({
        'data': [
          {'code': 'SHOW_CONFIRM_WHATSAPP_BUTTON', 'status': status},
          {'code': 'SHOW_CONFIRM_ORDER_BUTTON', 'status': false},
          {'code': 'SHOW_CONFIRM_ORDER_AND_PRINT_BUTTON', 'status': false},
        ],
      });
      final enabled = [true, 'true', '1', 1].contains(status);
      expect(settings.showConfirmWhatsappButton, enabled);
      expect(settings.showConfirmOrderButton, isFalse);
      expect(settings.showConfirmOrderAndPrintButton, isFalse);
      expect(AppSettings.fromJson(settings.toJson()).showConfirmWhatsappButton,
          enabled);
    });
  }
}
