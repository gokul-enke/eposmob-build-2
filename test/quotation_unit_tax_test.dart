import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/common/layout_rows.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_factory.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';
import 'package:pos_machine/screens/sales/widgets/build_quotation_details_widget.dart';
import 'package:pos_machine/services/quotation_print_service.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings extends AppSettingsProvider {
  final _settings = AppSettings.fromJson({
    'data': [
      {'code': 'CURRENCY', 'value': 'SAR', 'status': true},
    ],
  });

  @override
  AppSettings? get appSettings => _settings;

  @override
  Future<void> fetchAppSettings() async {}
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

class _Configs extends DocumentConfigProvider {
  _Configs(this.mode);
  String? mode;

  @override
  Future<void> initHive() async {}

  @override
  DocumentConfig? getDocumentConfig(String type) => type == 'Quotation'
      ? DocumentConfig.fromJson({
          'type': type,
          if (mode != null) 'item_tax_display_mode': mode,
        })
      : null;

  void changeMode(String value) {
    mode = value;
    notifyListeners();
  }
}

QuotationDetailsData _quotation({
  String unitTax = '5.00',
  String? apiTax = '50.00',
}) =>
    QuotationDetailsData.fromJson({
      'id': 1,
      'quotation_number': 'QT-UNIT-TAX',
      'quotation_date': '2026-10-11',
      'sub_total': '1000.00',
      'tax': apiTax,
      'grand_total': '1050.00',
      'items': [
        {
          'product_name': 'Unit tax product',
          'quantity': 10,
          'unit_price': '105.00',
          'tax_rate': 5,
          'tax_amount_unit': unitTax,
          'tax_amount': '50.00',
          'total_price': '1050.00',
        },
      ],
    });

Map<String, dynamic> _payload({
  String unitTax = '5.00',
  String? apiTax = '50.00',
}) =>
    const QuotationPrintService().buildPrintPayload(
      _quotation(unitTax: unitTax, apiTax: apiTax),
    );

Widget _host(Widget child, {String? taxMode = 'unit'}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsProvider>(create: (_) => _Settings()),
        ChangeNotifierProvider<PaymentGatewaysProvider>(
          create: (_) => PaymentGatewaysProvider(),
        ),
        ChangeNotifierProvider<DocumentConfigProvider>(
          create: (_) => _Configs(taxMode),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

ReceiptLayoutParams _params(
  BuildContext context, {
  String unitTax = '5.00',
  String? apiTax = '50.00',
  String theme = 'classic',
  String paper = 'A4',
  bool includeSubtotal = true,
  bool includeApiSubtotal = true,
  QuotationDetailsData? quotation,
  String? taxMode = 'unit',
  String documentType = 'Quotation',
  List<dynamic>? printItems,
  bool isFromLocalStorage = true,
}) {
  final payload = quotation == null
      ? _payload(unitTax: unitTax, apiTax: apiTax)
      : const QuotationPrintService().buildPrintPayload(quotation);
  return ReceiptLayoutParams(
    context: context,
    selectedPrinter: BluetoothPrinter.development(),
    cartItems: printItems ?? payload['cartItems'] as List<dynamic>,
    formattedTotal: payload['formattedTotal'] as String,
    discountAmount: payload['discountAmount'] as String?,
    orderDate: payload['orderDate'] as String,
    orderNumber: payload['orderNumber'] as String,
    isFromLocalStorage: isFromLocalStorage,
    selectedPaperSize: paper,
    customerCareNumber: '',
    customerCareEmail: '',
    netExcTax: includeApiSubtotal ? payload['netExcTax'] as String? : null,
    apiTotalTax: payload['apiTotalTax'] as double?,
    billDocumentConfig: DocumentConfig(
      type: documentType,
      itemTaxDisplayMode: ItemTaxDisplayMode.parse(taxMode),
      activeTheme: theme,
      language: 'en',
      showLogo: 0,
      displayConfiguration: DisplayConfiguration(options: {
        for (final key in [
          'showParticulars',
          'showQty',
          'showRate',
          'showRateExcTax',
          'showTaxHeader',
          'showTotal',
          if (includeSubtotal) 'showSubTotal',
          'showTax',
          'showNetAmount',
        ])
          key: DisplayOption(visible: true),
      }),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('quotation unit tax parses independently of full row tax', () {
    for (final value in <dynamic>[5, '5.000', 0, '0.000']) {
      final item = QuotationItem.fromJson({
        'quantity': 10,
        'tax_amount_unit': value,
        'tax_amount': '50.00',
      });
      expect(item.taxAmountUnit, value.toString());
      expect(item.taxAmount, '50.00');
    }
  });

  test('print payload retains full row tax when unit tax is zero or missing',
      () {
    for (final unitTax in ['5.00', '0.000']) {
      final item = (_payload(unitTax: unitTax)['cartItems'] as List).single;
      expect(item['tax_amount_unit'], unitTax);
      expect(item['tax_amount'], '50.00');
      expect(item['taxAmount'], '50.00');
      expect(item['quantity'], '10');
      expect(item['total_price'], '1050.00');
    }
    final payload = const QuotationPrintService().buildPrintPayload(
      QuotationDetailsData(items: [
        QuotationItem(quantity: '10', taxAmount: '50.00'),
      ]),
    );
    final item = (payload['cartItems'] as List).single;
    expect(item['tax_amount_unit'], isNull);
    expect(item['tax_amount'], '50.00');
  });

  test('print payload accepts the API tax total, including numeric zero', () {
    for (final value in <dynamic>[48.5, '48.50', 0, '0.00']) {
      final payload = const QuotationPrintService().buildPrintPayload(
        QuotationDetailsData.fromJson({'tax': value}),
      );
      expect(payload['apiTotalTax'], double.parse(value.toString()));
    }
    for (final value in [null, '', 'invalid', 'NaN', 'Infinity']) {
      expect(_payload(apiTax: value)['apiTotalTax'], isNull);
    }
  });

  for (final width in [390.0, 1200.0]) {
    for (final mode in ['unit', 'row_total', null, 'invalid']) {
      testWidgets('details respect $mode tax mode at width $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_host(
            SingleChildScrollView(
              child: QuotationDetailWidget(data: _quotation()),
            ),
            taxMode: mode));
        expect(find.text('SAR 5.00'),
            mode == 'unit' ? findsOneWidget : findsNothing);
        expect(find.text('SAR 50.00'),
            mode == 'unit' ? findsOneWidget : findsNWidgets(2));
        expect(find.text('SAR 1050.00'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('details react to a refreshed quotation tax mode',
      (tester) async {
    await tester.pumpWidget(_host(
        SingleChildScrollView(
          child: QuotationDetailWidget(data: _quotation()),
        ),
        taxMode: null));
    expect(find.text('SAR 50.00'), findsNWidgets(2));
    final configs = tester
        .element(find.byType(QuotationDetailWidget))
        .read<DocumentConfigProvider>() as _Configs;
    configs.changeMode('unit');
    await tester.pump();
    expect(find.text('SAR 5.00'), findsOneWidget);
    expect(find.text('SAR 50.00'), findsOneWidget);
  });

  testWidgets('unit tax cannot change PDF totals, subtotal or ex-tax rate',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(_host(Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    for (final unitTax in ['5.00', '0.000', '4.762', '999.00']) {
      final params =
          _params(context, unitTax: unitTax, includeApiSubtotal: false);
      final line = params.itemLines.single;
      expect(line.valueFor('showTaxHeader'),
          double.parse(unitTax).toStringAsFixed(2));
      expect(line.tax, '50.00');
      expect(line.rateExcTax, '100.00');
      expect(line.total, '1050.00');
      expect(params.totalTax, 50);
      expect(params.subtotalExcTax, 1000);
      expect(params.netAmountValue, 1050);
      expect(
          params.totalsRows.singleWhere((r) => r.key == 'showTax').amount, 50);
    }

    final params = _params(context, apiTax: null, includeApiSubtotal: false);
    params.cartItems.add({
      'productName': 'Second product',
      'quantity': '3',
      'unitPrice': '42',
      'totalPrice': '126',
      'tax_amount': '6',
      'tax_amount_unit': '2',
    });
    expect(params.itemLines.map((line) => line.valueFor('showTaxHeader')),
        ['5.00', '2.00']);
    expect(params.totalTax, 56, reason: 'Sum full row taxes, not unit taxes');
    expect(params.subtotalExcTax, 1120);

    final original = Map<String, dynamic>.from(params.cartItems.first as Map)
      ..remove('tax_amount_unit');
    expect(params.itemLine(original, 1).valueFor('showTaxHeader'), '5.00',
        reason:
            'Unit mode derives display tax for older rows without unit tax');
  });

  testWidgets('API quotation tax wins over row sums and falls back if missing',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(_host(Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    for (final value in [
      '48.50',
      '0.00',
      null,
      '',
      'invalid',
      'NaN',
      'Infinity'
    ]) {
      for (final mode in ['unit', 'row_total', null]) {
        final params = _params(context, apiTax: value, taxMode: mode);
        final expected = value == '48.50'
            ? 48.5
            : value == '0.00'
                ? 0.0
                : 50.0;
        expect(params.totalTax, expected);
        expect(params.totalsRows.singleWhere((r) => r.key == 'showTax').amount,
            expected);
        expect(params.itemLines.single.valueFor('showTaxHeader'),
            mode == 'unit' ? '5.00' : '50.00');
        expect(params.itemLines.single.tax, '50.00');
        expect(params.itemLines.single.rateExcTax, '100.00');
        expect(params.netAmountValue, 1050);
      }
    }
  });

  testWidgets(
      'unit display leaves discounted billing receipt accounting intact',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(_host(Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    final item = LocalCartItem(
      product: GetProduct(
        productId: 1,
        productName: 'Discounted product',
        unit: 'PC',
        price: ProductPrice(price: '100'),
        taxes: const [],
        stock: const [],
      ),
      price: 80,
      quantity: 2,
      taxRate: 15,
      standardUnitPrice: 100,
      isManualPriceOverride: true,
    );
    final rows = PrintService.savedOrderReceiptItems([item], 16);
    final quotation = QuotationDetailsData(
      subTotal: '125.22',
      discount: '16',
      grandTotal: '144',
    );
    ReceiptLayoutParams paramsFor(String? mode) => _params(context,
        quotation: quotation,
        taxMode: mode,
        documentType: 'Bill',
        printItems: rows);
    final baseline = paramsFor(null);
    final original = baseline.itemLines.single;
    for (final mode in ['unit', 'row_total']) {
      final params = paramsFor(mode);
      final line = params.itemLines.single;
      expect(line.valueFor('showTaxHeader'), mode == 'unit' ? '9.39' : '18.78');
      expect(line.tax, '18.78');
      expect([
        line.rate,
        line.rateExcTax,
        line.discount,
        line.total
      ], [
        original.rate,
        original.rateExcTax,
        original.discount,
        original.total
      ]);
      expect(params.totalTax, 18.78);
      expect(params.subtotalExcTax, baseline.subtotalExcTax);
      expect(params.netAmountValue, 144);
      expect({for (final row in params.totalsRows) row.key: row.amount},
          {for (final row in baseline.totalsRows) row.key: row.amount});
    }
    expect(rows.single['tax_amount'], '18.78');
  });

  testWidgets('quotation and sales PDFs and thermal prints respect tax mode',
      (tester) async {
    const export = bool.fromEnvironment('EXPORT_QUOTATION_TAX');
    final root = export
        ? Directory('build/item_tax_display').absolute
        : Directory.systemTemp.createTempSync('quotation-unit-tax-');
    root.createSync(recursive: true);
    final oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    addTearDown(() {
      PathProviderPlatform.instance = oldPaths;
      ArabicPrinterHelper.debugRenderedRowsObserver = null;
      if (!export) root.deleteSync(recursive: true);
    });
    final font = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    await tester.runAsync(() => font.load());
    late BuildContext context;
    await tester.pumpWidget(_host(Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    // The backend total deliberately differs from the row-tax sum to prove
    // every renderer uses the supplied final tax rather than recalculating it.
    final quotation = QuotationDetailsData(
      quotationNumber: 'QT-UNIT-TAX',
      quotationDate: '2026-10-11',
      subTotal: '1001.50',
      tax: '48.50',
      grandTotal: '1050.00',
      items: _quotation().items,
    );
    final salesApiItems = [
      OrderDetailsModelDataCartItem.fromJson({
        'product_name': 'Unit tax product',
        'quantity': 10,
        'unit_price': '105.00',
        'tax_rate': '5',
        'tax_amount': '50.00',
        // Deliberately differs from row tax / quantity to prove API precedence.
        'tax_amount_unit': '4.75',
        'total_price': '1050.00',
      })
    ];
    final localItem = LocalCartItem(
      product: GetProduct(
        productId: 1,
        productName: 'Unit tax product',
        unit: 'PC',
        price: ProductPrice(price: '105'),
        taxes: const [],
        stock: const [],
      ),
      price: 105,
      quantity: 10,
      taxRate: 5,
    );
    final salesLocalItems = PrintService.savedOrderReceiptItems([localItem], 0);
    expect(salesLocalItems.single['tax_amount'], '50.00');
    await tester.runAsync(() async {
      for (final source in ['quotation', 'sales_api', 'sales_local']) {
        for (final mode in ['unit', 'row_total', null]) {
          final label = '$source-${mode ?? 'missing'}';
          final expectedRowTax = mode == 'unit'
              ? source == 'sales_api'
                  ? '4.75'
                  : '5.00'
              : '50.00';
          final expectedTotalTax = source == 'sales_local' ? 50.0 : 48.5;
          final sourceQuotation = source == 'sales_local'
              ? QuotationDetailsData(
                  quotationNumber: 'LOCAL-TAX',
                  quotationDate: '2026-10-11',
                  subTotal: '1000.00',
                  grandTotal: '1050.00',
                )
              : quotation;
          ReceiptLayoutParams paramsFor(String theme, String paper,
                  {bool subtotal = true}) =>
              _params(
                context,
                theme: theme,
                paper: paper,
                quotation: sourceQuotation,
                taxMode: mode,
                documentType: source == 'quotation' ? 'Quotation' : 'Bill',
                printItems: source == 'sales_api'
                    ? salesApiItems
                    : source == 'sales_local'
                        ? salesLocalItems
                        : null,
                isFromLocalStorage: source != 'sales_api',
                includeSubtotal: subtotal,
              );
          for (final theme in StandardPdfLayoutFactory.availableThemes) {
            for (final paper in ['A4', 'A5']) {
              final params = paramsFor(theme, paper);
              expect(params.itemLines.single.valueFor('showTaxHeader'),
                  expectedRowTax);
              expect(params.itemLines.single.tax, '50.00');
              expect(params.itemLines.single.rateExcTax, '100.00');
              expect(params.totalTax, expectedTotalTax);
              expect(params.subtotalExcTax, 1050 - expectedTotalTax);
              final pdf = await StandardPdfLayoutFactory.getLayout(theme)
                  .buildPdfDocument(params);
              final bytes = await pdf.save();
              expect(bytes.length, greaterThan(1000));
              if (export) {
                await File('${root.path}/$label-$theme-$paper.pdf')
                    .writeAsBytes(bytes);
              }
            }
          }
          for (final theme in [
            'classic',
            'standard',
            'premium',
            'premium2_bilingual',
          ]) {
            for (final paper in ['58mm', '80mm']) {
              final columns = <List<ReceiptTableColumn>>[];
              ArabicPrinterHelper.debugRenderedRowsObserver =
                  (rows, _, __, ___) {
                for (final row in rows) {
                  if (row is ReceiptTableRow) columns.add(row.columns);
                  if (row is MultiLineReceiptTableRow) columns.add(row.columns);
                }
              };
              final params = paramsFor(theme, paper, subtotal: false);
              await ReceiptLayoutFactory.getLayout(theme).printThermal(params);
              final header = columns.firstWhere(
                  (row) => row.any((column) => column.text == 'Tax'));
              final taxIndex =
                  header.indexWhere((column) => column.text == 'Tax');
              expect(
                columns.any((row) =>
                    row.length == header.length &&
                    row[taxIndex].text == expectedRowTax),
                isTrue,
                reason: '$label $theme $paper must display $expectedRowTax',
              );
              expect(params.totalTax, expectedTotalTax);
              ArabicPrinterHelper.debugRenderedRowsObserver = null;
            }
          }
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
