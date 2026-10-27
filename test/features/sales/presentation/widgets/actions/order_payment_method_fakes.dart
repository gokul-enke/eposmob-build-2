import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:provider/provider.dart';

/// The company's payment methods, as master data returns them; [loaded]
/// false starts with none so the form has to fetch them.
class FakePaymentMethods extends MasterDataProvider {
  FakePaymentMethods({this.loaded = true});
  bool loaded;
  int fetches = 0;
  static final _methods = [
    MasterDataValue(id: 7974, value: 'CASH', description: 'Cash'),
    MasterDataValue(id: 7973, value: 'CARD', description: 'Card'),
  ];

  @override
  List<MasterDataValue>? get paymentMethods => loaded ? _methods : null;

  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
      {bool forceRefresh = false}) async {
    fetches++;
    loaded = true;
    notifyListeners();
    return _methods;
  }
}

/// Opens [modal] as a dialog, the way the order screens do.
Future<void> openOrderModal(
    WidgetTester tester, MasterDataProvider methods, Widget modal) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<MasterDataProvider>.value(
    value: methods,
    child: GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => modal),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Picks [label] in the [index]th dropdown of the open form.
Future<void> pickOption(WidgetTester tester, int index, String label) async {
  await tester.tap(find.byType(DropdownButton<String>).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String? dropdownValue(WidgetTester tester, int index) => tester
    .widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).at(index))
    .value;
