import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/sections/order_detail_inputs.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/sections/order_detail_overview.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/sections/order_detail_presentation_data.dart';
import 'package:pos_machine/models/order_details.dart';

final _deliveryLabel = 'sales_order_details.label_delivery_charge'.tr;
final _netTotalLabel = 'sales_order_details.label_net_total_inc_tax'.tr;

Future<void> _pumpOverview(WidgetTester tester, Object? deliveryCharge) async {
  // Phone width: the desktop header shows the avatar asset, which widget
  // tests can't load. The price summary is the same on both.
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Order details as the API returns them: the net total already holds the
  // delivery charge.
  final order = OrderDetailsModelData.fromJson({
    'orders_id': 7024,
    'order_number': 'ORD-7024',
    if (deliveryCharge != null) 'delivery_charge': deliveryCharge,
    'order_price_summary': {
      'net_total': '215.000',
      'net_exc_tax': '200.000',
      'total_tax': '15.000',
      'discount': '0.000',
      'net_payable': '215.000',
    },
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: OrderDetailOverview(
          inputs: OrderDetailInputs(
            currency: 'INR',
            data: OrderDetailPresentationData(
              orderDetailsModelData: order,
              priceSummary: null,
              cartItem: const [],
              customerDetails: null,
            ),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('the delivery charge is listed above the net total',
      (tester) async {
    await _pumpOverview(tester, '100.000');

    expect(find.text(_deliveryLabel), findsOneWidget);
    expect(find.text('INR 100.00'), findsOneWidget);
    expect(find.text('INR 215.00'), findsWidgets);
    expect(tester.getTopLeft(find.text(_deliveryLabel)).dy,
        lessThan(tester.getTopLeft(find.text(_netTotalLabel)).dy));
    expect(tester.takeException(), isNull);
  });

  for (final charge in [null, '0.000']) {
    testWidgets('no delivery charge row when the charge is $charge',
        (tester) async {
      await _pumpOverview(tester, charge);

      expect(find.text(_deliveryLabel), findsNothing);
      expect(find.text(_netTotalLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
