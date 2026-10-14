import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/presentation/commands/confirm_day_close_with_unsynced_sales.dart';

import '../../../../../tool/qa_confirmed_orders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OrdersQaEnvironment environment;

  setUp(() async {
    environment = OrdersQaEnvironment();
    await environment.initialize();
  });
  tearDown(() => environment.dispose());

  Future<List<bool>> mount(WidgetTester tester) async {
    environment.sync.dispose();
    environment.resetSync();
    await environment.sync.hydrate();
    final results = <bool>[];
    await tester.pumpWidget(environment.wrap(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              results.add(await confirmDayCloseWithUnsyncedSales(context)),
          child: const Text('Day Close'),
        ),
      ),
    )));
    await tester.tap(find.text('Day Close'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('warns about unsynced orders and blocks on cancel',
      (tester) async {
    final results = await mount(tester);
    expect(find.text('Sync orders before Day Close?'), findsOneWidget);
    expect(find.textContaining('4 orders have not been synced'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('day-close-unsynced-cancel')));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('close anyway lets Day Close continue', (tester) async {
    final results = await mount(tester);
    await tester.tap(find.byKey(const ValueKey('day-close-unsynced-continue')));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });
}
