import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/weigh_machine/data/plu_export_service.dart';
import 'package:pos_machine/features/weigh_machine/presentation/weigh_machine_export_page.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCatalog extends ChangeNotifier implements LocalProductProvider {
  _FakeCatalog(this.products);

  @override
  final List<GetProduct> products;

  @override
  Future<void> get hydrated async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GetProduct _product(int id, String name, {bool weighted = false}) => GetProduct(
      productId: id,
      productName: name,
      category: ProductCategory(name: id.isEven ? 'Meat' : 'Fruit'),
      barcode: '1000$id',
      price: ProductPrice(price: '${id * 3}'),
      unit: 'KG',
      // An SKU is what makes a product a weigh-machine item.
      sku: weighted ? 'SKU$id' : null,
    );

/// Pumps the page with a real temp save folder, returned for file checks.
Future<Directory> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final folder = Directory.systemTemp.createTempSync('plu_page_save_');
  addTearDown(() => folder.deleteSync(recursive: true));
  SharedPreferences.setMockInitialValues({
    // A chosen folder avoids path_provider, which has no plugin in tests.
    'plu_export_local_default_directory': folder.path,
  });
  final catalog = _FakeCatalog([
    _product(1, 'Apples', weighted: true),
    _product(2, 'Mutton'),
    _product(3, 'Bananas', weighted: true),
    for (var id = 4; id < 40; id++) _product(id, 'Item $id'),
  ]);
  await tester.pumpWidget(
    ChangeNotifierProvider<LocalProductProvider>.value(
      value: catalog,
      child: MaterialApp(
        // Mirrors main.dart, which outlines every focused input.
        theme: ThemeData(
          inputDecorationTheme: const InputDecorationTheme(
            focusedBorder: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(),
          ),
        ),
        home: const WeighMachineExportPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return folder;
}

void main() {
  testWidgets('desktop shows table beside the machine file panel',
      (tester) async {
    await _pump(tester, const Size(1366, 768));

    expect(tester.takeException(), isNull);
    expect(find.text('PRODUCT'), findsOneWidget);
    expect(find.byKey(const ValueKey('plu_download')), findsOneWidget);
    // PLU.csv holds every product with an SKU.
    expect(find.text('2 products ready'), findsOneWidget);

    // Search, category and Reset share one height and top edge.
    final category = tester.getRect(find.byKey(const ValueKey('plu_category')));
    final search = tester.getRect(find
        .ancestor(
          of: find.byKey(const ValueKey('plu_search')),
          matching: find.byType(Container),
        )
        .first);
    // Outer boxes: the tap area sits inside the 1px border, like the dropdown.
    final reset = tester.getRect(find
        .ancestor(
          of: find.byKey(const ValueKey('plu_reset_filters')),
          matching: find.byType(Container),
        )
        .first);
    for (final rect in [search, reset]) {
      expect(rect.height, category.height);
      expect(rect.top, category.top);
    }

    // Only the outer box outlines the search field, even with a themed border.
    await tester.tap(find.byKey(const ValueKey('plu_search')));
    await tester.pump();
    final decoration = tester
        .widget<InputDecorator>(find.descendant(
          of: find.byKey(const ValueKey('plu_search')),
          matching: find.byType(InputDecorator),
        ))
        .decoration;
    expect(decoration.focusedBorder, InputBorder.none);
    expect(decoration.enabledBorder, InputBorder.none);

    // Opens on the Weighted view: only the two SKU products.
    expect(find.text('Showing 2 of 39'), findsOneWidget);

    // Any product can be ticked (for Excel); ticks never change PLU.csv.
    await tester.tap(find.byKey(const ValueKey('plu_product_1')));
    await tester.tap(find.byKey(const ValueKey('plu_view_all')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plu_product_2')));
    await tester.pump();
    expect(find.text('2 products ready'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plu_view_selected')));
    await tester.pump();
    expect(find.text('Showing 2 of 39'), findsOneWidget);
    expect(find.text('Mutton'), findsOneWidget);
  });

  testWidgets('narrow layout keeps download in the sticky bar', (tester) async {
    await _pump(tester, const Size(375, 812));

    expect(tester.takeException(), isNull);
    expect(find.text('2 products in PLU.csv'), findsOneWidget);
    expect(find.byKey(const ValueKey('plu_download')), findsOneWidget);
    expect(find.byKey(const ValueKey('plu_clear_selection')), findsNothing);

    // Cards sit below the panel and filters on phones.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plu_product_1')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Bring the whole card clear of the bottom edge before tapping.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plu_product_1')));
    await tester.pump();
    expect(find.text('Untick 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plu_clear_selection')));
    await tester.pumpAndSettle();
    expect(find.text('Untick 1'), findsNothing);
    expect(find.text('2 products in PLU.csv'), findsOneWidget);

    // The overlay message from custom_dialog_box offers Undo.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Untick 1'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    // Let the message's auto-dismiss timer finish.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Download writes every SKU product and ignores ticks',
      (tester) async {
    final folder = await _pump(tester, const Size(1366, 768));

    // Tick a product without an SKU; it must still stay out of PLU.csv.
    await tester.tap(find.byKey(const ValueKey('plu_view_all')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plu_product_2')));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('plu_download')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final csv = File('${folder.path}${Platform.pathSeparator}PLU.csv')
        .readAsStringSync();
    expect(csv, contains('Apples'));
    expect(csv, contains('Bananas'));
    expect(csv, isNot(contains('Mutton')));
    expect(csv, isNot(contains('Item 4')));
    expect(find.textContaining('Last saved at'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('custom folder offers a way back to the default', (tester) async {
    final documents = Directory.systemTemp.createTempSync('plu_page_docs_');
    addTearDown(() => documents.deleteSync(recursive: true));
    final service = PluExportService.instance;
    final original = service.documentsDirectory;
    service.documentsDirectory = () async => documents;
    addTearDown(() => service.documentsDirectory = original);

    // _pump saves a custom folder, so the link is shown.
    await _pump(tester, const Size(1366, 768));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('plu_default_folder')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.byKey(const ValueKey('plu_default_folder')), findsNothing);
    expect(
      find.text([documents.path, 'epos', 'PLU'].join(Platform.pathSeparator)),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Excel export ticks only Product Name by default',
      (tester) async {
    await _pump(tester, const Size(1366, 768));

    await tester.tap(find.byKey(const ValueKey('product_excel_export')));
    await tester.pumpAndSettle();

    bool ticked(String field) => tester
        .widget<FilterChip>(find.byKey(ValueKey('excel_field_$field')))
        .selected;
    expect(ticked('name'), isTrue);
    expect(ticked('category'), isFalse);
    expect(ticked('price'), isFalse);

    await tester.tap(find.byKey(const ValueKey('excel_toggle_all')));
    await tester.pump();
    expect(ticked('arabicName'), isTrue);
    expect(find.text('Name only'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('excel_toggle_all')));
    await tester.pump();
    expect(ticked('name'), isTrue);
    expect(ticked('category'), isFalse);
  });

  testWidgets('category dropdown is searchable and Reset clears it',
      (tester) async {
    await _pump(tester, const Size(1366, 768));
    await tester.tap(find.byKey(const ValueKey('plu_view_all')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('plu_category')));
    await tester.pumpAndSettle();
    final popupSearch = find.descendant(
      of: find.byType(Overlay),
      matching: find.widgetWithText(TextField, 'Search categories'),
    );
    // "Fruit" also appears in table rows, so compare against the open popup.
    final fruitWithPopup = find.text('Fruit').evaluate().length;
    await tester.enterText(popupSearch, 'mea');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Fruit').evaluate().length, fruitWithPopup - 1);

    // The popup row, not its Text, receives the tap.
    await tester.tap(find.text('Meat').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Showing 19 of 39'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plu_reset_filters')));
    await tester.pumpAndSettle();
    // Back to the default Weighted view with no category.
    expect(find.text('Showing 2 of 39'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
  });

  testWidgets('Reset clears search and returns to the Weighted view',
      (tester) async {
    await _pump(tester, const Size(1366, 768));

    await tester.enterText(find.byKey(const ValueKey('plu_search')), 'zzz');
    await tester.pump();
    expect(find.text('No matching products'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plu_view_all')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('plu_reset_filters')));
    await tester.pump();
    expect(find.text('No matching products'), findsNothing);
    expect(find.text('Showing 2 of 39'), findsOneWidget);
    // Nothing left to reset, so the button disables itself.
    final reset =
        tester.widget<InkWell>(find.byKey(const ValueKey('plu_reset_filters')));
    expect(reset.onTap, isNull);
  });
}
