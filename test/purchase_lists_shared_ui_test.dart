import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/list/app_pagination_bar.dart';
import 'package:pos_machine/features/purchases/presentation/pages/purchase_order_list_page.dart';
import 'package:pos_machine/features/purchases/presentation/widgets/list/purchase_order_list_view.dart';
import 'package:pos_machine/features/purchases/presentation/widgets/list/purchase_list_filter_fields.dart';
import 'package:pos_machine/features/purchase_returns/presentation/pages/purchase_return_list_page.dart';
import 'package:pos_machine/features/purchase_returns/presentation/widgets/list/purchase_return_list_view.dart';
import 'test_support/export_capture.dart';
import 'test_support/header_actions.dart';
import 'test_support/purchase_list_fixtures.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'fixture'});
  });
  tearDown(Get.reset);
  Future<PurchaseListFixture> pump(WidgetTester tester, bool returns,
      {double width = 1280, CapturingExport? export}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = PurchaseListFixture();
    await tester.pumpWidget(fixture.wrap(returns
        ? PurchaseReturnListPage(exportController: export)
        : PurchaseOrderListPage(exportController: export)));
    await tester.pumpAndSettle();
    return fixture;
  }

  testWidgets(
      'order store menu retains all options and selected ID; Reset clears it',
      (tester) async {
    final fixture = await pump(tester, false);
    final store = find.byType(PurchaseListPicker).at(1);
    await tester
        .tap(find.descendant(of: store, matching: find.byType(TextField)));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(MenuItemButton), matching: find.text('Main Store')),
        findsOneWidget);
    expect(find.text('Second Store'), findsOneWidget);
    await tester.tap(find.text('Second Store'));
    await tester.pumpAndSettle();
    expect(fixture.requests.last.queryParameters['store_id'], '5');
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
        fixture.requests.last.queryParameters.containsKey('store_id'), isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final returns in [false, true]) {
    final kind = returns ? 'return' : 'order';
    for (final width in [375.0, 768.0, 1280.0]) {
      testWidgets(
          '$kind populated list at $width and filters open without overflow',
          (tester) async {
        await pump(tester, returns, width: width);
        expect(find.byType(AppPaginationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapFilterToggle(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
        '$kind supplier search/select, next page, date, Reset and typed-only Reset',
        (tester) async {
      final fixture = await pump(tester, returns);
      final picker = find.byType(PurchaseListPicker).first;
      final input =
          find.descendant(of: picker, matching: find.byType(TextField));
      await tester.enterText(input, 'Other');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other Supplier').last);
      await tester.pumpAndSettle();
      expect(fixture.requests.last.queryParameters['supplier_id'], '8');
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
      await tester.pumpAndSettle();
      expect(fixture.requests.last.queryParameters['page'], '2');
      // Calendar adapter callback retains the date-only request contract.
      final date = tester.widget<PurchaseListDateField>(
          find.byType(PurchaseListDateField).first);
      date.onChanged('2026-09-01');
      await tester.pumpAndSettle();
      expect(fixture.requests.last.queryParameters['page'], '1');
      expect(fixture.requests.last.queryParameters['date_from'], '2026-09-01');
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(fixture.requests.last.queryParameters.containsKey('supplier_id'),
          isFalse);
      expect(fixture.requests.last.queryParameters.containsKey('date_from'),
          isFalse);
      await tester.enterText(input, 'Unselected search');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Unselected search'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        '$kind export all filtered pages keeps visible page and workbook numbers',
        (tester) async {
      final export = CapturingExport();
      addTearDown(export.dispose);
      final fixture = await pump(tester, returns, export: export);
      if (returns) {
        final controller = tester
            .widget<PurchaseReturnListView>(find.byType(PurchaseReturnListView))
            .controller;
        controller.update(() {
          controller.supplierController.text = 'Other Supplier';
          controller.fromDateController.text = '2026-09-01';
        });
        await controller.fetchReturns(page: 2);
      } else {
        final controller = tester
            .widget<PurchaseOrderListView>(find.byType(PurchaseOrderListView))
            .controller;
        controller.update(() {
          controller.supplierController.text = 'Other Supplier';
          controller.storeController.text = 'Second Store';
          controller.fromDateController.text = '2026-09-01';
        });
        await controller.fetchPurchases(page: 2);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('purchase-$kind-export')));
      await tester.pump();
      await useTempExportDirectory(tester, 'purchase-export');
      final file = (await tester.runAsync(export.createFile!))!;
      final excel = Excel.decodeBytes(file.readAsBytesSync());
      final sheet = excel.tables.values.single;
      expect(sheet.maxRows, 18); // 17 records plus header, across both pages.
      expect(sheet.row(1)[4]!.value, const DoubleCellValue(126.125));
      final pagination =
          tester.widget<AppPaginationBar>(find.byType(AppPaginationBar));
      expect(pagination.currentPage, 2);
      expect(fixture.requests.takeLast(2).map((r) => r.queryParameters['page']),
          ['1', '2']);
      for (final request in fixture.requests.takeLast(2)) {
        expect(request.queryParameters['supplier_id'], '8');
        expect(request.queryParameters['date_from'], '2026-09-01');
        if (!returns) expect(request.queryParameters['store_id'], '5');
      }
    });
    for (final failure in [
      'duplicate',
      'request failure',
      'filter changed',
      'session changed',
      'disposed'
    ]) {
      testWidgets('$kind export stops for $failure', (tester) async {
        final export = CapturingExport();
        addTearDown(export.dispose);
        final fixture = await pump(tester, returns, export: export);
        await tester.tap(find.byKey(ValueKey('purchase-$kind-export')));
        await tester.pump();
        final start = fixture.requests.length;
        if (failure == 'duplicate') fixture.duplicate = true;
        if (failure == 'request failure') fixture.fail = true;
        if (failure == 'filter changed' || failure == 'session changed') {
          fixture.beforeResponse = () async {
            if (failure == 'session changed') {
              fixture.auth.login('other-session', 1);
            } else if (returns) {
              tester
                  .widget<PurchaseReturnListView>(
                      find.byType(PurchaseReturnListView))
                  .controller
                  .supplierController
                  .text = 'Other Supplier';
            } else {
              tester
                  .widget<PurchaseOrderListView>(
                      find.byType(PurchaseOrderListView))
                  .controller
                  .supplierController
                  .text = 'Other Supplier';
            }
          };
        }
        if (failure == 'disposed') {
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        }
        final error = failure == 'request failure'
            ? throwsA(isA<Exception>())
            : throwsStateError;
        await tester.runAsync(() => expectLater(export.createFile!(), error));
        expect(
            fixture.requests.length - start,
            failure == 'duplicate'
                ? 2
                : failure == 'disposed'
                    ? 0
                    : 1);
      });
    }
  }
}

extension _Last<T> on List<T> {
  Iterable<T> takeLast(int count) => skip(length - count);
}
