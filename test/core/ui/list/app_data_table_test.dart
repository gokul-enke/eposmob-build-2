import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  final columns = [
    TableColumnDef<String>(
      label: 'NO.',
      flex: 0.5,
      cellBuilder: (_, number) => TableCells.number(number),
    ),
    TableColumnDef<String>(
      label: 'NAME',
      flex: 2,
      cellBuilder: (item, _) => TableCells.text(item),
    ),
  ];

  Future<void> pumpTable(
    WidgetTester tester, {
    required List<String> items,
    int Function(int)? rowNumberOf,
    ValueChanged<String>? onRowTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 400,
            child: AppDataTable<String>(
              items: items,
              columns: columns,
              rowNumberOf: rowNumberOf,
              onRowTap: onRowTap,
              emptyState: const Text('Nothing here'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders headers, cells and row numbers', (tester) async {
    await pumpTable(tester,
        items: ['Ann', 'Bob'], rowNumberOf: (index) => index + 21);

    expect(find.text('NO.'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('header and body columns line up', (tester) async {
    await pumpTable(tester, items: ['Ann']);

    final header = tester.getTopLeft(find.text('NAME'));
    final cell = tester.getTopLeft(find.text('Ann'));
    expect(cell.dx, header.dx);
  });

  testWidgets('tapping a row reports the item', (tester) async {
    String? tapped;
    await pumpTable(tester, items: ['Ann', 'Bob'], onRowTap: (v) => tapped = v);

    await tester.tap(find.text('Bob'));
    expect(tapped, 'Bob');
  });

  testWidgets('shows the empty state without rows', (tester) async {
    await pumpTable(tester, items: const []);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
  });

  testWidgets('TableCells.amount colours by sign', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [TableCells.amount(-3), TableCells.amount(4.5)]),
    ));
    expect(tester.widget<Text>(find.text('-3.00')).style!.color, AppColors.red);
    expect(
        tester.widget<Text>(find.text('4.50')).style!.color, AppColors.green);
  });

  testWidgets('the frame border is painted over the content', (tester) async {
    await pumpTable(tester, items: ['Ann']);
    final frame = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('app_data_table_frame')),
    );
    expect(frame.position, DecorationPosition.foreground);
    expect((frame.decoration as BoxDecoration).border, isNotNull);
  });
}
