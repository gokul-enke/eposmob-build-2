import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  late TextEditingController name;
  late TextEditingController email;

  setUp(() {
    name = TextEditingController();
    email = TextEditingController();
  });

  tearDown(() {
    name.dispose();
    email.dispose();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    double width = 1200,
    bool showHeader = true,
    VoidCallback? onSearch,
    VoidCallback? onSubmit,
    VoidCallback? onReset,
    ValueChanged<int?>? onChoice,
  }) {
    final panel = FilterPanel(
      title: 'Find',
      hint: 'Type to search',
      resetLabel: 'Reset',
      onSearch: onSearch ?? () {},
      onSubmit: onSubmit,
      onReset: onReset ?? () {},
      fields: [
        TextFilterField(
          controller: name,
          label: 'Name',
          hint: 'By name',
          icon: Icons.person,
        ),
        TextFilterField(
          controller: email,
          label: 'Email',
          hint: 'By email',
          icon: Icons.mail,
        ),
        DropdownFilterField<int>(
          label: 'Choice',
          icon: Icons.list,
          value: 0,
          options: const [FilterOption(0, 'Zero'), FilterOption(1, 'One')],
          onChanged: onChoice ?? (_) {},
        ),
      ],
    );
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: showHeader ? panel : panel.embedded(),
          ),
        ),
      ),
    );
  }

  Finder field(TextEditingController controller) => find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.controller == controller,
      );

  testWidgets('renders title, fields and a header Reset', (tester) async {
    await pumpPanel(tester);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('Type to search'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('typing calls onSearch, Enter calls onSubmit', (tester) async {
    var searches = 0;
    var submits = 0;
    await pumpPanel(tester,
        onSearch: () => searches++, onSubmit: () => submits++);

    await tester.enterText(field(name), 'Ann');
    await tester.enterText(field(email), 'a@b');
    expect(searches, 2);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submits, 1);
  });

  testWidgets('Enter falls back to onSearch without onSubmit', (tester) async {
    var searches = 0;
    await pumpPanel(tester, onSearch: () => searches++);
    await tester.tap(field(name));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(searches, 1);
  });

  testWidgets('dropdown changes are reported', (tester) async {
    int? chosen;
    await pumpPanel(tester, onChoice: (value) => chosen = value);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One').last);
    await tester.pumpAndSettle();
    expect(chosen, 1);
  });

  testWidgets('Reset works in the header and embedded variants',
      (tester) async {
    var resets = 0;
    await pumpPanel(tester, onReset: () => resets++);
    await tester.tap(find.text('Reset'));

    await pumpPanel(tester, showHeader: false, onReset: () => resets++);
    expect(find.text('Find'), findsNothing);
    await tester.tap(find.text('Reset'));
    expect(resets, 2);
  });

  testWidgets('Tab moves focus between text fields in order', (tester) async {
    await pumpPanel(tester);
    await tester.tap(field(name));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final editable = tester.widget<EditableText>(find.descendant(
      of: field(email),
      matching: find.byType(EditableText),
    ));
    expect(editable.focusNode.hasFocus, isTrue);
  });

  test('columns follow the width bands', () {
    expect(FilterPanel.columnsFor(400), 1);
    expect(FilterPanel.columnsFor(600), 2);
    expect(FilterPanel.columnsFor(1000), 4);
  });

  testWidgets('fields share the row width equally', (tester) async {
    await pumpPanel(tester, width: 700);
    final first = tester.getSize(field(name)).width;
    final second = tester.getSize(field(email)).width;
    expect(first, second);
    expect(first, lessThan(700 / 2));
  });

  for (final density in [VisualDensity.compact, VisualDensity.standard]) {
    testWidgets('text, dropdown and date fields share one height ()',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(visualDensity: density),
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: FilterPanel(
              resetLabel: 'Reset',
              onSearch: () {},
              onReset: () {},
              fields: [
                TextFilterField(
                  controller: name,
                  label: 'Name',
                  hint: 'By name',
                  icon: Icons.person,
                ),
                DropdownFilterField<int>(
                  label: 'Choice',
                  icon: Icons.list,
                  value: 0,
                  options: const [FilterOption(0, 'Zero')],
                  onChanged: (_) {},
                ),
                DateRangeFilterField(
                  label: 'Dates',
                  value: null,
                  onChanged: (_) {},
                  formatRange: (range) => '',
                ),
              ],
            ),
          ),
        ),
      ));

      final heights = [
        tester.getSize(field(name)).height,
        tester.getSize(find.byType(DropdownButtonFormField<int>)).height,
        tester.getSize(find.byType(InputDecorator).last).height,
      ];
      expect(heights, everyElement(AppSizes.control));
    });
  }
}
