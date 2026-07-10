import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/barcode_layout_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/screens/print/barcode_layout_settings_panel.dart';
import 'package:pos_machine/screens/print/barcode_printer_service.dart';
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
}
