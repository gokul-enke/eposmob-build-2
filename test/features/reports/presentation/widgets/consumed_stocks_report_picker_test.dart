import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/reports/presentation/widgets/consumed_stocks_report/consumed_stocks_report_picker.dart';

void main() {
  final options = {for (var i = 0; i < 10000; i++) '$i': 'Product $i'};
  Future<void> mount(WidgetTester tester, ValueChanged<String?> onChanged,
      {double width = 300,
      double height = 800,
      Key? key,
      String? value}) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                    width: width,
                    child: ConsumedStocksReportPicker(
                        key: key,
                        options: options,
                        value: value,
                        onChanged: onChanged,
                        label: 'Product',
                        allLabel: 'All products',
                        icon: Icons.inventory_2_outlined))))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      '10000 choices mount only visible rows and search the entire directory',
      (tester) async {
    String? selected;
    await mount(tester, (value) => selected = value);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton).evaluate().length, lessThan(20));
    await tester.enterText(find.byType(TextField), '9999');
    await tester.pumpAndSettle();
    expect(find.text('Product 9999'), findsOneWidget);
    await tester.tap(find.text('Product 9999'));
    await tester.pumpAndSettle();
    expect(selected, '9999');
    expect(find.byType(MenuItemButton), findsNothing);
  });
  testWidgets(
      'ArrowUp opening scrolls to the last choice before Enter selects it',
      (tester) async {
    String? selected;
    await mount(tester, (value) => selected = value);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('Product 9999'), findsOneWidget);
    expect(
        tester
            .getRect(find.text('Product 9999'))
            .overlaps(const Rect.fromLTWH(0, 0, 400, 800)),
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, '9999');
  });
  testWidgets(
      'Escape, Tab, outside click and disposal close without changing selection',
      (tester) async {
    var selections = 0;
    await mount(tester, (_) => selections++);
    for (final key in [LogicalKeyboardKey.escape, LogicalKeyboardKey.tab]) {
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
    }
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(390, 750));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(selections, 0);
  });
  testWidgets(
      'reset revision clears typed search without requiring a selection',
      (tester) async {
    await mount(tester, (_) {}, key: const ValueKey(0));
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();
    await mount(tester, (_) {}, key: const ValueKey(1));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'All products');
    expect(find.byType(MenuItemButton), findsNothing);
  });
  testWidgets('short narrow viewport opens and keeps the shared white surface',
      (tester) async {
    await mount(tester, (_) {}, width: 190, height: 300);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        tester
            .widget<MenuAnchor>(find.byType(MenuAnchor))
            .style!
            .backgroundColor!
            .resolve({}),
        AppColors.surface);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
