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

    test('fromJson accepts attributes as name/value list', () {
      final variant = ProductVariant.fromJson({
        'id': 1,
        'attributes': [
          {'name': 'COLOR', 'value': 'Red'},
          {'name': 'SIZE', 'value': 'L'},
        ],
      });

      expect(variant.attributes, {'COLOR': 'Red', 'SIZE': 'L'});
      expect(variant.formattedAttributes, 'Red | L');
    });

    test('fromJson accepts empty attributes list', () {
      final variant = ProductVariant.fromJson({
        'id': 1,
        'attributes': [],
      });

      expect(variant.attributes, isEmpty);
    });

    test(
        'effectivePrice falls back to product price when variant price is zero',
        () {
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

    test('variant_mode remains true when backend returns no active rows', () {
      final product = GetProduct.fromJson({
        'product_id': 9,
        'product_name': 'Configured Shirt',
        'variant_mode': true,
        'variants': <Map<String, dynamic>>[],
      });

      expect(product.variantMode, isTrue);
      expect(product.hasVariants, isTrue);
      expect(product.activeVariants, isEmpty);
      expect(product.toJson()['variant_mode'], isTrue);
    });

    test('available_quantity takes precedence over legacy quantity', () {
      final variant = ProductVariant.fromJson({
        'id': 10,
        'quantity': 99,
        'available_quantity': '4.5',
        'store_id': '2',
      });

      expect(variant.quantity, 4.5);
      expect(variant.totalQuantity, 99);
      expect(variant.availableQuantity, 4.5);
      expect(variant.storeId, 2);
      expect(variant.toJson()['quantity'], 99);
      expect(variant.toJson()['available_quantity'], 4.5);
      expect(variant.toJson()['store_id'], 2);
    });

    test('product variant metadata survives a JSON/Hive payload round trip',
        () {
      final product = GetProduct.fromJson({
        'product_id': 9,
        'variant_mode': true,
        'has_variants': true,
        'matched_variant_id': 62,
        'variants': [
          {
            'id': 62,
            'quantity': 120,
            'available_quantity': 100,
            'store_id': 2,
            'active': true,
          },
        ],
      });

      final restored = GetProduct.fromJson(product.toJson());
      expect(restored.variantMode, isTrue);
      expect(restored.hasVariantsFlag, isTrue);
      expect(restored.matchedVariantId, 62);
      expect(restored.variants!.single.totalQuantity, 120);
      expect(restored.variants!.single.availableQuantity, 100);
      expect(restored.variants!.single.quantity, 100);
      expect(restored.variants!.single.storeId, 2);
    });
  });

  group('ProductVariantSelection', () {
    test('active variants and barcode resolution are scoped to active store',
        () {
      final product = _variantProduct(variants: [
        ProductVariant(id: 10, barcode: 'S1', storeId: 1),
        ProductVariant(id: 20, barcode: 'S2', storeId: 2),
        ProductVariant(id: 30, barcode: 'GLOBAL'),
      ]);

      expect(
        ProductVariantSelection.activeVariantsForStore(
          product,
          activeStoreId: 2,
        ).map((variant) => variant.id),
        [20, 30],
      );
      expect(
        ProductVariantSelection.findVariantByBarcode(
          product,
          'S1',
          activeStoreId: 2,
        ),
        isNull,
      );
      expect(
        ProductVariantSelection.findVariantByBarcode(
          product,
          'S2',
          activeStoreId: 2,
        )?.id,
        20,
      );
    });

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

    test('tryResolveWithoutPicker honors store-valid matched_variant_id', () {
      final product = GetProduct(
        productId: 1,
        matchedVariantId: 20,
        variants: [
          ProductVariant(id: 10, storeId: 1),
          ProductVariant(id: 20, storeId: 2),
          ProductVariant(id: 30, storeId: 2),
        ],
      );

      expect(
        ProductVariantSelection.tryResolveWithoutPicker(
          product,
          activeStoreId: 2,
        )?.id,
        20,
      );
      expect(
        ProductVariantSelection.tryResolveWithoutPicker(
          product,
          activeStoreId: 1,
        )?.id,
        10,
      );
    });

    test('tryResolveWithoutPicker returns null when multiple variants need UI',
        () {
      final product = _variantProduct(variants: [
        _variant(id: 1, attributes: {'COLOR': 'Red'}),
        _variant(id: 2, attributes: {'COLOR': 'Blue'}),
      ]);

      expect(ProductVariantSelection.tryResolveWithoutPicker(product), isNull);
      expect(ProductVariantSelection.needsVariantPicker(product), isTrue);
    });

    test(
        'tryResolveWithoutPicker prefers barcode match over multi-variant picker',
        () {
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

    // Real-world POS rule: a zero-quantity variant is a data signal, not a
    // sales block — the cashier may be holding the physical item. Resolution
    // still auto-selects it; ProductCartHelper is responsible for asking the
    // cashier to confirm an oversell before it reaches the cart.
    test(
        'tryResolveWithoutPicker still auto-selects out-of-stock single variant',
        () {
      final product = _variantProduct(variants: [
        _variant(id: 5, attributes: {'SIZE': 'M'}, quantity: 0),
      ]);

      final resolved = ProductVariantSelection.tryResolveWithoutPicker(product);

      expect(resolved?.id, 5);
      expect(ProductVariantSelection.isOutOfStock(resolved!), isTrue);
      expect(ProductVariantSelection.needsVariantPicker(product), isFalse);
    });

    test('tryResolveWithoutPicker still resolves out-of-stock barcode match',
        () {
      final product = _variantProduct(variants: [
        _variant(id: 1, barcode: 'AAA', quantity: 0),
        _variant(id: 2, barcode: 'BBB', quantity: 5),
      ]);

      final resolved = ProductVariantSelection.tryResolveWithoutPicker(
        product,
        scannedBarcode: 'AAA',
      );
      expect(resolved?.id, 1);
      expect(ProductVariantSelection.isOutOfStock(resolved!), isTrue);

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
