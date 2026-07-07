/// Pins the pure resolution chain used by [BillingMobileController.processBarcode]
/// without mounting widgets — sale-unit identity (P-01), embedded weight (§2),
/// and variant barcode skip-picker (P-05).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/barcode_sale_unit.dart';
import 'package:pos_machine/features/billing/domain/embedded_barcode.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/models/get_product.dart';

/// Mirrors the sale-unit branch inside `BillingMobileController.processBarcode`.
({SaleUnit? matched, num? quantity, SaleUnit? selectedSaleUnit})
    resolveMobileSaleUnitBarcode(GetProduct product, String scannedBarcode) {
  SaleUnit? matchedSaleUnit;
  for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
    final saleUnitBarcode = saleUnit.barcode?.trim() ?? '';
    if (saleUnitBarcode.isNotEmpty && saleUnitBarcode == scannedBarcode.trim()) {
      matchedSaleUnit = saleUnit;
      break;
    }
  }

  num? quantity;
  if (matchedSaleUnit != null) {
    quantity = BarcodeSaleUnit.resolveSaleUnitQuantity(matchedSaleUnit);
  }

  return (
    matched: matchedSaleUnit,
    quantity: quantity,
    selectedSaleUnit: BarcodeSaleUnit.resolveBarcodeSaleUnit(matchedSaleUnit),
  );
}

/// Mirrors embedded + unit branch inside `BillingMobileController.processBarcode`.
num? resolveMobileEmbeddedQuantity(GetProduct product, String scannedBarcode) {
  final isEmbedded = EmbeddedBarcode.isEmbedded(scannedBarcode);
  if ((product.unit == 'KGS' || product.unit == 'KG') && isEmbedded) {
    return EmbeddedBarcode.weightQuantityKg(scannedBarcode);
  }
  if ((product.unit == 'PCS' || product.unit == 'PC') && isEmbedded) {
    return EmbeddedBarcode.pieceQuantity(scannedBarcode);
  }
  return null;
}

GetProduct _productWithSaleUnits(List<SaleUnit> saleUnits) {
  return GetProduct(
    productId: 1,
    productName: 'Cola',
    unit: 'PCS',
    price: ProductPrice(price: '10'),
    saleUnits: saleUnits,
  );
}

void main() {
  group('P-01 mobile sale-unit barcode resolution', () {
    test('rate 12: quantity uses conversion; selectedSaleUnit is set', () {
      const barcode = 'CASEBAR12';
      final product = _productWithSaleUnits([
        SaleUnit(
          id: 10,
          unitName: 'CASE',
          barcode: barcode,
          conversionRate: '12',
        ),
      ]);

      final resolved = resolveMobileSaleUnitBarcode(product, barcode);

      expect(resolved.matched?.id, 10);
      expect(resolved.quantity, 12);
      expect(resolved.selectedSaleUnit, isNotNull);
      expect(resolved.selectedSaleUnit!.id, 10);
    });

    test('rate 1: quantity is 1 but selectedSaleUnit is omitted (base line)', () {
      const barcode = 'PCS123';
      final product = _productWithSaleUnits([
        SaleUnit(
          id: 1,
          unitName: 'PCS',
          barcode: barcode,
          conversionRate: '1',
        ),
      ]);

      final resolved = resolveMobileSaleUnitBarcode(product, barcode);

      expect(resolved.matched?.id, 1);
      expect(resolved.quantity, 1);
      expect(resolved.selectedSaleUnit, isNull);
    });

    test('burst mix: base rate-1 and rate>1 barcodes resolve independently', () {
      final product = _productWithSaleUnits([
        SaleUnit(id: 1, barcode: 'BASE', conversionRate: '1'),
        SaleUnit(id: 2, barcode: 'PACK6', conversionRate: '6'),
      ]);

      final base = resolveMobileSaleUnitBarcode(product, 'BASE');
      final pack = resolveMobileSaleUnitBarcode(product, 'PACK6');

      expect(base.selectedSaleUnit, isNull);
      expect(pack.selectedSaleUnit?.id, 2);
      expect(pack.quantity, 6);
    });
  });

  group('§2 embedded weight barcode resolution', () {
    test('14-char 000… KG barcode parses embedded weight quantity', () {
      const embedded = '00012345601500'; // 1.5 kg
      final product = GetProduct(
        productId: 2,
        productName: 'Rice',
        unit: 'KG',
        price: ProductPrice(price: '50'),
      );

      expect(resolveMobileEmbeddedQuantity(product, embedded), 1.5);
      expect(EmbeddedBarcode.searchCode(embedded), '123456');
    });

    test('14-char 000… PCS barcode parses piece count', () {
      const embedded = '00012345600003';
      final product = GetProduct(
        productId: 3,
        productName: 'Buns',
        unit: 'PCS',
        price: ProductPrice(price: '5'),
      );

      expect(resolveMobileEmbeddedQuantity(product, embedded), 3);
    });
  });

  group('P-05 variant barcode on multi-variant product', () {
    test('variant barcode skips picker and resolves scanned variant', () {
      final product = GetProduct(
        productId: 4,
        productName: 'T-Shirt',
        price: ProductPrice(price: '299'),
        variants: [
          ProductVariant(
            id: 1,
            barcode: 'VAR-RED',
            price: 349,
            attributes: const {'COLOR': 'Red'},
          ),
          ProductVariant(
            id: 2,
            barcode: 'VAR-BLUE',
            price: 359,
            attributes: const {'COLOR': 'Blue'},
          ),
        ],
      );

      final resolved = ProductVariantSelection.tryResolveWithoutPicker(
        product,
        scannedBarcode: 'VAR-BLUE',
      );

      expect(ProductVariantSelection.needsVariantPicker(product), isTrue);
      expect(resolved?.id, 2);
      expect(
        ProductVariantSelection.resolveVariantPrice(
          variant: resolved!,
          productPrice: 299,
        ),
        359,
      );
    });

    // Real-world POS rule: a zero-quantity variant barcode still auto-resolves
    // — the cashier is scanning a physical item in hand. ProductCartHelper is
    // responsible for the oversell confirmation, not variant resolution.
    test('out-of-stock variant barcode still auto-resolves for oversell confirmation', () {
      final product = GetProduct(
        productId: 5,
        productName: 'Hoodie',
        price: ProductPrice(price: '499'),
        variants: [
          ProductVariant(
            id: 1,
            barcode: 'VAR-OOS',
            price: 549,
            quantity: 0,
            attributes: const {'COLOR': 'Black'},
          ),
          ProductVariant(
            id: 2,
            barcode: 'VAR-OK',
            price: 559,
            quantity: 4,
            attributes: const {'COLOR': 'Grey'},
          ),
        ],
      );

      final resolvedOos = ProductVariantSelection.tryResolveWithoutPicker(
        product,
        scannedBarcode: 'VAR-OOS',
      );
      expect(resolvedOos?.id, 1);
      expect(ProductVariantSelection.isOutOfStock(resolvedOos!), isTrue);

      expect(
        ProductVariantSelection.tryResolveWithoutPicker(
          product,
          scannedBarcode: 'VAR-OK',
        )?.id,
        2,
      );
      expect(ProductVariantSelection.needsVariantPicker(product), isTrue);
    });
  });
}
