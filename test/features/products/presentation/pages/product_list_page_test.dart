import 'package:excel/excel.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/features/products/presentation/pages/product_list_page.dart';
import 'package:pos_machine/features/products/presentation/widgets/list/product_list_card.dart';
import '../../support/product_list_fixture.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../support/product_list_hive.dart';
import '../../../../test_support/hive_test_teardown.dart';

void main() {
  setUpAll(() async {
    final directory = await openProductListHive();
    addTearDown(() => closeHiveAndDeleteTestDir(directory));
  });
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(Get.reset);
  Future<ProductListFixture> pump(WidgetTester tester, double width,
      {CapturingExport? export}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = ProductListFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.wrap(ProductListPage(export: export)));
    await tester.pumpAndSettle();
    return fixture;
  }

  for (final width in [375.0, 768.0, 1280.0]) {
    testWidgets('shared list and filter toggle at $width', (tester) async {
      await pump(tester, width);
      expect(find.byType(ListPageScaffold<GetProduct>), findsOneWidget);
      expect(find.byType(PageHeader), findsOneWidget);
      if (width < 700) {
        expect(find.byType(ProductListCard), findsWidgets);
        expect(
            find.byKey(const ValueKey('product-mobile-filters')), findsNothing);
      } else {
        expect(find.byKey(const ValueKey('product-desktop-filters')),
            findsOneWidget);
      }
      await tapFilterToggle(tester, key: ProductListPage.filterKey);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'purchase price remains permission gated and responds to role changes',
      (tester) async {
    final fixture = await pump(tester, 1280);
    expect(find.text('Purchase Price'), findsNothing);
    expect(find.text('SECRET-COST'), findsNothing);
    fixture.role.setPurchaseAccess(true);
    await tester.pumpAndSettle();
    expect(find.text('Purchase Price'), findsOneWidget);
    expect(find.text('SECRET-COST'), findsWidgets);
    fixture.role.setPurchaseAccess(false);
    await tester.pumpAndSettle();
    expect(find.text('SECRET-COST'), findsNothing);
  });
  testWidgets(
      'wide table uses the shared visible and draggable horizontal scrollbar',
      (tester) async {
    await pump(tester, 1280);
    final table = find.byType(AppDataTable<GetProduct>);
    final scrollbarFinder =
        find.descendant(of: table, matching: find.byType(Scrollbar));
    expect(scrollbarFinder, findsOneWidget);
    final scrollbar = tester.widget<Scrollbar>(scrollbarFinder);
    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollbar.interactive, isTrue);
    final controller = scrollbar.controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));
    final rect = tester.getRect(scrollbarFinder);
    final pointer = await tester.startGesture(
        Offset(rect.left + 20, rect.bottom - 5),
        kind: PointerDeviceKind.mouse);
    await pointer.moveBy(const Offset(250, 0));
    await pointer.up();
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));
  testWidgets('phone filtering and Reset restore cards without leaking cost',
      (tester) async {
    final fixture = await pump(tester, 375);
    await tapFilterToggle(tester, key: ProductListPage.filterKey);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Catalog 45');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Catalog 45'), findsWidgets);
    expect(find.text('Catalog 1'), findsNothing);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog 1'), findsOneWidget);
    fixture.role.setPurchaseAccess(true);
    await tester.pumpAndSettle();
    expect(find.text('SECRET-COST'), findsWidgets);
    fixture.role.setPurchaseAccess(false);
    await tester.pumpAndSettle();
    expect(find.text('SECRET-COST'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'typing, Reset and catalog notifications retain independent list filters',
      (tester) async {
    final fixture = await pump(tester, 1280);
    final input = find.byType(TextFormField).first;
    await tester.enterText(input, 'Catalog 45');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Catalog 45'), findsWidgets);
    expect(find.text('Catalog 1'), findsNothing);
    fixture.catalog.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Catalog 45'), findsWidgets);
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(input).controller!.text, isEmpty);
    expect(find.text('Catalog 1'), findsOneWidget);
  });
  testWidgets('cancel deletion sends no request; confirming sends the exact ID',
      (tester) async {
    final fixture = await pump(tester, 1280);
    await tester.ensureVisible(find.text('Delete').first);
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.catalog.deletes, isEmpty);
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(fixture.catalog.deletes, [1]);
    expect(find.text('Catalog 1'), findsNothing);
  });
  testWidgets(
      'category search dismissal, reopening, selection and Reset keep labels and rows consistent',
      (tester) async {
    await pump(tester, 1280);
    final picker = find.byType(DropdownSearch<Category>);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'General');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Please Select'), findsOneWidget);
    expect(find.text('Catalog 1'), findsOneWidget);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('General').last);
    await tester.pumpAndSettle();
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Catalog 26'), findsOneWidget);
    expect(find.text('Catalog 1'), findsNothing);
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(find.text('Please Select'), findsOneWidget);
    expect(find.text('Catalog 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'early Export after a no-match edit gives feedback; Reset and a matching edit export correctly',
      (tester) async {
    final export = CapturingExport();
    addTearDown(export.dispose);
    await pump(tester, 1280, export: export);
    final input = find.byType(TextFormField).first;
    await tester.enterText(input, 'NO-MATCH-PRODUCT');
    await tester.tap(find.byKey(ProductListPage.exportKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(export.runs, 0);
    expect(
        find.descendant(
            of: find.byKey(AppToast.toastKey),
            matching: find.text('product.no_products'.tr)),
        findsOneWidget);
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    expect(find.text('Catalog 1'), findsOneWidget);
    await tester.enterText(input, 'Catalog 45');
    await tester.tap(find.byKey(ProductListPage.exportKey));
    await tester.pump();
    expect(export.runs, 1);
    await tester.tap(find.text('Reset').first);
    await tester.pumpAndSettle();
    await useTempExportDirectory(tester, 'product-list-export-pending');
    final file = (await tester.runAsync(export.createFile!))!;
    final workbook = (await tester
        .runAsync(() async => Excel.decodeBytes(await file.readAsBytes())))!;
    final rows = workbook.tables.values.single.rows;
    expect(rows, hasLength(2));
    expect(rows.last.any((c) => c?.value.toString() == 'Catalog 45'), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Export includes every local page and excludes restricted cost',
      (tester) async {
    final export = CapturingExport();
    addTearDown(export.dispose);
    final fixture = await pump(tester, 1280, export: export);
    await tester.tap(find.byKey(ProductListPage.exportKey));
    await tester.pump();
    // A delayed file callback must retain the filters and permission at click.
    fixture.role.setPurchaseAccess(true);
    await tester.enterText(find.byType(TextFormField).first, 'Catalog 45');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await useTempExportDirectory(tester, 'product-list-export');
    final file = (await tester.runAsync(export.createFile!))!;
    final workbook = (await tester
        .runAsync(() async => Excel.decodeBytes(await file.readAsBytes())))!;
    final rows = workbook.tables.values.single.rows;
    expect(rows, hasLength(46));
    expect(rows.first.map((c) => c?.value.toString()),
        isNot(contains('Purchase Price')));
    expect(
        rows.expand((r) => r).any((c) => c?.value.toString() == 'SECRET-COST'),
        isFalse);
    expect(rows.last.any((c) => c?.value.toString() == 'Catalog 45'), isTrue);
  });
  for (final width in [375.0, 1280.0]) {
    testWidgets(
        'Property selection, Reset and Export use assigned values at $width',
        (tester) async {
      final export = CapturingExport();
      addTearDown(export.dispose);
      final fixture = await pump(tester, width, export: export);
      fixture.catalog.values[0] =
          fixture.catalog.values[0].copyWith(productProps: [
        ProductProp(propsCode: 'PRODUCT_COLOR'),
        ProductProp(propsCode: 'SHIRT_SIZE'),
      ]);
      fixture.catalog.values[43] =
          fixture.catalog.values[43].copyWith(variants: [
        ProductVariant(id: 44, attributes: {'SHIRT_SIZE': 'M'}),
      ]);
      fixture.catalog.values[44] =
          fixture.catalog.values[44].copyWith(variants: [
        ProductVariant(id: 45, attributes: {'PRODUCT_COLOR': 'gold'}),
      ]);
      fixture.catalog.notifyListeners();
      await tester.pumpAndSettle();
      if (width < 700) {
        await tapFilterToggle(tester, key: ProductListPage.filterKey);
        await tester.pumpAndSettle();
      }
      final picker = find.byType(DropdownButtonFormField<String?>);
      Future<void> select(String label) async {
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      Future<void> reset() async {
        await tester.ensureVisible(find.text('Reset').first);
        await tester.tap(find.text('Reset').first);
        await tester.pumpAndSettle();
      }

      await select('product_list.color'.tr);
      expect(find.text('Catalog 45'), findsWidgets);
      expect(find.text('Catalog 1'), findsNothing);
      expect(
          tester.widget<DropdownButtonFormField<String?>>(picker).initialValue,
          'PRODUCT_COLOR');
      if (width < PageHeader.collapseActionsBelow) {
        await tester.ensureVisible(find.byKey(PageHeader.moreActionsKey));
        await tester.tap(find.byKey(PageHeader.moreActionsKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('list.export'.tr));
      } else {
        await tester.ensureVisible(find.byKey(ProductListPage.exportKey));
        await tester.tap(find.byKey(ProductListPage.exportKey));
      }
      await tester.pump();
      expect(export.runs, 1);
      await reset();
      expect(
          tester.widget<DropdownButtonFormField<String?>>(picker).initialValue,
          isNull);
      expect(find.text('Catalog 1'), findsOneWidget);
      await useTempExportDirectory(tester, 'product-list-property-export');
      final file = (await tester.runAsync(export.createFile!))!;
      final workbook = (await tester
          .runAsync(() async => Excel.decodeBytes(await file.readAsBytes())))!;
      final rows = workbook.tables.values.single.rows;
      expect(rows, hasLength(2));
      expect(rows.last.any((c) => c?.value.toString() == 'Catalog 45'), isTrue);
      await select('product_list.shirt_size'.tr);
      expect(find.text('Catalog 44'), findsWidgets);
      expect(find.text('Catalog 1'), findsNothing);
      await select('product_list.shoe_size'.tr);
      expect(find.text('product.no_products'.tr), findsOneWidget);
      await reset();
      expect(find.text('Catalog 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
