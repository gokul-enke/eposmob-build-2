import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_address_controller.dart';
import 'package:pos_machine/features/customers/presentation/widgets/address/customer_address_tab.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:provider/provider.dart';

class _FakeLocationProvider extends LocationProvider {
  @override
  Future<void> listAllStates(String accessToken) async {}

  @override
  Future<void> listAllDistricts({
    required String accessToken,
    required String stateId,
  }) async {}

  @override
  Future<void> listAllPincodes({
    required String accessToken,
    required String districtId,
  }) async {}
}

final _jeddah = Address(
  id: 1,
  address: 'Main Road',
  district: 'Jeddah District',
  city: 'Jeddah City',
  pincodeId: 4858,
  pincode: '21442',
  type: 'Home',
);

class _Harness {
  _Harness(List<Address> addresses) {
    controller = CustomerAddressController(
      customer: CustomerListModelData(
        id: 9,
        name: 'Test Customer',
        addresses: addresses,
      ),
      readToken: () async => 'tok',
      reloadCustomer: (_, __) async {
        reloads++;
        return {'status': 'error'};
      },
      createAddress: (_, data) async {
        saved.add(data);
        return {
          'status': 'success',
          'message': 'Saved',
          'data': {'id': 2, ...data},
        };
      },
      updateAddress: (_, id, data) async {
        saved.add({'id': id, ...data});
        return {
          'status': 'success',
          'message': 'Saved',
          'data': {..._jeddah.toJson(), ...data, 'id': id},
        };
      },
    );
  }

  late final CustomerAddressController controller;
  int reloads = 0;
  final saved = <Map<String, dynamic>>[];
}

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(harness.controller.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthModel>(
          create: (_) => AuthModel()..login('tok', 1),
        ),
        ChangeNotifierProvider<LocationProvider>(
          create: (_) => _FakeLocationProvider(),
        ),
      ],
      child: GetMaterialApp(
        home: Scaffold(
          body: CustomerAddressTab(
            customer: harness.controller.customer,
            controller: harness.controller,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows district, city, and readable pincode separately',
      (tester) async {
    final harness = _Harness([_jeddah]);
    await _pump(tester, harness);

    expect(harness.reloads, 1);
    expect(find.text('Main Road'), findsOneWidget);
    expect(find.text('Jeddah District'), findsOneWidget);
    expect(find.text('Jeddah City'), findsOneWidget);
    expect(find.text('21442'), findsOneWidget);
    expect(find.text('4858'), findsNothing);
  });

  testWidgets('shows the empty state without addresses', (tester) async {
    final harness = _Harness([]);
    await _pump(tester, harness);

    expect(find.text('customer_address.no_address_found'.tr), findsOneWidget);
  });

  testWidgets('edits an address through the form dialog', (tester) async {
    final harness = _Harness([_jeddah]);
    await _pump(tester, harness);

    await tester.tap(find.byTooltip('customer_address.title_edit'.tr));
    await tester.pumpAndSettle();

    expect(find.text('customer_address.title_edit'.tr), findsWidgets);
    await tester.enterText(
        find.byKey(const ValueKey('address_field')), 'Harbour Road');
    await tester.tap(find.text('customer_address.btn_update_address'.tr));
    await tester.pumpAndSettle();
    // Let the save toast time out.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(harness.saved.single['id'], 1);
    expect(harness.saved.single['address'], 'Harbour Road');
    expect(find.byKey(const ValueKey('address_field')), findsNothing);
    expect(find.text('Harbour Road'), findsOneWidget);
    // Reloaded once on open and once after saving.
    expect(harness.reloads, 2);
  });
}
