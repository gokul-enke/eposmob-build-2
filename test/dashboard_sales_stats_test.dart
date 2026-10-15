import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/dashboard_api.dart';

void main() {
  test('sales stats reads channel counts from the current API keys', () {
    final stats = SalesStats.fromJson({
      'status': 'success',
      'data': {
        'total_order': 1293,
        'pos_order': 1291,
        'web_order': 2,
        'kiosk_order': 0,
        'delivery_method': [],
        'payments': [],
      },
    });

    expect(stats.posOrders, 1291);
    expect(stats.webOrders, 2);
    expect(stats.kioskOrders, 0);
  });

  test('sales stats still accepts the older numeric keys', () {
    final stats = SalesStats.fromJson({
      'data': {'4': '7', '5': 3, '6': null},
    });

    expect(stats.posOrders, 7);
    expect(stats.webOrders, 3);
    expect(stats.kioskOrders, 0);
  });
}
