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

  // Lists kept alive behind their own details (Orders -> order details, ...).
  group('kept list', () {
    late OrderSubmissionCoordinator coordinator;
    setUp(() {
      coordinator = OrderSubmissionCoordinator(store: MemorySubmissionStore());
      _ListScreenState.created = 0;
    });
    tearDown(() => coordinator.dispose());

    Widget host(int index, {VoidCallback? onListHidden}) => MaterialApp(
        home: Scaffold(
            body: CheckoutNavigationHost(
                index: index,
                coordinator: coordinator,
                keepListFor: const {
                  1: {2}
                },
                onListHidden: onListHidden,
                screen: (i) => switch (i) {
                      1 || 3 || 4 => const _ListScreen(),
                      2 => const Text('Details'),
                      _ => Text('Screen $i'),
                    })));
    final filter = find.byKey(const ValueKey('filter'));
    String filterText(WidgetTester tester) => tester
        .widget<TextField>(
            find.byKey(const ValueKey('filter'), skipOffstage: false))
        .controller!
        .text;

    testWidgets('keeps its filters while its own details are open',
        (tester) async {
      await tester.pumpWidget(host(1));
      await tester.enterText(filter, '782');
      await tester.pumpWidget(host(2));
      expect(find.text('Details'), findsOneWidget);
      expect(filter, findsNothing);
      expect(find.byKey(const ValueKey('filter'), skipOffstage: false),
          findsOneWidget);

      await tester.pumpWidget(host(1));
      expect(filterText(tester), '782');
      expect(_ListScreenState.created, 1);
      // The list is told it is shown again, e.g. to reload its page.
      expect(find.text('shown again 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is dropped when the details lead somewhere else',
        (tester) async {
      await tester.pumpWidget(host(1));
      await tester.enterText(filter, '782');
      await tester.pumpWidget(host(2));
      await tester.pumpWidget(host(5));
      expect(find.text('Screen 5'), findsOneWidget);
      expect(find.byKey(const ValueKey('filter'), skipOffstage: false),
          findsNothing);

      await tester.pumpWidget(host(1));
      expect(filterText(tester), isEmpty);
      expect(_ListScreenState.created, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cannot keep focus while hidden and runs the hidden callback',
        (tester) async {
      var hidden = 0;
      await tester.pumpWidget(host(1));
      await tester.tap(filter);
      await tester.pump();
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue);

      await tester.pumpWidget(host(2, onListHidden: () => hidden++));
      await tester.pump();
      expect(hidden, 1);
      expect(
          tester
              .widget<EditableText>(
                  find.byType(EditableText, skipOffstage: false))
              .focusNode
              .hasFocus,
          isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('other screens still share one slot, as before',
        (tester) async {
      // Like billing (0/90) and the alias slots: same page type, same State.
      await tester.pumpWidget(host(3));
      await tester.enterText(filter, 'kept');
      await tester.pumpWidget(host(4));
      expect(filterText(tester), 'kept');
      expect(_ListScreenState.created, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// A list screen with a filter field, like the real lists.
class _ListScreen extends StatefulWidget {
  const _ListScreen();
  @override
  State<_ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<_ListScreen> {
  static int created = 0;
  final filter = TextEditingController();
  var shownAgain = 0;
  var _shown = true;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = ScreenVisibility.of(context);
    if (shown && !_shown) shownAgain++;
    _shown = shown;
  }

  @override
  void dispose() {
    filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(key: const ValueKey('filter'), controller: filter),
        Text('shown again $shownAgain'),
      ]);
}
