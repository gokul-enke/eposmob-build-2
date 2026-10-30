import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  Future<List<DateTime?>> pump(WidgetTester tester, DateTime? value,
      {bool until = false}) async {
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
              until: until,
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

  // A new pick covers the whole day unless the user changes the time.
  for (final until in [false, true]) {
    testWidgets(
        'a new ${until ? 'To' : 'From'} pick starts at '
        '${until ? '23:59' : '00:00'}', (tester) async {
      final changes = await pump(tester, null, until: until);
      await tester.tap(find.byKey(const ValueKey('field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
          tester
              .widget<TimePickerDialog>(find.byType(TimePickerDialog))
              .initialTime,
          until
              ? const TimeOfDay(hour: 23, minute: 59)
              : const TimeOfDay(hour: 0, minute: 0));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final picked = changes.single!;
      expect([picked.hour, picked.minute, picked.second],
          until ? [23, 59, 59] : [0, 0, 0]);
    });
  }

  testWidgets('a To keeps its chosen time and covers that minute',
      (tester) async {
    final changes =
        await pump(tester, DateTime(2026, 9, 1, 10, 30), until: true);
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 10, minute: 30));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changes, [DateTime(2026, 9, 1, 10, 30, 59)]);
  });

  testWidgets('the close button clears it', (tester) async {
    final changes = await pump(tester, DateTime(2026, 9, 1));
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(changes, [null]);
  });
}
