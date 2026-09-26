import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_address_view_widget.dart';

void main() {
  testWidgets('shows district, city, and readable pincode separately',
      (tester) async {
    final customer = CustomerListModelData(
      name: 'Test Customer',
      addresses: [
        Address(
          address: 'Main Road',
          district: 'Jeddah District',
          city: 'Jeddah City',
          pincodeId: 4858,
          pincode: '21442',
          type: 'Home',
        ),
      ],
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CustomerAddressViewWidget(
                size: const Size(1200, 800),
                customer: customer,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Jeddah District'), findsOneWidget);
    expect(find.text('Jeddah City'), findsOneWidget);
    expect(find.text('21442'), findsOneWidget);
    expect(find.text('4858'), findsNothing);
  });
}
