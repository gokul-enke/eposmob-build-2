import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/non_stock_visibility.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';

Stock _stock({
  required int id,
  required num? quantity,
  int? storeId,
  int? productVariantId,
}) =>
    Stock(
      id: id,
      productId: 1,
      quantity: quantity,
      storeId: storeId,
      productVariantId: productVariantId,
      price: '10',
      mrp: '12',
    );

ProductVariant _variant({
  required int id,
  required num? quantity,
  bool active = true,
  int? storeId,
}) =>
    ProductVariant(
      id: id,
      quantity: quantity,
      active: active,
      storeId: storeId,
    );

GetProduct _product({
  int productId = 1,
  List<Stock>? stock,
  List<ProductVariant>? variants,
  bool? hasVariantsFlag,
}) =>
    GetProduct(
      productId: productId,
      productName: 'Product $productId',
      stock: stock,
      variants: variants,
      hasVariantsFlag: hasVariantsFlag,
    );

void main() {
  group('NonStockVisibility.isActive', () {
    test('requires both the app setting and stock tracking', () {
      expect(
        NonStockVisibility.isActive(
          hideNonStockProduct: true,
          stockEnabled: true,
        ),
        isTrue,
      );
    });

    test('stays off when stock tracking is disabled', () {
      // Without stock tracking quantities are never maintained, so enabling
      // the filter would blank out the whole catalog.
      expect(
        NonStockVisibility.isActive(
          hideNonStockProduct: true,
          stockEnabled: false,
        ),
        isFalse,
      );
    });

    test('stays off when the tenant has not opted in', () {
      expect(
        NonStockVisibility.isActive(
          hideNonStockProduct: false,
          stockEnabled: true,
        ),
        isFalse,
      );
    });
  });

  group('NonStockVisibility.visibleStocks', () {
    test('drops zero and negative quantity rows', () {
      final stocks = [
        _stock(id: 1, quantity: 5),
        _stock(id: 2, quantity: 0),
        _stock(id: 3, quantity: -2),
      ];

      expect(
        NonStockVisibility.visibleStocks(stocks).map((s) => s.id),
        [1],
      );
    });

    test('treats a null quantity as empty', () {
      expect(
        NonStockVisibility.visibleStocks([_stock(id: 1, quantity: null)]),
        isEmpty,
      );
    });
  });

  group('NonStockVisibility.visibleVariants', () {
    test('hides zero-stock variants', () {
      final variants = [
        _variant(id: 1, quantity: 3),
        _variant(id: 2, quantity: 0),
      ];

      expect(
        NonStockVisibility.visibleVariants(variants).map((v) => v.id),
        [1],
      );
    });

    test('keeps variants whose stock is not tracked', () {
      // A null quantity means the backend does not track stock at variant
      // level, which must not be confused with "sold out".
      expect(
        NonStockVisibility.visibleVariants([_variant(id: 1, quantity: null)])
            .map((v) => v.id),
        [1],
      );
    });
  });

  group('NonStockVisibility.isProductVisible', () {
    test('hides a product whose every stock row is empty', () {
      final product = _product(stock: [
        _stock(id: 1, quantity: 0),
        _stock(id: 2, quantity: 0),
      ]);

      expect(NonStockVisibility.isProductVisible(product), isFalse);
    });

    test('shows a product with at least one non-empty row', () {
      final product = _product(stock: [
        _stock(id: 1, quantity: 0),
        _stock(id: 2, quantity: 4),
      ]);

      expect(NonStockVisibility.isProductVisible(product), isTrue);
    });

    test('keeps products that carry no stock rows at all', () {
      // No rows means stock was never recorded rather than sold out; the
      // add-to-cart flow already falls back to base pricing for these.
      expect(NonStockVisibility.isProductVisible(_product(stock: [])), isTrue);
      expect(NonStockVisibility.isProductVisible(_product()), isTrue);
    });

    test('ignores stock held by a different store', () {
      final product = _product(stock: [
        _stock(id: 1, quantity: 0, storeId: 7),
        _stock(id: 2, quantity: 9, storeId: 8),
      ]);

      // Store 8's stock must not keep the product visible in store 7.
      expect(
        NonStockVisibility.isProductVisible(product, activeStoreId: 7),
        isFalse,
      );
      expect(
        NonStockVisibility.isProductVisible(product, activeStoreId: 8),
        isTrue,
      );
    });

    test('ignores variant-scoped rows for a plain product', () {
      final product = _product(stock: [
        _stock(id: 1, quantity: 0),
        _stock(id: 2, quantity: 6, productVariantId: 42),
      ]);

      expect(NonStockVisibility.isProductVisible(product), isFalse);
    });

    test('hides a variant product when every active variant is empty', () {
      final product = _product(
        hasVariantsFlag: true,
        variants: [
          _variant(id: 1, quantity: 0),
          _variant(id: 2, quantity: 0),
        ],
      );

      expect(NonStockVisibility.isProductVisible(product), isFalse);
    });

    test('shows a variant product when one variant still has stock', () {
      final product = _product(
        hasVariantsFlag: true,
        variants: [
          _variant(id: 1, quantity: 0),
          _variant(id: 2, quantity: 2),
        ],
      );

      expect(NonStockVisibility.isProductVisible(product), isTrue);
    });

    test('ignores inactive variants when judging availability', () {
      final product = _product(
        hasVariantsFlag: true,
        variants: [
          _variant(id: 1, quantity: 5, active: false),
          _variant(id: 2, quantity: 0),
        ],
      );

      expect(NonStockVisibility.isProductVisible(product), isFalse);
    });
  });

  group('NonStockVisibility.filterProducts', () {
    final inStock = _product(productId: 1, stock: [_stock(id: 1, quantity: 3)]);
    final outOfStock =
        _product(productId: 2, stock: [_stock(id: 2, quantity: 0)]);

    test('returns the list untouched when the setting is off', () {
      final result = NonStockVisibility.filterProducts(
        [inStock, outOfStock],
        hideNonStockProduct: false,
        stockEnabled: true,
      );

      expect(result.map((p) => p.productId), [1, 2]);
    });

    test('returns the list untouched when stock tracking is off', () {
      final result = NonStockVisibility.filterProducts(
        [inStock, outOfStock],
        hideNonStockProduct: true,
        stockEnabled: false,
      );

      expect(result.map((p) => p.productId), [1, 2]);
    });

    test('removes out-of-stock products when active', () {
      final result = NonStockVisibility.filterProducts(
        [inStock, outOfStock],
        hideNonStockProduct: true,
        stockEnabled: true,
      );

      expect(result.map((p) => p.productId), [1]);
    });
  });

  group('AppSettings POS_HIDE_NONSTOCK_PRODUCT parsing', () {
    AppSettings parse(List<Map<String, dynamic>> rows) =>
        AppSettings.fromJson({'data': rows});

    test('defaults to false when the row is absent', () {
      expect(parse([]).posHideNonStockProduct, isFalse);
    });

    test('reads a boolean status', () {
      final settings = parse([
        {
          'code': 'POS_HIDE_NONSTOCK_PRODUCT',
          'value': '',
          'status': true,
        }
      ]);

      expect(settings.posHideNonStockProduct, isTrue);
    });

    test('reads the string and numeric status encodings', () {
      for (final raw in <dynamic>['true', '1', 1]) {
        final settings = parse([
          {
            'code': 'POS_HIDE_NONSTOCK_PRODUCT',
            'value': '',
            'status': raw,
          }
        ]);

        expect(
          settings.posHideNonStockProduct,
          isTrue,
          reason: 'status "$raw" should enable the setting',
        );
      }
    });

    test('stays false for a disabled row', () {
      final settings = parse([
        {
          'code': 'POS_HIDE_NONSTOCK_PRODUCT',
          'value': '',
          'status': 'false',
        }
      ]);

      expect(settings.posHideNonStockProduct, isFalse);
    });

    test('survives a toJson round trip', () {
      final settings = parse([
        {
          'code': 'POS_HIDE_NONSTOCK_PRODUCT',
          'value': '',
          'status': true,
        }
      ]);

      expect(
        AppSettings.fromJson(settings.toJson()).posHideNonStockProduct,
        isTrue,
      );
    });
  });
}
