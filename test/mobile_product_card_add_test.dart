/// Widget tests for P0.3: Mobile product cards must not block add-to-cart
/// based on raw stock rows.
///
/// These are structural contract tests: they verify that [ProductCard] and
/// [ProductListRow] always render enabled, tappable Add controls — even when
/// a product has zero stock entries — instead of checking full helper logic
/// (which requires a heavy provider tree and is covered by unit tests).
///
/// Approach chosen: pure-presentation widget test.
///
/// [ProductCard] and [ProductListRow] are pure presentation widgets that
/// accept [onInfoTap] / [onAddWithOptions] as callbacks and delegate all
/// stock decisions to [ProductCartHelper] (supplied by [MarketProductGrid]).
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
    testWidgets(
        'tapping info button on a no-stock product calls onInfoTap',
        (tester) async {
      int infoCount = 0;
      final product = _noStockProduct();

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: product,
            onInfoTap: () => infoCount++,
            onAddWithOptions: () {},
          ),
        ),
      ));

      final infoFinder = find.byIcon(Icons.info_outline);
      expect(infoFinder, findsOneWidget);

      await tester.tap(infoFinder);
      await tester.pump();

      expect(infoCount, 1,
          reason: 'onInfoTap must fire even when product has no stock rows');
    });

    testWidgets(
        'tapping Add on a zero-qty-stock product calls onAddWithOptions',
        (tester) async {
      int addCount = 0;
      final product = _zeroQtyStockProduct();

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: product,
            onInfoTap: () {},
            onAddWithOptions: () => addCount++,
          ),
        ),
      ));

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(addCount, 1,
          reason:
              'onAddWithOptions must fire even when all stock-row quantities are zero');
    });

    testWidgets('dense ProductCard + icon is always tappable for no-stock',
        (tester) async {
      int addCount = 0;
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
          ),
        ),
      ));

      final iconFinder = find.byIcon(Icons.add);
      expect(iconFinder, findsOneWidget);

      await tester.tap(iconFinder);
      await tester.pump();

      expect(addCount, 1,
          reason: 'Dense card onAddWithOptions must fire for no-stock product');
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
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(find.text('Out Of Stock'), findsOneWidget,
          reason: 'StockBadge must stay as a visual indicator');
    });
  });

  group('ProductListRow — action buttons are always enabled', () {
    testWidgets('tapping info button on a no-stock product calls onInfoTap',
        (tester) async {
      _tolerateOverflow();
      int infoCount = 0;
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
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();

      expect(infoCount, 1,
          reason: 'ProductListRow onInfoTap must fire for no-stock product');
    });

    testWidgets('tapping Add on a zero-qty-stock product calls onAddWithOptions',
        (tester) async {
      _tolerateOverflow();
      int addCount = 0;
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
          ),
        ),
      ));

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(addCount, 1,
          reason:
              'ProductListRow onAddWithOptions must fire even when stock sums to zero');
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
