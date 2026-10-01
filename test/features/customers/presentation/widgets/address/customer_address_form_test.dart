import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/widgets/address/customer_address_form.dart';

const _states = [MapEntry('1', 'Kerala'), MapEntry('2', 'Makkah')];
const _districts = [MapEntry('10', 'Ernakulam')];
const _pincodes = [MapEntry('100', '682001')];

Future<List<Map<String, dynamic>>> _pumpForm(
  WidgetTester tester, {
  Address? address,
  bool requirePincode = false,
  List<String>? stateCalls,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final submitted = <Map<String, dynamic>>[];
  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomerAddressForm(
            customer: CustomerListModelData(id: 7, name: 'Asha', phone: '555'),
            address: address,
            requirePincode: requirePincode,
            states: _states,
            districts: _districts,
            pincodes: _pincodes,
            onStateSelected: stateCalls?.add,
            onSubmit: submitted.add,
            onCancel: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return submitted;
}

Finder _saveButton() => find.text('customer_address.btn_save_address'.tr);

void main() {
  testWidgets('requires the address line', (tester) async {
    final submitted = await _pumpForm(tester);

    await tester.tap(_saveButton());
    await tester.pump();

    expect(find.text('customer_address.required'.tr), findsOneWidget);
    expect(submitted, isEmpty);
  });

  testWidgets('requires a pincode when asked to', (tester) async {
    final submitted = await _pumpForm(tester, requirePincode: true);

    await tester.enterText(
        find.byKey(const ValueKey('address_field')), 'Line 1');
    await tester.tap(_saveButton());
    await tester.pump();

    expect(find.text('customer_address.pincode_required'.tr), findsOneWidget);
    expect(submitted, isEmpty);
  });

  testWidgets('submits the add payload', (tester) async {
    final stateCalls = <String>[];
    final submitted = await _pumpForm(tester, stateCalls: stateCalls);

    await tester.enterText(
        find.byKey(const ValueKey('address_field')), 'Line 1');
    await tester.enterText(find.byKey(const ValueKey('city_field')), 'Kochi');
    await tester.enterText(
        find.byKey(const ValueKey('landmark_field')), 'Temple');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kerala').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('customer_address.type_home'.tr));
    await tester.pumpAndSettle();
    await tester.tap(find.text('customer_address.type_office'.tr).last);
    await tester.pumpAndSettle();

    await tester.tap(_saveButton());
    await tester.pump();

    expect(stateCalls, ['1']);
    expect(submitted.single, {
      'customer_id': 7,
      'name': 'Asha',
      'phone': '555',
      'address': 'Line 1',
      'city': 'Kochi',
      'state_id': '1',
      'district_id': null,
      'pincode_id': null,
      'landmark': 'Temple',
      'type': 'Office',
    });
  });

  testWidgets('prefills an edited address and keeps its ids', (tester) async {
    final submitted = await _pumpForm(
      tester,
      address: Address(
        id: 3,
        name: 'Desk',
        phone: '999',
        address: 'Old line',
        city: 'Kochi',
        stateId: 1,
        districtId: 10,
        pincodeId: 100,
        type: 'Warehouse',
      ),
    );

    expect(find.text('Old line'), findsOneWidget);
    expect(find.text('Kerala'), findsOneWidget);
    expect(find.text('682001'), findsOneWidget);
    // An unknown type from the API still shows instead of crashing.
    expect(find.text('Warehouse'), findsOneWidget);

    await tester.tap(find.text('customer_address.btn_update_address'.tr));
    await tester.pump();

    expect(submitted.single, containsPair('name', 'Desk'));
    expect(submitted.single, containsPair('phone', '999'));
    expect(submitted.single, containsPair('state_id', '1'));
    expect(submitted.single, containsPair('district_id', '10'));
    expect(submitted.single, containsPair('pincode_id', '100'));
    expect(submitted.single, containsPair('type', 'Warehouse'));
  });
}
