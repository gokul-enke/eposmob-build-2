import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/presentation/widgets/product_variant_details_section.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  testWidgets('shows only active-store variants and their scoped stock rows',
      (tester) async {
    final product = GetProduct(
      productId: 1,
      productName: 'Variant Product',
      variants: <ProductVariant>[
        ProductVariant(
          id: 61,
          sku: 'STORE-ONE',
          storeId: 1,
          attributes: {'COLOR': 'Blue'},
        ),
        ProductVariant(
          id: 62,
          sku: 'STORE-TWO',
          storeId: 2,
          availableQuantity: 8,
          quantity: 8,
          attributes: {'COLOR': 'Bronze'},
        ),
      ],
    );
    final stocks = <Stock>[
      Stock(
        id: 101,
        productId: 1,
        productVariantId: 61,
        storeId: 1,
        quantity: 5,
      ),
      Stock(
        id: 202,
        productId: 1,
        productVariantId: 62,
        storeId: 2,
        quantity: 8,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductVariantDetailsSection(
              product: product,
              stocks: stocks.where((stock) => stock.storeId == 2).toList(),
              currency: 'INR',
              activeStoreId: 2,
              selectedVariantId: 62,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Variants & Variant Stock'), findsOneWidget);
    expect(find.textContaining('Bronze'), findsOneWidget);
    expect(find.textContaining('STORE-TWO'), findsOneWidget);
    expect(find.textContaining('Stock ID: 202'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.textContaining('Blue'), findsNothing);
    expect(find.textContaining('STORE-ONE'), findsNothing);
    expect(find.textContaining('Stock ID: 101'), findsNothing);
  });
}
