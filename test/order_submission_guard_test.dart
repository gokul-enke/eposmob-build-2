import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/order_submission_guard.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'test_support/memory_submission_store.dart';

void main() {
  testWidgets(
      'receipt dialog accepts Enter and Escape while billing stays busy',
      (tester) async {
    final coordinator =
        OrderSubmissionCoordinator(store: MemorySubmissionStore());
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(
        body: OrderSubmissionGuard(
          coordinator: coordinator,
          child: const TextField(),
        ),
      ),
    ));
    final finish = coordinator.holdCheckoutUi();
    var accepted = false;
    Future<void> openPrompt() => showDialog<void>(
          context: navigator.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Print customer copy?'),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () {
                  accepted = true;
                  Navigator.pop(context);
                },
                child: const Text('Print'),
              ),
            ],
          ),
        );
    final first = openPrompt();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await first;
    expect(accepted, isTrue);
    expect(coordinator.isBusy, isTrue);
    accepted = false;
    final second = openPrompt();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await second;
    expect(accepted, isFalse);
    expect(find.text('Print customer copy?'), findsNothing);
    finish();
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
  });

  testWidgets(
      'billing stays focused, blocks edits and leaves outside controls usable',
      (tester) async {
    final coordinator =
        OrderSubmissionCoordinator(store: MemorySubmissionStore());
    final focus = FocusNode();
    final text = TextEditingController();
    var outsideTaps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      OrderSubmissionGuard(
          coordinator: coordinator,
          child: TextField(focusNode: focus, controller: text)),
      TextButton(onPressed: () => outsideTaps++, child: const Text('Outside')),
    ]))));
    focus.requestFocus();
    await tester.pump();
    final finish = coordinator.holdCheckoutUi();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(text.text, isEmpty);
    expect(
        tester
            .widget<AbsorbPointer>(find
                .descendant(
                    of: find.byType(OrderSubmissionGuard),
                    matching: find.byType(AbsorbPointer))
                .first)
            .absorbing,
        isTrue);
    // Pointer-down outside a field can intentionally move focus; verify the
    // busy transition itself first, then the unrelated button separately.
    finish();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    final finishAgain = coordinator.holdCheckoutUi();
    await tester.pump();
    await tester.tap(find.text('Outside'));
    expect(outsideTaps, 1);
    finishAgain();
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    text.dispose();
    coordinator.dispose();
  });

  testWidgets(
      'navigation waits through receipt completion and then opens requested page',
      (tester) async {
    final coordinator =
        OrderSubmissionCoordinator(store: MemorySubmissionStore());
    Widget app(int index) => MaterialApp(
        home: CheckoutNavigationHost(
            index: index,
            coordinator: coordinator,
            screen: (value) => Text(value == 0 ? 'Billing' : 'Sales')));
    await tester.pumpWidget(app(0));
    final finish = coordinator.holdCheckoutUi();
    await tester.pumpWidget(app(1));
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Sales'), findsNothing);
    finish();
    finish(); // The same completion callback cannot release another lease.
    await tester.pump();
    expect(find.text('Sales'), findsOneWidget);
    expect(coordinator.isBusy, isFalse);
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
  });
}
