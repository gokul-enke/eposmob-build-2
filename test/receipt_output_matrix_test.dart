import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/bank.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/providers/bank_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/screens/print/return_bill_layout_params_builder.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_factory.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Settings extends AppSettingsProvider {
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

class _Paths extends PathProviderPlatform {
  final String root;
  _Paths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => '$root/temp';
}

/// Explicit opt-in: exercises the production raster printer and PDF builders,
/// saving reviewable artifacts rather than treating parameter checks as prints.
/// flutter test test/receipt_output_matrix_test.dart --dart-define=RECEIPT_OUTPUT_MATRIX=true
void main() {
  const enabled = bool.fromEnvironment('RECEIPT_OUTPUT_MATRIX');
  const snapshotPath = String.fromEnvironment('RECEIPT_CONFIG_SNAPSHOT');
  const emptyCustomerName = bool.fromEnvironment('RECEIPT_CUSTOMER_NAME_EMPTY');
  const documentFilter = String.fromEnvironment('RECEIPT_DOCUMENT_FILTER');
  const thermalPaper = String.fromEnvironment('RECEIPT_THERMAL_PAPER', defaultValue: '80mm');
  const pdfPaper = String.fromEnvironment('RECEIPT_PDF_PAPER', defaultValue: 'A4');
  const returnBuilder = bool.fromEnvironment('RECEIPT_RETURN_BUILDER');
  const finalVisibility = int.fromEnvironment('RECEIPT_FINAL_VISIBILITY', defaultValue: -1);
  const totalCase = String.fromEnvironment('RECEIPT_RETURN_TOTAL_CASE');
  const scenarioFilter = String.fromEnvironment('RECEIPT_SCENARIO');
  const hideReturnNames = bool.fromEnvironment('RECEIPT_HIDE_RETURN_NAMES');
  testWidgets('render every registered theme in all five language scenarios',
      (tester) async {
    expect(['58mm', '80mm'], contains(thermalPaper));
    expect(['A4', 'A5'], contains(pdfPaper));
    if (returnBuilder) expect(documentFilter, 'Return Bill');
    expect(finalVisibility >= -1 && finalVisibility <= 15, isTrue);
    if (finalVisibility >= 0) expect(snapshotPath, isEmpty);
    expect(['', 'missing', 'comma', 'zero'], contains(totalCase));
    expect(['', 'en', 'ar', 'both', 'empty_en', 'table_en'], contains(scenarioFilter));
    final paperSuffix = thermalPaper == '80mm' && pdfPaper == 'A4'
        ? '' : '_${thermalPaper}_$pdfPaper';
    final snapshot = snapshotPath.isEmpty
        ? null
        : (jsonDecode(File(snapshotPath).readAsStringSync())
                as Map<String, dynamic>)['document_configurations']
            as Map<String, dynamic>;
    final outputRoot = snapshot == null
            ? 'build/receipt_output_matrix_full${hideReturnNames ? '_hidden_return_names' : ''}'
            : 'build/receipt_live_render_${File(snapshotPath).uri.pathSegments.last.replaceAll('.json', '')}${emptyCustomerName ? '_no_customer_name' : ''}';
    final root = Directory('$outputRoot$paperSuffix${returnBuilder ? '_builder' : ''}${finalVisibility < 0 ? '' : '_final_$finalVisibility'}${totalCase.isEmpty ? '' : '_total_$totalCase'}${scenarioFilter.isEmpty ? '' : '_lang_$scenarioFilter'}${documentFilter.isEmpty ? '' : '_only_${documentFilter.replaceAll(' ', '-')}'}')
        .absolute;
    root.createSync(recursive: true);
    final originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    addTearDown(() => PathProviderPlatform.instance = originalPaths);
    SharedPreferences.setMockInitialValues({});
    for (final family in ['NotoSansArabic', 'Poppins']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'));
      await loader.load();
    }
    late BuildContext context;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsProvider>(create: (_) => _Settings()),
        ChangeNotifierProvider<PaymentGatewaysProvider>(
            create: (_) => PaymentGatewaysProvider()),
        ChangeNotifierProvider<BankProvider>(create: (_) => BankProvider()),
        ChangeNotifierProvider<StoreSessionProvider>(create: (_) => StoreSessionProvider()),
      ],
      child: MaterialApp(home: Builder(builder: (value) {
        context = value;
        return const Scaffold(body: SizedBox.shrink());
      })),
    ));
    final manifest = <Map<String, dynamic>>[];
    const documentTypes = ['Bill', 'Bill A4', 'Sales and Return Bill',
      'Sales and Return Bill A4', 'Return Bill'];
    expect(documentFilter.isEmpty || documentTypes.contains(documentFilter), isTrue);
    final scenarios = snapshot == null
        ? (scenarioFilter.isEmpty ? ['en', 'ar', 'both', 'empty_en', 'table_en'] : [scenarioFilter])
        : ['live'];
    for (final scenario in scenarios) {
      for (final documentType in [
        'Bill',
        'Bill A4',
        'Sales and Return Bill',
        'Sales and Return Bill A4',
        'Return Bill'
      ]) {
        if (documentFilter.isNotEmpty && documentType != documentFilter) continue;
        for (final thermal in [false, true]) {
          if (documentType.endsWith('A4') && thermal) continue;
          if (!documentType.endsWith('A4') &&
              documentType != 'Return Bill' &&
              !thermal) continue;
          final themes = thermal
              ? ReceiptLayoutFactory.availableThemes
              : StandardPdfLayoutFactory.availableThemes;
          for (final theme in themes) {
            final fieldKeys = [
              ...ReceiptConfigurationContract.canonicalBillKeys,
              if (documentType.contains('Return')) ...[
                'showReturnSLNumber',
                'showReturnParticulars',
                'showReturnMRP',
                'showReturnQty',
                'showReturnRate',
                'showReturnTotal',
                'showReturnItemsCount',
                'showReturnTotalAmount',
                'showReturnNetAmount',
                'showReturnAmountInWords',
                'showFinalPurchase',
                'showFinalReturn',
                'showFinalNetAmount',
                'showFinalAmountInWords',
                'showGstSubtitle',
                'showAuthorizedSignatory',
                'showCustomerGstin',
                'showUnitPrice',
                if (documentType == 'Return Bill') ...[
                  'showOriginalInvoice',
                  'showInvoiceDate',
                  'showHsnCode',
                  'showTaxRateColumn',
                ],
              ],
            ];
            final id =
                '${documentType.replaceAll(' ', '-')}_${scenario}_${thermal ? 'thermal' : 'pdf'}_$theme';
            final options = <String, DisplayOption>{
              for (final key in fieldKeys)
                key: DisplayOption(
                  visible: true,
                  value: scenario == 'en'
                      ? 'EN${fieldKeys.indexOf(key) + 1}X'
                      : 'عربي ${fieldKeys.indexOf(key) + 1}',
                  defaultValue: scenario == 'en' ||
                          scenario == 'both' ||
                          (scenario == 'table_en' &&
                              (documentType == 'Return Bill' ? [
                                'showReturnSLNumber',
                                'showReturnParticulars',
                                'showReturnMRP',
                                'showReturnQty',
                                'showReturnRate',
                                'showReturnTotal',
                                'showUnitPrice',
                              ] : [
                                'showSLNumber',
                                'showParticulars',
                                'showQty',
                                'showRate',
                                'showUnit',
                                'showTaxHeader',
                                'showTotal'
                              ]).contains(key))
                      ? 'EN${fieldKeys.indexOf(key) + 1}X'
                      : '',
                ),
            };
            if (hideReturnNames) {
              expect(snapshotPath, isEmpty);
              final original = options['showReturnParticulars'];
              if (original != null) {
                options['showReturnParticulars'] = DisplayOption(
                    visible: false, value: original.value,
                    defaultValue: original.defaultValue);
              }
            }
            if (returnBuilder) {
              options['showInvoiceTitle'] = DisplayOption(
                  visible: true, value: '', defaultValue: '');
            }
            if (finalVisibility >= 0) {
              for (final entry in {
                'showFinalPurchase': 1,
                'showFinalReturn': 2,
                'showFinalNetAmount': 4,
                'showFinalAmountInWords': 8,
              }.entries) {
                final original = options[entry.key];
                options[entry.key] = DisplayOption(
                  visible: finalVisibility & entry.value != 0,
                  value: original?.value,
                  defaultValue: original?.defaultValue,
                );
              }
            }
            final fixture = ReceiptLayoutParams(
              context: context,
              selectedPrinter: BluetoothPrinter.development(),
              cartItems: documentType == 'Return Bill'
                  ? const []
                  : const [
                      {
                        'product_name': 'Coffee قهوة',
                        'quantity': 2,
                        'unit_price': '11.00',
                        'total_price': '22.00',
                        'mrp': '12.00',
                        'warranty_enabled': true,
                        'warranty_in_month': 12,
                        'tax_amount': '2.00',
                        'currency': 'SAR',
                        'product_unit': 'pcs',
                      },
                      {
                        'product_name': 'Tea شاي',
                        'quantity': 4,
                        'unit_price': '5.00',
                        'total_price': '20.00',
                        'mrp': '6.00',
                        'tax_amount': '2.00',
                        'currency': 'SAR',
                        'product_unit': 'pcs',
                      },
                    ],
              formattedTotal: documentType == 'Return Bill' ? '21.00' : '40.00',
              discountAmount: '2.00',
              savedTotal: '8.00',
              tokenNumber: '42',
              orderDate: '2026-09-26T10:00:00Z',
              // Identical data across themes makes pixel comparisons meaningful.
              orderNumber: 'QA-VERIFY',
              originalInvoiceNumber: documentType == 'Return Bill' ? 'SALE-789' : null,
              originalInvoiceDate: documentType == 'Return Bill' ? '2026-08-20' : null,
              isFromLocalStorage: false,
              selectedPaperSize: thermal ? thermalPaper : pdfPaper,
              billDocumentConfig: snapshot != null
                  ? DocumentConfig.fromJson({
                      ...snapshot[documentType] as Map<String, dynamic>,
                      'theme': theme,
                    })
                  : DocumentConfig(
                      type: documentType,
                      activeTheme: theme,
                      language: scenario == 'en' || scenario == 'ar'
                          ? scenario
                          : 'en_ar',
                      displayConfiguration:
                          DisplayConfiguration(options: options),
                    ),
              customerCareNumber: '123',
              customerCareEmail: 'qa@example.test',
              storeName: 'QA Store',
              storeLocation: 'QA Address',
              storePhone: '555',
              storeEmail: 'store@example.test',
              customerName: emptyCustomerName ? '' : 'QA Customer',
              customerPhone: '1234567890',
              customerAddress: 'Customer Address',
              paidAmount: 15,
              customerOldBalance: 100,
              customerCurrentBalance: 125,
              customerVatNumber: '300000000000003',
              customerCrNumber: '1010000000',
              customerType: 'B2B',
              orderComment: 'Handle with care',
              deliveryMethod: 'Home Delivery',
              deliveryPhone: '9876543210',
              paymentBreakdown: const {'CASH': 10.0, 'CARD': 5.0},
              zatcaVatNumber: '300000000000003',
              zatcaCrNumber: '1010000001',
              zatcaCompanyName: 'QA Store',
              bankDetails: const [
                StoreBank(bankName: 'QA Bank', bankAccounts: [
                  StoreBankAccount(
                      accountHolderName: 'QA Account',
                      accountNumber: '123456789',
                      iban: 'SA0380000000608010167519',
                      swiftCode: 'TESTSARI')
                ])
              ],
              isReturnOnly: documentType == 'Return Bill',
              orderReturns: documentType.contains('Return')
                  ? OrderReturns(
                      returnTotalAmount: totalCase == 'missing' ? null
                          : totalCase == 'comma' ? '0,021.00'
                          : totalCase == 'zero' ? '0.00' : '21.00',
                      returnItems: [
                        OrderReturnItem(
                            productName: 'Coffee قهوة',
                            variantAttributes: const {'Size': 'Large'},
                            hsnCode: '090121', taxRate: '18',
                            quantity: 1,
                            unitPrice: '11.00',
                            mrp: '12.00',
                            reason: 'Damaged'),
                        OrderReturnItem(
                            productName: 'Tea شاي',
                            variantAttributes: const {'Size': 'Small'},
                            hsnCode: '090240', taxRate: '0',
                            quantity: 2,
                            unitPrice: '5.00',
                            mrp: '6.00',
                            reason: 'Unneeded'),
                      ],
                    )
                  : null,
              paymentMethod: 'CASH',
              apiTotalTax: documentType == 'Return Bill' ? 0 : 4,
            );
            final params = returnBuilder
                ? await ReturnBillLayoutParamsBuilder.build(
                    context: context,
                    selectedPrinter: fixture.selectedPrinter,
                    returnItems: fixture.orderReturns!.returnItems!,
                    returnTotalAmount: fixture.orderReturns!.returnTotalAmount ?? fixture.formattedTotal,
                    orderDate: fixture.orderDate,
                    orderNumber: fixture.orderNumber,
                    originalInvoiceNumber: fixture.originalInvoiceNumber,
                    originalInvoiceDate: fixture.originalInvoiceDate,
                    selectedPaperSize: fixture.selectedPaperSize,
                    returnBillDocumentConfig: fixture.billDocumentConfig,
                    customerName: fixture.customerName,
                    customerPhone: fixture.customerPhone,
                    customerAddress: fixture.customerAddress,
                    customerType: fixture.customerType,
                    customerVatNumber: fixture.customerVatNumber,
                    customerCrNumber: fixture.customerCrNumber,
                  )
                : fixture;
            await tester.runAsync(() async {
              if (thermal) {
                final folder = Directory('${root.path}/epos/developer_prints');
                final before = folder.existsSync()
                    ? folder.listSync().map((f) => f.path).toSet()
                    : <String>{};
                await ReceiptLayoutFactory.getLayout(theme)
                    .printThermal(params);
                final created = folder
                    .listSync()
                    .where((f) => !before.contains(f.path))
                    .toList();
                expect(created, isNotEmpty, reason: id);
                manifest.add({
                  'id': id,
                  'document': documentType,
                  'scenario': scenario,
                  'theme': theme,
                  'kind': 'thermal',
                  'paper': thermalPaper,
                  'files': created.map((f) => f.path).toList()
                });
              } else {
                final document = await StandardPdfLayoutFactory.getLayout(theme)
                    .buildPdfDocument(params);
                final bytes = await document.save();
                expect(bytes.length, greaterThan(500), reason: id);
                final file = File('${root.path}/$id.pdf');
                await file.writeAsBytes(bytes);
                manifest.add({
                  'id': id,
                  'document': documentType,
                  'scenario': scenario,
                  'theme': theme,
                  'kind': 'pdf',
                  'paper': pdfPaper,
                  'files': [file.path]
                });
              }
              File('${root.path}/manifest.json').writeAsStringSync(
                  const JsonEncoder.withIndent('  ').convert(manifest));
            });
            await tester.pump(const Duration(seconds: 4));
            expect(tester.takeException(), isNull, reason: id);
          }
        }
      }
    }
    final expectedPerScenario = documentFilter.isEmpty
        ? 3 * 17 + 3 * 6
        : documentFilter == 'Return Bill' ? 17 + 6
        : documentFilter.endsWith('A4') ? 6 : 17;
    expect(manifest.length, scenarios.length * expectedPerScenario);
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 20)));
}
