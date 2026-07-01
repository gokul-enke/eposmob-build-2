/// Widget tests for mobile billing accessibility + currency correctness.
///
/// These are hermetic, provider-free presentation tests (same approach as
/// `mobile_product_card_add_test.dart`). They lock in two production
/// guarantees for the Market product widgets:
///
///   1. **Currency is tenant-driven, never hardcoded.** The price prefix comes
///      from the `currency` supplied by the parent grid (from
///      `appSettings.currency`). A previous bug hardcoded `SAR`, which is wrong
///      for INR (and every other) tenant — these tests guard against a
///      regression.
///   2. **Add controls meet reasonable touch targets** in grid/list mode; dense
///      mode intentionally uses compact 32px icon buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/product_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_grid.dart';
import 'package:pos_machine/models/get_product.dart';

GetProduct _product({String name = 'Test Product'}) {
  return GetProduct(
    productId: 1,
    productName: name,
    stock: const [],
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// True if any [ConstrainedBox] in the subtree enforces a >= [min] minimum on
/// both axes — i.e. a guaranteed touch target.
bool _hasMinTouchTarget(WidgetTester tester, Finder root, double min) {
  final boxes = tester.widgetList<ConstrainedBox>(
    find.descendant(of: root, matching: find.byType(ConstrainedBox)),
  );
  return boxes.any((b) =>
      b.constraints.minWidth >= min && b.constraints.minHeight >= min);
}

void main() {
  group('ProductCard — currency is tenant-driven', () {
    testWidgets('prefixes the price with the supplied currency', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: _product(),
            currency: 'INR',
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(find.text('INR 0.00'), findsOneWidget);
      expect(find.textContaining('SAR'), findsNothing,
          reason: 'currency must never be hardcoded to SAR');
    });

    testWidgets('renders a bare amount when no currency is configured',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: _product(),
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(find.text('0.00'), findsOneWidget);
      expect(find.textContaining('SAR'), findsNothing);
    });
  });

  group('ProductListRow — currency is tenant-driven', () {
    testWidgets('prefixes the price with the supplied currency', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 560,
          height: 80,
          child: ProductListRow(
            product: _product(),
            currency: 'INR',
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(find.text('INR 0.00'), findsOneWidget);
      expect(find.textContaining('SAR'), findsNothing);
    });
  });

  group('ProductCard — action buttons touch targets', () {
    testWidgets('standard card Add button meets 40px minimum', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 180,
          height: 240,
          child: ProductCard(
            product: _product(),
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(_hasMinTouchTarget(tester, find.byType(ProductCard), 40), isTrue,
          reason: 'Standard Add button must enforce a >= 40px touch target');
    });

    testWidgets('dense card uses compact 32px icon buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 120,
          height: 180,
          child: ProductCard(
            product: _product(),
            isDense: true,
            onInfoTap: () {},
            onAddWithOptions: () {},
          ),
        ),
      ));

      expect(_hasMinTouchTarget(tester, find.byType(ProductCard), 32), isTrue,
          reason: 'Dense mode should use compact 32px action buttons');
      expect(_hasMinTouchTarget(tester, find.byType(ProductCard), 44), isFalse,
          reason: 'Dense mode intentionally avoids bulky 44px buttons');
    });
  });
}
