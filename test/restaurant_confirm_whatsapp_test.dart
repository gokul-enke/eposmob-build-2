import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  final page = _read('lib/screens/billing/restaurant/restaurant_page.dart');
  final panel =
      _read('lib/screens/billing/restaurant/widgets/order_panel.dart');

  test('counter bar shows Confirm & WhatsApp only when the setting is on', () {
    expect(page, contains('appSettings?.showConfirmWhatsappButton ?? false'));
    expect(page, contains('if (showConfirmAndWhatsappButton) ...['));
    expect(page, contains("'general.confirm_and_whatsapp'.tr"));
    expect(page, contains('showCurrentCartConfirmAndWhatsappFromParent()'));
  });

  test('WhatsApp loading has its own flag and blocks every checkout action',
      () {
    expect(page, contains('_isLoadingCounterConfirmAndPrint ||\n'
        '            _isLoadingCounterConfirmAndWhatsapp;'));
    expect(page, contains('if (whatsappReceipt) {\n'
        '        _isLoadingCounterConfirmAndWhatsapp = isLoading;'));
  });

  test('entry point respects the setting and mirrors Confirm & Print', () {
    final start =
        panel.indexOf('void showCurrentCartConfirmAndWhatsappFromParent()');
    expect(start, isNonNegative);
    final body = panel.substring(
        start, panel.indexOf('void showCurrentCartConfirmAndPrintFromParent'));
    expect(body, contains('showConfirmWhatsappButton ?? false)) return;'));
    expect(body, contains('if (_skipCheckoutOnConfirmAndPrint)'));
    expect(
        body,
        contains('_confirmCurrentCartAndPrintWithoutCheckoutModal('
            'whatsappReceipt: true)'));
    expect(body, contains('showCheckoutFromParent(forCurrentCart: true);'));
  });

  test('skip-checkout WhatsApp confirms without printing', () {
    final start =
        panel.indexOf('Future<void> _confirmCurrentCartAndPrintWithoutCheckoutModal(');
    final body = panel.substring(
        start, panel.indexOf('void showCurrentCartConfirmAndWhatsappFromParent'));
    expect(body, contains('await _confirmCurrentCart(\n'
        '        printBill: !whatsappReceipt,\n'
        '        whatsappReceipt: whatsappReceipt,'));
  });
}
