import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

GetProduct _variantProduct({
  List<ProductVariant>? variants,
  double basePrice = 299,
}) {
  return GetProduct(
    productId: 1,
    productName: 'T-Shirt',
    price: ProductPrice(price: basePrice.toString()),
    mrp: '499',
    variants: variants,
  );
}

ProductVariant _variant({
  required int id,
  String? barcode,
  double? price,
  Map<String, dynamic> attributes = const {},
  bool active = true,
  num? quantity,
}) {
  return ProductVariant(
    id: id,
    barcode: barcode,
    price: price,
    attributes: attributes,
    active: active,
    quantity: quantity,
  );
}

void main() {
  group('ProductVariant model', () {
    test('fromJson parses nested attributes and prices', () {
      final variant = ProductVariant.fromJson({
        'id': 45,
        'sku': 'SHIRT-RED-L',
        'barcode': '1234567890',
        'price': 349,
        'mrp': 499,
        'quantity': 10,
        'active': true,
        'attributes': {'COLOR': 'Red', 'SIZE': 'L'},
      });

      expect(variant.id, 45);
      expect(variant.sku, 'SHIRT-RED-L');
      expect(variant.price, 349);
      expect(variant.formattedAttributes, 'Red | L');
      expect(variant.effectivePrice(299), 349);
    });

    test('effectivePrice falls back to product price when variant price is zero', () {
      final variant = _variant(id: 1, price: 0);
      expect(variant.effectivePrice(299), 299);
    });

    test('GetProduct.hasVariants and activeVariants ignore inactive rows', () {
      final product = _variantProduct(variants: [
        _variant(id: 1, active: false, attributes: {'COLOR': 'Blue'}),
        _variant(id: 2, active: true, attributes: {'COLOR': 'Red'}),
      ]);

      expect(product.hasVariants, isTrue);
      expect(product.activeVariants.map((v) => v.id), [2]);
    });
  });

  group('ProductVariantSelection', () {
    test('findVariantByBarcode matches trimmed variant barcode', () {
      final product = _variantProduct(variants: [
        _variant(id: 10, barcode: '111'),
        _variant(id: 20, barcode: '222'),
      ]);

      expect(
        ProductVariantSelection.findVariantByBarcode(product, ' 222 ')?.id,
        20,
      );
      expect(
        ProductVariantSelection.findVariantByBarcode(product, '999'),
        isNull,
      );
    });

    test('tryResolveWithoutPicker auto-selects single active variant', () {
      final product = _variantProduct(variants: [
        _variant(id: 5, price: 319, attributes: {'SIZE': 'M'}),
      ]);

      final resolved = ProductVariantSelection.tryResolveWithoutPicker(product);

      expect(resolved?.id, 5);
      expect(ProductVariantSelection.needsVariantPicker(product), isFalse);
      expect(
        ProductVariantSelection.resolveVariantPrice(
          variant: resolved!,
          productPrice: 299,
        ),
        319,
      );
    });

    test('tryResolveWithoutPicker returns null when multiple variants need UI', () {
      final product = _variantProduct(variants: [
        _variant(id: 1, attributes: {'COLOR': 'Red'}),
        _variant(id: 2, attributes: {'COLOR': 'Blue'}),
      ]);

      expect(ProductVariantSelection.tryResolveWithoutPicker(product), isNull);
      expect(ProductVariantSelection.needsVariantPicker(product), isTrue);
    });

    test('tryResolveWithoutPicker prefers barcode match over multi-variant picker', () {
      final product = _variantProduct(variants: [
        _variant(id: 1, barcode: 'AAA', attributes: {'COLOR': 'Red'}),
        _variant(id: 2, barcode: 'BBB', attributes: {'COLOR': 'Blue'}),
      ]);

      expect(
        ProductVariantSelection.tryResolveWithoutPicker(
          product,
          scannedBarcode: 'BBB',
        )?.id,
        2,
      );
    });

    test('isOutOfStock is true only for explicit zero quantity', () {
      expect(_variant(id: 1, quantity: 0), isNotNull);
      expect(ProductVariantSelection.isOutOfStock(_variant(id: 1, quantity: 0)),
          isTrue);
      expect(ProductVariantSelection.isOutOfStock(_variant(id: 1, quantity: 5)),
          isFalse);
      expect(
          ProductVariantSelection.isOutOfStock(_variant(id: 1, quantity: null)),
          isFalse);
    });

    test('tryResolveWithoutPicker skips out-of-stock single variant', () {
      final product = _variantProduct(variants: [
        _variant(id: 5, attributes: {'SIZE': 'M'}, quantity: 0),
      ]);

      expect(ProductVariantSelection.tryResolveWithoutPicker(product), isNull);
      expect(ProductVariantSelection.needsVariantPicker(product), isFalse);
    });

    test('tryResolveWithoutPicker skips out-of-stock barcode match', () {
      final product = _variantProduct(variants: [
        _variant(id: 1, barcode: 'AAA', quantity: 0),
        _variant(id: 2, barcode: 'BBB', quantity: 5),
      ]);

      expect(
        ProductVariantSelection.tryResolveWithoutPicker(
          product,
          scannedBarcode: 'AAA',
        ),
        isNull,
      );
      expect(
        ProductVariantSelection.tryResolveWithoutPicker(
          product,
          scannedBarcode: 'BBB',
        )?.id,
        2,
      );
    });

    test('cartDisplayName appends variant attributes', () {
      expect(
        ProductVariantSelection.cartDisplayName(
          productName: 'T-Shirt',
          variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
        ),
        'T-Shirt (Red | L)',
      );
    });
  });

  group('variant order payload', () {
    test('buildOrderItemsPayloadFrom includes product_variant_id', () {
      final product = _variantProduct(variants: [
        _variant(id: 45, price: 349, attributes: {'COLOR': 'Red'}),
      ]);
      final item = LocalCartItem(
        product: product,
        quantity: 2,
        price: 349,
        mrp: 499,
        variantId: 45,
        variantAttributes: const {'COLOR': 'Red'},
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.length, 1);
      expect(payload.first['product_id'], 1);
      expect(payload.first['product_variant_id'], 45);
      expect(payload.first['quantity'], 2);
      expect(payload.first['price'], 349);
    });

    test('payload omits product_variant_id for non-variant lines', () {
      final product = GetProduct(
        productId: 2,
        productName: 'Plain Item',
        price: ProductPrice(price: '10'),
      );
      final item = LocalCartItem(product: product, quantity: 1, price: 10);

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.first.containsKey('product_variant_id'), isFalse);
    });

    test('LocalCartItem.displayName shows variant label', () {
      final product = _variantProduct();
      final item = LocalCartItem(
        product: product,
        variantAttributes: const {'COLOR': 'Red', 'SIZE': 'L'},
      );

      expect(item.displayName, 'T-Shirt (Red | L)');
    });
  });
}
