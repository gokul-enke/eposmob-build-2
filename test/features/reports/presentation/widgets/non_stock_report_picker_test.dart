import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/reports/presentation/widgets/non_stock_report/non_stock_report_picker.dart';

void main() {
  final options = {for (var i = 0; i < 10000; i++) 'Product $i': 'Product $i'};
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
                    child: NonStockReportPicker(
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
    expect(selected, 'Product 9999');
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
    expect(selected, 'Product 9999');
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
  testWidgets('closing without a selection restores the applied label',
      (tester) async {
    var selections = 0;
    await mount(tester, (_) => selections++, value: 'Product 7');
    TextEditingController text() =>
        tester.widget<TextField>(find.byType(TextField)).controller!;
    for (final close in ['escape', 'tab', 'outside']) {
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Product 12');
      await tester.pumpAndSettle();
      expect(text().text, 'Product 12');
      if (close == 'outside') {
        await tester.tapAt(const Offset(390, 750));
      } else {
        await tester.sendKeyEvent(close == 'tab'
            ? LogicalKeyboardKey.tab
            : LogicalKeyboardKey.escape);
      }
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(text().text, 'Product 7', reason: close);
    }
    expect(selections, 0);
  });
  testWidgets('Enter picks the first real match when text also matches All',
      (tester) async {
    String? selected = 'unset';
    await mount(tester, (value) => selected = value);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    // "product" is part of "All products" and of every product name.
    await tester.enterText(find.byType(TextField), 'product 42');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'Product 42');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Product 42');
  });
  testWidgets('All stays first with no typed text and reachable by typing',
      (tester) async {
    String? selected = 'unset';
    await mount(tester, (value) => selected = value, value: 'Product 1');
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'all');
    await tester.pumpAndSettle();
    selected = 'unset';
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, isNull);
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
  testWidgets('picking an option reports its key, not its label',
      (tester) async {
    String? value;
    Widget picker() => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: NonStockReportPicker(
                    options: const {'1060': 'SALESMEDINA', '4': 'Alex'},
                    value: value,
                    onChanged: (id) => value = id,
                    label: 'Executive',
                    allLabel: 'All',
                    icon: Icons.badge_outlined))));
    await tester.pumpWidget(picker());
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SALESMEDINA'));
    await tester.pumpAndSettle();
    expect(value, '1060');
    await tester.pumpWidget(picker());
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'SALESMEDINA');
  });
  testWidgets('a fixed filter shows its name and cannot be changed',
      (tester) async {
    Widget picker(Map<String, String> options) => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: NonStockReportPicker(
                    options: options,
                    value: '4',
                    onChanged: (_) => fail('a fixed filter never changes'),
                    label: 'Executive',
                    allLabel: 'All',
                    icon: Icons.badge_outlined,
                    enabled: false))));
    String text() =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;
    // The name may arrive after the value: the field follows it, and never
    // claims All meanwhile.
    await tester.pumpWidget(picker(const {}));
    expect(text(), '');
    expect(find.text('All'), findsNothing, reason: 'not even as the hint');
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    await tester.pumpWidget(picker(const {'4': 'Asha'}));
    await tester.pumpAndSettle();
    expect(text(), 'Asha');
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.tap(find.byType(TextField), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
  });
  testWidgets('while its list loads the picker spins and does not open',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 300,
                child: NonStockReportPicker(
                    options: const {},
                    value: null,
                    onChanged: (_) {},
                    label: 'Customer',
                    allLabel: 'All',
                    icon: Icons.person_outline,
                    loading: true)))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MenuItemButton), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  });
}
