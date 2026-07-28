import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/barcode_layout_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/screens/print/barcode_layout_settings_panel.dart';
import 'package:pos_machine/screens/print/barcode_printer_service.dart';
import 'package:pos_machine/screens/print/barcode_sticker_image_renderer.dart';
import 'package:pos_machine/screens/print/printer_settings.dart';
import 'package:pos_machine/screens/product/product_barcode.dart';
import 'package:pos_machine/screens/product/widgets/confirm_barcode_print_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('barcode print flow public types remain constructible', () {
    const result = BarcodePrintResult(
      BarcodePrintStatus.sentToPrinter,
      'sent',
    );

    expect(result.isSuccess, isTrue);
    expect(BarcodeLayoutSettings().barcodeWidthPercent, 70);
    expect(const PrinterSettings(), isA<PrinterSettings>());
    expect(const ProductBarcodeScreen(), isA<ProductBarcodeScreen>());
    expect(
      const BarcodeLayoutSettingsPanel(),
      isA<BarcodeLayoutSettingsPanel>(),
    );
  });

  testWidgets('barcode settings remain scrollable on a phone viewport',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BarcodeLayoutSettingsPanel()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barcode Width (% of sticker)'), findsOneWidget);
    expect(find.text('Printer Resolution'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple stock batches do not fabricate or guess label dates',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final product = GetProduct(
      productName: 'Batch product',
      barcode: '1234567890',
      stock: [
        Stock(pkgMfg: '2026-01-01', expiryDate: '2027-01-01'),
        Stock(pkgMfg: '2026-02-01', expiryDate: '2027-02-01'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmBarcodePrintModal(selectedProducts: [product]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select Date'), findsNWidgets(2));
    expect(find.text('2026-01-01'), findsNothing);
  });

  test('reduced barcode height retains the default whitespace reservation', () {
    expect(BarcodeStickerImageRenderer.reservedBarcodeHeight(5), 15);
    expect(BarcodeStickerImageRenderer.reservedBarcodeHeight(10), 15);
    expect(BarcodeStickerImageRenderer.reservedBarcodeHeight(15), 15);
    expect(BarcodeStickerImageRenderer.reservedBarcodeHeight(20), 20);
  });

  test('BarcodeRow.toProductForPrint copies correct prices and updates names with suffixes', () {
    final baseProduct = GetProduct(
      productName: 'Keyboard',
      barcode: '111111',
      price: ProductPrice(price: 130),
      names: {'en': 'Keyboard', 'ar': 'لوحة مفاتيح'},
    );

    // 1. Base row case
    final baseRow = BarcodeRow(product: baseProduct);
    final basePrint = baseRow.toProductForPrint();
    expect(basePrint.productName, 'Keyboard');
    expect(basePrint.price?.price, 130);
    expect(basePrint.names['en'], 'Keyboard');
    expect(basePrint.names['ar'], 'لوحة مفاتيح');

    // 2. Variant row case
    final variant = ProductVariant(
      id: 1,
      barcode: '222222',
      price: 250,
      attributes: {'color': 'Blue', 'size': 'XL'},
    );
    final variantRow = BarcodeRow(product: baseProduct, variant: variant);
    final variantPrint = variantRow.toProductForPrint();
    expect(variantPrint.productName, 'Keyboard - Blue/XL');
    expect(variantPrint.price?.price, 250);
    expect(variantPrint.names['en'], 'Keyboard - Blue/XL');
    expect(variantPrint.names['ar'], 'لوحة مفاتيح - Blue/XL');

    // 3. SaleUnit row case
    final saleUnit = SaleUnit(
      id: 2,
      barcode: '333333',
      unitName: 'BOX',
      resolvedPrice: 700,
    );
    final unitRow = BarcodeRow(product: baseProduct, saleUnit: saleUnit);
    final unitPrint = unitRow.toProductForPrint();
    expect(unitPrint.productName, 'Keyboard (BOX)');
    expect(unitPrint.price?.price, 700);
    expect(unitPrint.names['en'], 'Keyboard (BOX)');
    expect(unitPrint.names['ar'], 'لوحة مفاتيح (BOX)');
  });

  test('BarcodeRow.toProductForPrint filters stock correctly', () {
    final baseProduct = GetProduct(
      productName: 'Keyboard',
      barcode: '111111',
      stock: [
        Stock(id: 1, productVariantId: 10, pkgMfg: '2026-01-01', expiryDate: '2027-01-01'),
        Stock(id: 2, productVariantId: 20, pkgMfg: '2026-02-01', expiryDate: '2027-02-01'),
      ],
    );

    // 1. Base row case: stock list should remain unfiltered (length 2)
    final baseRow = BarcodeRow(product: baseProduct);
    final basePrint = baseRow.toProductForPrint();
    expect(basePrint.stock?.length, 2);

    // 2. Variant row case: stock list should only contain entries with matching productVariantId
    final variant = ProductVariant(
      id: 10,
      barcode: '222222',
    );
    final variantRow = BarcodeRow(product: baseProduct, variant: variant);
    final variantPrint = variantRow.toProductForPrint();
    expect(variantPrint.stock?.length, 1);
    expect(variantPrint.stock?.first.productVariantId, 10);

    // 3. SaleUnit row case: stock list should be cleared
    final saleUnit = SaleUnit(
      id: 2,
      barcode: '333333',
      unitName: 'BOX',
    );
    final unitRow = BarcodeRow(product: baseProduct, saleUnit: saleUnit);
    final unitPrint = unitRow.toProductForPrint();
    expect(unitPrint.stock, isEmpty);
  });
}
