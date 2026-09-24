import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/purchase/widgets/purchase_orders_responsive.dart';

void main() {
  testWidgets(
    'keeps the purchase order table visible and scrollable at narrow widths',
    (tester) async {
      const columnWidths = <int, TableColumnWidth>{
        0: FractionColumnWidth(0.08),
        1: FractionColumnWidth(0.14),
        2: FractionColumnWidth(0.16),
        3: FractionColumnWidth(0.20),
        4: FractionColumnWidth(0.12),
        5: FractionColumnWidth(0.14),
        6: FractionColumnWidth(0.16),
      };

      Table buildTable(List<String> values) {
        return Table(
          columnWidths: columnWidths,
          children: [
            TableRow(
              children: values.map((value) => Text(value)).toList(),
            ),
          ],
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 760,
              height: 240,
              child: PurchaseOrdersResponsiveTable(
                minWidth: 900,
                table: Column(
                  children: [
                    buildTable(const [
                      'SL',
                      'Purchase Date',
                      'Store',
                      'Supplier',
                      'Total Price',
                      'Received Items',
                      'Action',
                    ]),
                    Expanded(
                      child: SingleChildScrollView(
                        child: buildTable(const [
                          '1',
                          '2026-09-24',
                          'FUNZCART',
                          'Supplier 1',
                          'SAR 1000',
                          '1 / 1',
                          'View',
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.text('Purchase Date'), findsOneWidget);
      expect(find.text('2026-09-24'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);

      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(scrollbar.controller, isNotNull);
      expect(scrollbar.controller!.position.maxScrollExtent, greaterThan(0));
      expect(tester.getSize(find.text('Purchase Date')).width, greaterThan(0));
    },
  );
}
