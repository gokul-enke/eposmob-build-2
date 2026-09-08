/// Widget tests for mobile product card tap handling:
/// - Card body tap → direct add callback
/// - Info button → product details callback
/// - Add button → custom qty/price sheet callback
/// - Button taps must not bubble to the card-body handler
///
/// Stock decisions are delegated to [ProductCartHelper] via
/// [MarketProductGrid]; these are structural contract tests only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_grid.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/product_card.dart';
import 'package:pos_machine/models/get_product.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A [GetProduct] with no stock rows — the worst case that used to be blocked.
GetProduct _noStockProduct({String name = 'Test Product'}) {
  return GetProduct(
    productId: 1,
    productName: name,
    stock: const [], // explicitly empty — no stock rows
  );
}

/// A [GetProduct] with stock rows that all sum to zero.
GetProduct _zeroQtyStockProduct({String name = 'Zero Qty Product'}) {
  return GetProduct(
    productId: 2,
    productName: name,
    stock: [
      Stock(id: 10, quantity: 0),
      Stock(id: 11, quantity: 0),
    ],
  );
}

/// Wraps [child] in a bare [MaterialApp] so that [Material]/[InkWell] can
/// resolve their theme — no provider tree needed.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Suppresses RenderFlex overflow errors for the duration of the current test.
void _tolerateOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

// ---------------------------------------------------------------------------
// ProductCard tests
// ---------------------------------------------------------------------------

void main() {
  group('ProductCard — action buttons are always enabled', () {
    testWidgets('tapping card body on a no-stock product calls onDirectAdd',
        (tester) async {
      int directAddCount = 0;
      final product = _noStockProduct(name: 'Body Tap Product');

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: product,
            onInfoTap: () {},
            onAddWithOptions: () {},
            onDirectAdd: () => directAddCount++,
          ),
        ),
      ));

      await tester.tap(find.text('Body Tap Product'));
      await tester.pump();

      expect(directAddCount, 1,
          reason: 'onDirectAdd must fire when tapping the card body');
    });

    testWidgets(
        'tapping info button on a no-stock product calls onInfoTap only',
        (tester) async {
      int infoCount = 0;
      int directAddCount = 0;
      final product = _noStockProduct();

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: product,
            onInfoTap: () => infoCount++,
            onAddWithOptions: () {},
            onDirectAdd: () => directAddCount++,
          ),
        ),
      ));

      final infoFinder = find.byIcon(Icons.info_outline);
      expect(infoFinder, findsOneWidget);

      await tester.tap(infoFinder);
      await tester.pump();

      expect(infoCount, 1,
          reason: 'onInfoTap must fire even when product has no stock rows');
      expect(directAddCount, 0,
          reason: 'info button tap must not trigger onDirectAdd');
    });

    testWidgets(
        'tapping Add on a zero-qty-stock product calls onAddWithOptions only',
        (tester) async {
      int addCount = 0;
      int directAddCount = 0;
      final product = _zeroQtyStockProduct();

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: product,
            onInfoTap: () {},
            onAddWithOptions: () => addCount++,
            onDirectAdd: () => directAddCount++,
          ),
        ),
      ));

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(addCount, 1,
          reason:
              'onAddWithOptions must fire even when all stock-row quantities are zero');
      expect(directAddCount, 0,
          reason: 'Add button tap must not trigger onDirectAdd');
    });

    testWidgets('dense ProductCard + icon is always tappable for no-stock',
        (tester) async {
      int addCount = 0;
      int directAddCount = 0;
      final product = _noStockProduct(name: 'Dense Product');

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 120,
          height: 180,
          child: ProductCard(
            product: product,
            isDense: true,
            onInfoTap: () {},
            onAddWithOptions: () => addCount++,
            onDirectAdd: () => directAddCount++,
          ),
        ),
      ));

      final iconFinder = find.byIcon(Icons.add);
      expect(iconFinder, findsOneWidget);

      await tester.tap(iconFinder);
      await tester.pump();

      expect(addCount, 1,
          reason: 'Dense card onAddWithOptions must fire for no-stock product');
      expect(directAddCount, 0,
          reason: 'dense Add icon tap must not trigger onDirectAdd');
    });

    testWidgets('StockBadge still shows Out Of Stock for no-stock product',
        (tester) async {
      final product = _noStockProduct(name: 'Badge Test');

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: product,
            stockEnabled: true,
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(find.text('Out of Stock'), findsOneWidget,
          reason: 'StockBadge must stay as a visual indicator');
    });
  });

  group('ProductListRow — action buttons are always enabled', () {
    testWidgets('tapping card body on a no-stock product calls onDirectAdd',
        (tester) async {
      _tolerateOverflow();
      int directAddCount = 0;
      final product = _noStockProduct(name: 'List Body Tap');

      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 560,
          height: 80,
          child: ProductListRow(
            product: product,
            onInfoTap: () {},
            onAddWithOptions: () {},
            onDirectAdd: () => directAddCount++,
          ),
        ),
      ));

      await tester.tap(find.text('List Body Tap'));
      await tester.pump();

      expect(directAddCount, 1,
          reason: 'ProductListRow onDirectAdd must fire for card body tap');
    });

    testWidgets(
        'tapping info button on a no-stock product calls onInfoTap only',
        (tester) async {
      _tolerateOverflow();
      int infoCount = 0;
      int directAddCount = 0;
      final product = _noStockProduct();

      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 560,
          height: 80,
          child: ProductListRow(
            product: product,
            onInfoTap: () => infoCount++,
            onAddWithOptions: () {},
            onDirectAdd: () => directAddCount++,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();

      expect(infoCount, 1,
          reason: 'ProductListRow onInfoTap must fire for no-stock product');
      expect(directAddCount, 0,
          reason: 'info button tap must not trigger onDirectAdd');
    });

    testWidgets(
        'tapping Add on a zero-qty-stock product calls onAddWithOptions only',
        (tester) async {
      _tolerateOverflow();
      int addCount = 0;
      int directAddCount = 0;
      final product = _zeroQtyStockProduct();

      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 560,
          height: 80,
          child: ProductListRow(
            product: product,
            onInfoTap: () {},
            onAddWithOptions: () => addCount++,
            onDirectAdd: () => directAddCount++,
          ),
        ),
      ));

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(addCount, 1,
          reason:
              'ProductListRow onAddWithOptions must fire even when stock sums to zero');
      expect(directAddCount, 0,
          reason: 'Add button tap must not trigger onDirectAdd');
    });

    testWidgets(
        'visual stock label still shows "Out of Stock" for a no-stock product',
        (tester) async {
      _tolerateOverflow();
      final product = _noStockProduct(name: 'Visual Badge');

      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 560,
          height: 80,
          child: ProductListRow(
            product: product,
            stockEnabled: true,
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(find.text('Out of Stock'), findsOneWidget,
          reason: 'Stock badge must remain as a visual-only indicator');
    });
  });
}
