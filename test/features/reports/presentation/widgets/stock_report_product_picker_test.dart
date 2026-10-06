import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/reports/domain/stock_report_query.dart';
import 'package:pos_machine/features/reports/presentation/widgets/stock_report/stock_report_product_picker.dart';
import '../../../../test_support/app_translations.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);
  final catalog = <String, StockReportOption>{
    for (var i = 0; i < 10000; i++)
      '$i': StockReportOption('$i', 'Product ${i.toString().padLeft(5, '0')}'),
  };
  late String? selected;
  late int changes;
  late int revision;
  late StateSetter rebuild;
  Future<void> mount(WidgetTester tester, {double width = 300}) async {
    selected = null;
    changes = 0;
    revision = 0;
    await tester.pumpWidget(GetMaterialApp(
      translations: EnglishTranslations(),
      locale: const Locale('en'),
      home: Scaffold(
          body: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
            child: SizedBox(
                width: width,
                child: StatefulBuilder(builder: (context, setState) {
                  rebuild = setState;
                  return Column(children: [
                    StockReportProductPicker(
                        key: ValueKey(revision),
                        options: catalog,
                        value: selected,
                        onChanged: (option) => setState(() {
                              selected = option?.id;
                              changes++;
                            })),
                    const SizedBox(height: 350),
                    const TextField(key: ValueKey('next-field')),
                  ]);
                }))),
      )),
    ));
    await tester.pumpAndSettle();
  }

  Finder input() => find.descendant(
      of: find.byType(StockReportProductPicker),
      matching: find.byType(TextField));
  Finder menu() => find.byType(MenuItemButton);

  for (final size in [
    const Size(300, 600),
    const Size(190, 600),
    const Size(300, 300)
  ]) {
    testWidgets(
        '10k directory builds bounded rows, scrolls and selects at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, width: size.width);
      expect(menu(), findsNothing);
      await tester.tap(input());
      await tester.pumpAndSettle();
      expect(menu().evaluate().length, lessThan(25));
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(menu().evaluate().length, lessThan(25));
      await tester.tap(find.widgetWithText(MenuItemButton, 'Product 09999'));
      await tester.pumpAndSettle();
      expect(selected, '9999');
      expect(changes, 1);
      expect(menu(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('keyboard can reach offscreen last row, select and clear All',
      (tester) async {
    await mount(tester);
    await tester.tap(input());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(MenuItemButton, 'Product 09999'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, '9999');
    await tester.tap(input());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(changes, 2);
    expect(tester.takeException(), isNull);
  });
  for (final up in [true, false]) {
    testWidgets(
        'first ${up ? 'Up' : 'Down'} opens closed picker with visible highlight',
        (tester) async {
      await mount(tester);
      tester.widget<TextField>(input()).focusNode!.requestFocus();
      await tester.pump();
      expect(menu(), findsNothing);
      await tester.sendKeyEvent(
          up ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
          find
              .widgetWithText(
                  MenuItemButton, up ? 'Product 09999' : 'All Products')
              .hitTestable(),
          findsOneWidget);
      expect(changes, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, up ? '9999' : null);
      expect(changes, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'deferred keyboard scroll is safe after closing or disposing picker',
      (tester) async {
    await mount(tester);
    tester.widget<TextField>(input()).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menu(), findsNothing);
    expect(changes, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('search, no match, Escape, outside tap, Tab, reset and disposal',
      (tester) async {
    await mount(tester);
    await tester.enterText(input(), '09999');
    await tester.pumpAndSettle();
    expect(menu(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, '9999');
    await tester.enterText(input(), 'does not exist');
    await tester.pumpAndSettle();
    expect(menu(), findsNothing);
    expect(find.text('No data found'), findsOneWidget);
    expect(changes, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('No data found'), findsNothing);
    await tester.tap(input());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-field')));
    await tester.pumpAndSettle();
    expect(menu(), findsNothing);
    await tester.tap(input());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(menu(), findsNothing);
    expect(
        tester
            .widget<EditableText>(find.descendant(
                of: find.byKey(const ValueKey('next-field')),
                matching: find.byType(EditableText)))
            .focusNode
            .hasFocus,
        isTrue);
    await tester.tap(input());
    await tester.pumpAndSettle();
    rebuild(() {
      revision++;
      selected = null;
    });
    await tester.pumpAndSettle();
    expect(menu(), findsNothing);
    expect(tester.widget<TextField>(input()).controller!.text, 'All Products');
    await tester.tap(input());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
