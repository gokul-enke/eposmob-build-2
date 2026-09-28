import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/print_unit_helper.dart';

import 'receipt_configuration_contract.dart';
import 'receipt_layout_params.dart';

/// One label/value row of a receipt section. [label] carries the Arabic and
/// English lines separately so two-column templates can place each language
/// in its own cell; [value] is data and must be drawn as its own text run.
class ReceiptInfoRow {
  const ReceiptInfoRow(this.key, this.label, this.value);

  final String key;
  final ReceiptLabelParts label;
  final String value;
}

/// One amount row (totals, final summary). [text] replaces the money value
/// for count rows such as "Items".
class ReceiptAmountRow {
  const ReceiptAmountRow(
    this.key,
    this.label,
    this.amount, {
    this.emphasised = false,
    this.text,
  });

  final String key;
  final ReceiptLabelParts label;
  final double amount;
  final bool emphasised;
  final String? text;
}

/// A visible item-table column and its header label.
class ReceiptItemColumn {
  const ReceiptItemColumn(this.key, this.label);

  final String key;
  final ReceiptLabelParts label;
}

/// The printable values of one cart line, keyed like the display options.
class ReceiptItemLine {
  const ReceiptItemLine({
    required this.index,
    required this.nameLines,
    required this.mrp,
    required this.quantity,
    required this.rate,
    required this.rateExcTax,
    required this.unit,
    required this.tax,
    required this.total,
    required this.hasWarranty,
  });

  final int index;
  final List<String> nameLines;
  final String mrp;
  final String quantity;
  final String rate;
  final String rateExcTax;
  final String unit;
  final String tax;
  final String total;
  final bool hasWarranty;

  /// Cell text for a column key (`showQty`, `showTotal`, ...).
  String valueFor(String key) => switch (key) {
        'showSLNumber' => '$index',
        'showParticulars' => nameLines.join('\n'),
        'showMRP' => mrp,
        'showQty' => quantity,
        'showRate' => rate,
        'showRateExcTax' => rateExcTax,
        'showUnit' => unit,
        'showTaxHeader' => tax,
        'showTotal' => total,
        _ => '',
      };
}

/// Returns / credit-note block, resolved once for every template.
class ReceiptReturnsSection {
  const ReceiptReturnsSection({
    this.subtitle = '',
    this.signatory = '',
    required this.heading,
    required this.creditNoteHeading,
    required this.creditNoteRows,
    required this.customerHeading,
    required this.customerRows,
    required this.itemsHeading,
    required this.columns,
    required this.lines,
    required this.countRow,
    required this.totalRows,
    required this.wordsHeading,
    required this.wordsLines,
  });

  /// Section heading; empty when a credit-note block replaces it.
  final String heading;
  final String subtitle;
  final String signatory;
  final String creditNoteHeading;
  final List<(String, String)> creditNoteRows;
  final String customerHeading;
  final List<(String, String)> customerRows;
  final String itemsHeading;
  final List<ReceiptItemColumn> columns;
  final List<Map<String, String>> lines;
  final (String, String)? countRow;
  final List<(String, double)> totalRows;
  final String wordsHeading;
  final List<String> wordsLines;
}

/// Section data shared by the thermal receipt and every A4/A5 PDF template:
/// which rows print, in which language, with which values. Templates only
/// decide where and how to draw them.
extension ReceiptSections on ReceiptLayoutParams {
  /// Thermal layouts put the serial and description on a full-width line.
  /// Each switch still controls only its own content on that line.
  static String returnItemHeading({
    required String name,
    required int number,
    required bool showSerial,
    required bool showParticulars,
  }) => [
    if (showSerial) '$number.',
    if (showParticulars && name.trim().isNotEmpty) name.trim(),
  ].join(' ');

  static const itemColumnKeys = <String>[
    'showSLNumber',
    'showParticulars',
    'showMRP',
    'showQty',
    'showRate',
    'showRateExcTax',
    'showUnit',
    'showTaxHeader',
    'showTotal',
  ];

  bool get isQuotation {
    final config = billDocumentConfig;
    return (config.template ?? '').toLowerCase() == 'quotation' ||
        (config.type ?? '').toLowerCase().contains('quotation');
  }

  /// The configured key for the payment row (`showPaymentMethod` on older
  /// configurations, otherwise `showPayment`).
  String get paymentConfigKey =>
      displayConfig?.containsKey('showPaymentMethod') == true
          ? 'showPaymentMethod'
          : 'showPayment';

  /// The configured key for the order comment row.
  String get commentConfigKey =>
      displayConfig?.containsKey('showOrderComment') == true
          ? 'showOrderComment'
          : 'showComment';

  // ── Header ──────────────────────────────────────────────────────────

  /// A configured header text (store name, description, extra headings,
  /// FSSAI) split by language; empty when hidden.
  ReceiptLabelParts headerTextParts(String key) {
    if (!isVisible(key)) return const ReceiptLabelParts();
    return fieldLabelParts(key);
  }

  /// A store detail line (`showStoreAddress`, `showTel`, `showEmail`,
  /// `showVatNumber`, `showCRNumber`) as `label: value` per language; empty
  /// when hidden or when the store has no value.
  ReceiptLabelParts storeLineParts(String key) {
    final value = switch (key) {
      'showStoreAddress' => storeAddressValue,
      'showTel' || 'showEmail' => storeContactValue(key),
      'showVatNumber' => zatcaVatNumber?.trim() ?? '',
      'showCRNumber' => zatcaCrNumber?.trim() ?? '',
      _ => '',
    };
    if (!isVisible(key) || value.isEmpty) return const ReceiptLabelParts();
    return labelledFieldParts(key, value);
  }

  /// Header lines for one language column of a two-column header, in the
  /// thermal order. Single-language documents put every line in their own
  /// column; a bilingual column only carries text typed for its language.
  List<String> headerColumnLines({
    required bool arabic,
    List<String> keys = const [
      'showStoreName',
      'showDescription',
      'showStoreAddress',
      'showExtraHeading1',
      'showVatNumber',
      'showCRNumber',
      'showTel',
      'showEmail',
    ],
  }) {
    final lines = <String>[];
    for (final key in keys) {
      final parts = switch (key) {
        'showStoreAddress' ||
        'showTel' ||
        'showEmail' ||
        'showVatNumber' ||
        'showCRNumber' =>
          storeLineParts(key),
        _ => headerTextParts(key),
      };
      final line = arabic ? parts.arabic : parts.english;
      if (line.trim().isNotEmpty) lines.add(line);
    }
    return lines;
  }

  /// Invoice title (B2B/B2C resolved by [displayConfig]); empty when hidden.
  /// A bilingual title is two lines (Arabic, then English) — draw each line
  /// as its own text so the scripts do not reorder each other.
  String get invoiceTitleText =>
      isVisible('showInvoiceTitle') ? fieldLabel('showInvoiceTitle') : '';

  // ── Customer & order info ──────────────────────────────────────────

  /// Customer rows, gated by the `showCustomerNameAndPhone` master switch.
  List<ReceiptInfoRow> get customerInfoRows {
    if (!isVisible('showCustomerNameAndPhone')) return const [];
    final rows = <ReceiptInfoRow>[];
    void add(String key, String? value, {bool gate = true}) {
      final clean = value?.trim() ?? '';
      if (gate && clean.isNotEmpty) {
        rows.add(ReceiptInfoRow(key, fieldLabelParts(key), clean));
      }
    }

    add('showCustomerName', customerName, gate: isVisible('showCustomerName'));
    add('showCustomerPhone', customerPhoneLineText);
    add('showCustomerAddress', customerAddress,
        gate: isVisible('showCustomerAddress'));
    add('showCustomerVatNumber', customerVatNumber,
        gate: isVisible('showCustomerVatNumber'));
    add('showCustomerCrNumber', customerCrNumber,
        gate: isVisible('showCustomerCrNumber'));
    return rows;
  }

  /// Order rows: invoice number (printed without a label, like the thermal
  /// receipt), token, date and — inside the customer master switch — payment,
  /// delivery method and delivery phone.
  List<ReceiptInfoRow> get orderInfoRows {
    final rows = <ReceiptInfoRow>[];
    if (isVisible('showInvoiceNumber')) {
      rows.add(ReceiptInfoRow(
          'showInvoiceNumber', const ReceiptLabelParts(), invoiceNumberText));
    }
    final token = tokenNumber?.trim() ?? '';
    if (isVisible('showTokenNumber') && token.isNotEmpty) {
      rows.add(ReceiptInfoRow(
          'showTokenNumber', fieldLabelParts('showTokenNumber'), token));
    }
    if (isVisible('showDate')) {
      rows.add(ReceiptInfoRow(
          'showDate', fieldLabelParts('showDate'), orderDateTimeText));
    }
    if (isVisible('showCustomerNameAndPhone')) {
      final payment = paymentMethodSummary;
      if (!isQuotation && isVisible(paymentConfigKey) && payment.isNotEmpty) {
        rows.add(ReceiptInfoRow(
            paymentConfigKey, fieldLabelParts(paymentConfigKey), payment));
      }
      final delivery = deliveryMethod?.trim() ?? '';
      if (isVisible('showDeliveryMethod') && delivery.isNotEmpty) {
        rows.add(ReceiptInfoRow('showDeliveryMethod',
            fieldLabelParts('showDeliveryMethod'), delivery));
      }
      final deliveryPhoneValue = deliveryPhone?.trim() ?? '';
      if (isVisible('showDeliveryPhone') && deliveryPhoneValue.isNotEmpty) {
        rows.add(ReceiptInfoRow('showDeliveryPhone',
            fieldLabelParts('showDeliveryPhone'), deliveryPhoneValue));
      }
    }
    return rows;
  }

  /// `label: comment` when the order comment prints.
  String get commentText {
    final comment = orderComment?.trim() ?? '';
    if (!isVisible('showCustomerNameAndPhone') ||
        !isVisible(commentConfigKey) ||
        comment.isEmpty) {
      return '';
    }
    return labelledField(commentConfigKey, comment);
  }

  // ── Items ───────────────────────────────────────────────────────────

  /// Visible item-table columns in the thermal order.
  List<ReceiptItemColumn> get itemColumns => [
        for (final key in itemColumnKeys)
          if (isVisible(key)) ReceiptItemColumn(key, fieldLabelParts(key)),
      ];

  /// Printable values of every cart line.
  List<ReceiptItemLine> get itemLines => [
        for (var i = 0; i < cartItems.length; i++)
          itemLine(cartItems[i], i + 1),
      ];

  ReceiptItemLine itemLine(dynamic item, int index) {
    double number(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0.0;
    dynamic read(List<String> mapKeys, dynamic Function() model) {
      if (item is Map) {
        for (final key in mapKeys) {
          final value = item[key];
          if (value != null && value.toString().trim().isNotEmpty) return value;
        }
        return null;
      }
      try {
        return model();
      } catch (_) {
        return null;
      }
    }

    final quantity = number(read(['quantity'], () => item.quantity));
    final unitPrice =
        number(read(['unitPrice', 'unit_price'], () => item.unitPrice));
    final tax = number(read(['tax_amount', 'taxAmount'], () => item.taxAmount));
    final total =
        number(read(['totalPrice', 'total_price'], () => item.totalPrice));
    final mrp = number(read(['mrp'], () => item.mrp));
    final taxPerUnit = quantity > 0 ? tax / quantity : 0.0;
    return ReceiptItemLine(
      index: index,
      nameLines: itemNameLines(item),
      mrp: mrp.toStringAsFixed(2),
      quantity: formatQuantity(quantity),
      rate: unitPrice.toStringAsFixed(2),
      rateExcTax: (unitPrice - taxPerUnit).toStringAsFixed(2),
      unit: getPrintUnit(item),
      tax: tax.toStringAsFixed(2),
      total: total.toStringAsFixed(2),
      hasWarranty: itemHasWarranty(item),
    );
  }

  /// Whether the line prints the `showWarranty` label.
  /// Accepts the same truthy values as the thermal StandardReceiptLayout
  /// (`true`, `1`, `"1"`), plus the string `"true"`.
  bool itemHasWarranty(dynamic item) {
    bool truthy(dynamic value) {
      if (value == true) return true;
      final text = value?.toString().trim().toLowerCase();
      return text == '1' || text == 'true';
    }

    if (item is Map) {
      return truthy(item['warranty_enabled']) ||
          truthy(item['warrantyEnabled']);
    }
    try {
      return truthy(item.warrantyEnabled);
    } catch (_) {
      return false;
    }
  }

  static String formatQuantity(double quantity) {
    if (quantity % 1 == 0) return quantity.toInt().toString();
    return quantity
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  // ── Totals ──────────────────────────────────────────────────────────

  double get netAmountValue =>
      double.tryParse(formattedTotal.replaceAll(',', '')) ?? 0.0;

  double get discountAmountValue =>
      double.tryParse((discountAmount ?? '0').replaceAll(',', '')) ?? 0.0;

  double get savedAmountValue =>
      double.tryParse((savedTotal ?? '0').replaceAll(',', '')) ?? 0.0;

  /// Retail total uses the same net-plus-savings amount in every layout.
  double get mrpTotalValue => netAmountValue + savedAmountValue;

  /// Taxable amount: the API's net excluding tax, else the item lines'
  /// totals minus their tax.
  double get subtotalExcTax {
    final api = double.tryParse((netExcTax ?? '').replaceAll(',', ''));
    if (api != null) return api;
    var sum = 0.0;
    for (final line in itemLines) {
      sum +=
          (double.tryParse(line.total) ?? 0) - (double.tryParse(line.tax) ?? 0);
    }
    return sum;
  }

  /// Items / quantity counts, then sub total, discount (when non-zero), VAT
  /// and grand total — each only when its key is visible.
  List<ReceiptAmountRow> get totalsRows {
    final rows = <ReceiptAmountRow>[];
    if (isVisible('showItemsCount')) {
      rows.add(ReceiptAmountRow('showItemsCount',
          fieldLabelParts('showItemsCount'), cartItems.length.toDouble(),
          text: '${cartItems.length}'));
    }
    if (isVisible('showQuantityCount')) {
      rows.add(ReceiptAmountRow('showQuantityCount',
          fieldLabelParts('showQuantityCount'), totalQuantity,
          text: formatQuantity(totalQuantity)));
    }
    if (isVisible('showSubTotal')) {
      rows.add(ReceiptAmountRow(
          'showSubTotal', fieldLabelParts('showSubTotal'), subtotalExcTax));
    }
    if (isVisible('showMRPTotal')) {
      rows.add(ReceiptAmountRow(
          'showMRPTotal', fieldLabelParts('showMRPTotal'), mrpTotalValue));
    }
    if (isVisible('showDiscount') && discountAmountValue != 0) {
      rows.add(ReceiptAmountRow('showDiscount', fieldLabelParts('showDiscount'),
          discountAmountValue));
    }
    if (isVisible('showTax')) {
      rows.add(
          ReceiptAmountRow('showTax', fieldLabelParts('showTax'), totalTax));
    }
    if (isVisible('showNetAmount')) {
      rows.add(ReceiptAmountRow(
          'showNetAmount', fieldLabelParts('showNetAmount'), netAmountValue,
          emphasised: true));
    }
    return rows;
  }

  /// `label` for the "you saved" line, empty when it does not print.
  String get savedLabel => isVisible('showSaved') && savedAmountValue > 0
      ? ReceiptConfigurationContract.withoutTrailingColon(
          fieldLabel('showSaved', inlineBilingual: true))
      : '';

  /// Warranty label printed under a warranty line (empty when hidden).
  String get warrantyLabel => isVisible('showWarranty')
      ? fieldLabel('showWarranty', inlineBilingual: true)
      : '';

  /// Customer / salesman signature captions (template-owned text).
  String get customerSignatureLabel =>
      rendererText(english: 'Customer Signature', arabic: 'توقيع العميل');
  String get salesmanSignatureLabel =>
      rendererText(english: 'Salesman Signature', arabic: 'توقيع البائع');

  // ── Returns ─────────────────────────────────────────────────────────

  /// Preserve a return's explicit unit price (including zero), then use its
  /// original cart line. Only legacy responses without either use an average.
  (double, double) returnItemRate(OrderReturnItem item) {
    final explicitRate =
        double.tryParse(item.unitPrice?.replaceAll(',', '') ?? '');
    if (explicitRate != null) {
      return (
        explicitRate,
        double.tryParse(item.mrp?.replaceAll(',', '') ?? '') ?? explicitRate
      );
    }
    for (final cartItem in cartItems) {
      var name = '';
      double? rate;
      var mrp = 0.0;
      int? cartId;
      int? variantId;
      if (cartItem is Map) {
        cartId = int.tryParse(cartItem['id']?.toString() ?? '');
        variantId =
            int.tryParse(cartItem['product_variant_id']?.toString() ?? '');
        name = (cartItem['product_name'] ?? cartItem['productName'] ?? '')
            .toString();
        rate = double.tryParse(
            (cartItem['unit_price'] ?? cartItem['unitPrice'])?.toString() ??
                '');
        mrp = double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
      } else {
        try {
          cartId = int.tryParse(cartItem.id?.toString() ?? '');
          variantId = int.tryParse(cartItem.productVariantId?.toString() ?? '');
          name = cartItem.productName?.toString() ?? '';
          rate = double.tryParse(cartItem.unitPrice?.toString() ?? '');
          mrp = double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0;
        } catch (_) {}
      }
      final matches = item.cartItemId != null && cartId != null
          ? item.cartItemId == cartId
          : name == item.productName &&
              (item.productVariantId == null ||
                  item.productVariantId == variantId);
      if (matches && rate != null) return (rate, mrp);
    }
    final returns = orderReturns;
    final total = double.tryParse(
            (returns?.returnTotalAmount ?? '0').replaceAll(',', '')) ??
        0.0;
    num quantity = 0;
    for (final returned in returns?.returnItems ?? const <OrderReturnItem>[]) {
      quantity += returned.quantity ?? 0;
    }
    final average = quantity > 0 ? total / quantity : 0.0;
    return (average, average);
  }

  /// The returns block, or null when the order has no returned items.
  ReceiptReturnsSection? get returnsSection {
    final returns = orderReturns;
    final items = returns?.returnItems;
    if (returns == null || items == null || items.isEmpty) return null;

    final retDc = returnBillDisplayConfig;
    final retLabels = returnBillResolvedLabels;
    final labels = billDocumentConfig.resolvedLabels;
    final hasCreditNote = retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null;

    String retLabel(
            String key, String? resolved, String english, String arabic) =>
        ReceiptConfigurationContract.withoutTrailingColon(
          ReceiptConfigurationContract.label(
            options: retDc,
            key: key,
            mode: receiptLanguageMode,
            englishFallback: english,
            arabicFallback: arabic,
            resolvedArabic: resolved,
            inlineBilingual: true,
          ),
        );
    String billLabel(
            String key, String? resolved, String english, String arabic) =>
        ReceiptConfigurationContract.withoutTrailingColon(labelFor(key,
            englishFallback: english,
            arabicFallback: arabic,
            resolvedArabic: resolved,
            inlineBilingual: true));

    final creditNoteRows = <(String, String)>[];
    if (hasCreditNote) {
      if (isVisible('showInvoiceNumber') &&
          retLabels?.creditNoteNumber != null) {
        creditNoteRows.add((
          retLabel('showCreditNoteNumber', retLabels?.creditNoteNumber,
              'Credit Note No', 'رقم إشعار الائتمان'),
          orderNumber,
        ));
      }
      if (isVisible('showInvoiceNumber') && retLabels?.creditNoteDate != null) {
        creditNoteRows.add((
          retLabel('showCreditNoteDate', retLabels?.creditNoteDate,
              'Credit Note Date', 'تاريخ إشعار الائتمان'),
          orderDateTimeText,
        ));
      }
      final reasons = {
        for (final item in items)
          if ((item.reason ?? '').trim().isNotEmpty) item.reason!.trim(),
      }.join(', ');
      if (ReceiptConfigurationContract.isVisible(
              retDc, 'showCreditNoteReason') &&
          reasons.isNotEmpty) {
        creditNoteRows.add((
          retLabel('showCreditNoteReason', retLabels?.creditNoteReason,
              'Reason', 'السبب'),
          reasons,
        ));
      }
    }

    // Original sale details are independent of the credit-note identity and
    // must never use the return creation date as the original invoice date.
    if (ReceiptConfigurationContract.isVisible(retDc, 'showOriginalInvoice')) {
      final number = originalInvoiceNumber?.trim() ?? '';
      final date = originalInvoiceDate?.trim() ?? '';
      if (number.isNotEmpty) {
        creditNoteRows.add((
          retLabel('showOriginalInvoice', retLabels?.creditNoteOrder,
              'Original Invoice', 'الفاتورة الأصلية'),
          number,
        ));
      }
      if (date.isNotEmpty) {
        creditNoteRows.add((
          retLabel('showInvoiceDate', retLabels?.text('invoice_date'),
              'Invoice Date', 'تاريخ الفاتورة'),
          DateHelper.formatISODate(date),
        ));
      }
    }

    final customerRows = <(String, String)>[];
    final name = customerName?.trim() ?? '';
    final showCustomer = hasCreditNote
        ? isVisible('showCustomerNameAndPhone')
        : isVisible('showCustomerName');
    final returnPhone = hasCreditNote
        ? customerPhoneForVisibility(showCustomer)
        : customerPhoneText;
    if (showCustomer) {
      if (name.isNotEmpty) {
        customerRows.add((
          retLabel('showCreditNoteCustomerName', retLabels?.text('customer_name'),
              'Customer Name', 'اسم العميل'),
          name,
        ));
      }
      if (returnPhone.isNotEmpty) {
        customerRows.add((
          retLabel('showCreditNoteCustomerPhone',
              retLabels?.text('customer_phone'), 'Phone', 'الهاتف'),
          returnPhone
        ));
      }
      final address = customerAddress?.trim() ?? '';
      if ((hasCreditNote || isVisible('showCustomerAddress')) &&
          address.isNotEmpty) {
        customerRows.add((
          retLabel(
              'showCreditNoteBillingAddress',
              retLabels?.text('billing_address'),
              'Billing Address',
              'عنوان الفاتورة'),
          address,
        ));
      }
      final taxId = customerVatNumber?.trim() ?? '';
      if (ReceiptConfigurationContract.isVisible(retDc, 'showCustomerGstin') &&
          taxId.isNotEmpty) {
        customerRows.add((
          retLabel('showCustomerGstin', retLabels?.text('customer_gstin'),
              'GSTIN', 'الرقم الضريبي'),
          taxId,
        ));
      }
    }

    final columnDefs = <(String, String?, String, String)>[
      ('showReturnSLNumber', labels?.returnSlNumber, 'SL#', '#'),
      (
        'showReturnParticulars',
        labels?.returnParticulars,
        'PARTICULARS',
        'البيان'
      ),
      ('showReturnMRP', labels?.returnMrp, 'MRP', 'MRP'),
      ('showHsnCode', retLabels?.text('hsn'), 'HSN', 'رمز الصنف'),
      ('showTaxRateColumn', retLabels?.text('tax_rate_column'), 'Tax Rate', 'نسبة الضريبة'),
      ('showUnitPrice', retLabels?.text('unit_price'), 'Unit Price', 'سعر الوحدة'),
      ('showReturnQty', labels?.returnQty, 'QTY', 'الكمية'),
      ('showReturnRate', labels?.returnRate, 'RATE', 'السعر'),
      (
        'showReturnTotal',
        retLabels?.text('grand_total_header') ?? labels?.returnTotal,
        'TOTAL',
        'الإجمالي'
      ),
    ];
    final columns = <ReceiptItemColumn>[
      for (final def in columnDefs)
        if (isVisible(def.$1))
          ReceiptItemColumn(
            def.$1,
            ReceiptLabelParts(
              arabic: receiptLanguageMode.isEnglish
                  ? ''
                  : billLabel(def.$1, def.$2, def.$3, def.$4),
              english: receiptLanguageMode.isEnglish
                  ? billLabel(def.$1, def.$2, def.$3, def.$4)
                  : '',
            ),
          ),
    ];
    final lines = <Map<String, String>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final (rate, mrp) = returnItemRate(item);
      final quantity = (item.quantity ?? 0).toDouble();
      var productName = item.productName ?? '';
      final attributes = item.formattedVariantAttributes;
      if (attributes.isNotEmpty && !productName.contains('($attributes)')) {
        productName = '$productName ($attributes)';
      }
      lines.add({
        'showReturnSLNumber': '${i + 1}',
        'showReturnParticulars': productName,
        'showReturnMRP': mrp.toStringAsFixed(2),
        'showHsnCode': item.hsnCode?.trim() ?? '',
        'showTaxRateColumn': returnTaxRateText(item),
        'showUnitPrice': rate.toStringAsFixed(2),
        'showReturnQty': formatQuantity(quantity),
        'showReturnRate': rate.toStringAsFixed(2),
        'showReturnTotal': (quantity * rate).toStringAsFixed(2),
      });
    }

    (String, String)? countRow;
    if (isVisible('showReturnItemsCount')) {
      countRow = (
        retLabels?.creditNoteItemsCount != null
            ? retLabel(
                'showReturnItemsCount',
                retLabels?.creditNoteItemsCount,
                'Total Items',
                'إجمالي العناصر')
            : billLabel(
                'showReturnItemsCount', null, 'Return Items', 'عناصر المرتجع'),
        // Credit-note admin previews count returned units, including weighted
        // quantities. Combined sales/return bills keep their line-count row.
        isReturnOnly
            ? formatQuantity(items.fold<double>(
                0, (sum, item) => sum + (item.quantity ?? 0)))
            : '${items.length}',
      );
    }

    final returnTotal = returnTotalValue;
    final mrpTotal = returnMrpTotalRow;
    final totalRows = <(String, double)>[
      if (mrpTotal != null) mrpTotal,
      if (isVisible('showReturnTotalAmount'))
        (
          retLabels?.creditNoteTotalAmount != null
              ? retLabel(
                  'showCreditNoteTotalAmount',
                  retLabels?.creditNoteTotalAmount,
                  'Total Amount',
                  'المبلغ الإجمالي')
              : billLabel('showReturnTotalAmount', null, 'Return Total',
                  'إجمالي المرتجع'),
          returnTotal,
        ),
      if (isVisible('showReturnNetAmount'))
        (
          retLabels?.creditNoteRefund != null
              ? retLabel('showCreditNoteRefund', retLabels?.creditNoteRefund,
                  'Credit Note Total', 'إجمالي إشعار الائتمان')
              : billLabel('showReturnNetAmount', null, 'Return Net Amount',
                  'صافي مبلغ الإرجاع'),
          returnTotal,
        ),
    ];

    return ReceiptReturnsSection(
      subtitle: ReceiptConfigurationContract.isVisible(retDc, 'showGstSubtitle')
          ? retLabel('showGstSubtitle', retLabels?.text('subtitle'),
              'Credit Note', 'إشعار دائن')
          : '',
      signatory: ReceiptConfigurationContract.isVisible(retDc, 'showAuthorizedSignatory')
          ? retLabel('showAuthorizedSignatory', retLabels?.signatory,
              'Authorized Signatory', 'المفوض بالتوقيع')
          : '',
      heading: hasCreditNote ? '' : returnsSectionHeading,
      creditNoteHeading: creditNoteRows.isEmpty
          ? ''
          : retLabel('showCreditNoteDetailsHeading', retLabels?.detailsHeading,
              'CREDIT NOTE DETAILS', 'تفاصيل إشعار الائتمان'),
      creditNoteRows: creditNoteRows,
      customerHeading: customerRows.isEmpty
          ? ''
          : retLabel('showCreditNoteCustomerHeading',
              retLabels?.customerHeading, 'CUSTOMER DETAILS', 'بيانات العميل'),
      customerRows: customerRows,
      // Printed only when the config supplies an items heading; the built-in
      // text replaces it when it is in the wrong language for this document.
      itemsHeading: retLabels?.itemsHeading?.trim().isNotEmpty == true
          ? retLabel('showCreditNoteItemsHeading', retLabels?.itemsHeading,
              'RETURNED ITEMS', 'العناصر المرتجعة')
          : '',
      columns: columns,
      lines: lines,
      countRow: countRow,
      totalRows: totalRows,
      wordsHeading: isVisible('showReturnAmountInWords')
          ? billLabel(
              'showReturnAmountInWords',
              retLabels?.text('amount_in_words'),
              'Amount in Words',
              'المبلغ كتابة')
          : '',
      wordsLines: const [],
    );
  }

  /// Return words have their own visibility control, independent of totals.
  List<String> returnsWordsLines(String currency) {
    final section = returnsSection;
    if (section == null || section.wordsHeading.isEmpty) return const [];
    return amountInWordsLines(returnTotalValue, currency: currency);
  }

  /// Preserve a known zero rate; absent or invalid source rates stay blank.
  String returnTaxRateText(OrderReturnItem item) {
    final rate = double.tryParse(item.taxRate?.trim() ?? '');
    return rate == null || !rate.isFinite || rate < 0
        ? ''
        : '${formatQuantity(rate)}%';
  }

  /// An explicit refund, including zero, wins. Missing totals use returned lines.
  double get returnTotalValue => double.tryParse(
          (orderReturns?.returnTotalAmount ?? '').replaceAll(',', '').trim()) ??
      (orderReturns?.returnItems ?? const <OrderReturnItem>[]).fold<double>(
          0, (sum, item) => sum + (item.quantity ?? 0) * returnItemRate(item).$1);

  /// Credit-note MRP totals use only the returned quantities, not the full sale
  /// or the refund total. Match the per-item MRP fallback used by the table.
  (String, double)? get returnMrpTotalRow {
    if (!isReturnOnly || !isVisible('showMRPTotal')) return null;
    final label = ReceiptConfigurationContract.withoutTrailingColon(labelFor(
      'showMRPTotal',
      englishFallback: 'MRP Total',
      arabicFallback: 'إجمالي السعر الأقصى',
      resolvedArabic: returnBillResolvedLabels?.text('mrp_total'),
      inlineBilingual: true,
    ));
    final amount = (orderReturns?.returnItems ?? const <OrderReturnItem>[])
        .fold<double>(0,
            (sum, item) => sum + (item.quantity ?? 0) * returnItemRate(item).$2);
    return (label, amount);
  }

  /// Order total / return total / final total after returns.
  List<ReceiptAmountRow> get finalSummaryRows {
    final section = returnsSection;
    if (section == null) return const [];
    final returnTotal = returnTotalValue;
    final orderTotal = netAmountValue;
    ReceiptLabelParts label(String key, String english, String arabic) =>
        ReceiptConfigurationContract.labelParts(
          options: displayConfig,
          key: key,
          mode: receiptLanguageMode,
          englishFallback: english,
          arabicFallback: arabic,
        );
    return [
      if (isVisible('showFinalPurchase'))
        ReceiptAmountRow(
            'showFinalPurchase',
            label('showFinalPurchase', 'ORDER TOTAL', 'إجمالي الطلب'),
            orderTotal),
      if (isVisible('showFinalReturn'))
        ReceiptAmountRow(
            'showFinalReturn',
            label('showFinalReturn', 'RETURN TOTAL', 'إجمالي المرتجع'),
            returnTotal),
      if (isVisible('showFinalNetAmount'))
        ReceiptAmountRow(
          'showFinalNetAmount',
          label('showFinalNetAmount', 'FINAL TOTAL', 'المبلغ النهائي'),
          orderTotal - returnTotal,
          emphasised: true,
        ),
    ];
  }

  /// Final-summary amount in words (after returns).
  List<String> finalSummaryWordsLines(String currency) {
    final items = orderReturns?.returnItems;
    if (items == null || items.isEmpty ||
        !isVisible('showFinalAmountInWords')) {
      return const [];
    }
    return amountInWordsLines(netAmountValue - returnTotalValue, currency: currency);
  }
}
