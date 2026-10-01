import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_chat_controller.dart';
import 'package:pos_machine/features/customers/presentation/widgets/profile/customer_chat_tab.dart';

import 'profile_test_helpers.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    CustomerChatController? controller,
    Size size = const Size(900, 700),
  }) async {
    useSurfaceSize(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerChatTab(
            customer: testCustomer(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty history invites a first message', (tester) async {
    await pump(tester);

    expect(find.text('Asha Menon'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('No Messages Yet'), findsOneWidget);
    expect(
      find.text('Start a conversation with Asha Menon.'),
      findsOneWidget,
    );
  });

  testWidgets('sending adds a bubble and clears the field', (tester) async {
    final controller = CustomerChatController(
      customerId: 42,
      clock: () => DateTime(2026, 10, 1, 14, 5),
    );
    addTearDown(controller.dispose);
    await pump(tester, controller: controller);

    await tester.enterText(find.byType(TextField), '  Your order is ready  ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('Your order is ready'), findsOneWidget);
    expect(find.text('2:05 PM'), findsOneWidget);
    expect(find.text('No Messages Yet'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );

    // Blank input is ignored.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(controller.messages, hasLength(1));
  });

  testWidgets('load failure shows a retry that reloads', (tester) async {
    var attempts = 0;
    final controller = CustomerChatController(
      customerId: 42,
      loadHistory: (_) async {
        attempts++;
        if (attempts == 1) throw Exception('offline');
        return [
          CustomerChatMessage(
            id: '1',
            text: 'Hello there',
            sentAt: DateTime(2026, 10, 1, 9, 30),
            isFromMe: false,
          ),
        ];
      },
    );
    addTearDown(controller.dispose);
    await pump(tester, controller: controller);

    expect(find.text('Error Loading Chat'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Try Again'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('fits a phone without overflow', (tester) async {
    await pump(tester, size: const Size(343, 420));
    expect(tester.takeException(), isNull);
  });
}
