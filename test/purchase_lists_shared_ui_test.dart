import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/list/app_pagination_bar.dart';
import 'package:pos_machine/core/ui/buttons/app_buttons.dart';
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

  for (final scenario in [
    (
      returns: false,
      index: 0,
      field: 'supplier_id',
      selected: 'Other Supplier',
      id: '8',
      next: 'Supplier Funzcart',
      nextId: '7',
      search: 'Funz'
    ),
    (
      returns: true,
      index: 0,
      field: 'supplier_id',
      selected: 'Other Supplier',
      id: '8',
      next: 'Supplier Funzcart',
      nextId: '7',
      search: 'Funz'
    ),
    (
      returns: false,
      index: 1,
      field: 'store_id',
      selected: 'Second Store',
      id: '5',
      next: 'Main Store',
      nextId: '4',
      search: 'Main'
    ),
  ]) {
    final returns = scenario.returns;
    testWidgets(
        '${returns ? 'return' : 'order'} ${scenario.field} Escape then arrow reopening and keyboard selection',
        (tester) async {
      final fixture = await pump(tester, returns);
      final picker = find.byType(PurchaseListPicker).at(scenario.index);
      final input =
          find.descendant(of: picker, matching: find.byType(TextField));
      await tester.tap(input);
      await tester.enterText(input, scenario.search);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, 'All');
      final before = fixture.requests.length;
      await tester.tap(
          find.descendant(of: picker, matching: find.byType(IconButton)).last);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsWidgets);
      expect(fixture.requests.length, before);
      await tester.tap(find
          .descendant(
              of: find.byType(MenuItemButton),
              matching: find.text(scenario.selected))
          .last);
      await tester.pumpAndSettle();
      expect(
          fixture.requests.last.queryParameters[scenario.field], scenario.id);
      await tester.tap(input);
      await tester.enterText(input, scenario.search);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
          tester.widget<TextField>(input).controller!.text, scenario.selected);
      await tester.tap(
          find.descendant(of: picker, matching: find.byType(IconButton)).last);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsWidgets);
      await tester.tap(input);
      await tester.enterText(input, scenario.search);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fixture.requests.last.queryParameters[scenario.field],
          scenario.nextId);
      expect(tester.widget<TextField>(input).controller!.text, scenario.next);
      expect(find.byType(MenuItemButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
    for (final dismissal in [
      'Escape',
      'Tab',
      'Shift+Tab',
      'outside click',
      'arrow'
    ]) {
      testWidgets(
          '${returns ? 'return' : 'order'} abandoned ${scenario.field} search via $dismissal keeps applied selection and export',
          (tester) async {
        final export = CapturingExport();
        addTearDown(export.dispose);
        final fixture = await pump(tester, returns, export: export);
        final picker = find.byType(PurchaseListPicker).at(scenario.index);
        final input =
            find.descendant(of: picker, matching: find.byType(TextField));
        await tester.tap(input);
        await tester.pumpAndSettle();
        await tester.tap(find
            .descendant(
                of: find.byType(MenuItemButton),
                matching: find.text(scenario.selected))
            .last);
        await tester.pumpAndSettle();
        expect(
            fixture.requests.last.queryParameters[scenario.field], scenario.id);
        final beforeDismissal = fixture.requests.length;
        await tester.tap(input);
        await tester.enterText(input, scenario.search);
        await tester.pumpAndSettle();
        if (dismissal == 'Escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else if (dismissal == 'Tab') {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        } else if (dismissal == 'Shift+Tab') {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        } else if (dismissal == 'arrow') {
          await tester.tap(find
              .descendant(of: picker, matching: find.byType(IconButton))
              .last);
        } else {
          await tester
              .tap(find.text(returns ? 'Purchase Returns' : 'Purchase Order'));
        }
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(input).controller!.text,
            scenario.selected);
        expect(fixture.requests.length, beforeDismissal);
        expect(find.byType(MenuItemButton), findsNothing);

        // The next export must use the same selection the field now displays.
        await tester.tap(find.byKey(
            ValueKey('purchase-${returns ? 'return' : 'order'}-export')));
        await tester.pump();
        await useTempExportDirectory(tester, 'purchase-cancelled-search');
        await tester.runAsync(export.createFile!);
        expect(
            fixture.requests.takeLast(2).every((request) =>
                request.queryParameters[scenario.field] == scenario.id),
            isTrue);
        await tester.pumpAndSettle();

        // Reopening and choosing a new entry still changes the actual filter.
        await tester.tap(input);
        await tester.enterText(input, scenario.search);
        await tester.pumpAndSettle();
        await tester.tap(find
            .descendant(
                of: find.byType(MenuItemButton),
                matching: find.text(scenario.next))
            .last);
        await tester.pumpAndSettle();
        expect(fixture.requests.last.queryParameters[scenario.field],
            scenario.nextId);
        expect(tester.widget<TextField>(input).controller!.text, scenario.next);
        expect(tester.takeException(), isNull);
      });
    }
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
    testWidgets(
        '$kind cancelled unselected search restores All; Reset and disposal remain safe',
        (tester) async {
      final fixture = await pump(tester, returns);
      final picker = find.byType(PurchaseListPicker).first;
      final input =
          find.descendant(of: picker, matching: find.byType(TextField));
      final before = fixture.requests.length;
      await tester.enterText(input, 'No matching supplier');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, 'All');
      expect(fixture.requests.length, before);
      expect(fixture.requests.last.queryParameters.containsKey('supplier_id'),
          isFalse);
      await tester.enterText(input, 'Other');
      await tester.pumpAndSettle();
      await tester.tap(find
          .descendant(
              of: find.byType(MenuItemButton),
              matching: find.text('Other Supplier'))
          .last);
      await tester.pumpAndSettle();
      await tester.enterText(input, 'Unselected');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, 'All');
      expect(fixture.requests.last.queryParameters.containsKey('supplier_id'),
          isFalse);
      await tester.enterText(input, 'Pending search');
      await tester.pumpAndSettle();
      // Closing queues label restoration, then the page is immediately removed.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    for (final width in [375.0, 768.0, 1280.0]) {
      testWidgets(
          '$kind populated list at $width and filters open without overflow',
          (tester) async {
        await pump(tester, returns, width: width);
        expect(find.byType(AppPaginationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width >= 768) {
          final filter = tester.widget<AppSquareIconButton>(find.byKey(ValueKey(
              returns
                  ? 'purchase-return-filter-toggle'
                  : 'purchase-order-filter-toggle')));
          expect(filter.icon, Icons.filter_alt_rounded);
          expect(filter.tooltip, 'list.hide_filters'.tr);
        }
        await tapFilterToggle(tester);
        await tester.pumpAndSettle();
        if (width >= 768) {
          final filter = tester.widget<AppSquareIconButton>(find.byKey(ValueKey(
              returns
                  ? 'purchase-return-filter-toggle'
                  : 'purchase-order-filter-toggle')));
          expect(filter.icon, Icons.filter_alt_outlined);
          expect(filter.tooltip, 'list.filters'.tr);
        }
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
