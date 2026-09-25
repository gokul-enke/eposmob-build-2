import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/models/bank.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/screens/print/receipt_customer_segment.dart';
import 'package:provider/provider.dart';
import 'receipt_configuration_contract.dart';
import '../thermal/thermal_paper_profile.dart';

/// Data class containing all parameters needed for receipt generation.
/// This eliminates the need to pass many individual parameters to layout methods.
class ReceiptLayoutParams {
  final BuildContext context;
  final BluetoothPrinter selectedPrinter;
  final List<dynamic> cartItems;
  final String formattedTotal;
  final String? savedTotal;
  final String? discountAmount;
  final String orderDate;
  final String orderNumber;
  final String? tokenNumber;
  final bool isFromLocalStorage;
  final String selectedPaperSize;
  final DocumentConfig billDocumentConfig;
  final String customerCareNumber;
  final String customerCareEmail;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final OrderReturns? orderReturns;
  final double? customerOldBalance;
  final double? customerCurrentBalance;
  final double? paidAmount;
  final String? orderComment;
  final String? deliveryMethod;
  final String? deliveryPhone;
  final String? customerAlternatePhone;
  final String? paymentMethod;
  final String? customerVatNumber;
  final String? customerCrNumber;
  final String? customerType;
  final String? documentTitleOverride;
  final Map<String, dynamic>?
      paymentBreakdown; // Added for multi-payment support
  // ZATCA fields for Saudi Arabia e-invoicing
  final String? zatcaVatNumber;
  final String? zatcaCrNumber;
  final String? zatcaCompanyName;
  // Flag to indicate if the customer is the default/walk-in customer
  final bool isDefaultCustomer;
  // Flag to hide phone for default/walk-in customer
  final bool hideDefaultCustomerPhone;
  final String? netExcTax;
  final List<StoreBank> bankDetails;
  final String? storeName;
  final String? storeLocation;
  final String? storePhone;
  final String? storeEmail;
  // Pre-computed total tax from API price_summary.total_tax (post-discount).
  // Null for offline/local-storage orders, which fall back to item-level sum.
  final double? apiTotalTax;
  final bool isReturnOnly;
  final DocumentConfig? returnBillDocumentConfig;

  ReceiptLayoutParams({
    required this.context,
    required this.selectedPrinter,
    required this.cartItems,
    required this.formattedTotal,
    this.savedTotal,
    this.discountAmount,
    required this.orderDate,
    required this.orderNumber,
    this.tokenNumber,
    required this.isFromLocalStorage,
    required this.selectedPaperSize,
    required this.billDocumentConfig,
    required this.customerCareNumber,
    required this.customerCareEmail,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    String? customerAddress,
    this.orderReturns,
    this.customerOldBalance,
    this.customerCurrentBalance,
    this.paidAmount,
    this.orderComment,
    this.deliveryMethod,
    this.deliveryPhone,
    this.customerAlternatePhone,
    this.paymentMethod,
    this.customerVatNumber,
    this.customerCrNumber,
    this.customerType,
    this.documentTitleOverride,
    this.paymentBreakdown,
    this.zatcaVatNumber,
    this.zatcaCrNumber,
    this.zatcaCompanyName,
    this.isDefaultCustomer = false,
    this.hideDefaultCustomerPhone = true,
    this.netExcTax,
    this.bankDetails = const [],
    this.storeName,
    this.storeLocation,
    this.storePhone,
    this.storeEmail,
    this.apiTotalTax,
    this.isReturnOnly = false,
    this.returnBillDocumentConfig,
  }) : customerAddress = printableAddress(customerAddress);

  /// Saved addresses can carry empty parts rendered as the literal text
  /// "null" (e.g. "177, 897, null, null"). Drop those parts so every layout
  /// prints only the address the customer actually has.
  static String? printableAddress(String? raw) {
    if (raw == null) return null;
    final parts = raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.toLowerCase() != 'null')
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Get the display configuration options from the document config
  Map<String, DisplayOption>? get displayConfig {
    final options = billDocumentConfig.displayConfiguration?.options;
    if (options == null) return null;
    final titleOverride = documentTitleOverride?.trim();

    final hasKycDetails = (customerVatNumber?.trim().isNotEmpty ?? false) ||
        (customerCrNumber?.trim().isNotEmpty ?? false);
    final isB2B = ReceiptCustomerSegment.isBusiness(
      customerType: customerType,
      vatNumber: customerVatNumber,
      crNumber: customerCrNumber,
    );
    if (!isB2B) {
      if (titleOverride == null || titleOverride.isEmpty) return options;
      final merged = Map<String, DisplayOption>.from(options);
      merged['showInvoiceTitle'] = DisplayOption(
        visible: true,
        value: titleOverride,
        // With no configured English title the override is the whole title,
        // so bilingual mode must not pair it with the 'INVOICE' fallback.
        defaultValue:
            options['showInvoiceTitle']?.defaultValue ?? titleOverride,
      );
      return merged;
    }

    final b2bInvoiceTitle =
        options['showInvoiceTitleB2B'] ?? options['showInvoiceTitleB2b'];
    final b2bTitleKey = options.containsKey('showInvoiceTitleB2B')
        ? 'showInvoiceTitleB2B'
        : (options.containsKey('showInvoiceTitleB2b')
            ? 'showInvoiceTitleB2b'
            : 'missing');
    debugPrint(
        '[ReceiptLayoutParams] B2B title check: customerType=${customerType ?? 'null'}, hasCustomerKyc=$hasKycDetails, key=$b2bTitleKey, visible=${b2bInvoiceTitle?.visible}, value=${b2bInvoiceTitle?.value}');
    if (b2bInvoiceTitle == null || b2bInvoiceTitle.visible != true) {
      if (titleOverride != null && titleOverride.isNotEmpty) {
        final merged = Map<String, DisplayOption>.from(options);
        merged['showInvoiceTitle'] = DisplayOption(
          visible: true,
          value: titleOverride,
          defaultValue:
              options['showInvoiceTitle']?.defaultValue ?? titleOverride,
        );
        return merged;
      }
      return options;
    }

    final merged = Map<String, DisplayOption>.from(options);
    merged['showInvoiceTitle'] =
        titleOverride != null && titleOverride.isNotEmpty
            ? DisplayOption(
                visible: true,
                value: titleOverride,
                defaultValue: b2bInvoiceTitle.defaultValue,
              )
            : b2bInvoiceTitle;
    return merged;
  }

  /// Keeps a stable offline receipt reference intact in every thermal and
  /// PDF theme while retaining legacy ORD-/CONF- number stripping.
  ///
  /// gokul-dev resolves this through `ReceiptIdentityService`; this branch
  /// does not carry that service yet, so the same two rules live here.
  String get printableOrderNumberComponent {
    final trimmed = orderNumber.trim();
    if (RegExp(r'^\d+-\d{2,3}-\d{6}-\d{4,}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return RegExp(r'[1-9]\d*').firstMatch(trimmed)?.group(0) ?? trimmed;
  }

  /// Display configuration options from the Return Bill document config.
  Map<String, DisplayOption>? get returnBillDisplayConfig =>
      (returnBillDocumentConfig ?? billDocumentConfig)
          .displayConfiguration
          ?.options;

  /// Resolved labels from the Return Bill document config.
  ResolvedLabels? get returnBillResolvedLabels =>
      (returnBillDocumentConfig ?? billDocumentConfig).resolvedLabels;

  /// Resolves the returns section heading from the Return Bill document config.
  ///
  /// Fallback chain:
  /// 1. Return Bill config display option `showReturnsHeader` value
  /// 2. Parent bill display option `showReturnsHeader` value
  /// 3. Hardcoded 'RETURNS'
  String get returnsSectionHeading {
    final retConfig = returnBillDocumentConfig ?? billDocumentConfig;
    final retDisplay = retConfig.displayConfiguration?.options;
    final parentDisplay = billDocumentConfig.displayConfiguration?.options;
    final retOption =
        ReceiptConfigurationContract.option(retDisplay, 'showReturnsHeader');
    if (retOption != null) {
      return ReceiptConfigurationContract.label(
        options: retDisplay,
        key: 'showReturnsHeader',
        mode: receiptLanguageMode,
        englishFallback: 'RETURNS',
        arabicFallback: 'المرتجعات',
      );
    }
    return ReceiptConfigurationContract.label(
      options: parentDisplay,
      key: 'showReturnsHeader',
      mode: receiptLanguageMode,
      englishFallback: 'RETURNS',
      arabicFallback: 'المرتجعات',
    );
  }

  /// Arabic fallback for bilingual returns section heading.
  String get returnsSectionHeadingArabic {
    final retConfig = returnBillDocumentConfig ?? billDocumentConfig;
    final retDisplay = retConfig.displayConfiguration?.options;

    final retHeaderValue = ReceiptConfigurationContract.label(
      options: retDisplay,
      key: 'showReturnsHeaderAr',
      mode: ReceiptLanguageMode.arabic,
      englishFallback: '',
      arabicFallback: 'المرتجعات',
    );
    return retHeaderValue.isNotEmpty ? retHeaderValue : 'المرتجعات';
  }

  /// Check if the document is configured for RTL (Arabic)
  bool get isRtl => receiptLanguageMode.isArabic;

  /// Check if the document is configured for English
  bool get isEnglish => receiptLanguageMode.isEnglish;

  /// Check if the document is bilingual
  bool get isBilingual => receiptLanguageMode.isBilingual;

  /// Normalized language mode shared by every receipt layout.
  ReceiptLanguageMode get receiptLanguageMode =>
      ReceiptConfigurationContract.languageMode(billDocumentConfig.language);

  /// Resolve a configuration option through the shared canonical/alias map.
  DisplayOption? option(String key) =>
      ReceiptConfigurationContract.option(displayConfig, key);

  /// Missing configuration is hidden by default. Templates should use this
  /// instead of `visible != false`, which silently enables absent keys.
  bool isVisible(String key) =>
      ReceiptConfigurationContract.isVisible(displayConfig, key);

  /// The printable address always comes from the active store. The document
  /// configuration owns only its label and visibility switch.
  String get storeAddressValue => storeLocation?.trim() ?? '';

  /// Resolves the complete store-address line with one shared contract for all
  /// thermal and standard-PDF themes. This prevents individual layouts from accidentally
  /// printing the configured label as though it were the address value.
  String storeAddressText({
    bool inlineBilingual = true,
    ReceiptLanguageMode? mode,
  }) {
    if (!isVisible('showStoreAddress') || storeAddressValue.isEmpty) return '';

    final label = ReceiptConfigurationContract.label(
      options: displayConfig,
      key: 'showStoreAddress',
      mode: mode ?? receiptLanguageMode,
      englishFallback: 'Address',
      arabicFallback: 'العنوان',
      inlineBilingual: inlineBilingual,
    ).trim();
    return label.isEmpty ? storeAddressValue : '$label: $storeAddressValue';
  }

  /// Store phone / email line shared by every template. [key] is `showTel`
  /// or `showEmail`: the option owns the label and the visibility switch, the
  /// active store (then the customer-care setting) owns the value. Empty when
  /// hidden or when there is no value, so no template prints an orphan label.
  String storeContactText(String key, {bool inlineBilingual = true}) {
    final value = storeContactValue(key);
    if (!isVisible(key) || value.isEmpty) return '';

    final label = fieldLabel(key, inlineBilingual: inlineBilingual).trim();
    return label.isEmpty ? value : '$label: $value';
  }

  /// The store phone (`showTel`) or email (`showEmail`) value alone: the
  /// active store's, else the customer-care setting.
  String storeContactValue(String key) {
    final isTel = key == 'showTel';
    final primary = (isTel ? storePhone : storeEmail)?.trim() ?? '';
    return primary.isNotEmpty
        ? primary
        : (isTel ? customerCareNumber : customerCareEmail).trim();
  }

  /// Customer phone exactly as every template must print it: empty when the
  /// toggle is off, the phone is missing, or the walk-in default customer is
  /// hidden; masked when `showCustomerPhoneMasked` is on.
  String get customerPhoneText {
    final phone = customerPhone?.trim() ?? '';
    if (!isVisible('showCustomerPhone') || phone.isEmpty) return '';
    if (isDefaultCustomer && hideDefaultCustomerPhone) return '';
    return isVisible('showCustomerPhoneMasked')
        ? StringHelper.maskStringShowLast4(phone)
        : phone;
  }

  /// Printed invoice number: the literal configured prefix (or the primary
  /// language fallback) followed by the stable order-number component.
  String get invoiceNumberText {
    final prefix = ReceiptConfigurationContract.numberPrefix(
      billDocumentConfig.numberPrefix,
      receiptLanguageMode,
      englishFallback: 'INV-',
      arabicFallback: 'رقم الفاتورة: ',
    );
    return '$prefix$printableOrderNumberComponent';
  }

  /// Terms block: the text configured on `showTermsConditions`, falling back
  /// to the document-level `terms`. Empty when the toggle is off.
  String get termsText {
    if (!isVisible('showTermsConditions')) return '';
    final documentTerms = documentText(billDocumentConfig.terms);
    final text = labelFor(
      'showTermsConditions',
      englishFallback: documentTerms,
      arabicFallback: documentTerms,
    );
    return text.isNotEmpty ? text : documentTerms;
  }

  /// Closing message: the text configured on `showThankYouMessage`, then the
  /// document-level `footer`, then the renderer default. Empty when hidden.
  String get thankYouText {
    if (!isVisible('showThankYouMessage')) return '';
    final documentFooter = documentText(billDocumentConfig.footer);
    final text = labelFor(
      'showThankYouMessage',
      englishFallback: documentFooter.isNotEmpty
          ? documentFooter
          : 'Thank You for Your Visit!',
      arabicFallback:
          documentFooter.isNotEmpty ? documentFooter : 'شكراً لزيارتكم!',
    );
    return text.isNotEmpty ? text : documentFooter;
  }

  /// Language code for amount-in-words. Bilingual templates print both.
  /// Amount-in-words language: English documents only; Arabic and bilingual
  /// documents print Arabic (a bilingual document adds no generated English).
  String get amountInWordsLanguage =>
      receiptLanguageMode.isEnglish ? 'en' : 'ar';

  // ==================== SHARED FIELD TEXT ====================
  //
  // Every template — the thermal receipt and all six A4/A5 PDFs — resolves a
  // display key's label through [fieldLabel] / [fieldLabelParts], so one
  // configuration prints the same words everywhere. The fallbacks are the
  // renderer defaults `StandardReceiptLayout` has always used; they only print
  // when the store typed nothing for the key (see
  // [ReceiptConfigurationContract.label] for the language rule).

  static const Map<String, (String, String)> _fieldFallbacks = {
    'showStoreAddress': ('Address', 'العنوان'),
    'showTel': ('Telephone', 'الهاتف'),
    'showEmail': ('Email', 'البريد الإلكتروني'),
    'showVatNumber': ('VAT No', 'الرقم الضريبي'),
    'showCRNumber': ('CR No', 'السجل التجاري'),
    // A blank description prints nothing (never a "store description"
    // placeholder); a blank store name uses the active store's name.
    'showDescription': ('', ''),
    'showCustomerName': ('Customer', 'العميل'),
    'showCustomerPhone': ('Phone', 'الهاتف'),
    'showPayment': ('Payment', 'الدفع'),
    'showPaymentMethod': ('Payment', 'الدفع'),
    'showCustomerAddress': ('Address', 'العنوان'),
    'showComment': ('Comment', 'تعليق'),
    'showOrderComment': ('Comment', 'تعليق'),
    'showDeliveryMethod': ('Delivery', 'التوصيل'),
    'showDeliveryPhone': ('Delivery Phone', 'هاتف التوصيل'),
    'showCustomerVatNumber': ('Customer VAT', 'الرقم الضريبي للعميل'),
    'showCustomerCrNumber': ('Customer CR', 'السجل التجاري للعميل'),
    'showSLNumber': ('SL#', '#'),
    'showParticulars': ('Item', 'البيان'),
    'showMRP': ('MRP', 'MRP'),
    'showQty': ('Qty', 'الكمية'),
    'showRate': ('Rate', 'السعر'),
    'showRateExcTax': ('Rate Ex Tax', 'السعر بدون ضريبة'),
    'showUnit': ('Unit', 'الوحدة'),
    'showTaxHeader': ('Tax', 'الضريبة'),
    'showTotal': ('Total', 'الإجمالي'),
    'showWarranty': ('Warranty', 'الضمان'),
    'showSubTotal': ('NET TOTAL (Exc Tax)', 'المجموع'),
    'showDiscount': ('DISCOUNTS', 'الخصم'),
    'showTax': ('VAT', 'الضريبة'),
    'showNetAmount': ('GRAND TOTAL', 'المبلغ الاجمالي'),
    'showCash': ('Cash', 'نقدي'),
    'showItemsCount': ('Items', 'العدد'),
    'showQuantityCount': ('Total Qty', 'إجمالي الكمية'),
    'showSaved': ('You Saved', 'لقد وفرت'),
    'showCustomerPrevBalance': ('Previous Balance', 'الرصيد السابق'),
    'showCustomerPaidAmount': ('Paid Amount', 'المبلغ المدفوع'),
    'showCustomerCurrentBalance': ('Current Balance', 'الرصيد الحالي'),
    'showBankInfo': ('BANK DETAILS', 'تفاصيل البنك'),
    'showBankName': ('Bank', 'البنك'),
    'showAccountName': ('Account Name', 'اسم الحساب'),
    'showAccountNumber': ('Account Number', 'رقم الحساب'),
    'showIBAN': ('IBAN', 'الآيبان'),
    'showSwiftCode': ('SWIFT', 'سويفت'),
    'showVATFooter': ('VAT', 'الرقم الضريبي'),
  };

  ({
    String english,
    String arabic,
    String? resolvedEnglish,
    String? resolvedArabic,
  }) _fieldFallback(String key) {
    final labels = billDocumentConfig.resolvedLabels;
    // Item-table headers: bilingual documents consult both resolved labels,
    // single-language documents only the value-side one — as the thermal
    // header always has.
    String? englishResolved(String? value) =>
        receiptLanguageMode.isBilingual ? value : null;
    ({
      String english,
      String arabic,
      String? resolvedEnglish,
      String? resolvedArabic,
    }) fallback(
      String english,
      String arabic, {
      String? resolvedEnglish,
      String? resolvedArabic,
    }) =>
        (
          english: english,
          arabic: arabic,
          resolvedEnglish: resolvedEnglish,
          resolvedArabic: resolvedArabic,
        );

    switch (key) {
      case 'showStoreName':
        final name = storeName?.trim() ?? '';
        return name.isNotEmpty
            ? fallback(name, name)
            : fallback('STORE NAME', 'اسم المتجر');
      case 'showInvoiceTitle':
        return fallback(_printTitle ?? 'INVOICE', 'فاتورة');
      case 'showQRCode':
        return hasZatcaCredentials
            ? fallback('ZATCA E-Invoice QR', 'فاتورة الكترونية')
            : fallback('Scan to Pay', 'امسح للدفع');
      case 'showOrderNumberInFooter':
        final prefix = ReceiptConfigurationContract.numberPrefix(
          billDocumentConfig.numberPrefix,
          receiptLanguageMode,
          englishFallback: 'INV NO:',
          arabicFallback: 'رقم الفاتورة:',
        );
        return fallback(prefix, prefix);
      case 'showDate':
        return fallback('', '', resolvedArabic: labels?.date);
      case 'showTax':
        return fallback('VAT', 'الضريبة', resolvedArabic: labels?.tax);
      case 'showSLNumber':
        return fallback('SL#', '#',
            resolvedArabic: labels?.slNumber,
            resolvedEnglish: englishResolved(labels?.slNumberDefault));
      case 'showParticulars':
        return fallback('Item', 'البيان',
            resolvedArabic: labels?.particulars,
            resolvedEnglish: englishResolved(labels?.particularsDefault));
      case 'showMRP':
        return fallback('MRP', 'MRP', resolvedArabic: labels?.mrp);
      case 'showQty':
        return fallback('Qty', 'الكمية',
            resolvedArabic: labels?.qty,
            resolvedEnglish: englishResolved(labels?.qtyDefault));
      case 'showRate':
        return fallback('Rate', 'السعر',
            resolvedArabic: labels?.rate,
            resolvedEnglish: englishResolved(labels?.rateDefault));
      case 'showUnit':
        return fallback('Unit', 'الوحدة', resolvedArabic: labels?.unitName);
      case 'showTaxHeader':
        return fallback('Tax', 'الضريبة',
            resolvedArabic: labels?.tax,
            resolvedEnglish: englishResolved(labels?.taxDefault));
      case 'showTotal':
        return fallback('Total', 'الإجمالي',
            resolvedArabic: labels?.total,
            resolvedEnglish: englishResolved(labels?.totalDefault));
    }
    final pair = _fieldFallbacks[key] ?? ('', '');
    return fallback(pair.$1, pair.$2);
  }

  String? get _printTitle {
    try {
      final title = Provider.of<AppSettingsProvider>(context, listen: false)
          .appSettings
          ?.printTitle
          .trim();
      return title == null || title.isEmpty ? null : title;
    } catch (_) {
      return null;
    }
  }

  /// The label a display key prints on this document — the same text on every
  /// template. [inlineBilingual] joins a two-language label on one line.
  String fieldLabel(String key, {bool inlineBilingual = false}) {
    final fallback = _fieldFallback(key);
    return labelFor(
      key,
      englishFallback: fallback.english,
      arabicFallback: fallback.arabic,
      resolvedEnglish: fallback.resolvedEnglish,
      resolvedArabic: fallback.resolvedArabic,
      inlineBilingual: inlineBilingual,
    );
  }

  /// [fieldLabel] split into its Arabic and English lines, for templates that
  /// print the two languages in separate cells or columns.
  ReceiptLabelParts fieldLabelParts(String key) {
    final fallback = _fieldFallback(key);
    return ReceiptConfigurationContract.labelParts(
      options: displayConfig,
      key: key,
      mode: receiptLanguageMode,
      englishFallback: fallback.english,
      arabicFallback: fallback.arabic,
      resolvedEnglish: fallback.resolvedEnglish,
      resolvedArabic: fallback.resolvedArabic,
    );
  }

  /// `label: value` for [key] on one line (bilingual labels inline).
  String labelledField(String key, String value) =>
      ReceiptConfigurationContract.labelled(
        fieldLabel(key, inlineBilingual: true),
        value,
      );

  /// `label: value` per language line, for two-column templates. When the key
  /// resolves to no label at all, [value] goes to the document's own column.
  ReceiptLabelParts labelledFieldParts(String key, String value) {
    final parts = fieldLabelParts(key);
    if (parts.isEmpty) {
      return receiptLanguageMode.isEnglish
          ? ReceiptLabelParts(english: value)
          : ReceiptLabelParts(arabic: value);
    }
    String join(String label) =>
        label.isEmpty ? '' : ReceiptConfigurationContract.labelled(label, value);
    return ReceiptLabelParts(
      arabic: join(parts.arabic),
      english: join(parts.english),
    );
  }

  /// Template-owned text with no display key (signatures, page numbers,
  /// section headings). Nothing can be typed for it, so it follows the rule
  /// for an empty key: English documents print [english]; Arabic and
  /// bilingual documents print the built-in Arabic.
  String rendererText({required String english, required String arabic}) =>
      receiptLanguageMode.isEnglish ? english : arabic;

  /// "Page 1 of 2" on English documents; a language-neutral "1 / 2" on Arabic
  /// and bilingual ones (the PDF engine drops the space between Arabic words
  /// and digits inside one run).
  String pageNumberText(int page, int pageCount) => rendererText(
        english: 'Page $page of $pageCount',
        arabic: '$page / $pageCount',
      );

  /// Order date and time as every template prints them. Draw it as its own
  /// left-to-right text: inside an Arabic run the bidi algorithm would reorder
  /// it ("PM 03:10 24-09-2026"), and the PDF engine has no isolate support.
  String get orderDateTimeText {
    try {
      final date = isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(orderDate)
          : DateHelper.formatISODate(orderDate);
      final time = isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(orderDate)
          : DateHelper.formatISOTimeOnlyToIST(orderDate);
      return time.trim().isEmpty ? date : '$date  $time';
    } catch (_) {
      return orderDate;
    }
  }

  /// `<showTokenNumber label>: 286` (a symbol prefix such as `#` stays
  /// attached). Empty when hidden or when the order has no token.
  String get tokenText {
    final token = tokenNumber?.trim() ?? '';
    if (!isVisible('showTokenNumber') || token.isEmpty) return '';
    final prefix = ReceiptConfigurationContract.withoutTrailingColon(
      fieldLabel('showTokenNumber', inlineBilingual: true),
    );
    if (prefix.isEmpty) return token;
    final separator = RegExp(r'[A-Za-z؀-ۿ]$').hasMatch(prefix) ? ': ' : '';
    return '$prefix$separator$token';
  }

  /// Store VAT / CR registration line (`showVatNumber` / `showCRNumber`). The
  /// number always comes from the store's ZATCA registration.
  String storeTaxText(String key) {
    final number = (key == 'showCRNumber' ? zatcaCrNumber : zatcaVatNumber)
            ?.trim() ??
        '';
    if (!isVisible(key) || number.isEmpty) return '';
    return labelledField(key, number);
  }

  /// Footer VAT line: `<showVATFooter label> 300000000000003`.
  String get vatFooterText {
    final vat = zatcaVatNumber?.trim() ?? '';
    if (!isVisible('showVATFooter') || vat.isEmpty) return '';
    return '${fieldLabel('showVATFooter', inlineBilingual: true)} $vat'.trim();
  }

  /// Footer order number: `<showOrderNumberInFooter label> 15`.
  String get orderNumberFooterText {
    if (!isVisible('showOrderNumberInFooter')) return '';
    final label = fieldLabel('showOrderNumberInFooter', inlineBilingual: true);
    return '$label $printableOrderNumberComponent'.trim();
  }

  /// Caption printed above the QR code.
  String get qrCaption => fieldLabel('showQRCode', inlineBilingual: true);

  /// Bank block heading (`showBankInfo`).
  String get bankDetailsHeading =>
      fieldLabel('showBankInfo', inlineBilingual: true);

  /// `(label, value)` for each enabled bank field that has a value. Empty when
  /// `showBankInfo` is off.
  List<(String, String)> get bankDetailRows {
    if (!isVisible('showBankInfo')) return const [];
    final bank = primaryBank;
    final account = primaryBankAccount;
    final rows = <(String, String)>[];
    void add(String key, String? value) {
      final clean = value?.trim() ?? '';
      if (isVisible(key) && clean.isNotEmpty) {
        rows.add((
          ReceiptConfigurationContract.withoutTrailingColon(
              fieldLabel(key, inlineBilingual: true)),
          clean,
        ));
      }
    }

    add('showBankName', bank?.bankName);
    add('showAccountName', account?.accountHolderName);
    add('showAccountNumber', account?.accountNumber);
    add('showIBAN', account?.iban);
    add('showSwiftCode', account?.swiftCode);
    return rows;
  }

  /// Printable name of a payment method: the configured `showCash` label for
  /// cash, renderer names for card / UPI, otherwise the method's own name.
  String paymentMethodName(String method) {
    final clean = method.trim();
    switch (clean.toUpperCase()) {
      case 'CASH':
        return fieldLabel('showCash', inlineBilingual: true);
      case 'CARD':
        return rendererText(english: 'Card', arabic: 'بطاقة');
      case 'UPI':
        return 'UPI';
      default:
        return clean;
    }
  }

  /// Per-method amounts from [paymentBreakdown] or a multi-payment JSON
  /// [paymentMethod]; null when the order was paid with a single method.
  Map<String, dynamic>? get _paymentAmounts {
    var breakdown = paymentBreakdown;
    if (breakdown != null && breakdown['amounts'] is Map) {
      breakdown = Map<String, dynamic>.from(breakdown['amounts'] as Map);
    }
    if (breakdown != null && breakdown.isNotEmpty) return breakdown;
    final raw = paymentMethod?.trim() ?? '';
    if (!raw.startsWith('{')) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map &&
          decoded['isMultiPayment'] == true &&
          decoded['amounts'] is Map) {
        return Map<String, dynamic>.from(decoded['amounts'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// `(method name, amount)` rows of the payment breakdown, printed when a
  /// paid amount exists and `showPaymentBreaked` is on.
  List<(String, double)> get paymentBreakdownRows {
    if (paidAmount == null || !isVisible('showPaymentBreaked')) return const [];
    final amounts = _paymentAmounts;
    if (amounts != null) {
      final rows = <(String, double)>[];
      amounts.forEach((method, amount) {
        final value = double.tryParse(amount.toString()) ?? 0.0;
        if (value > 0) rows.add((paymentMethodName(method), value));
      });
      if (rows.isNotEmpty) return rows;
    }
    final method = paymentMethod?.trim() ?? '';
    final label = method.isEmpty || method.startsWith('{')
        ? fieldLabel('showCash', inlineBilingual: true)
        : paymentMethodName(method);
    return [(label, paidAmount!)];
  }

  /// Payment method(s) for the customer section, e.g. `نقدي, بطاقة`.
  String get paymentMethodSummary {
    final amounts = _paymentAmounts;
    if (amounts != null) {
      final names = <String>[
        for (final entry in amounts.entries)
          if ((double.tryParse(entry.value.toString()) ?? 0.0) > 0)
            paymentMethodName(entry.key),
      ];
      if (names.isNotEmpty) return names.join(', ');
    }
    final method = paymentMethod?.trim() ?? '';
    return method.isEmpty || method.startsWith('{')
        ? ''
        : paymentMethodName(method);
  }

  /// `(label, amount, emphasised)` rows of the customer balance block. Empty
  /// for walk-in customers, when `showCustomerBalance` is off, or when the
  /// order carries no balance.
  List<(String, double, bool)> get customerBalanceRows {
    if (!isVisible('showCustomerBalance') || isDefaultCustomer) {
      return const [];
    }
    if (customerOldBalance == null && customerCurrentBalance == null) {
      return const [];
    }
    String label(String key) => ReceiptConfigurationContract.withoutTrailingColon(
        fieldLabel(key, inlineBilingual: true));
    return [
      if (isVisible('showCustomerPrevBalance') && customerOldBalance != null)
        (label('showCustomerPrevBalance'), customerOldBalance!, false),
      if (isVisible('showCustomerPaidAmount') && paidAmount != null)
        (label('showCustomerPaidAmount'), paidAmount!, false),
      if (isVisible('showCustomerCurrentBalance') &&
          customerCurrentBalance != null)
        (label('showCustomerCurrentBalance'), customerCurrentBalance!, true),
    ];
  }

  /// Amount in words, one entry per printed line, in [amountInWordsLanguage]:
  /// English on English documents, Arabic on Arabic and bilingual ones.
  List<String> amountInWordsLines(double amount, {required String currency}) {
    final language = amountInWordsLanguage;
    final words = AmountHelper()
        .convertNumberToWords(amount, currency: currency, language: language);
    return ['$words${language == 'ar' ? ' فقط.' : ' Only.'}'];
  }

  /// Item name lines as every template prints them: Arabic above English on a
  /// bilingual document (when the product has an Arabic name), the Arabic name
  /// alone on an Arabic document, otherwise the English name. Variant
  /// attributes follow the primary name.
  List<String> itemNameLines(dynamic item) {
    String text(dynamic value) => value?.toString().trim() ?? '';
    var arabic = '';
    var english = '';
    var attributes = '';
    if (item is Map) {
      String fromNames(String field, String language) {
        final names = item[field];
        return names is Map ? text(names[language]) : '';
      }

      arabic = [
        fromNames('names', 'ar'),
        fromNames('product_names', 'ar'),
        fromNames('productNames', 'ar'),
        text(item['product_name_ar']),
        text(item['productNameAr']),
      ].firstWhere((name) => name.isNotEmpty, orElse: () => '');
      english = [
        fromNames('names', 'en'),
        text(item['productName']),
        text(item['product_name']),
      ].firstWhere((name) => name.isNotEmpty, orElse: () => '');
      attributes = _variantText(
          item['variant_attributes'] ?? item['variantAttributes']);
    } else {
      try {
        arabic = text(item.names?.ar);
        english = text(item.names?.en);
      } catch (_) {}
      if (english.isEmpty) {
        try {
          english = text(item.productName);
        } catch (_) {}
      }
      try {
        attributes = _variantText(item.variantAttributes);
      } catch (_) {}
    }
    String withAttributes(String name) =>
        attributes.isEmpty || name.contains('($attributes)')
            ? name
            : (name.isEmpty ? attributes : '$name ($attributes)');

    if (arabic.isNotEmpty && receiptLanguageMode.isBilingual) {
      return [arabic, withAttributes(english)]
          .where((line) => line.isNotEmpty)
          .toList();
    }
    if (arabic.isNotEmpty && receiptLanguageMode.isArabic) {
      return [withAttributes(arabic)];
    }
    return [withAttributes(english)];
  }

  static String _variantText(dynamic raw) {
    var attributes = raw;
    if (attributes is String) {
      final trimmed = attributes.trim();
      if (trimmed.isEmpty) return '';
      try {
        attributes = json.decode(trimmed);
      } catch (_) {
        return trimmed;
      }
    }
    if (attributes is! Map) return '';
    return attributes.values
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' | ');
  }

  String labelFor(
    String key, {
    required String englishFallback,
    required String arabicFallback,
    String? resolvedEnglish,
    String? resolvedArabic,
    bool inlineBilingual = false,
  }) {
    return ReceiptConfigurationContract.label(
      options: displayConfig,
      key: key,
      mode: receiptLanguageMode,
      englishFallback: englishFallback,
      arabicFallback: arabicFallback,
      resolvedEnglish: resolvedEnglish,
      resolvedArabic: resolvedArabic,
      inlineBilingual: inlineBilingual,
    );
  }

  /// Resolve renderer-owned text (for example payment method names) with the
  /// same EN/AR/bilingual semantics as configured labels.
  String textForMode({
    required String english,
    required String arabic,
    bool inlineBilingual = false,
  }) =>
      rendererText(english: english, arabic: arabic);

  String documentText(
    String? text, {
    String? englishFallback,
    String? arabicFallback,
  }) {
    return ReceiptConfigurationContract.documentText(
      text,
      receiptLanguageMode,
      englishFallback: englishFallback,
      arabicFallback: arabicFallback,
    );
  }

  /// Get the active theme, defaulting to 'classic'
  String get activeTheme => billDocumentConfig.activeTheme ?? 'classic';

  /// Check if this is a thermal paper size (58mm, 80mm, or 112mm)
  bool get isThermal {
    final normalized =
        selectedPaperSize.trim().toLowerCase().replaceAll(' ', '');
    return normalized == '58mm' ||
        normalized == '80mm' ||
        normalized == '112mm';
  }

  /// Check if this is 58mm paper
  bool get is58mm => thermalPaperProfile.is58mm;

  /// Shared thermal paper profile.  In particular, 112 mm is raster-only
  /// because esc_pos_utils_plus does not expose a custom-width PaperSize.
  ThermalPaperProfile get thermalPaperProfile =>
      ThermalPaperProfile.fromSelection(selectedPaperSize);

  /// Get print width for image-based printing
  double get printWidth => thermalPaperProfile.rasterWidthPx.toDouble();

  /// Get base font size for image-based printing
  double get baseFontSize => thermalPaperProfile.is80mm ? 28.0 : 20.0;

  /// Total tax for display. Prefers the API-provided post-discount value
  /// (price_summary.total_tax). Falls back to summing item-level taxAmount for
  /// offline/local-storage orders where the API value is unavailable.
  double get totalTax {
    if (apiTotalTax != null) return apiTotalTax!;
    double tax = 0.0;
    for (var item in cartItems) {
      if (isFromLocalStorage || item is Map) {
        tax += double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
      } else {
        tax += double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
      }
    }
    return tax;
  }

  /// Calculate total quantity from cart items
  double get totalQuantity {
    double qty = 0.0;
    for (var item in cartItems) {
      if (isFromLocalStorage || item is Map) {
        qty += double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      } else {
        qty += double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0;
      }
    }
    return qty;
  }

  /// Check if order has returns
  bool get hasReturns =>
      orderReturns != null &&
      orderReturns!.returnItems != null &&
      orderReturns!.returnItems!.isNotEmpty;

  /// Check if ZATCA credentials are available for Saudi Arabia e-invoicing
  bool get hasZatcaCredentials =>
      zatcaVatNumber != null &&
      zatcaVatNumber!.isNotEmpty &&
      zatcaCompanyName != null &&
      zatcaCompanyName!.isNotEmpty;

  /// Get the total amount as double
  double get totalAmountAsDouble => double.tryParse(formattedTotal) ?? 0.0;

  StoreBank? get primaryBank {
    for (final bank in bankDetails) {
      if (bank.isActive && bank.bankAccounts.isNotEmpty) {
        return bank;
      }
    }
    for (final bank in bankDetails) {
      if (bank.bankAccounts.isNotEmpty) {
        return bank;
      }
    }
    if (bankDetails.isEmpty) {
      return null;
    }
    return bankDetails.first;
  }

  StoreBankAccount? get primaryBankAccount => primaryBank?.primaryAccount;

  List<String> get bankAccountDetailLines {
    final bank = primaryBank;
    final account = primaryBankAccount;
    final lines = <String>[];

    void addLine(String label, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        lines.add('$label: $trimmed');
      }
    }

    addLine('Bank', bank?.bankName);
    addLine('Branch', bank?.headOffice);
    addLine('A/C Name', account?.accountHolderName);
    addLine('A/C No', account?.accountNumber);
    addLine('IBAN', account?.iban);
    addLine('IFSC', account?.ifsc);

    final swiftCode = account?.swiftCode?.trim();
    final ifsc = account?.ifsc?.trim();
    if (swiftCode != null && swiftCode.isNotEmpty && swiftCode != ifsc) {
      lines.add('SWIFT: $swiftCode');
    }

    addLine('Phone', account?.phoneNumber ?? bank?.phone);
    addLine('Email', account?.emailId);

    return lines;
  }

  /// Returns bank detail lines enabled by the document configuration, as
  /// `label: value` with the configured (or built-in) labels of [bankDetailRows].
  ///
  /// `showBankInfo` is the master switch. The individual fields are controlled
  /// by `showBankName`, `showAccountName`, `showAccountNumber`, `showIBAN`, and
  /// `showSwiftCode`, matching the API's `display_configuration` keys.
  List<String> visibleBankAccountDetailLines(
          [Map<String, DisplayOption>? displayConfig]) =>
      [for (final row in bankDetailRows) '${row.$1}: ${row.$2}'];
}
