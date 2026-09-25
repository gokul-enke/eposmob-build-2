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

    add('showCustomerName', customerName,
        gate: isVisible('showCustomerName'));
    var phone = customerPhoneText;
    final alternate = customerAlternatePhone?.trim() ?? '';
    if (phone.isNotEmpty && alternate.isNotEmpty) phone = '$phone, $alternate';
    add('showCustomerPhone', phone);
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
      rows.add(
          ReceiptInfoRow('showDate', fieldLabelParts('showDate'), orderDateTimeText));
    }
    if (isVisible('showCustomerNameAndPhone')) {
      final payment = paymentMethodSummary;
      if (!isQuotation && isVisible(paymentConfigKey) && payment.isNotEmpty) {
        rows.add(ReceiptInfoRow(
            paymentConfigKey, fieldLabelParts(paymentConfigKey), payment));
      }
      final delivery = deliveryMethod?.trim() ?? '';
      if (isVisible('showDeliveryMethod') && delivery.isNotEmpty) {
        rows.add(ReceiptInfoRow(
            'showDeliveryMethod', fieldLabelParts('showDeliveryMethod'), delivery));
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
        for (var i = 0; i < cartItems.length; i++) itemLine(cartItems[i], i + 1),
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
  bool itemHasWarranty(dynamic item) {
    if (item is Map) {
      return item['warranty_enabled'] == true ||
          item['warrantyEnabled'] == true ||
          item['warranty_enabled'] == 1 ||
          item['warrantyEnabled'] == 1;
    }
    try {
      return item.warrantyEnabled == true;
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

  /// Taxable amount: the API's net excluding tax, else the item lines'
  /// totals minus their tax.
  double get subtotalExcTax {
    final api = double.tryParse((netExcTax ?? '').replaceAll(',', ''));
    if (api != null) return api;
    var sum = 0.0;
    for (final line in itemLines) {
      sum += (double.tryParse(line.total) ?? 0) - (double.tryParse(line.tax) ?? 0);
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
    if (isVisible('showSubTotal') || isVisible('showMRPTotal')) {
      rows.add(ReceiptAmountRow(
          'showSubTotal', fieldLabelParts('showSubTotal'), subtotalExcTax));
    }
    if (isVisible('showDiscount') && discountAmountValue != 0) {
      rows.add(ReceiptAmountRow(
          'showDiscount', fieldLabelParts('showDiscount'), discountAmountValue));
    }
    if (isVisible('showTax')) {
      rows.add(ReceiptAmountRow('showTax', fieldLabelParts('showTax'), totalTax));
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

  /// Unit rate (and MRP) of a returned product: the matching cart line's
  /// price, else the average of the return total.
  (double, double) returnItemRate(OrderReturnItem item) {
    for (final cartItem in cartItems) {
      var name = '';
      var rate = 0.0;
      var mrp = 0.0;
      if (cartItem is Map) {
        name = (cartItem['product_name'] ?? cartItem['productName'] ?? '')
            .toString();
        rate = double.tryParse(
                (cartItem['unit_price'] ?? cartItem['unitPrice'])?.toString() ??
                    '0') ??
            0.0;
        mrp = double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
      } else {
        try {
          name = cartItem.productName?.toString() ?? '';
          rate = double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
          mrp = double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0;
        } catch (_) {}
      }
      if (name == item.productName && rate != 0.0) return (rate, mrp);
    }
    final returns = orderReturns;
    final total = double.tryParse(returns?.returnTotalAmount ?? '0') ?? 0.0;
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

    String retLabel(String key, String? resolved, String english, String arabic) =>
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
    String billLabel(String key, String? resolved, String english, String arabic) =>
        ReceiptConfigurationContract.withoutTrailingColon(labelFor(key,
            englishFallback: english,
            arabicFallback: arabic,
            resolvedArabic: resolved,
            inlineBilingual: true));

    final creditNoteRows = <(String, String)>[];
    if (hasCreditNote) {
      if (retLabels?.creditNoteNumber != null) {
        creditNoteRows.add((
          retLabel('showCreditNoteNumber', retLabels?.creditNoteNumber,
              'Credit Note No', 'رقم إشعار الائتمان'),
          orderNumber,
        ));
      }
      if (retLabels?.creditNoteDate != null) {
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
      if (retLabels?.creditNoteReason != null && reasons.isNotEmpty) {
        creditNoteRows.add((
          retLabel('showCreditNoteReason', retLabels?.creditNoteReason,
              'Reason', 'السبب'),
          reasons,
        ));
      }
    }

    final customerRows = <(String, String)>[];
    final name = customerName?.trim() ?? '';
    if (isVisible('showCustomerName') && name.isNotEmpty) {
      customerRows.add((
        rendererText(english: 'Customer Name', arabic: 'اسم العميل'),
        name,
      ));
      if (customerPhoneText.isNotEmpty) {
        customerRows.add(
            (rendererText(english: 'Phone', arabic: 'الهاتف'), customerPhoneText));
      }
      final address = customerAddress?.trim() ?? '';
      if (isVisible('showCustomerAddress') && address.isNotEmpty) {
        customerRows.add((
          rendererText(english: 'Billing Address', arabic: 'عنوان الفاتورة'),
          address,
        ));
      }
    }

    final columnDefs = <(String, String?, String, String)>[
      ('showReturnSLNumber', labels?.returnSlNumber, 'SL#', '#'),
      ('showReturnParticulars', labels?.returnParticulars, 'PARTICULARS', 'البيان'),
      ('showReturnMRP', labels?.returnMrp, 'MRP', 'MRP'),
      ('showReturnQty', labels?.returnQty, 'QTY', 'الكمية'),
      ('showReturnRate', labels?.returnRate, 'RATE', 'السعر'),
      ('showReturnTotal', labels?.returnTotal, 'TOTAL', 'الإجمالي'),
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
        'showReturnQty': formatQuantity(quantity),
        'showReturnRate': rate.toStringAsFixed(2),
        'showReturnTotal': (quantity * rate).toStringAsFixed(2),
      });
    }

    (String, String)? countRow;
    if (isVisible('showReturnItemsCount')) {
      countRow = (
        retLabels?.creditNoteItemsCount != null
            ? retLabel('showCreditNoteItemsCount',
                retLabels?.creditNoteItemsCount, 'Total Items', 'إجمالي العناصر')
            : billLabel('showReturnItemsCount', null, 'Return Items',
                'عناصر المرتجع'),
        '${items.length}',
      );
    }

    final returnTotal = double.tryParse(returns.returnTotalAmount ?? '0') ?? 0.0;
    final totalRows = <(String, double)>[
      if (isVisible('showReturnTotalAmount'))
        (
          retLabels?.creditNoteTotalAmount != null
              ? retLabel('showCreditNoteTotalAmount',
                  retLabels?.creditNoteTotalAmount, 'Total Amount', 'المبلغ الإجمالي')
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
      heading: hasCreditNote ? '' : returnsSectionHeading,
      creditNoteHeading: creditNoteRows.isEmpty
          ? ''
          : retLabel('showCreditNoteOrder', retLabels?.detailsHeading,
              'CREDIT NOTE DETAILS', 'تفاصيل إشعار الائتمان'),
      creditNoteRows: creditNoteRows,
      customerHeading: customerRows.isEmpty
          ? ''
          : (retLabels?.customerHeading?.trim().isNotEmpty == true
              ? retLabels!.customerHeading!.trim()
              : rendererText(english: 'CUSTOMER DETAILS', arabic: 'بيانات العميل')),
      customerRows: customerRows,
      itemsHeading: retLabels?.itemsHeading?.trim() ?? '',
      columns: columns,
      lines: lines,
      countRow: countRow,
      totalRows: totalRows,
      wordsHeading: hasCreditNote && totalRows.isNotEmpty
          ? rendererText(english: 'Amount in Words', arabic: 'المبلغ كتابة')
          : '',
      wordsLines: const [],
    );
  }

  /// Returns-section amount in words (credit notes only).
  List<String> returnsWordsLines(String currency) {
    final section = returnsSection;
    if (section == null || section.wordsHeading.isEmpty) return const [];
    final total =
        double.tryParse(orderReturns?.returnTotalAmount ?? '0') ?? 0.0;
    return amountInWordsLines(total, currency: currency);
  }

  /// Order total / return total / final total after returns.
  List<ReceiptAmountRow> get finalSummaryRows {
    final section = returnsSection;
    if (section == null) return const [];
    var returnTotal = 0.0;
    for (final item in orderReturns!.returnItems!) {
      returnTotal += (item.quantity ?? 0) * returnItemRate(item).$1;
    }
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
        ReceiptAmountRow('showFinalPurchase',
            label('showFinalPurchase', 'ORDER TOTAL', 'إجمالي الطلب'), orderTotal),
      if (isVisible('showFinalReturn'))
        ReceiptAmountRow('showFinalReturn',
            label('showFinalReturn', 'RETURN TOTAL', 'إجمالي المرتجع'), returnTotal),
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
    final rows = finalSummaryRows;
    if (rows.isEmpty || !isVisible('showFinalAmountInWords')) return const [];
    final finalRow = rows.lastWhere((row) => row.key == 'showFinalNetAmount',
        orElse: () => rows.last);
    return amountInWordsLines(finalRow.amount, currency: currency);
  }
}
