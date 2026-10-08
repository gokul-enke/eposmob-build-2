import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/offers/presentation/widgets/cart_offer_badge.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

void main() {
  LocalCartItem offerLine() {
    return LocalCartItem(
      product: GetProduct(productId: 1, productName: 'Chocobar'),
      price: 90,
      standardUnitPrice: 1234.5,
      offerId: 9,
      offerVersion: 1,
    );
  }

  Future<void> pumpBadge(WidgetTester tester, double width,
      {LocalCartItem? item, double fontSize = 12}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CartOfferBadge(item: item ?? offerLine(), fontSize: fontSize),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Finder struckPrice() => find.byWidgetPredicate((widget) =>
      widget is Text && widget.style?.decoration == TextDecoration.lineThrough);

  testWidgets('shows the tag and the struck-through price before the offer',
      (tester) async {
    await pumpBadge(tester, 300);

    expect(struckPrice(), findsOneWidget);
    expect(find.textContaining('1,234.50', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.local_offer_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [120.0, 60.0, 30.0]) {
    testWidgets('does not overflow at a ${width}px wide cell', (tester) async {
      await pumpBadge(tester, width);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CartOfferBadge)).width,
          lessThanOrEqualTo(width));
    });
  }

  testWidgets('has an "offer applied, was" semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBadge(tester, 300);

    // "Offer applied, was 1,234.50" (offers.badge_semantics).
    expect(
      find.bySemanticsLabel(RegExp(r'1,234\.50$')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('renders nothing for a line without an offer', (tester) async {
    await pumpBadge(
      tester,
      300,
      item: LocalCartItem(
        product: GetProduct(productId: 1, productName: 'Chocobar'),
        price: 100,
      ),
    );

    expect(struckPrice(), findsNothing);
    expect(find.byIcon(Icons.local_offer_outlined), findsNothing);
  });
}
