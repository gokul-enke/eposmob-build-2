import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/order_details.dart';

void main() {
  test('parses the external delivery job returned by order details', () {
    final order = OrderDetailsModelData.fromJson({
      'orders_id': 5982,
      'order_number': 'ORD-5982',
      'external_delivery_job': {
        'id': 10,
        'external_logistic_id': 1,
        'shipping_service': 'parcel',
        'transport_mode': 'surface',
        'warehouse_id': 2,
        'external_shipment_id': 'ABC123',
        'tracking_url': 'https://track.example.com/ABC123',
        'payment_mode': 'COD',
        'cod_amount': '1500.00',
        'package_count': 1,
        'external_logistic': {'id': 1, 'name': 'Delhivery'},
        'warehouse': {'id': 2, 'name': 'Main Warehouse'},
      },
    });

    final job = order.externalDeliveryJob;
    expect(job, isNotNull);
    expect(job!.hasDetails, isTrue);
    expect(job.externalLogisticName, 'Delhivery');
    expect(job.warehouseName, 'Main Warehouse');
    expect(job.shippingService, 'parcel');
    expect(job.paymentMode, 'COD');
  });
}
