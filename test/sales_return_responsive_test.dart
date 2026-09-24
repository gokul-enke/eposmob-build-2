import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/sales_return/widgets/sales_return_responsive.dart';

void main() {
  group('sales return item layout', () {
    test('uses cards only at phone widths', () {
      expect(salesReturnUseItemCards(599), isTrue);
    });

    test('uses the scrollable table at desktop widths', () {
      expect(salesReturnUseItemCards(600), isFalse);
      expect(salesReturnUseItemCards(774), isFalse);
      expect(salesReturnUseItemCards(960), isFalse);
      expect(salesReturnUseItemCards(1600), isFalse);
    });
  });

  testWidgets('shows a visible horizontal scrollbar when the table is narrow',
      (tester) async {
    const columnWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(3),
      1: FlexColumnWidth(1),
      2: FlexColumnWidth(1.5),
      3: FlexColumnWidth(1.5),
      4: FlexColumnWidth(1.5),
      5: FlexColumnWidth(1.5),
      6: FlexColumnWidth(1),
      7: FlexColumnWidth(1.5),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 200,
            child: SalesReturnResponsiveTable(
              minWidth: 1100,
              table: Column(
                children: [
                  Table(
                    columnWidths: columnWidths,
                    children: const [
                      TableRow(
                        children: [
                          Text('Product Name'),
                          Text('Quantity'),
                          Text('Unit Price'),
                          Text('Total Price'),
                          Text('Returned Qty'),
                          Text('Returned Total'),
                          Text('Status'),
                          Text('Action'),
                        ],
                      ),
                    ],
                  ),
                  Table(
                    columnWidths: columnWidths,
                    children: const [
                      TableRow(
                        children: [
                          Text('pringles'),
                          Text('1.000'),
                          Text('15.000'),
                          Text('15.000'),
                          Text('0'),
                          Text('0'),
                          Icon(Icons.cancel),
                          Text('Return'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(tester.getSize(find.text('Product Name')).width, greaterThan(0));
    expect(tester.getSize(find.text('pringles')).width, greaterThan(0));
    expect(find.text('Return'), findsOneWidget);
  });
}
