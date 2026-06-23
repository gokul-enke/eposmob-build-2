import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/widgets/stock_selection_modal.dart';

void main() {
  group('Stock Grouping Logic', () {
    Stock buildStock({
      required int id,
      String price = '10',
      String mrp = '12',
      String purchasePrice = '8',
      String unit = 'PCS',
      String hsnCode = 'HSN1',
      String taxRate = '5',
      String? wholesalePrice,
      int? wholesaleMinUnit,
      num quantity = 1,
      String? expiryDate,
      String? date,
    }) {
      return Stock(
        id: id,
        productId: 1,
        quantity: quantity,
        price: price,
        mrp: mrp,
        purchasePrice: purchasePrice,
        unit: unit,
        hsnCode: hsnCode,
        taxRate: taxRate,
        wholesalePrice: wholesalePrice,
        wholesaleMinUnit: wholesaleMinUnit,
        expiryDate: expiryDate,
        date: date,
      );
    }

    test('combines stocks with identical pricing fields', () {
      final stocks = [
        buildStock(id: 1, quantity: 2),
        buildStock(id: 2, quantity: 3),
      ];
      final groups = groupStocksByPricing(stocks);
      expect(groups.length, 1);
      expect(groups.first.totalQuantity, 5);
      expect(
        groups.first.originalStocks.map((s) => s.id).toList()..sort(),
        [1, 2],
      );
    });

    // ---------------------------------------------------------------------
    // Default grouping behaviour (re-baselined).
    //
    // The default field set is now `kDefaultStockGroupingFields = {price,
    // unit}` (see stock_selection_modal.dart). With the default, stocks that
    // differ ONLY in mrp / purchasePrice / hsnCode / taxRate / wholesale*
    // are grouped together. The per-field separation logic below verifies
    // each field is still honoured when explicitly activated.
    // ---------------------------------------------------------------------
    test('default fields (price + unit) ignore non-price attribute differences',
        () {
      final stocks = [
        buildStock(
            id: 1,
            mrp: '12',
            purchasePrice: '8',
            hsnCode: 'HSN1',
            taxRate: '5',
            wholesalePrice: '9',
            wholesaleMinUnit: 5),
        buildStock(
            id: 2,
            mrp: '13',
            purchasePrice: '9',
            hsnCode: 'HSN2',
            taxRate: '12',
            wholesalePrice: '8',
            wholesaleMinUnit: 10),
      ];
      final groups = groupStocksByPricing(stocks);
      expect(groups.length, 1);
      expect(groups.first.totalQuantity, 2);
    });

    test('separates stocks with different MRP when mrp is an active field', () {
      final stocks = [
        buildStock(id: 1, mrp: '12'),
        buildStock(id: 2, mrp: '13'),
      ];
      final groups = groupStocksByPricing(stocks,
          activeFields: {'price', 'unit', 'mrp'});
      expect(groups.length, 2);
    });

    test('separates stocks with different purchase price when active', () {
      final stocks = [
        buildStock(id: 1, purchasePrice: '8'),
        buildStock(id: 2, purchasePrice: '9'),
      ];
      final groups = groupStocksByPricing(stocks,
          activeFields: {'price', 'unit', 'purchasePrice'});
      expect(groups.length, 2);
    });

    test('separates stocks with different unit (unit is a default field)', () {
      final stocks = [
        buildStock(id: 1, unit: 'PCS'),
        buildStock(id: 2, unit: 'BOX'),
      ];
      final groups = groupStocksByPricing(stocks);
      expect(groups.length, 2);
    });

    test('separates stocks with different HSN code when active', () {
      final stocks = [
        buildStock(id: 1, hsnCode: 'HSN1'),
        buildStock(id: 2, hsnCode: 'HSN2'),
      ];
      final groups = groupStocksByPricing(stocks,
          activeFields: {'price', 'unit', 'hsnCode'});
      expect(groups.length, 2);
    });

    test('separates stocks with different tax rate when active', () {
      final stocks = [
        buildStock(id: 1, taxRate: '5'),
        buildStock(id: 2, taxRate: '12'),
      ];
      final groups = groupStocksByPricing(stocks,
          activeFields: {'price', 'unit', 'taxRate'});
      expect(groups.length, 2);
    });

    test('separates stocks with different wholesale price when active', () {
      final stocks = [
        buildStock(id: 1, wholesalePrice: '9', wholesaleMinUnit: 5),
        buildStock(id: 2, wholesalePrice: '8', wholesaleMinUnit: 5),
      ];
      final groups = groupStocksByPricing(stocks,
          activeFields: {'price', 'unit', 'wholesalePrice'});
      expect(groups.length, 2);
    });

    test('separates stocks with different wholesale min unit when active', () {
      final stocks = [
        buildStock(id: 1, wholesalePrice: '9', wholesaleMinUnit: 5),
        buildStock(id: 2, wholesalePrice: '9', wholesaleMinUnit: 10),
      ];
      final groups = groupStocksByPricing(stocks,
          activeFields: {'price', 'unit', 'wholesaleMinUnit'});
      expect(groups.length, 2);
    });

    test('combines stocks with same pricing but different expiry dates', () {
      final stocks = [
        buildStock(id: 1, expiryDate: '2025-01-01'),
        buildStock(id: 2, expiryDate: '2025-06-01'),
      ];
      final groups = groupStocksByPricing(stocks);
      expect(groups.length, 1);
      expect(groups.first.totalQuantity, 2);
    });

    test('combines stocks with same pricing but different inward dates', () {
      final stocks = [
        buildStock(id: 1, date: '2024-01-01'),
        buildStock(id: 2, date: '2024-06-01'),
      ];
      final groups = groupStocksByPricing(stocks);
      expect(groups.length, 1);
      expect(groups.first.totalQuantity, 2);
    });

    test('firstStock returns earliest expiry date stock', () {
      final stocks = [
        buildStock(id: 1, expiryDate: '2025-06-01'),
        buildStock(id: 2, expiryDate: '2025-01-01'),
        buildStock(id: 3, expiryDate: '2025-12-01'),
      ];
      final combined = CombinedStock(
        price: '10',
        mrp: '12',
        purchasePrice: '8',
        unit: 'PCS',
        hsnCode: 'HSN1',
        wholesalePrice: null,
        wholesaleMinUnit: null,
        totalQuantity: 3,
        originalStocks: stocks,
      );
      expect(combined.firstStock.id, 2);
    });

    test('firstStock falls back to earliest date when no expiry', () {
      final stocks = [
        buildStock(id: 1, date: '2024-06-01'),
        buildStock(id: 2, date: '2024-01-01'),
      ];
      final combined = CombinedStock(
        price: '10',
        mrp: '12',
        purchasePrice: '8',
        unit: 'PCS',
        hsnCode: 'HSN1',
        wholesalePrice: null,
        wholesaleMinUnit: null,
        totalQuantity: 2,
        originalStocks: stocks,
      );
      expect(combined.firstStock.id, 2);
    });

    test('firstStock falls back to lowest id when no dates', () {
      final stocks = [
        buildStock(id: 3),
        buildStock(id: 1),
        buildStock(id: 2),
      ];
      final combined = CombinedStock(
        price: '10',
        mrp: '12',
        purchasePrice: '8',
        unit: 'PCS',
        hsnCode: 'HSN1',
        wholesalePrice: null,
        wholesaleMinUnit: null,
        totalQuantity: 3,
        originalStocks: stocks,
      );
      expect(combined.firstStock.id, 1);
    });

    test('empty stock list returns empty groups', () {
      final groups = groupStocksByPricing([]);
      expect(groups, isEmpty);
    });

    test('single stock returns one group with same quantity', () {
      final stocks = [buildStock(id: 1, quantity: 7)];
      final groups = groupStocksByPricing(stocks);
      expect(groups.length, 1);
      expect(groups.first.totalQuantity, 7);
      expect(groups.first.originalStocks.length, 1);
    });
  });
}
