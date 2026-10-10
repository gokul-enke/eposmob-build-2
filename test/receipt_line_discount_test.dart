import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/domain/cart_discount_breakdown.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_factory.dart';
import 'package:pos_machine/screens/print/receipt_line_discount.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

class _OfflineSettings extends AppSettingsProvider {
  final _settings = AppSettings.fromJson({
    'data': [
      {'code': 'CURRENCY', 'value': 'SAR', 'status': true},
    ]
  });
  @override
  AppSettings? get appSettings => _settings;
  @override
  Future<void> fetchAppSettings() async {}
}

LocalCartItem _item(
        {double price = 80,
        num quantity = 2,
        int? offerId,
        bool manual = true}) =>
    LocalCartItem(
      product: GetProduct(
          productId: 1,
          productName: 'Discounted product',
          unit: 'PC',
          price: ProductPrice(price: '100'),
          mrp: '120',
          taxes: const [],
          stock: const []),
      price: price,
      mrp: 120,
      quantity: quantity,
      taxRate: 15,
      standardUnitPrice: 100,
      isManualPriceOverride: manual,
      offerId: offerId,
    );

void main() {
  test('API pricing fields survive parsing, serialization and partial copies',
      () {
    final item = OrderDetailsModelDataCartItem.fromJson({
      'quantity': 2,
      'unit_price': '80',
      'total_price': '160',
      'standard_unit_price': '100',
      'line_discount': '16',
      'discounted_total': '144',
      'discounted_base_amount': '125.22',
      'discounted_tax_amount': '18.78',
    });
    final restored = OrderDetailsModelDataCartItem.fromJson(item.toJson());
    final amounts = ReceiptLineDiscount.fromItem(restored);
    expect(amounts.itemDiscount, 40);
    expect(amounts.orderDiscount, 16);
    expect(amounts.discountedTotal, 144);
    expect(amounts.originalRate, 100);
    final partial = restored.copyWith(quantity: 1, totalPrice: '80');
    expect(ReceiptLineDiscount.fromItem(partial).itemDiscount, 20);
    expect(ReceiptLineDiscount.fromItem(partial).orderDiscount, 8);
    expect(partial.discountedTaxAmount, '9.39');
  });

  test('MRP, missing references, and price increases do not invent discounts',
      () {
    for (final standard in [null, '70']) {
      final amount = ReceiptLineDiscount.fromItem({
        'quantity': '2',
        'unitPrice': '80',
        'totalPrice': '160',
        'mrp': '120',
        'standard_unit_price': standard,
      });
      expect(amount.itemDiscount, 0);
      expect(amount.originalRate, 80);
    }
    expect(
        ReceiptLineDiscount.fromItem({
          'quantity': '1',
          'totalPrice': '0',
          'standard_unit_price': '100',
        }).itemDiscount,
        100);
  });

  test('fixed item reduction prints original rate, saving and final amount',
      () {
    for (final row in [
      {
        'quantity': '1',
        'unit_price': '17',
        'total_price': '17',
        'standard_unit_price': '20',
        'tax_rate': '18',
      },
      {
        'quantity': '1',
        'unit_price': '17',
        'total_price': '17',
        'item_discount_amount': '3',
        'tax_rate': '18',
      },
    ]) {
      final amounts = ReceiptLineDiscount.fromItem(row);
      expect(amounts.originalRate, 20);
      expect(amounts.totalDiscount, 3);
      expect(amounts.discountedTotal, 17);
      expect(amounts.formattedRateExcTax, '16.95');
    }
    final explicitZero = ReceiptLineDiscount.fromItem({
      'quantity': '1',
      'unit_price': '17',
      'total_price': '17',
      'standard_unit_price': '20',
      'item_discount_amount': '0',
    });
    expect(explicitZero.originalRate, 17);
    expect(explicitZero.totalDiscount, 0);
    expect(explicitZero.discountedTotal, 17);
  });

  test('manual and offer discounts are counted once and VAT follows coupon',
      () {
    for (final item in [_item(), _item(offerId: 7, manual: false)]) {
      final row = PrintService.savedOrderReceiptItems([item], 16).single;
      final amounts = ReceiptLineDiscount.fromItem(row);
      expect(row['totalPrice'], '160.00');
      expect(amounts.itemDiscount, 40);
      expect(amounts.orderDiscount, 16);
      expect(amounts.discountedTotal, 144);
      expect(row['tax_amount'], '18.78');
      expect(row['discounted_base_amount'], '125.22');
    }
  });

  test('sale units print their original and discounted rates in the same unit',
      () {
    final row = PrintService.savedOrderReceiptItem(LocalCartItem(
      product: _item().product,
      price: 8,
      mrp: 12,
      quantity: 24,
      taxRate: 15,
      standardUnitPrice: 10,
      isManualPriceOverride: true,
      saleUnitId: 3,
      saleUnitName: 'CASE',
      saleUnitConversionRate: 12,
    ));
    expect(row['quantity'], '2');
    expect(row['unitPrice'], '96.0');
    expect(row['standard_unit_price'], '120.0');
    expect(ReceiptLineDiscount.fromItem(row).itemDiscount, 48);
    expect(ReceiptLineDiscount.fromItem(row).originalRate, 120);
  });

  test('mixed VAT and penny remainders match backend submission order', () {
    final lines = CartDiscountBreakdown.calculate([
      (total: 115.0, taxRate: 15.0),
      (total: 100.0, taxRate: 0.0),
    ], 21.5);
    expect(lines.map((l) => l.discount), [11.5, 10]);
    expect(lines.map((l) => l.tax), [13.5, 0]);
    final tiny = CartDiscountBreakdown.calculate([
      (total: 0.05, taxRate: 15.0),
      (total: 0.05, taxRate: 15.0),
      (total: 0.05, taxRate: 15.0),
    ], 0.01);
    expect(tiny.map((l) => l.total), [0.05, 0.05, 0.04]);
    expect(
        CartDiscountBreakdown.calculate([
          (total: 115.0, taxRate: 15.0),
        ], 115)
            .single
            .tax,
        0);
  });

  test('split batches retain each rounded line price reduction', () {
    final item = _item(price: 9.315);
    item.standardUnitPrice = 10;
    item.stockReservations = [
      StockReservation(stockId: 1, quantity: 1),
      StockReservation(stockId: 2, quantity: 1),
    ];
    final row = PrintService.savedOrderReceiptItems([item], 0).single;
    expect(row['totalPrice'], '18.64');
    expect(ReceiptLineDiscount.fromItem(row).itemDiscount, 1.36);
  });

  test('saved receipt order keeps the rounding remainder on the last row', () {
    final rows = PrintService.savedOrderReceiptItems([
      _item(price: 0.05, quantity: 1),
      _item(price: 0.05, quantity: 1),
      _item(price: 0.05, quantity: 1),
    ], 0.01);
    expect(rows.map((r) => r['discounted_total']), ['0.05', '0.05', '0.04']);
    expect(rows.map((r) => r['line_discount']), ['0.00', '0.00', '0.01']);
  });

  test('completed sale sends printed tax, round-off and payable snapshot', () {
    final payload = OrderSubmissionPayload(
      items: LocalProductProvider.buildOrderItemsPayloadFrom([_item()]),
      transactionNumber: '',
      storeId: 2,
      clientSaleId: 'sale-id',
      receiptNumber: 'receipt',
      issuedAt: '2026-10-09T00:00:00Z',
      posDeviceId: 'device',
      discountAmount: 16,
      deliveryCharge: 5,
      grandTotal: 149,
      roundOff: 0,
    );
    final body = payload.toApiJson();
    expect(body['tax_total'], 18.78);
    expect(body['grand_total'], 149);
    expect(body['round_off'], 0);
    expect(body['discount_amount'], 16,
        reason: 'the item discount is already included in line prices');
  });

  test('discounted historical VAT does not invent a gross ex-tax rate', () {
    final row = {
      'quantity': 1,
      'unit_price': '3',
      'total_price': '3',
      'line_discount': '2.73',
      'discounted_total': '0.27',
      'discounted_base_amount': '0.25',
      'tax_amount': '0.02',
    };
    expect(ReceiptLineDiscount.fromItem(row).formattedRateExcTax, '-');
    row['tax_rate'] = '15';
    expect(ReceiptLineDiscount.fromItem(row).formattedRateExcTax, '2.61');
  });

  testWidgets('discount column reaches every production PDF and thermal layout',
      (tester) async {
    const export = bool.fromEnvironment('EXPORT_DISCOUNT_RECEIPTS');
    final root = export
        ? Directory('artifacts/discount-receipts').absolute
        : Directory.systemTemp.createTempSync('receipt-discounts-');
    root.createSync(recursive: true);
    final originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    addTearDown(() async {
      PathProviderPlatform.instance = originalPaths;
      ArabicPrinterHelper.debugRenderedRowsObserver = null;
      if (!export) root.deleteSync(recursive: true);
    });
    SharedPreferences.setMockInitialValues({});
    final font = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await tester.runAsync(() => font.load());
    late BuildContext context;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _OfflineSettings()),
          ChangeNotifierProvider<PaymentGatewaysProvider>(
              create: (_) => PaymentGatewaysProvider()),
        ],
        child: MaterialApp(home: Builder(builder: (c) {
          context = c;
          return const Scaffold(body: SizedBox());
        }))));
    final futureOrder = OrderDetailsModel.fromJson(jsonDecode(
        File('docs/api/receipt-discount-order-response.example.json')
            .readAsStringSync()));
    final futureConfig = DocumentConfigurationsModel.fromJson(jsonDecode(
            File('docs/api/receipt-discount-document-config.example.json')
                .readAsStringSync()))
        .documentConfigurations!['Bill A4']!;
    ReceiptLayoutParams params(String theme, String language, String paper,
            {bool future = false}) =>
        ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: future
              ? futureOrder.data!.cart!.cartItems!
              : PrintService.savedOrderReceiptItems([_item()], 16),
          formattedTotal: future ? '184.50' : '149.00',
          discountAmount: future ? '20.50' : '16.00',
          savedTotal: '96',
          orderDate: '2026-10-09T00:00:00Z',
          orderNumber: 'DISCOUNT-QA',
          isFromLocalStorage: !future,
          selectedPaperSize: paper,
          customerCareNumber: '',
          customerCareEmail: '',
          netExcTax: future ? '160.44' : '130.22',
          apiTotalTax: future ? 24.06 : 18.78,
          billDocumentConfig: DocumentConfig(
              activeTheme: theme,
              language: language,
              showLogo: 0,
              displayConfiguration: future
                  ? futureConfig.displayConfiguration
                  : DisplayConfiguration(options: {
                      for (final key in [
                        'showParticulars',
                        'showQty',
                        'showRate',
                        'showTotal',
                        'showDiscount',
                        'showTax',
                        'showNetAmount',
                        'showSubTotal'
                      ])
                        key: DisplayOption(visible: true),
                    })),
        );
    final english = params('classic', 'en', 'A4');
    expect(english.itemLines.single.nameLines, ['Discounted product']);
    expect(english.itemLines.single.discount, '56.00');
    expect(english.itemColumns.map((column) => column.key),
        contains('showItemDiscount'));
    expect(english.mrpTotalValue, 240);
    expect(english.netAmountValue, 149);
    expect(english.discountAmountValue, 16);
    expect(english.totalTax, 18.78);
    expect(english.subtotalExcTax, closeTo(146.22, 0.001));
    expect(
        english.subtotalExcTax - english.discountAmountValue + english.totalTax,
        closeTo(english.netAmountValue, 0.001));
    expect(english.itemLines.single.rateExcTax, '86.96');
    expect(english.itemLines.single.rate, '100.00');
    expect(english.itemLines.single.total, '144.00');
    final ar = params('classic', 'ar', 'A4');
    expect(
        ar.itemColumns
            .firstWhere((column) => column.key == 'showItemDiscount')
            .label
            .arabic,
        'الخصم');
    await tester.runAsync(() async {
      for (final theme in StandardPdfLayoutFactory.availableThemes) {
        for (final language in ['en', 'ar', 'en_ar']) {
          for (final paper in ['A4', 'A5']) {
            final pdf = await StandardPdfLayoutFactory.getLayout(theme)
                .buildPdfDocument(params(theme, language, paper, future: true));
            final bytes = await pdf.save();
            expect(bytes.length, greaterThan(1000));
            if (export) {
              final file = File(
                  'artifacts/discount-receipts/future-$theme-$language-$paper.pdf');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes);
            }
          }
        }
      }
      if (export) {
        final sampleItems = <Map<String, dynamic>>[
          for (final row in [
            ('5 STAR', 'خمس نجوم', '5', '3', '2.73', '0.27', '0.02', 'PC'),
            ('5 STAR', 'خمس نجوم', '5', '4', '3.64', '0.36', '0.03', 'PC'),
            (
              '7DAYS CAKE BAR VANILLA 25G',
              '7 دايز بار كيك فانيليا 25جم',
              '1',
              '12',
              '10.91',
              '1.09',
              '0.17',
              'DZ'
            ),
            (
              '7DAYS JOMBO HAZELNUTWITH COCOA FILLING 100G',
              '7 دايز جمبو بندق مع حشوة كاكاو 100جم',
              '3',
              '3',
              '2.72',
              '0.28',
              '0.02',
              'PC'
            ),
          ])
            {
              'product_name': row.$1,
              'product_names': {'en': row.$1, 'ar': row.$2},
              'mrp': row.$3,
              'quantity': '1',
              'unit_price': row.$4,
              'standard_unit_price': row.$4,
              'total_price': row.$4,
              'line_discount': row.$5,
              'discounted_total': row.$6,
              'tax_amount': row.$7,
              'product_unit': row.$8,
            },
        ];
        final sampleConfig = DocumentConfig.fromJson({
          'type': 'Bill A4',
          'language': 'en_ar',
          'display_configuration': {
            for (final entry in {
              'showSLNumber': ('SL', '#'),
              'showParticulars': ('Item', 'تفاصيل'),
              'showMRP': ('MRP', 'سعر التجزئة'),
              'showQty': ('Qty', 'الكمية'),
              'showRate': ('Rate', 'السعر'),
              'showRateExcTax': ('Rate Ex Tax', 'السعر بدون ضريبة'),
              'showUnit': ('Unit', 'الوحدة'),
              'showTaxHeader': ('Tax', 'الضريبة'),
              'showItemDiscount': ('Discount', 'الخصم'),
              'showTotal': ('Total', 'الإجمالي'),
              'showSubTotal': ('Subtotal', 'المجموع الفرعي'),
              'showDiscount': ('Order discount', 'خصم الطلب'),
              'showTax': ('VAT', 'الضريبة'),
              'showNetAmount': ('Payable', 'المبلغ المستحق'),
            }.entries)
              entry.key: {
                'visible': true,
                'default': entry.value.$1,
                'value': entry.value.$2,
              },
          },
        });
        final sample = ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: sampleItems,
          formattedTotal: '2.00',
          discountAmount: '20.00',
          orderDate: '2026-10-09',
          orderNumber: '2.00 SAMPLE',
          isFromLocalStorage: false,
          selectedPaperSize: 'A4',
          billDocumentConfig: sampleConfig,
          customerCareNumber: '',
          customerCareEmail: '',
        );
        expect(sample.itemLines.map((line) => line.discount),
            ['2.73', '3.64', '10.91', '2.72']);
        expect(sample.itemLines.map((line) => line.total),
            ['0.27', '0.36', '1.09', '0.28']);
        expect(sample.discountAmountValue, 20);
        expect(sample.netAmountValue, 2);
        final pdf = await StandardPdfLayoutFactory.getLayout(
                'bilingual_centered_tax_invoice')
            .buildPdfDocument(sample);
        final file = File('output/pdf/discount-column-2-sample.pdf');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(await pdf.save());

        final offerRows = PrintService.savedOrderReceiptItems([
          LocalCartItem(
            product: GetProduct(
              productId: 38898,
              productName: 'testdiscountstore',
              unit: 'PACK',
              mrp: '25',
              price: ProductPrice(price: '20'),
            ),
            quantity: 1,
            price: 17,
            mrp: 25,
            standardUnitPrice: 20,
            taxRate: 18,
            offerId: 28,
            offerVersion: 2,
          ),
        ], 0);
        final offerSample = ReceiptLayoutParams(
          context: context,
          selectedPrinter: BluetoothPrinter.development(),
          cartItems: offerRows,
          formattedTotal: '17.00',
          discountAmount: '0.00',
          orderDate: '2026-10-10',
          orderNumber: 'OFFER 28 SAMPLE',
          isFromLocalStorage: true,
          selectedPaperSize: 'A4',
          billDocumentConfig: sampleConfig,
          customerCareNumber: '',
          customerCareEmail: '',
        );
        expect(offerSample.itemLines.single.rate, '20.00');
        expect(offerSample.itemLines.single.discount, '3.00');
        expect(offerSample.itemLines.single.total, '17.00');
        final offerPdf = await StandardPdfLayoutFactory.getLayout(
                'bilingual_centered_tax_invoice')
            .buildPdfDocument(offerSample);
        await File('output/pdf/offer-28-rate-discount-sample.pdf')
            .writeAsBytes(await offerPdf.save());
      }
      for (final theme in ['standard', 'premium', 'premium2_bilingual']) {
        for (final paper in ['58mm', '80mm']) {
          final columns = <List<ReceiptTableColumn>>[];
          final texts = <String>[];
          ArabicPrinterHelper.debugRenderedRowsObserver = (rows, _, __, ___) {
            texts.addAll(rows.whereType<TextRow>().map((row) => row.text));
            for (final row in rows) {
              try {
                final value = (row as dynamic).columns;
                if (value is List<ReceiptTableColumn>) columns.add(value);
              } catch (_) {}
            }
          };
          await ReceiptLayoutFactory.getLayout(theme)
              .printThermal(params(theme, 'en_ar', paper, future: true));
          final header = columns.firstWhere(
              (row) => row.any((column) => column.text.contains('Discount')));
          final discountIndex =
              header.indexWhere((column) => column.text.contains('Discount'));
          final prices = columns
              .where((row) =>
                  row.length == header.length &&
                  row[discountIndex].text == '56.00')
              .toList();
          expect(prices, hasLength(1), reason: '$theme $paper');
          final rateIndex = header.indexWhere((column) =>
              column.text.contains('Rate') && !column.text.contains('Tax'));
          final totalIndex =
              header.indexWhere((column) => column.text.contains('Total'));
          expect(prices.single[rateIndex].text, '100.00',
              reason: '$theme $paper original rate');
          expect(prices.single[totalIndex].text, '144.00',
              reason: '$theme $paper final total');
          expect(
              prices.single[discountIndex].weight, header[discountIndex].weight,
              reason: '$theme $paper');
          expect(
              columns.any((row) =>
                  row.length == header.length &&
                  row[discountIndex].text == '9.50'),
              isTrue,
              reason: '$theme $paper');
          expect(texts.join(' '), isNot(contains('Summer offer')));
          expect(texts.join(' '), isNot(contains('SAVE10')));
          expect(texts.join(' '), isNot(contains('After order discount')));
          ArabicPrinterHelper.debugRenderedRowsObserver = null;
        }
      }
    });
    await tester.pump(const Duration(seconds: 5));
  });
}
