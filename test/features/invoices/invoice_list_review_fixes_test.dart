import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/display/info_row.dart';
import 'package:pos_machine/core/ui/list/table_cells.dart';
import 'package:pos_machine/features/invoices/domain/invoice_list_query.dart';

void main() {
  test('Today range uses the same text format the date picker writes', () {
    final range = invoiceTodayRange(DateTime(2026, 1, 5, 14, 30));

    expect(range.from, '2026-01-05 00:00:00');
    expect(range.to, '2026-01-05 23:59:59');
    expect(
      range.from,
      invoiceFilterDateTimeFormat.format(DateTime(2026, 1, 5)),
    );
  });

  testWidgets('table text cell is selectable only when asked', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          TableCells.text('2-11-261015-0010', selectable: true),
          TableCells.text('plain'),
        ]),
      ),
    ));

    expect(find.widgetWithText(SelectableText, '2-11-261015-0010'),
        findsOneWidget);
    expect(find.widgetWithText(SelectableText, 'plain'), findsNothing);
    expect(find.text('plain'), findsOneWidget);
  });

  testWidgets('InfoRow value is selectable only when asked', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          InfoRow(label: 'Receipt', value: '2-11-261015-0010', selectable: true),
          InfoRow(label: 'Date', value: '2026-10-15'),
        ]),
      ),
    ));

    expect(find.widgetWithText(SelectableText, '2-11-261015-0010'),
        findsOneWidget);
    expect(find.widgetWithText(SelectableText, '2026-10-15'), findsNothing);
  });
}
