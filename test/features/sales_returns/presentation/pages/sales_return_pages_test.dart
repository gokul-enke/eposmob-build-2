import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_machine/features/sales_returns/presentation/pages/create_sales_return_page.dart';
import 'package:pos_machine/features/sales_returns/presentation/pages/sales_return_list_page.dart';
import 'package:pos_machine/features/sales_returns/presentation/pages/sales_return_detail_modal.dart';
import '../../support/page_fakes.dart';
import '../../support/return_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'active_store_id': 1, 'api_key': 'tenant'});
  });
  tearDown(Get.reset);
  testWidgets(
      'item dialog cancels and releases its inputs after route transition',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrapReturnPage(const CreateSalesReturnPage()));
    await tester.pumpAndSettle();
    final returnButton = find.text('sales_return_form.btn_return_item'.tr);
    await tester.ensureVisible(returnButton.first);
    await tester.tap(returnButton.first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('general.cancel'.tr));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(375, 812), const Size(1440, 900)]) {
    testWidgets('list loads and details renders at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrapReturnPage(const SalesReturnListPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('2.00'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(wrapReturnPage(
          SalesReturnDetailModal(order: returnPage().data.data.single)));
      await tester.pumpAndSettle();
      expect(find.textContaining('2.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
    testWidgets('form loads selected order at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrapReturnPage(const CreateSalesReturnPage()));
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsWidgets);
      expect(find.textContaining('INV-100'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
