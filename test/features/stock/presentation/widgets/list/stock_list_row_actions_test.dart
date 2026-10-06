import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/features/stock/presentation/widgets/list/stock_list_row_actions.dart';

void main() {
  for (final mobile in [true, false]) {
    testWidgets(
        'row callbacks retain stock identity on ${mobile ? 'phone' : 'desktop'}',
        (tester) async {
      Get.testMode = true;
      final stock = ListStockModelData(stockId: 321);
      final calls = <String>[];
      void record(String action, ListStockModelData item) {
        expect(identical(item, stock), isTrue);
        calls.add(action);
      }

      await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
              body: StockListRowActions(
                  isMobile: mobile,
                  stock: stock,
                  onEdit: (s) => record('edit', s),
                  onView: (s) => record('view', s),
                  onAdjust: (s) => record('adjust', s),
                  onMove: (s) => record('move', s),
                  onWithdraw: (s) => record('withdraw', s)))));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.tap(find.byIcon(Icons.visibility));
      for (final action in ['adjust', 'move', 'withdraw']) {
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.byWidgetPredicate(
            (w) => w is PopupMenuItem<String> && w.value == action));
        await tester.pumpAndSettle();
      }
      expect(calls, ['edit', 'view', 'adjust', 'move', 'withdraw']);
      await tester.pumpWidget(const SizedBox.shrink());
      Get.reset();
    });
  }
}
