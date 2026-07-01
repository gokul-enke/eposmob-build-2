import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/barcode_sale_unit.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  group('BarcodeSaleUnit.resolveSaleUnitQuantity', () {
    test('parses positive conversion rate', () {
      final unit = SaleUnit(conversionRate: '12');
      expect(BarcodeSaleUnit.resolveSaleUnitQuantity(unit), 12);
    });

    test('returns 1 for rate of 1', () {
      final unit = SaleUnit(conversionRate: '1');
      expect(BarcodeSaleUnit.resolveSaleUnitQuantity(unit), 1);
    });

    test('returns 1 for null, empty, zero, or invalid rate', () {
      expect(BarcodeSaleUnit.resolveSaleUnitQuantity(SaleUnit()), 1);
      expect(
        BarcodeSaleUnit.resolveSaleUnitQuantity(SaleUnit(conversionRate: '')),
        1,
      );
      expect(
        BarcodeSaleUnit.resolveSaleUnitQuantity(SaleUnit(conversionRate: '0')),
        1,
      );
      expect(
        BarcodeSaleUnit.resolveSaleUnitQuantity(
          SaleUnit(conversionRate: 'abc'),
        ),
        1,
      );
    });

    test('trims whitespace before parsing', () {
      final unit = SaleUnit(conversionRate: '  6  ');
      expect(BarcodeSaleUnit.resolveSaleUnitQuantity(unit), 6);
    });

    test('parses fractional conversion rate above 1', () {
      final unit = SaleUnit(conversionRate: '2.5');
      expect(BarcodeSaleUnit.resolveSaleUnitQuantity(unit), 2.5);
      expect(BarcodeSaleUnit.shouldUseSaleUnitForBarcode(unit), isTrue);
    });
  });

  group('BarcodeSaleUnit.shouldUseSaleUnitForBarcode', () {
    test('false for null match', () {
      expect(BarcodeSaleUnit.shouldUseSaleUnitForBarcode(null), isFalse);
    });

    test('false when conversion rate is 1', () {
      final unit = SaleUnit(id: 1, unitName: 'PCS', conversionRate: '1');
      expect(BarcodeSaleUnit.shouldUseSaleUnitForBarcode(unit), isFalse);
    });

    test('false when conversion rate is missing or invalid', () {
      expect(
        BarcodeSaleUnit.shouldUseSaleUnitForBarcode(SaleUnit(id: 1)),
        isFalse,
      );
      expect(
        BarcodeSaleUnit.shouldUseSaleUnitForBarcode(
          SaleUnit(id: 1, conversionRate: '0'),
        ),
        isFalse,
      );
    });

    test('true when conversion rate is greater than 1', () {
      final unit = SaleUnit(id: 10, unitName: 'CASE', conversionRate: '12');
      expect(BarcodeSaleUnit.shouldUseSaleUnitForBarcode(unit), isTrue);
    });
  });

  group('BarcodeSaleUnit.resolveBarcodeSaleUnit', () {
    test('returns null for rate-1 sale unit (plain product add)', () {
      final unit = SaleUnit(
        id: 1,
        unitName: 'PCS',
        barcode: 'PCS123',
        conversionRate: '1',
      );
      expect(BarcodeSaleUnit.resolveBarcodeSaleUnit(unit), isNull);
    });

    test('returns sale unit when conversion rate > 1', () {
      final unit = SaleUnit(
        id: 10,
        unitName: 'CASE',
        barcode: 'CASE123',
        conversionRate: '12',
      );
      expect(BarcodeSaleUnit.resolveBarcodeSaleUnit(unit), same(unit));
    });

    test('returns null for null input', () {
      expect(BarcodeSaleUnit.resolveBarcodeSaleUnit(null), isNull);
    });
  });

  group('mobile barcode path parity with desktop rule', () {
    SaleUnit? mobileSelectedSaleUnit(SaleUnit? matchedSaleUnit) =>
        BarcodeSaleUnit.resolveBarcodeSaleUnit(matchedSaleUnit);

    bool desktopUseSaleUnit(SaleUnit? matchedSaleUnit) =>
        matchedSaleUnit != null &&
        BarcodeSaleUnit.resolveSaleUnitQuantity(matchedSaleUnit) > 1;

    SaleUnit? desktopSelectedSaleUnit(SaleUnit? matchedSaleUnit) =>
        desktopUseSaleUnit(matchedSaleUnit) ? matchedSaleUnit : null;

    test('rate 1: both paths omit selectedSaleUnit', () {
      final matched = SaleUnit(
        id: 1,
        barcode: 'BASEBAR',
        conversionRate: '1',
      );
      expect(mobileSelectedSaleUnit(matched), isNull);
      expect(desktopSelectedSaleUnit(matched), isNull);
    });

    test('rate > 1: both paths pass selectedSaleUnit', () {
      final matched = SaleUnit(
        id: 10,
        barcode: 'CASEBAR',
        conversionRate: '12',
      );
      expect(mobileSelectedSaleUnit(matched), matched);
      expect(desktopSelectedSaleUnit(matched), matched);
    });
  });
}
