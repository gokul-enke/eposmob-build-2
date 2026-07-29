import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/screens/product/product_barcode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_support/hive_test_teardown.dart';

List<BarcodeRow> testExpandProductsToBarcodeRows(List<GetProduct> products) {
  final rows = <BarcodeRow>[];
  for (final product in products) {
    final subRows = <BarcodeRow>[];

    final variants = product.variants;
    if (variants != null && variants.isNotEmpty) {
      for (final v in variants) {
        if (!v.active) continue;
        final bc = v.barcode?.trim() ?? '';
        if (bc.isNotEmpty) {
          subRows.add(BarcodeRow(product: product, variant: v));
        }
      }
    }

    final units = product.saleUnits;
    if (units != null && units.isNotEmpty) {
      final baseBarcode = (product.barcode ?? '').trim();
      for (final u in units) {
        final bc = u.barcode?.trim() ?? '';
        if (bc.isNotEmpty && bc != baseBarcode) {
          subRows.add(BarcodeRow(product: product, saleUnit: u));
        }
      }
    }

    rows.add(BarcodeRow(product: product));
    rows.addAll(subRows);
  }
  return rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_barcode_row_test_');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(HiveStringValueAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HiveLocalCartItemAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HiveSavedOrderAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(HiveProductAdapter());
    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'general_stock_enabled': true});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(() => awaitPendingHiveBoxWrites());
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  // ── Helpers ──────────────────────────────────────────────────────────────

  GetProduct _mkProduct({
    int id = 1,
    String price = '100.0',
    String? mrp,
    String? barcode,
    List<Stock>? stock,
    List<ProductVariant>? variants,
    List<SaleUnit>? saleUnits,
  }) =>
      GetProduct(
        productId: id,
        productName: 'Test',
        unit: 'PCS',
        barcode: barcode,
        price: ProductPrice(price: price),
        mrp: mrp,
        stock: stock,
        variants: variants,
        saleUnits: saleUnits,
      );

  BarcodeRow _baseRow(GetProduct p) => BarcodeRow(product: p);
  BarcodeRow _vRow(GetProduct p, ProductVariant v) => BarcodeRow(product: p, variant: v);
  BarcodeRow _uRow(GetProduct p, SaleUnit u) => BarcodeRow(product: p, saleUnit: u);

  // ─────────────────────────────────────────────────────────────────────────
  // Issue 1 — Base-row stock filtering
  // ─────────────────────────────────────────────────────────────────────────
  group('Issue 1 — base row stock filter', () {
    test('only variant-owned stock → base row has empty stock', () {
      final p = _mkProduct(stock: [Stock(id: 1, productVariantId: 42, quantity: 5)]);
      expect(_baseRow(p).toProductForPrint().stock, isEmpty);
    });

    test('base-only stock → all forwarded', () {
      final p = _mkProduct(stock: [
        Stock(id: 1, productVariantId: null, quantity: 5),
        Stock(id: 2, productVariantId: null, quantity: 3),
      ]);
      final printed = _baseRow(p).toProductForPrint();
      expect(printed.stock?.length, 2);
    });

    test('mixed stock → variant rows excluded', () {
      final p = _mkProduct(stock: [
        Stock(id: 1, productVariantId: null, quantity: 10),
        Stock(id: 2, productVariantId: 99, quantity: 5),
        Stock(id: 3, productVariantId: null, quantity: 2),
      ]);
      final printed = _baseRow(p).toProductForPrint();
      expect(printed.stock?.length, 2);
      final ids = (printed.stock?.map((s) => s.id).toList() ?? [])..sort();
      expect(ids, [1, 3]);
    });

    test('no stock → empty, not null', () {
      expect(_baseRow(_mkProduct(stock: null)).toProductForPrint().stock, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Issue 2 — SaleUnit.resolveDisplayPrice fallback chain
  // ─────────────────────────────────────────────────────────────────────────
  group('Issue 2 — SaleUnit.resolveDisplayPrice', () {
    test('resolvedPrice > 0 → uses it', () {
      final p = _mkProduct(price: '100.0');
      final u = SaleUnit(id: 1, conversionRate: '12', resolvedPrice: 150.0);
      expect(SaleUnit.resolveDisplayPrice(product: p, saleUnit: u), 150.0);
    });

    test('explicit price > 0, no resolvedPrice → uses price', () {
      final p = _mkProduct(price: '100.0');
      final u = SaleUnit(id: 1, conversionRate: '12', price: 130.0);
      expect(SaleUnit.resolveDisplayPrice(product: p, saleUnit: u), 130.0);
    });

    test('both null → base × rate', () {
      final p = _mkProduct(price: '10.0');
      final u = SaleUnit(id: 1, conversionRate: '12');
      expect(SaleUnit.resolveDisplayPrice(product: p, saleUnit: u), closeTo(120.0, 0.001));
    });

    test('batch override wins over price and resolvedPrice', () {
      final p = _mkProduct(price: '10.0');
      final u = SaleUnit(id: 5, conversionRate: '12', price: 130.0, resolvedPrice: 140.0);
      final stock = Stock(id: 99, unitPriceOverrides: {5: 200.0});
      expect(SaleUnit.resolveDisplayPrice(product: p, saleUnit: u, selectedStock: stock), 200.0);
    });

    test('batch override zero → falls through to master price', () {
      final p = _mkProduct(price: '10.0');
      final u = SaleUnit(id: 5, conversionRate: '12', price: 130.0);
      final stock = Stock(id: 99, unitPriceOverrides: {5: 0.0});
      expect(SaleUnit.resolveDisplayPrice(product: p, saleUnit: u, selectedStock: stock), 130.0);
    });

    test('priceDisplay auto-fallback base×rate when no price on unit', () {
      final p = _mkProduct(price: '20.0');
      final u = SaleUnit(id: 1, conversionRate: '5');
      expect(_uRow(p, u).priceDisplay, '100.0');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Issue 3 — Zero price/MRP treated as invalid
  // ─────────────────────────────────────────────────────────────────────────
  group('Issue 3 — zero price/MRP fallback', () {
    test('variant positive price → shows variant price', () {
      final p = _mkProduct(price: '100.0');
      final v = ProductVariant(id: 1, active: true, price: 60.0);
      expect(_vRow(p, v).priceDisplay, '60.0');
    });

    test('variant null price → falls back to base', () {
      final p = _mkProduct(price: '100.0');
      final v = ProductVariant(id: 1, active: true, price: null);
      expect(_vRow(p, v).priceDisplay, '100.0');
    });

    test('variant ZERO price → falls back to base (not 0)', () {
      final p = _mkProduct(price: '100.0');
      final v = ProductVariant(id: 1, active: true, price: 0.0);
      expect(_vRow(p, v).priceDisplay, '100.0');
    });

    test('variant positive MRP → shows variant MRP', () {
      final p = _mkProduct(mrp: '150.0');
      final v = ProductVariant(id: 1, active: true, mrp: 120.0);
      expect(_vRow(p, v).mrpDisplay, '120.0');
    });

    test('variant null MRP → falls back to base', () {
      final p = _mkProduct(mrp: '150.0');
      final v = ProductVariant(id: 1, active: true, mrp: null);
      expect(_vRow(p, v).mrpDisplay, '150.0');
    });

    test('variant ZERO MRP → falls back to base', () {
      final p = _mkProduct(mrp: '150.0');
      final v = ProductVariant(id: 1, active: true, mrp: 0.0);
      expect(_vRow(p, v).mrpDisplay, '150.0');
    });

    test('sale unit price 0 → auto base×rate fallback', () {
      final p = _mkProduct(price: '10.0');
      final u = SaleUnit(id: 1, conversionRate: '6', price: 0.0);
      expect(_uRow(p, u).priceDisplay, '60.0');
    });

    test('toProductForPrint: variant zero price → uses base price', () {
      final p = _mkProduct(price: '100.0');
      final v = ProductVariant(id: 1, active: true, price: 0.0);
      expect(_vRow(p, v).toProductForPrint().price?.price, '100.0');
    });

    test('toProductForPrint: variant zero mrp → uses base mrp', () {
      final p = _mkProduct(price: '100.0', mrp: '120.0');
      final v = ProductVariant(id: 1, active: true, mrp: 0.0);
      expect(_vRow(p, v).toProductForPrint().mrp, '120.0');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Issue 4 — Selection key uniqueness
  // ─────────────────────────────────────────────────────────────────────────
  group('Issue 4 — selection key uniqueness', () {
    test('two null-id units on same product → distinct keys', () {
      final p = _mkProduct();
      final uA = SaleUnit(id: null, unitId: 1, unitName: 'DOZEN', conversionRate: '12');
      final uB = SaleUnit(id: null, unitId: 2, unitName: 'HALF', conversionRate: '6');
      expect(_uRow(p, uA).selectionKey, isNot(equals(_uRow(p, uB).selectionKey)));
    });

    test('same unit → same key (stable)', () {
      final p = _mkProduct();
      final u = SaleUnit(id: null, unitId: 7, unitName: 'BOX', conversionRate: '24');
      expect(_uRow(p, u).selectionKey, equals(_uRow(p, u).selectionKey));
    });

    test('units differing only by barcode → distinct keys', () {
      final p = _mkProduct();
      final uA = SaleUnit(id: null, unitId: 1, conversionRate: '12', barcode: 'A');
      final uB = SaleUnit(id: null, unitId: 1, conversionRate: '12', barcode: 'B');
      expect(_uRow(p, uA).selectionKey, isNot(equals(_uRow(p, uB).selectionKey)));
    });

    test('unit with real id → key includes id', () {
      final p = _mkProduct();
      final u = SaleUnit(id: 10, unitName: 'CASE', conversionRate: '12');
      expect(_uRow(p, u).selectionKey, contains('10'));
    });

    test('base row key → id:N', () {
      expect(_baseRow(_mkProduct(id: 7)).selectionKey, 'id:7');
    });

    test('variant key → variant:productId:variantId', () {
      final p = _mkProduct();
      final v = ProductVariant(id: 5, active: true);
      expect(_vRow(p, v).selectionKey, 'variant:1:5');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Issue 5 — expandProductsToBarcodeRows row counts & pagination maths
  // ─────────────────────────────────────────────────────────────────────────
  group('Issue 5 — row expansion and pagination', () {
    test('plain product → 1 row', () {
      expect(testExpandProductsToBarcodeRows([_mkProduct()]).length, 1);
    });

    test('product with 2 active variants → 3 rows', () {
      final p = _mkProduct(variants: [
        ProductVariant(id: 1, active: true, barcode: 'BC1'),
        ProductVariant(id: 2, active: true, barcode: 'BC2'),
      ]);
      expect(testExpandProductsToBarcodeRows([p]).length, 3);
    });

    test('product with 1 active + 1 inactive → 2 rows', () {
      final p = _mkProduct(variants: [
        ProductVariant(id: 1, active: true, barcode: 'BC1'),
        ProductVariant(id: 2, active: false, barcode: 'BC2'),
      ]);
      expect(testExpandProductsToBarcodeRows([p]).length, 2);
    });

    test('product with 2 sale units → 3 rows', () {
      final p = _mkProduct(
        barcode: 'BASE',
        saleUnits: [
          SaleUnit(id: 1, unitName: 'HALF', barcode: 'BC1'),
          SaleUnit(id: 2, unitName: 'FULL', barcode: 'BC2'),
        ],
      );
      expect(testExpandProductsToBarcodeRows([p]).length, 3);
    });

    test('5 products, 3 with sub-rows → 11 rows total', () {
      final rows = testExpandProductsToBarcodeRows([
        _mkProduct(id: 1),
        _mkProduct(id: 2),
        GetProduct(productId: 3, productName: 'PV', variants: [
          ProductVariant(id: 31, active: true, barcode: 'V1'),
          ProductVariant(id: 32, active: true, barcode: 'V2'),
        ]),
        GetProduct(productId: 4, productName: 'PU1', barcode: 'BASE4', saleUnits: [
          SaleUnit(id: 41, barcode: 'U1'), SaleUnit(id: 42, barcode: 'U2')
        ]),
        GetProduct(productId: 5, productName: 'PU2', barcode: 'BASE5', saleUnits: [
          SaleUnit(id: 51, barcode: 'U3'), SaleUnit(id: 52, barcode: 'U4')
        ]),
      ]);
      expect(rows.length, 11);
    });

    test('page slicing: 11 rows at 5/page → correct counts', () {
      const size = 5;
      List<BarcodeRow> page(List<BarcodeRow> all, int p) {
        final s = (p - 1) * size;
        final e = (s + size).clamp(0, all.length);
        return all.sublist(s, e);
      }
      final all = List.generate(11, (i) => BarcodeRow(product: _mkProduct(id: i + 1)));
      expect(page(all, 1).length, 5);
      expect(page(all, 2).length, 5);
      expect(page(all, 3).length, 1);
    });

    test('serial numbers are offset by page', () {
      const size = 5;
      final fromPage2 = (2 - 1) * size + 1;
      expect(fromPage2 + 0, 6);
      expect(fromPage2 + 4, 10);
      final fromPage3 = (3 - 1) * size + 1;
      expect(fromPage3 + 0, 11);
    });

    test('filteredProductsVersion increments on listAllProducts', () {
      final provider = LocalProductProvider();
      provider.initializeProducts([_mkProduct()]);
      final v0 = provider.filteredProductsVersion;
      provider.listAllProducts();
      expect(provider.filteredProductsVersion, greaterThan(v0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Issue 6 — Inactive variant search
  // ─────────────────────────────────────────────────────────────────────────
  group('Issue 6 — inactive variant search', () {
    test('active variant barcode → filterProductByBarcode returns product', () {
      final provider = LocalProductProvider();
      final p = GetProduct(
        productId: 1,
        productName: 'P1',
        variants: [ProductVariant(id: 11, active: true, barcode: 'ACTIVE-BAR')],
      );
      provider.initializeProducts([p]);
      expect(provider.filterProductByBarcode(barCode: 'ACTIVE-BAR'), hasLength(1));
    });

    test('inactive variant barcode → filterProductByBarcode returns empty', () {
      final provider = LocalProductProvider();
      final p = GetProduct(
        productId: 2,
        productName: 'P2',
        variants: [ProductVariant(id: 21, active: false, barcode: 'INACTIVE-BAR')],
      );
      provider.initializeProducts([p]);
      expect(provider.filterProductByBarcode(barCode: 'INACTIVE-BAR'), isEmpty);
    });

    test('active variant SKU → listAllProducts returns product', () {
      final provider = LocalProductProvider();
      final p = GetProduct(
        productId: 3, productName: 'P3',
        variants: [ProductVariant(id: 31, active: true, sku: 'ACTIVE-SKU')],
      );
      provider.initializeProducts([p]);
      provider.listAllProducts(filterName: 'ACTIVE-SKU');
      expect(provider.allFilteredProducts, hasLength(1));
    });

    test('inactive variant SKU only → listAllProducts returns empty', () {
      final provider = LocalProductProvider();
      final p = GetProduct(
        productId: 4, productName: 'P4',
        variants: [ProductVariant(id: 41, active: false, sku: 'INACTIVE-SKU')],
      );
      provider.initializeProducts([p]);
      provider.listAllProducts(filterName: 'INACTIVE-SKU');
      expect(provider.allFilteredProducts, isEmpty);
    });

    test('inactive variant not included in expanded rows', () {
      final p = GetProduct(
        productId: 5, productName: 'P5',
        variants: [
          ProductVariant(id: 51, active: false, barcode: 'INACT'),
          ProductVariant(id: 52, active: true, barcode: 'ACT'),
        ],
      );
      final rows = testExpandProductsToBarcodeRows([p]);
      expect(rows.length, 2); // base + 1 active
      expect(rows.any((r) => r.variant?.id == 51), isFalse);
    });
  });
}
