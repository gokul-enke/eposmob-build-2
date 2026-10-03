import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  Future<List<DateTime?>> pump(WidgetTester tester, DateTime? value) async {
    final changes = <DateTime?>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: Builder(
            builder: (context) => DateTimeFilterField(
              key: const ValueKey('field'),
              label: 'From',
              value: value,
              format: (v) => 'at ${v.hour}:${v.minute}',
              onChanged: changes.add,
            ).build(context, onTextChanged: () {}, onTextSubmitted: () {}),
          ),
        ),
      ),
    ));
    return changes;
  }

  testWidgets('picks a date and then a time', (tester) async {
    final changes = await pump(tester, DateTime(2026, 9, 1, 10, 30));
    expect(find.text('at 10:30'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changes, [DateTime(2026, 9, 1, 10, 30)]);
  });

  testWidgets('cancelling the time keeps the value', (tester) async {
    final changes = await pump(tester, null);
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('the close button clears it', (tester) async {
    final changes = await pump(tester, DateTime(2026, 9, 1));
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(changes, [null]);
  });
}
