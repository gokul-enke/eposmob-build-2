/// Comprehensive keyboard / Tab-order test suite for the salesman billing
/// flow (Phases 1–6 of the keyboard-accessibility refactor).
///
/// Strategy
/// --------
/// Mounting the real `BillingPage` in a unit test requires an enormous amount
/// of provider, Hive, and SharedPreferences plumbing. Instead, this suite
/// exercises every keyboard *pattern* introduced by the refactor with small,
/// hermetic widget harnesses that mirror the production wiring 1-for-1:
///
///  • [BillingFocusOrders] constants (band invariants).
///  • `FocusTraversalGroup(policy: OrderedTraversalPolicy())` + the same
///    `FocusTraversalOrder(NumericFocusOrder(BillingFocusOrders.*))` values
///    used in `billing_page.dart` — Tab / Shift+Tab walks the entry row,
///    cart, and action buttons in the exact production order.
///  • `ExcludeFocus(excluding: true)` around the header toolbar.
///  • `Focus(descendantsAreTraversable: false, canRequestFocus: false)`
///    around the cart cells (Tab skips them, click-focus still works).
///  • Customer-grid arrow navigation algorithm (recreated as a public
///    helper that mirrors `_handleCustomerListKey`).
///  • Delivery / Payment tile `Shortcuts` mapping arrow keys to
///    `Previous/NextFocusIntent`.
///  • Payment / Delivery tile `InkWell.onTap` activation via Enter / Space.
///  • `KeyboardShortcutsHelpDialog` Esc-close, autofocus, and the
///    "GLOBAL ACTIONS" section content.
///
/// Each group uses `debugPrint` to emit a focus trace that makes failures
/// easy to diagnose from `flutter test --reporter expanded`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_machine/screens/billing/utils/billing_focus_orders.dart';
import 'package:pos_machine/screens/billing/widgets/keyboard_shortcuts_help_dialog.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in a minimal `MaterialApp + Scaffold` so widgets that need
/// a `Material` ancestor (`InkWell`, `IconButton`, etc.) work in tests.
///
/// Defaults the surface to **2000×1500** so the entry row + action buttons
/// row (which are wider than the default 800×600) don't trigger a
/// `RenderFlex overflow` during layout. Surface is reset automatically.
Future<void> pumpHarness(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(2000, 1500));
  addTearDown(() async => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: child),
    ),
  );
  // Allow autofocus / addPostFrameCallback to settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

/// Returns the debugLabel of whichever node currently has primary focus, or
/// `'<none>'` when no node is focused. Useful for assertion messages and
/// `debugPrint` traces.
String currentFocusLabel() =>
    FocusManager.instance.primaryFocus?.debugLabel ?? '<none>';

/// Sends a single Tab keypress and pumps a frame so the FocusManager has a
/// chance to advance traversal.
Future<void> pressTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

/// Sends a Shift+Tab keypress (reverse traversal).
Future<void> pressShiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// Sends an arbitrary key keypress and pumps a frame.
Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Re-implementation of `_CheckoutModalState._handleCustomerListKey`. Because
/// the production code lives inside a private `State`, we reproduce the
/// algorithm here verbatim and assert that the same key contract is honoured.
class CustomerGridKeyResult {
  CustomerGridKeyResult({
    required this.handled,
    required this.newIndex,
    this.activatedItemIndex,
  });

  final bool handled;
  final int newIndex;
  final int? activatedItemIndex;

  @override
  String toString() =>
      'CustomerGridKeyResult(handled: $handled, newIndex: $newIndex, '
      'activatedItemIndex: $activatedItemIndex)';
}

CustomerGridKeyResult handleCustomerGridKey({
  required LogicalKeyboardKey key,
  required int focusedIndex,
  required int itemCount,
  required int columns,
}) {
  if (itemCount == 0) {
    return CustomerGridKeyResult(handled: false, newIndex: focusedIndex);
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space) {
    final clamped = focusedIndex.clamp(0, itemCount - 1);
    return CustomerGridKeyResult(
      handled: true,
      newIndex: clamped,
      activatedItemIndex: clamped,
    );
  }
  int? delta;
  if (key == LogicalKeyboardKey.arrowRight) {
    delta = 1;
  } else if (key == LogicalKeyboardKey.arrowLeft) {
    delta = -1;
  } else if (key == LogicalKeyboardKey.arrowDown) {
    delta = columns;
  } else if (key == LogicalKeyboardKey.arrowUp) {
    delta = -columns;
  }
  if (delta == null) {
    return CustomerGridKeyResult(handled: false, newIndex: focusedIndex);
  }
  final next = (focusedIndex + delta).clamp(0, itemCount - 1);
  return CustomerGridKeyResult(handled: true, newIndex: next);
}

// ---------------------------------------------------------------------------
// Production-shaped harness widgets
// ---------------------------------------------------------------------------

/// Mirrors the entry-row + cart + action-button structure from
/// `billing_page.dart` so the tab order can be exercised end-to-end.
class _BillingTabOrderHarness extends StatelessWidget {
  const _BillingTabOrderHarness({
    required this.headerHelpFn,
    required this.headerKeyboardFn,
    required this.headerDrawerFn,
    required this.headerSyncFn,
    required this.searchFn,
    required this.qtyFn,
    required this.priceFn,
    required this.addItemFn,
    required this.clearEntryFn,
    required this.cartTableFn,
    required this.cartCellQtyFn,
    required this.cartCellPriceFn,
    required this.cartCellMrpFn,
    required this.cartCellTaxFn,
    required this.cartCellDeleteFn,
    required this.clearCartFn,
    required this.saveOrderFn,
    required this.confirmAndPrintFn,
    required this.confirmOrderFn,
    required this.saveAndPrintFn,
  });

  final FocusNode headerHelpFn;
  final FocusNode headerKeyboardFn;
  final FocusNode headerDrawerFn;
  final FocusNode headerSyncFn;

  final FocusNode searchFn;
  final FocusNode qtyFn;
  final FocusNode priceFn;
  final FocusNode addItemFn;
  final FocusNode clearEntryFn;

  final FocusNode cartTableFn;
  final FocusNode cartCellQtyFn;
  final FocusNode cartCellPriceFn;
  final FocusNode cartCellMrpFn;
  final FocusNode cartCellTaxFn;
  final FocusNode cartCellDeleteFn;

  final FocusNode clearCartFn;
  final FocusNode saveOrderFn;
  final FocusNode confirmAndPrintFn;
  final FocusNode confirmOrderFn;
  final FocusNode saveAndPrintFn;

  Widget _orderedField(double order, FocusNode fn, String hint) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: SizedBox(
        width: 120,
        child: TextField(
          focusNode: fn,
          decoration: InputDecoration(hintText: hint),
        ),
      ),
    );
  }

  Widget _orderedButton(double order, FocusNode fn, String label) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: ElevatedButton(
        focusNode: fn,
        onPressed: () {},
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          // ----- Header (toolbar icons) — excluded from tab order -----
          ExcludeFocus(
            excluding: true,
            child: Row(
              children: [
                IconButton(
                  focusNode: headerHelpFn,
                  onPressed: () {},
                  icon: const Icon(Icons.help_outline),
                ),
                IconButton(
                  focusNode: headerKeyboardFn,
                  onPressed: () {},
                  icon: const Icon(Icons.keyboard),
                ),
                IconButton(
                  focusNode: headerDrawerFn,
                  onPressed: () {},
                  icon: const Icon(Icons.point_of_sale),
                ),
                IconButton(
                  focusNode: headerSyncFn,
                  onPressed: () {},
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
          ),
          // ----- Entry row -----
          Row(
            children: [
              _orderedField(
                  BillingFocusOrders.searchProduct, searchFn, 'Search Product'),
              _orderedField(BillingFocusOrders.quantity, qtyFn, 'Qty'),
              _orderedField(BillingFocusOrders.unitPrice, priceFn, 'Price'),
              _orderedButton(BillingFocusOrders.addItem, addItemFn, 'Add'),
              _orderedButton(
                  BillingFocusOrders.clearEntry, clearEntryFn, 'Clear'),
            ],
          ),
          // ----- Cart table — single tab stop, inner cells skipped -----
          FocusTraversalOrder(
            order: const NumericFocusOrder(BillingFocusOrders.cartTable),
            child: Focus(
              focusNode: cartTableFn,
              child: Focus(
                descendantsAreTraversable: false,
                canRequestFocus: false,
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(focusNode: cartCellQtyFn),
                    ),
                    SizedBox(
                      width: 60,
                      child: TextField(focusNode: cartCellPriceFn),
                    ),
                    SizedBox(
                      width: 60,
                      child: TextField(focusNode: cartCellMrpFn),
                    ),
                    SizedBox(
                      width: 60,
                      child: TextField(focusNode: cartCellTaxFn),
                    ),
                    IconButton(
                      focusNode: cartCellDeleteFn,
                      onPressed: () {},
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ----- Action buttons -----
          Row(
            children: [
              _orderedButton(
                  BillingFocusOrders.clearCart, clearCartFn, 'Clear Cart'),
              _orderedButton(
                  BillingFocusOrders.saveOrder, saveOrderFn, 'Save Order'),
              _orderedButton(BillingFocusOrders.confirmAndPrint,
                  confirmAndPrintFn, 'Confirm & Print'),
              _orderedButton(BillingFocusOrders.confirmOrder, confirmOrderFn,
                  'Confirm Order'),
              _orderedButton(BillingFocusOrders.saveAndPrint, saveAndPrintFn,
                  'Save & Print'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stateful customer grid harness that uses the same key contract as the
/// production `_handleCustomerListKey` (verified via [handleCustomerGridKey]).
class _CustomerGridHarness extends StatefulWidget {
  const _CustomerGridHarness({
    required this.itemCount,
    required this.columns,
    required this.onSelected,
  });

  final int itemCount;
  final int columns;
  final ValueChanged<int> onSelected;

  @override
  State<_CustomerGridHarness> createState() => _CustomerGridHarnessState();
}

class _CustomerGridHarnessState extends State<_CustomerGridHarness> {
  final FocusNode _gridFn = FocusNode(debugLabel: 'customer-grid');
  int _focusedIndex = 0;

  @override
  void dispose() {
    _gridFn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _gridFn,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final result = handleCustomerGridKey(
          key: event.logicalKey,
          focusedIndex: _focusedIndex,
          itemCount: widget.itemCount,
          columns: widget.columns,
        );
        if (!result.handled) return KeyEventResult.ignored;
        if (result.activatedItemIndex != null) {
          widget.onSelected(result.activatedItemIndex!);
        }
        if (_focusedIndex != result.newIndex) {
          setState(() => _focusedIndex = result.newIndex);
        }
        return KeyEventResult.handled;
      },
      child: SizedBox(
        width: 360,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.columns,
            childAspectRatio: 2.5,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            final isFocused = _gridFn.hasFocus && index == _focusedIndex;
            return Container(
              key: ValueKey('customer-$index'),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFocused ? Colors.orange : Colors.grey,
                  width: isFocused ? 2 : 1,
                ),
              ),
              child: Center(child: Text('Customer $index')),
            );
          },
        ),
      ),
    );
  }
}

/// Delivery-method tile harness using the production `Shortcuts` pattern.
class _DeliveryShortcutsHarness extends StatelessWidget {
  const _DeliveryShortcutsHarness({
    required this.tiles,
  });

  final List<({FocusNode fn, String label})> tiles;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft): PreviousFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
        },
        child: Row(
          children: [
            for (var i = 0; i < tiles.length; i++)
              FocusTraversalOrder(
                order: NumericFocusOrder(
                    CheckoutDeliveryOrders.methodTilesBase + i),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      focusNode: tiles[i].fn,
                      onTap: () {},
                      child: Center(child: Text(tiles[i].label)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================================================
  group('BillingFocusOrders constants — band invariants', () {
    test('entry-row band is monotonically increasing', () {
      expect(BillingFocusOrders.barcode,
          lessThan(BillingFocusOrders.searchProduct));
      expect(BillingFocusOrders.searchProduct,
          lessThan(BillingFocusOrders.quantity));
      expect(
          BillingFocusOrders.quantity, lessThan(BillingFocusOrders.unitPrice));
      expect(
          BillingFocusOrders.unitPrice, lessThan(BillingFocusOrders.addItem));
      expect(
          BillingFocusOrders.addItem, lessThan(BillingFocusOrders.clearEntry));
    });

    test('entry row → cart table → action buttons (band ordering)', () {
      expect(BillingFocusOrders.clearEntry,
          lessThan(BillingFocusOrders.cartTable));
      expect(
          BillingFocusOrders.cartTable, lessThan(BillingFocusOrders.clearCart));
    });

    test('action-button band is monotonically increasing', () {
      expect(
          BillingFocusOrders.clearCart, lessThan(BillingFocusOrders.saveOrder));
      expect(BillingFocusOrders.saveOrder,
          lessThan(BillingFocusOrders.confirmAndPrint));
      expect(BillingFocusOrders.confirmAndPrint,
          lessThan(BillingFocusOrders.confirmOrder));
      expect(BillingFocusOrders.confirmOrder,
          lessThan(BillingFocusOrders.saveAndPrint));
    });

    test('entry row uses 10-step gaps so future fields can slot in', () {
      const gaps = [
        BillingFocusOrders.barcode,
        BillingFocusOrders.searchProduct,
        BillingFocusOrders.quantity,
        BillingFocusOrders.unitPrice,
        BillingFocusOrders.addItem,
        BillingFocusOrders.clearEntry,
      ];
      for (var i = 1; i < gaps.length; i++) {
        expect(gaps[i] - gaps[i - 1], 10,
            reason: 'gap between #${i - 1} and #$i should be 10');
      }
    });

    test('cart table sits in its own band (= 100)', () {
      expect(BillingFocusOrders.cartTable, 100);
    });

    test('CheckoutCustomerOrders.footer is 9000 (always last in step)', () {
      expect(CheckoutCustomerOrders.footer, 9000);
      expect(CheckoutCustomerOrders.customerList,
          lessThan(CheckoutCustomerOrders.footer));
    });

    test('CheckoutDeliveryOrders.methodTilesBase reserves 90 tile slots', () {
      // tile[i] = methodTilesBase + i; first non-tile field is `carNumber`.
      expect(CheckoutDeliveryOrders.methodTilesBase + 89,
          lessThan(CheckoutDeliveryOrders.carNumber));
    });

    test('CheckoutPaymentOrders interleaves row + amount per method', () {
      expect(CheckoutPaymentOrders.cashRow,
          lessThan(CheckoutPaymentOrders.cashAmount));
      expect(CheckoutPaymentOrders.cashAmount,
          lessThan(CheckoutPaymentOrders.cardRow));
      expect(CheckoutPaymentOrders.cardRow,
          lessThan(CheckoutPaymentOrders.cardAmount));
      expect(CheckoutPaymentOrders.cardAmount,
          lessThan(CheckoutPaymentOrders.upiRow));
    });
  });

  // ==========================================================================
  group('Tab order — full billing-page traversal', () {
    /// Builds a fresh set of focus nodes, registers them for cleanup with
    /// `addTearDown` (which fires *before* the test binding is torn down,
    /// so disposing focus nodes is safe), and returns the harness widget.
    Widget makeHarness({
      required FocusNode searchFn,
      required FocusNode qtyFn,
      required FocusNode priceFn,
      required FocusNode addItemFn,
      required FocusNode clearEntryFn,
      required FocusNode cartTableFn,
      required FocusNode clearCartFn,
      required FocusNode saveOrderFn,
      required FocusNode confirmAndPrintFn,
      required FocusNode confirmOrderFn,
      required FocusNode saveAndPrintFn,
    }) {
      return _BillingTabOrderHarness(
        headerHelpFn: FocusNode(debugLabel: 'header-help'),
        headerKeyboardFn: FocusNode(debugLabel: 'header-keyboard'),
        headerDrawerFn: FocusNode(debugLabel: 'header-drawer'),
        headerSyncFn: FocusNode(debugLabel: 'header-sync'),
        searchFn: searchFn,
        qtyFn: qtyFn,
        priceFn: priceFn,
        addItemFn: addItemFn,
        clearEntryFn: clearEntryFn,
        cartTableFn: cartTableFn,
        cartCellQtyFn: FocusNode(debugLabel: 'cart-cell-qty'),
        cartCellPriceFn: FocusNode(debugLabel: 'cart-cell-price'),
        cartCellMrpFn: FocusNode(debugLabel: 'cart-cell-mrp'),
        cartCellTaxFn: FocusNode(debugLabel: 'cart-cell-tax'),
        cartCellDeleteFn: FocusNode(debugLabel: 'cart-cell-delete'),
        clearCartFn: clearCartFn,
        saveOrderFn: saveOrderFn,
        confirmAndPrintFn: confirmAndPrintFn,
        confirmOrderFn: confirmOrderFn,
        saveAndPrintFn: saveAndPrintFn,
      );
    }

    testWidgets(
        'forward Tab walks Search → Qty → Price → Add → Clear → CartTable → '
        'ClearCart → SaveOrder → ConfirmAndPrint → ConfirmOrder → SaveAndPrint',
        (tester) async {
      final searchFn = FocusNode(debugLabel: 'search');
      final qtyFn = FocusNode(debugLabel: 'qty');
      final priceFn = FocusNode(debugLabel: 'price');
      final addItemFn = FocusNode(debugLabel: 'add-item');
      final clearEntryFn = FocusNode(debugLabel: 'clear-entry');
      final cartTableFn = FocusNode(debugLabel: 'cart-table');
      final clearCartFn = FocusNode(debugLabel: 'clear-cart');
      final saveOrderFn = FocusNode(debugLabel: 'save-order');
      final confirmAndPrintFn = FocusNode(debugLabel: 'confirm-and-print');
      final confirmOrderFn = FocusNode(debugLabel: 'confirm-order');
      final saveAndPrintFn = FocusNode(debugLabel: 'save-and-print');
      addTearDown(() {
        for (final fn in [
          searchFn,
          qtyFn,
          priceFn,
          addItemFn,
          clearEntryFn,
          cartTableFn,
          clearCartFn,
          saveOrderFn,
          confirmAndPrintFn,
          confirmOrderFn,
          saveAndPrintFn,
        ]) {
          fn.dispose();
        }
      });

      await pumpHarness(
        tester,
        makeHarness(
          searchFn: searchFn,
          qtyFn: qtyFn,
          priceFn: priceFn,
          addItemFn: addItemFn,
          clearEntryFn: clearEntryFn,
          cartTableFn: cartTableFn,
          clearCartFn: clearCartFn,
          saveOrderFn: saveOrderFn,
          confirmAndPrintFn: confirmAndPrintFn,
          confirmOrderFn: confirmOrderFn,
          saveAndPrintFn: saveAndPrintFn,
        ),
      );

      searchFn.requestFocus();
      await tester.pump();
      expect(searchFn.hasFocus, isTrue,
          reason: 'precondition: search must hold initial focus');

      final expected = <FocusNode>[
        qtyFn,
        priceFn,
        addItemFn,
        clearEntryFn,
        cartTableFn,
        clearCartFn,
        saveOrderFn,
        confirmAndPrintFn,
        confirmOrderFn,
        saveAndPrintFn,
      ];

      for (final node in expected) {
        await pressTab(tester);
        debugPrint(
            '[tab-order] after Tab → ${currentFocusLabel()} (expected ${node.debugLabel})');
        expect(node.hasFocus, isTrue,
            reason: 'Tab should have advanced focus to ${node.debugLabel}, '
                'but primary focus is on ${currentFocusLabel()}');
      }
    });

    testWidgets('Shift+Tab reverses the same path SaveAndPrint → … → Search',
        (tester) async {
      final searchFn = FocusNode(debugLabel: 'search');
      final qtyFn = FocusNode(debugLabel: 'qty');
      final priceFn = FocusNode(debugLabel: 'price');
      final addItemFn = FocusNode(debugLabel: 'add-item');
      final clearEntryFn = FocusNode(debugLabel: 'clear-entry');
      final cartTableFn = FocusNode(debugLabel: 'cart-table');
      final clearCartFn = FocusNode(debugLabel: 'clear-cart');
      final saveOrderFn = FocusNode(debugLabel: 'save-order');
      final confirmAndPrintFn = FocusNode(debugLabel: 'confirm-and-print');
      final confirmOrderFn = FocusNode(debugLabel: 'confirm-order');
      final saveAndPrintFn = FocusNode(debugLabel: 'save-and-print');
      addTearDown(() {
        for (final fn in [
          searchFn,
          qtyFn,
          priceFn,
          addItemFn,
          clearEntryFn,
          cartTableFn,
          clearCartFn,
          saveOrderFn,
          confirmAndPrintFn,
          confirmOrderFn,
          saveAndPrintFn,
        ]) {
          fn.dispose();
        }
      });

      await pumpHarness(
        tester,
        makeHarness(
          searchFn: searchFn,
          qtyFn: qtyFn,
          priceFn: priceFn,
          addItemFn: addItemFn,
          clearEntryFn: clearEntryFn,
          cartTableFn: cartTableFn,
          clearCartFn: clearCartFn,
          saveOrderFn: saveOrderFn,
          confirmAndPrintFn: confirmAndPrintFn,
          confirmOrderFn: confirmOrderFn,
          saveAndPrintFn: saveAndPrintFn,
        ),
      );

      saveAndPrintFn.requestFocus();
      await tester.pump();
      expect(saveAndPrintFn.hasFocus, isTrue);

      final reverseExpected = <FocusNode>[
        confirmOrderFn,
        confirmAndPrintFn,
        saveOrderFn,
        clearCartFn,
        cartTableFn,
        clearEntryFn,
        addItemFn,
        priceFn,
        qtyFn,
        searchFn,
      ];

      for (final node in reverseExpected) {
        await pressShiftTab(tester);
        debugPrint(
            '[tab-order-reverse] after Shift+Tab → ${currentFocusLabel()} '
            '(expected ${node.debugLabel})');
        expect(node.hasFocus, isTrue,
            reason: 'Shift+Tab should have moved focus to ${node.debugLabel}, '
                'but primary focus is on ${currentFocusLabel()}');
      }
    });
  });

  // ==========================================================================
  group('ExcludeFocus — header toolbar icons stay out of Tab order', () {
    testWidgets('Tab skips every IconButton wrapped in ExcludeFocus(true)',
        (tester) async {
      final beforeFn = FocusNode(debugLabel: 'before');
      final helpFn = FocusNode(debugLabel: 'header-help');
      final keyboardFn = FocusNode(debugLabel: 'header-keyboard');
      final drawerFn = FocusNode(debugLabel: 'header-drawer');
      final syncFn = FocusNode(debugLabel: 'header-sync');
      final afterFn = FocusNode(debugLabel: 'after');

      addTearDown(() {
        for (final fn in [
          beforeFn,
          helpFn,
          keyboardFn,
          drawerFn,
          syncFn,
          afterFn,
        ]) {
          fn.dispose();
        }
      });

      await pumpHarness(
        tester,
        FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(focusNode: beforeFn),
              ),
              ExcludeFocus(
                excluding: true,
                child: Row(
                  children: [
                    IconButton(
                      focusNode: helpFn,
                      onPressed: () {},
                      icon: const Icon(Icons.help_outline),
                    ),
                    IconButton(
                      focusNode: keyboardFn,
                      onPressed: () {},
                      icon: const Icon(Icons.keyboard),
                    ),
                    IconButton(
                      focusNode: drawerFn,
                      onPressed: () {},
                      icon: const Icon(Icons.point_of_sale),
                    ),
                    IconButton(
                      focusNode: syncFn,
                      onPressed: () {},
                      icon: const Icon(Icons.sync),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(focusNode: afterFn),
              ),
            ],
          ),
        ),
      );

      beforeFn.requestFocus();
      await tester.pump();
      expect(beforeFn.hasFocus, isTrue);

      await pressTab(tester);
      debugPrint('[exclude-focus] after Tab → ${currentFocusLabel()}');
      expect(afterFn.hasFocus, isTrue,
          reason: 'Tab must skip every excluded icon and land on `after`');

      for (final excluded in [helpFn, keyboardFn, drawerFn, syncFn]) {
        expect(excluded.hasFocus, isFalse,
            reason: '${excluded.debugLabel} must not steal Tab focus');
      }
    });

    testWidgets(
        'flipping `excluding: false` brings the icons back into Tab order',
        (tester) async {
      var excluding = true;
      final beforeFn = FocusNode(debugLabel: 'before');
      final iconFn = FocusNode(debugLabel: 'icon');
      final afterFn = FocusNode(debugLabel: 'after');
      addTearDown(() {
        beforeFn.dispose();
        iconFn.dispose();
        afterFn.dispose();
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => excluding = !excluding),
                  child: const Text('toggle'),
                ),
                FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(focusNode: beforeFn),
                      ),
                      ExcludeFocus(
                        excluding: excluding,
                        child: IconButton(
                          focusNode: iconFn,
                          onPressed: () {},
                          icon: const Icon(Icons.help_outline),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(focusNode: afterFn),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ));
      await tester.pump();

      // Default: excluded → Tab skips iconFn.
      beforeFn.requestFocus();
      await tester.pump();
      await pressTab(tester);
      expect(afterFn.hasFocus, isTrue);

      // Toggle excluding=false and verify the icon now joins the order.
      await tester.tap(find.text('toggle'));
      await tester.pump();
      beforeFn.requestFocus();
      await tester.pump();
      await pressTab(tester);
      debugPrint(
          '[exclude-focus-toggle] after toggle Tab → ${currentFocusLabel()}');
      expect(iconFn.hasFocus, isTrue,
          reason: 'with excluding=false the icon must become Tab-reachable');
    });
  });

  // ==========================================================================
  group('Cart table — descendantsAreTraversable: false', () {
    testWidgets('Tab visits the cart table once and skips every inner cell',
        (tester) async {
      final beforeFn = FocusNode(debugLabel: 'before');
      final cartFn = FocusNode(debugLabel: 'cart');
      final cellA = FocusNode(debugLabel: 'cell-a');
      final cellB = FocusNode(debugLabel: 'cell-b');
      final cellC = FocusNode(debugLabel: 'cell-c');
      final afterFn = FocusNode(debugLabel: 'after');

      addTearDown(() {
        for (final fn in [beforeFn, cartFn, cellA, cellB, cellC, afterFn]) {
          fn.dispose();
        }
      });

      await pumpHarness(
        tester,
        FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            children: [
              SizedBox(
                width: 120,
                child: TextField(focusNode: beforeFn),
              ),
              Focus(
                focusNode: cartFn,
                child: Focus(
                  descendantsAreTraversable: false,
                  canRequestFocus: false,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(focusNode: cellA),
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(focusNode: cellB),
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(focusNode: cellC),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(focusNode: afterFn),
              ),
            ],
          ),
        ),
      );

      beforeFn.requestFocus();
      await tester.pump();
      expect(beforeFn.hasFocus, isTrue);

      // First Tab → the cart-table outer node.
      await pressTab(tester);
      debugPrint('[cart-skip] Tab #1 → ${currentFocusLabel()}');
      expect(cartFn.hasFocus, isTrue,
          reason: 'Tab #1 should land on the outer cart-table focus node');

      // Second Tab → must jump over every cell straight to `after`.
      await pressTab(tester);
      debugPrint('[cart-skip] Tab #2 → ${currentFocusLabel()}');
      expect(afterFn.hasFocus, isTrue,
          reason: 'Tab #2 should skip all cells and land on `after`');
      for (final cell in [cellA, cellB, cellC]) {
        expect(cell.hasFocus, isFalse,
            reason: '${cell.debugLabel} must remain untouched by Tab');
      }
    });

    testWidgets(
        'cells remain focusable via direct `requestFocus` (click-equivalent)',
        (tester) async {
      final cartFn = FocusNode(debugLabel: 'cart');
      final cellA = FocusNode(debugLabel: 'cell-a');
      addTearDown(() {
        cartFn.dispose();
        cellA.dispose();
      });

      await pumpHarness(
        tester,
        Focus(
          focusNode: cartFn,
          child: Focus(
            descendantsAreTraversable: false,
            canRequestFocus: false,
            child: SizedBox(
              width: 80,
              child: TextField(focusNode: cellA),
            ),
          ),
        ),
      );

      cellA.requestFocus();
      await tester.pump();
      debugPrint(
          '[cart-skip-click] after requestFocus → ${currentFocusLabel()}');
      expect(cellA.hasFocus, isTrue,
          reason:
              'cells must remain focusable on tap (descendantsAreFocusable=true)');
    });
  });

  // ==========================================================================
  group('Customer grid — arrow nav + Enter/Space contract', () {
    test('arrow right increments index, clamped at last slot', () {
      var idx = 0;
      for (var i = 1; i <= 8; i++) {
        final r = handleCustomerGridKey(
          key: LogicalKeyboardKey.arrowRight,
          focusedIndex: idx,
          itemCount: 7,
          columns: 3,
        );
        expect(r.handled, isTrue);
        expect(r.newIndex, i.clamp(0, 6));
        idx = r.newIndex;
      }
      expect(idx, 6, reason: 'must clamp at itemCount - 1');
    });

    test('arrow left decrements index, clamped at 0', () {
      var idx = 5;
      for (var i = 1; i <= 8; i++) {
        final r = handleCustomerGridKey(
          key: LogicalKeyboardKey.arrowLeft,
          focusedIndex: idx,
          itemCount: 7,
          columns: 3,
        );
        expect(r.handled, isTrue);
        idx = r.newIndex;
      }
      expect(idx, 0, reason: 'must clamp at 0');
    });

    test('arrow down jumps by `columns`', () {
      final r = handleCustomerGridKey(
        key: LogicalKeyboardKey.arrowDown,
        focusedIndex: 1,
        itemCount: 9,
        columns: 3,
      );
      expect(r.newIndex, 4);
    });

    test('arrow up jumps by `columns` (clamped)', () {
      final r = handleCustomerGridKey(
        key: LogicalKeyboardKey.arrowUp,
        focusedIndex: 4,
        itemCount: 9,
        columns: 3,
      );
      expect(r.newIndex, 1);

      final clamped = handleCustomerGridKey(
        key: LogicalKeyboardKey.arrowUp,
        focusedIndex: 1,
        itemCount: 9,
        columns: 3,
      );
      expect(clamped.newIndex, 0,
          reason: 'arrow up from row 0 stays at 0 (clamped)');
    });

    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
    ]) {
      test('${key.debugName} activates the focused customer', () {
        final r = handleCustomerGridKey(
          key: key,
          focusedIndex: 4,
          itemCount: 9,
          columns: 3,
        );
        expect(r.handled, isTrue);
        expect(r.activatedItemIndex, 4);
      });
    }

    test('non-navigation keys (e.g. Tab) are ignored by the handler', () {
      final r = handleCustomerGridKey(
        key: LogicalKeyboardKey.tab,
        focusedIndex: 2,
        itemCount: 9,
        columns: 3,
      );
      expect(r.handled, isFalse);
      expect(r.newIndex, 2,
          reason: 'unhandled keys must not move the focused index');
    });

    test('empty list → handler refuses every key', () {
      for (final key in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
      ]) {
        final r = handleCustomerGridKey(
          key: key,
          focusedIndex: 0,
          itemCount: 0,
          columns: 3,
        );
        expect(r.handled, isFalse,
            reason: 'empty list must not handle ${key.debugName}');
      }
    });

    testWidgets(
        'live grid widget moves the orange focus ring across rows / cols',
        (tester) async {
      var lastSelected = -1;
      await pumpHarness(
        tester,
        _CustomerGridHarness(
          itemCount: 9,
          columns: 3,
          onSelected: (i) => lastSelected = i,
        ),
      );

      final state = tester
          .state<_CustomerGridHarnessState>(find.byType(_CustomerGridHarness));
      state._gridFn.requestFocus();
      await tester.pump();
      expect(state._gridFn.hasFocus, isTrue);

      // Initial orange ring on index 0.
      expect(state._focusedIndex, 0);

      await pressKey(tester, LogicalKeyboardKey.arrowRight);
      expect(state._focusedIndex, 1);

      await pressKey(tester, LogicalKeyboardKey.arrowDown);
      expect(state._focusedIndex, 4);

      await pressKey(tester, LogicalKeyboardKey.arrowLeft);
      expect(state._focusedIndex, 3);

      await pressKey(tester, LogicalKeyboardKey.arrowUp);
      expect(state._focusedIndex, 0);

      // Enter selects the focused item.
      await pressKey(tester, LogicalKeyboardKey.enter);
      expect(lastSelected, 0);

      // Space also selects.
      await pressKey(tester, LogicalKeyboardKey.arrowRight);
      await pressKey(tester, LogicalKeyboardKey.space);
      expect(lastSelected, 1);
    });
  });

  // ==========================================================================
  group('Delivery tiles — Shortcuts arrow nav', () {
    testWidgets('→ ↓ advance focus, ← ↑ retreat focus across InkWell tiles',
        (tester) async {
      final fns = List.generate(4, (i) => FocusNode(debugLabel: 'tile-$i'));
      addTearDown(() {
        for (final fn in fns) {
          fn.dispose();
        }
      });

      await pumpHarness(
        tester,
        _DeliveryShortcutsHarness(
          tiles: [
            for (var i = 0; i < fns.length; i++) (fn: fns[i], label: 'M$i'),
          ],
        ),
      );

      fns[0].requestFocus();
      await tester.pump();
      expect(fns[0].hasFocus, isTrue);

      await pressKey(tester, LogicalKeyboardKey.arrowRight);
      expect(fns[1].hasFocus, isTrue,
          reason: 'arrowRight should NextFocusIntent → tile 1');

      await pressKey(tester, LogicalKeyboardKey.arrowDown);
      expect(fns[2].hasFocus, isTrue,
          reason: 'arrowDown should also NextFocusIntent → tile 2');

      await pressKey(tester, LogicalKeyboardKey.arrowLeft);
      expect(fns[1].hasFocus, isTrue,
          reason: 'arrowLeft should PreviousFocusIntent → tile 1');

      await pressKey(tester, LogicalKeyboardKey.arrowUp);
      expect(fns[0].hasFocus, isTrue,
          reason: 'arrowUp should also PreviousFocusIntent → tile 0');
    });

    testWidgets('Tab still walks tiles in their FocusTraversalOrder',
        (tester) async {
      final fns = List.generate(3, (i) => FocusNode(debugLabel: 'tile-$i'));
      addTearDown(() {
        for (final fn in fns) {
          fn.dispose();
        }
      });

      await pumpHarness(
        tester,
        _DeliveryShortcutsHarness(
          tiles: [
            for (var i = 0; i < fns.length; i++) (fn: fns[i], label: 'M$i'),
          ],
        ),
      );

      fns[0].requestFocus();
      await tester.pump();
      expect(fns[0].hasFocus, isTrue);

      await pressTab(tester);
      expect(fns[1].hasFocus, isTrue);

      await pressTab(tester);
      expect(fns[2].hasFocus, isTrue);
    });
  });

  // ==========================================================================
  group('Payment / delivery InkWell — Enter & Space toggle', () {
    testWidgets('Enter on a focused InkWell calls onTap', (tester) async {
      var taps = 0;
      final fn = FocusNode(debugLabel: 'pay-cash');
      addTearDown(fn.dispose);

      await pumpHarness(
        tester,
        Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: fn,
                onTap: () => taps++,
                child: const Center(child: Text('Cash')),
              ),
            ),
          ),
        ),
      );

      fn.requestFocus();
      await tester.pump();
      expect(fn.hasFocus, isTrue);

      await pressKey(tester, LogicalKeyboardKey.enter);
      expect(taps, 1, reason: 'Enter must fire onTap when InkWell is focused');
    });

    testWidgets('Space on a focused InkWell calls onTap', (tester) async {
      var taps = 0;
      final fn = FocusNode(debugLabel: 'pay-card');
      addTearDown(fn.dispose);

      await pumpHarness(
        tester,
        Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: fn,
                onTap: () => taps++,
                child: const Center(child: Text('Card')),
              ),
            ),
          ),
        ),
      );

      fn.requestFocus();
      await tester.pump();
      expect(fn.hasFocus, isTrue);

      await pressKey(tester, LogicalKeyboardKey.space);
      expect(taps, 1, reason: 'Space must fire onTap when InkWell is focused');
    });

    testWidgets('repeated Space toggles fire onTap each press', (tester) async {
      var taps = 0;
      final fn = FocusNode(debugLabel: 'pay-toggle');
      addTearDown(fn.dispose);

      await pumpHarness(
        tester,
        Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: fn,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      fn.requestFocus();
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        await pressKey(tester, LogicalKeyboardKey.space);
      }
      expect(taps, 4, reason: 'each Space press must fire onTap');
    });
  });

  // ==========================================================================
  group('KeyboardShortcutsHelpDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => KeyboardShortcutsHelpDialog.show(ctx),
                  child: const Text('Open help'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open help'));
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardShortcutsHelpDialog), findsOneWidget,
          reason: 'help dialog should be in the widget tree');
    }

    testWidgets('Esc closes the help dialog', (tester) async {
      await openDialog(tester);

      await pressKey(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      debugPrint(
          '[help-esc] after Esc → present? ${tester.any(find.byType(KeyboardShortcutsHelpDialog))}');
      expect(find.byType(KeyboardShortcutsHelpDialog), findsNothing,
          reason: 'Esc should pop the dialog route');
    });

    testWidgets('shows the GLOBAL ACTIONS section with Ctrl+H/K/D/S',
        (tester) async {
      await openDialog(tester);

      expect(find.text('GLOBAL ACTIONS'), findsOneWidget);
      expect(find.text('Ctrl + H'), findsOneWidget);
      expect(find.text('Ctrl + K'), findsOneWidget);
      expect(find.text('Ctrl + D'), findsOneWidget);
      expect(find.text('Ctrl + S'), findsOneWidget);
    });

    testWidgets(
        'shows the FINALIZE ORDER MODAL section with Arrow / Enter / Space',
        (tester) async {
      await openDialog(tester);

      expect(find.text('FINALIZE ORDER MODAL'), findsOneWidget);
      expect(find.text('Arrow Keys'), findsWidgets,
          reason: 'arrow-keys hint must appear at least once');
      expect(find.text('Enter / Space'), findsOneWidget);
    });

    testWidgets('still includes the legacy F-key shortcuts', (tester) async {
      await openDialog(tester);

      // Spot-check a representative subset; full coverage would be brittle.
      for (final label in const ['F1', 'F2', 'F6', 'F7', 'F8', 'F9']) {
        expect(find.text(label), findsWidgets,
            reason: 'legacy shortcut $label must remain documented');
      }
    });
  });

  // ==========================================================================
  group('Footer always traverses last (CheckoutCustomerOrders.footer = 9000)',
      () {
    testWidgets(
        'after walking inputs, Tab lands on the footer ConfirmAndPrint button',
        (tester) async {
      final searchFn = FocusNode(debugLabel: 'cust-search');
      final selectedFn = FocusNode(debugLabel: 'cust-selected');
      final listFn = FocusNode(debugLabel: 'cust-list');
      final addFn = FocusNode(debugLabel: 'cust-add');
      final footerConfirmFn = FocusNode(debugLabel: 'footer-confirm');
      final footerPrintFn = FocusNode(debugLabel: 'footer-print');

      addTearDown(() {
        for (final fn in [
          searchFn,
          selectedFn,
          listFn,
          addFn,
          footerConfirmFn,
          footerPrintFn,
        ]) {
          fn.dispose();
        }
      });

      await pumpHarness(
        tester,
        FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            children: [
              FocusTraversalOrder(
                order:
                    const NumericFocusOrder(CheckoutCustomerOrders.searchField),
                child: SizedBox(
                  width: 120,
                  child: TextField(focusNode: searchFn),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(
                    CheckoutCustomerOrders.selectedCard),
                child: SizedBox(
                  width: 120,
                  child: TextField(focusNode: selectedFn),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(
                    CheckoutCustomerOrders.customerList),
                child: SizedBox(
                  width: 120,
                  child: TextField(focusNode: listFn),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(
                    CheckoutCustomerOrders.addCustomerButton),
                child: ElevatedButton(
                  focusNode: addFn,
                  onPressed: () {},
                  child: const Text('Add Customer'),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(CheckoutCustomerOrders.footer),
                child: Row(
                  children: [
                    ElevatedButton(
                      focusNode: footerConfirmFn,
                      onPressed: () {},
                      child: const Text('Confirm'),
                    ),
                    ElevatedButton(
                      focusNode: footerPrintFn,
                      onPressed: () {},
                      child: const Text('Print'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      searchFn.requestFocus();
      await tester.pump();
      expect(searchFn.hasFocus, isTrue);

      await pressTab(tester);
      expect(selectedFn.hasFocus, isTrue);
      await pressTab(tester);
      expect(listFn.hasFocus, isTrue);
      await pressTab(tester);
      expect(addFn.hasFocus, isTrue);
      await pressTab(tester);
      // FocusTraversalOrder applied to a Row provides the order to the first
      // descendant focus node, so the next Tab stop is the leftmost footer
      // button. (Subsequent Tabs stay inside the footer Row in widget order.)
      debugPrint(
          '[footer-last] after entering footer → ${currentFocusLabel()}');
      expect(footerConfirmFn.hasFocus || footerPrintFn.hasFocus, isTrue,
          reason: 'after the inputs, focus must land inside the footer Row');
    });
  });

  // ==========================================================================
  group('Restaurant billing keyboard flow', () {
    testWidgets(
        'Ctrl+A -> category, Tab -> search, Tab -> products, Tab -> cart',
        (tester) async {
      await pumpHarness(tester, const _RestaurantKeyboardFlowHarness());

      final state = tester.state<_RestaurantKeyboardFlowHarnessState>(
          find.byType(_RestaurantKeyboardFlowHarness));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(state.categoryFn.hasFocus, isTrue);
      expect(state.focusedCategoryIndex, 0);

      await pressKey(tester, LogicalKeyboardKey.arrowRight);
      expect(state.focusedCategoryIndex, 1);

      await pressTab(tester);
      expect(state.searchFn.hasFocus, isTrue);

      await tester.enterText(
        find.byKey(_RestaurantKeyboardFlowHarness.searchKey),
        'beef',
      );
      await tester.pump();
      expect(state.searchText, 'beef');

      await pressTab(tester);
      expect(state.productGridFn.hasFocus, isTrue);
      expect(state.focusedProductIndex, 0);

      await pressKey(tester, LogicalKeyboardKey.arrowRight);
      expect(state.focusedProductIndex, 1);

      await pressKey(tester, LogicalKeyboardKey.enter);
      expect(state.addedProducts, <String>['Beef Burger']);

      await pressTab(tester);
      expect(state.cartFn.hasFocus, isTrue);
      expect(state.focusedCartIndex, 0);
    });
  });
}

class _RestaurantKeyboardFlowHarness extends StatefulWidget {
  const _RestaurantKeyboardFlowHarness();

  static const searchKey = ValueKey('restaurant-search');

  @override
  State<_RestaurantKeyboardFlowHarness> createState() =>
      _RestaurantKeyboardFlowHarnessState();
}

class _RestaurantKeyboardFlowHarnessState
    extends State<_RestaurantKeyboardFlowHarness> {
  final rootFn = FocusNode(debugLabel: 'restaurant-root');
  final categoryFn = FocusNode(debugLabel: 'restaurant-category-row');
  final searchFn = FocusNode(debugLabel: 'restaurant-search');
  final productGridFn = FocusNode(debugLabel: 'restaurant-product-grid');
  final cartFn = FocusNode(debugLabel: 'restaurant-cart');

  int focusedCategoryIndex = 0;
  int focusedProductIndex = 0;
  int? focusedCartIndex;
  String searchText = '';
  final addedProducts = <String>[];

  final categories = const ['ALL', 'BEEF CUISINE', 'BIRIYANI'];
  final products = const ['Apple', 'Beef Burger', 'Beef Burger Egg'];
  final cartItems = const ['Carrot Shake', 'Chatti Choru'];

  @override
  void initState() {
    super.initState();
    searchFn.onKeyEvent = (node, event) => _handleSearchKey(event);
  }

  @override
  void dispose() {
    rootFn.dispose();
    categoryFn.dispose();
    searchFn.dispose();
    productGridFn.dispose();
    cartFn.dispose();
    super.dispose();
  }

  KeyEventResult _handleRootKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyA) {
      setState(() => focusedCategoryIndex = 0);
      categoryFn.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCategoryKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed) {
      searchFn.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        focusedCategoryIndex =
            (focusedCategoryIndex + 1).clamp(0, categories.length - 1);
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        focusedCategoryIndex =
            (focusedCategoryIndex - 1).clamp(0, categories.length - 1);
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSearchKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        categoryFn.requestFocus();
      } else {
        setState(() => focusedProductIndex = 0);
        productGridFn.requestFocus();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleProductGridKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed) {
      setState(() => focusedCartIndex = cartItems.isEmpty ? null : 0);
      cartFn.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        focusedProductIndex =
            (focusedProductIndex + 1).clamp(0, products.length - 1);
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        focusedProductIndex =
            (focusedProductIndex - 1).clamp(0, products.length - 1);
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      addedProducts.add(products[focusedProductIndex]);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: rootFn,
      autofocus: true,
      onKeyEvent: (node, event) => _handleRootKey(event),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(10),
              child: Focus(
                focusNode: categoryFn,
                onKeyEvent: (node, event) => _handleCategoryKey(event),
                child: Row(
                  children: [
                    for (var i = 0; i < categories.length; i++)
                      Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                categoryFn.hasFocus && focusedCategoryIndex == i
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        ),
                        child: Text(categories[i]),
                      ),
                  ],
                ),
              ),
            ),
            FocusTraversalOrder(
              order: const NumericFocusOrder(20),
              child: SizedBox(
                width: 240,
                child: TextField(
                  key: _RestaurantKeyboardFlowHarness.searchKey,
                  focusNode: searchFn,
                  onChanged: (value) => setState(() => searchText = value),
                ),
              ),
            ),
            FocusTraversalOrder(
              order: const NumericFocusOrder(30),
              child: Focus(
                focusNode: productGridFn,
                onKeyEvent: (node, event) => _handleProductGridKey(event),
                child: Row(
                  children: [
                    for (var i = 0; i < products.length; i++)
                      Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: productGridFn.hasFocus &&
                                    focusedProductIndex == i
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                        child: Text(products[i]),
                      ),
                  ],
                ),
              ),
            ),
            FocusTraversalOrder(
              order: const NumericFocusOrder(40),
              child: Focus(
                focusNode: cartFn,
                child: Column(
                  children: [
                    for (var i = 0; i < cartItems.length; i++)
                      Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: cartFn.hasFocus && focusedCartIndex == i
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                        child: Text(cartItems[i]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
