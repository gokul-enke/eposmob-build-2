import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      weightInfo: WeightInfo(isWeighted: weighted),
    );

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    // Avoids path_provider, which has no plugin in widget tests.
    'plu_export_local_default_directory': '/tmp',
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
}

void main() {
  testWidgets('desktop shows table beside the machine file panel',
      (tester) async {
    await _pump(tester, const Size(1366, 768));

    expect(tester.takeException(), isNull);
    expect(find.text('PRODUCT'), findsOneWidget);
    expect(find.byKey(const ValueKey('plu_download')), findsOneWidget);
    // Weighted products are selected by default.
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

    await tester.tap(find.byKey(const ValueKey('plu_product_2')));
    await tester.pump();
    expect(find.text('3 products ready'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plu_view_selected')));
    await tester.pump();
    expect(find.text('Showing 3 of 39'), findsOneWidget);
  });

  testWidgets('narrow layout keeps download in the sticky bar', (tester) async {
    await _pump(tester, const Size(375, 812));

    expect(tester.takeException(), isNull);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('plu_download')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plu_clear_selection')));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('No products selected'), findsOneWidget);

    // The overlay message from custom_dialog_box offers Undo.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);

    // Let the message's auto-dismiss timer finish.
    await tester.pump(const Duration(seconds: 6));
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
    expect(find.text('39 products'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
  });

  testWidgets('Reset clears search and returns to all products',
      (tester) async {
    await _pump(tester, const Size(1366, 768));

    await tester.enterText(find.byKey(const ValueKey('plu_search')), 'zzz');
    await tester.pump();
    expect(find.text('No matching products'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plu_view_weighted')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('plu_reset_filters')));
    await tester.pump();
    expect(find.text('No matching products'), findsNothing);
    expect(find.text('39 products'), findsOneWidget);
    // Nothing left to reset, so the button disables itself.
    final reset =
        tester.widget<InkWell>(find.byKey(const ValueKey('plu_reset_filters')));
    expect(reset.onTap, isNull);
  });
}
