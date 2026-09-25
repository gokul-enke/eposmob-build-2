import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bank.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

/// The shared field-text helpers every template (thermal and A4/A5 PDF) uses.
/// The fixture follows the bilingual audit brief: every option carries an
/// Arabic `value` except a few left empty, and only the item-table header
/// options also carry a typed English `default`.

const _itemHeaderDefaults = {
  'showSLNumber': 'No',
  'showParticulars': 'Item',
  'showQty': 'Qty',
  'showRate': 'Rate',
  'showUnit': 'Unit',
  'showTaxHeader': 'Tax',
  'showTotal': 'Total',
};

const _emptyValueKeys = {
  'showCustomerName',
  'showCustomerAddress',
  'showPayment',
  'showDate',
  'showBankInfo',
  'showBankName',
  'showAccountName',
  'showAccountNumber',
  'showIBAN',
  'showSwiftCode',
};

Map<String, DisplayOption> _auditOptions() => {
      for (final key in ReceiptConfigurationContract.canonicalBillKeys)
        key: DisplayOption(
          visible: key != 'showCustomerPhoneMasked',
          value: _emptyValueKeys.contains(key) ? null : 'عربي $key',
          defaultValue: _itemHeaderDefaults[key],
        ),
    };

ReceiptLayoutParams _params(
  BuildContext context, {
  required String language,
  Map<String, DisplayOption>? options,
  Map<String, dynamic>? paymentBreakdown,
  String? paymentMethod = 'CASH',
  double? paidAmount = 100,
  List<dynamic> cartItems = const [],
  String? numberPrefix,
}) {
  return ReceiptLayoutParams(
    context: context,
    selectedPrinter: BluetoothPrinter.development(),
    cartItems: cartItems,
    formattedTotal: '100.00',
    orderDate: '2026-09-24T09:40:00Z',
    orderNumber: 'ORD-000015',
    tokenNumber: '286',
    isFromLocalStorage: true,
    selectedPaperSize: 'A4',
    billDocumentConfig: DocumentConfig(
      language: language,
      numberPrefix: numberPrefix,
      displayConfiguration:
          DisplayConfiguration(options: options ?? _auditOptions()),
    ),
    customerCareNumber: '',
    customerCareEmail: '',
    paymentMethod: paymentMethod,
    paymentBreakdown: paymentBreakdown,
    paidAmount: paidAmount,
    customerOldBalance: 10,
    customerCurrentBalance: 4,
    zatcaVatNumber: '300000000000003',
    zatcaCrNumber: '1010101010',
    bankDetails: const [
      StoreBank(
        bankName: 'Al Rajhi Bank',
        status: 1,
        bankAccounts: [
          StoreBankAccount(
            accountHolderName: 'FUNZCART',
            accountNumber: '30312312',
            iban: 'SA03',
            swiftCode: 'RJHISARI',
          ),
        ],
      ),
    ],
  );
}

bool _hasArabic(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);

void main() {
  late BuildContext context;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        Builder(builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        }),
      );

  testWidgets(
      'en_ar: only typed English defaults reach the English slot; the rest '
      'print Arabic', (tester) async {
    await pump(tester);
    final params = _params(context, language: 'en_ar');

    for (final key in ReceiptConfigurationContract.canonicalBillKeys) {
      final parts = params.fieldLabelParts(key);
      expect(parts.english, _itemHeaderDefaults[key] ?? '', reason: key);
      if (!_emptyValueKeys.contains(key)) {
        expect(parts.arabic, 'عربي $key', reason: key);
      }
    }

    // Keys the store left empty print the built-in Arabic fallback.
    expect(params.fieldLabelParts('showCustomerName').arabic, 'العميل');
    expect(params.fieldLabelParts('showPayment').arabic, 'الدفع');
    expect(params.fieldLabelParts('showBankInfo').arabic, 'تفاصيل البنك');
    // No date label unless the store or resolved_labels supply one.
    expect(params.fieldLabelParts('showDate').isEmpty, isTrue);

    // Every row helper stays Arabic.
    for (final row in params.bankDetailRows) {
      expect(_hasArabic(row.$1), isTrue, reason: row.$1);
    }
    expect(params.bankDetailsHeading, 'تفاصيل البنك');
    for (final row in params.paymentBreakdownRows) {
      expect(_hasArabic(row.$1), isTrue, reason: row.$1);
    }
    for (final row in params.customerBalanceRows) {
      expect(_hasArabic(row.$1), isTrue, reason: row.$1);
    }
    expect(params.tokenText, 'عربي showTokenNumber: 286');
    expect(params.vatFooterText, 'عربي showVATFooter 300000000000003');
    expect(params.orderNumberFooterText, 'عربي showOrderNumberInFooter 15');
    expect(params.storeTaxText('showCRNumber'), 'عربي showCRNumber: 1010101010');
    expect(params.qrCaption, 'عربي showQRCode');
    expect(params.rendererText(english: 'Page', arabic: 'صفحة'), 'صفحة');
  });

  testWidgets('item headers stack the Arabic value over the typed default',
      (tester) async {
    await pump(tester);
    final params = _params(context, language: 'en_ar');
    expect(params.fieldLabel('showQty'), 'عربي showQty\nQty');
    expect(params.fieldLabelParts('showQty').arabic, 'عربي showQty');
    expect(params.fieldLabelParts('showQty').english, 'Qty');
    // Rate Ex Tax has no typed default: Arabic only, never "RATE EX TAX".
    expect(params.fieldLabel('showRateExcTax'), 'عربي showRateExcTax');
  });

  testWidgets('English and Arabic documents fill only their own slot',
      (tester) async {
    await pump(tester);
    final english = _params(context, language: 'en', options: {
      'showQty': DisplayOption(visible: true, value: 'الكمية', defaultValue: 'Qty'),
      'showCustomerName': DisplayOption(visible: true),
    });
    expect(english.fieldLabelParts('showQty').english, 'Qty');
    expect(english.fieldLabelParts('showQty').arabic, '');
    expect(english.fieldLabel('showCustomerName'), 'Customer');

    final arabic = _params(context, language: 'ar', options: {
      'showQty': DisplayOption(visible: true, value: 'الكمية', defaultValue: 'Qty'),
      'showCustomerName': DisplayOption(visible: true),
    });
    expect(arabic.fieldLabelParts('showQty').arabic, 'الكمية');
    expect(arabic.fieldLabelParts('showQty').english, '');
    expect(arabic.fieldLabel('showCustomerName'), 'العميل');
  });

  testWidgets('payment rows use the cash label and renderer method names',
      (tester) async {
    await pump(tester);
    final single = _params(context, language: 'en_ar');
    expect(single.paymentBreakdownRows, [('نقدي', 100.0)]);
    expect(single.paymentMethodSummary, 'نقدي');

    final multi = _params(
      context,
      language: 'en_ar',
      paymentBreakdown: {'CASH': 60.0, 'Card': 40.0, 'BANK': 0},
    );
    expect(multi.paymentBreakdownRows, [('نقدي', 60.0), ('بطاقة', 40.0)]);
    expect(multi.paymentMethodSummary, 'نقدي, بطاقة');

    final english = _params(
      context,
      language: 'en',
      paymentBreakdown: {'isMultiPayment': true, 'amounts': {'CASH': 60.0}},
    );
    expect(english.paymentBreakdownRows, [('Cash', 60.0)]);

    final noPaid = _params(context, language: 'en', paidAmount: null);
    expect(noPaid.paymentBreakdownRows, isEmpty);
  });

  testWidgets('item names follow the document language', (tester) async {
    await pump(tester);
    final item = <String, dynamic>{
      'product_name': 'Milk',
      'names': {'en': 'Milk', 'ar': 'حليب'},
      'variant_attributes': {'size': '1L'},
    };
    List<String> lines(String language) =>
        _params(context, language: language).itemNameLines(item);

    expect(lines('en_ar'), ['حليب', 'Milk (1L)']);
    expect(lines('ar'), ['حليب (1L)']);
    expect(lines('en'), ['Milk (1L)']);
    expect(
      _params(context, language: 'ar').itemNameLines({'product_name': 'Kitkat'}),
      ['Kitkat'],
    );
  });

  testWidgets('order date/time is one left-to-right value', (tester) async {
    await pump(tester);
    final text = _params(context, language: 'ar').orderDateTimeText;
    expect(_hasArabic(text), isFalse);
    expect(text, contains('2026'));
    expect(text.split('  '), hasLength(2));
  });

  test('labelled strips a typed trailing colon before joining', () {
    expect(ReceiptConfigurationContract.labelled('الكمية:', '3'), 'الكمية: 3');
    expect(ReceiptConfigurationContract.labelled('', '3'), '3');
  });
}
