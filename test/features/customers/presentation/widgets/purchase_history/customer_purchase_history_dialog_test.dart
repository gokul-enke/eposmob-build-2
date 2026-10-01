import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/widgets/purchase_history/customer_purchase_history_dialog.dart';
import 'package:pos_machine/features/customers/presentation/widgets/purchase_history/purchase_history_list.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/models/get_product.dart';

final _table = find.byWidgetPredicate((w) => w is AppDataTable);

List<CustomerPurchaseItem> _history(int count) => [
      for (var i = 1; i <= count; i++)
        CustomerPurchaseItem(
          price: '${i}2.50',
          quantity: '$i',
          total: '0',
          date: '2026-01-0${i}T10:00:00',
          orderNumber: 'ORD-$i',
        ),
    ];

/// Opens the dialog from a button and records what it pops with.
Future<List<Object?>> _open(
  WidgetTester tester, {
  required Size size,
  int count = 3,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              results.add(await showDialog<Map<String, dynamic>?>(
                context: context,
                builder: (_) => CustomerPurchaseHistoryDialog(
                  product: GetProduct(productName: 'Masala Tea'),
                  purchaseHistory: _history(count),
                  customerName: 'Asha',
                ),
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('CustomerPurchaseHistoryDialog', () {
    testWidgets('wide dialog shows a table and Use This returns the price',
        (tester) async {
      final results = await _open(tester, size: const Size(1280, 800));

      expect(find.byType(AppDialog), findsOneWidget);
      expect(_table, findsOneWidget);
      expect(find.text('Customer purchase history'), findsOneWidget);
      expect(find.textContaining('Asha'), findsOneWidget);
      expect(find.textContaining('Masala Tea'), findsOneWidget);
      expect(find.text('ORD-2'), findsOneWidget);

      await tester.tap(find.text('Use This').at(1));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(results.single, {
        'price': 22.5,
        'orderNumber': 'ORD-2',
        'useCurrentPrice': false,
      });
    });

    testWidgets('narrow dialog shows cards', (tester) async {
      final results = await _open(tester, size: const Size(375, 812));

      expect(_table, findsNothing);
      expect(find.byType(PurchaseHistoryCard), findsWidgets);

      await tester.tap(find.text('Use This').first);
      await tester.pumpAndSettle();
      expect((results.single as Map)['orderNumber'], 'ORD-1');
    });

    testWidgets('Use Current Price and Cancel', (tester) async {
      final results = await _open(tester, size: const Size(1280, 800));

      await tester.tap(find.text('Use Current Price'));
      await tester.pumpAndSettle();
      expect(results.last, {'useCurrentPrice': true});

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, hasLength(2));
      expect(results.last, isNull);
    });

    testWidgets('close button returns null', (tester) async {
      final results = await _open(tester, size: const Size(1280, 800));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(results.single, isNull);
    });
  });
}
