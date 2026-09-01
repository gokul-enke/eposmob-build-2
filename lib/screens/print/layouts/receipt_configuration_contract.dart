import 'package:pos_machine/models/document_configurations.dart';

/// The only language modes a receipt renderer is allowed to consume.
///
/// The API has historically returned several spellings for bilingual
/// documents. Templates must use this normalized value instead of comparing
/// the raw configuration string themselves.
enum ReceiptLanguageMode { english, arabic, bilingual }

extension ReceiptLanguageModeX on ReceiptLanguageMode {
  bool get isEnglish => this == ReceiptLanguageMode.english;
  bool get isArabic => this == ReceiptLanguageMode.arabic;
  bool get isBilingual => this == ReceiptLanguageMode.bilingual;

  String get code => switch (this) {
        ReceiptLanguageMode.english => 'en',
        ReceiptLanguageMode.arabic => 'ar',
        ReceiptLanguageMode.bilingual => 'en_ar',
      };
}

/// Shared document-configuration semantics for every receipt theme.
///
/// The supplied Bill response contains 61 display keys. A few newer renderer
/// names are aliases for keys still used by older API responses; resolution is
/// centralized here so a theme cannot accidentally implement a different
/// contract.
class ReceiptConfigurationContract {
  ReceiptConfigurationContract._();

  static const List<String> canonicalBillKeys = [
    'showAccountName',
    'showAccountNumber',
    'showAmountInWords',
    'showBankInfo',
    'showBankName',
    'showComment',
    'showCRNumber',
    'showCustomerAddress',
    'showCustomerBalance',
    'showCustomerCrNumber',
    'showCustomerCurrentBalance',
    'showCustomerName',
    'showCustomerNameAndPhone',
    'showCustomerPaidAmount',
    'showCustomerPhone',
    'showCustomerPhoneMasked',
    'showCustomerPrevBalance',
    'showCustomerVatNumber',
    'showDate',
    'showDeliveryMethod',
    'showDeliveryPhone',
    'showDescription',
    'showDiscount',
    'showEmail',
    'showExtraHeading1',
    'showExtraHeading2',
    'showFssaiInfo',
    'showIBAN',
    'showInvoiceNumber',
    'showInvoiceTitle',
    'showInvoiceTitleB2b',
    'showItemsCount',
    'showMRP',
    'showMRPTotal',
    'showNetAmount',
    'showOrderNumberInFooter',
    'showParticulars',
    'showPayment',
    'showPaymentBreaked',
    'showQRCode',
    'showQty',
    'showQuantityCount',
    'showRate',
    'showRateExcTax',
    'showSaved',
    'showSLNumber',
    'showStoreAddress',
    'showStoreName',
    'showSubTotal',
    'showSwiftCode',
    'showTax',
    'showTaxHeader',
    'showTel',
    'showTermsConditions',
    'showThankYouMessage',
    'showTokenNumber',
    'showTotal',
    'showUnit',
    'showVATFooter',
    'showVatNumber',
    'showWarranty',
  ];

  /// Newer semantic names mapped to the legacy/API key that may be present.
  static const Map<String, List<String>> aliases = {
    'showTotalMRP': ['showMRPTotal'],
    'showTaxableAmount': ['showSubTotal'],
    'showNetTotal': ['showNetAmount'],
    'showPaymentBreakdown': ['showPaymentBreaked'],
    'showCustomerOldBalance': ['showCustomerPrevBalance'],
    'showCustomerCurrentBalance': ['showCustomerBalance'],
    'showPaidAmount': ['showCustomerPaidAmount'],
    'showBankDetails': ['showBankInfo'],
    'showBankAccountName': ['showAccountName'],
    'showBankAccountNumber': ['showAccountNumber'],
    'showBankIban': ['showIBAN'],
    'showBankSwiftCode': ['showSwiftCode'],
    'showTerms': ['showTermsConditions'],
    'showInvoiceTitleB2B': ['showInvoiceTitleB2b'],
  };

  static ReceiptLanguageMode languageMode(String? raw) {
    if (raw == null) return ReceiptLanguageMode.english;
    switch (raw.trim().toLowerCase()) {
      case 'ar':
        return ReceiptLanguageMode.arabic;
      case 'en_ar':
      case 'ar_en':
        return ReceiptLanguageMode.bilingual;
      case 'en':
        return ReceiptLanguageMode.english;
      default:
        return ReceiptLanguageMode.english;
    }
  }

  static DisplayOption? option(
    Map<String, DisplayOption>? options,
    String key,
  ) {
    if (options == null) return null;
    final direct = options[key];
    if (direct != null) return direct;
    for (final alias in aliases[key] ?? const <String>[]) {
      final resolved = options[alias];
      if (resolved != null) return resolved;
    }
    return null;
  }

  static bool isVisible(Map<String, DisplayOption>? options, String key) =>
      option(options, key)?.visible == true;

  /// Resolves a configured label according to the API's current semantics:
  /// `default` is English and `value` is Arabic. English-only responses that
  /// put their text in `value` are supported, while wrong-script leakage is
  /// rejected when a better language value exists.
  static String label({
    required Map<String, DisplayOption>? options,
    required String key,
    required ReceiptLanguageMode mode,
    required String englishFallback,
    required String arabicFallback,
    String? resolvedEnglish,
    String? resolvedArabic,
    bool inlineBilingual = false,
  }) {
    final configured = option(options, key);
    final value = _clean(configured?.value);
    final defaultValue = _clean(configured?.defaultValue);
    final safeEnglishFallback = _firstNonEmpty([
      englishFallback,
      _englishFallbackForArabic(arabicFallback),
    ]);
    final safeArabicFallback = _firstNonEmpty([
      arabicFallback,
      _arabicFallbackForEnglish(englishFallback),
    ]);
    final english = _firstNonEmpty([
      _withoutArabic(defaultValue),
      _withoutArabic(resolvedEnglish),
      _withoutArabic(resolvedArabic),
      _withoutArabic(value),
      _withoutArabic(safeEnglishFallback),
    ]);
    final arabic = _firstNonEmpty([
      _withArabic(value),
      _withArabic(resolvedArabic),
      _withArabic(defaultValue),
      // The renderer-owned fallback may legitimately be transliterated or
      // contain only punctuation/numbers.
      _clean(safeArabicFallback),
    ]);

    switch (mode) {
      case ReceiptLanguageMode.english:
        return english;
      case ReceiptLanguageMode.arabic:
        return arabic;
      case ReceiptLanguageMode.bilingual:
        if (arabic.isEmpty) return english;
        if (english.isEmpty || arabic.toLowerCase() == english.toLowerCase()) {
          return arabic;
        }
        return inlineBilingual ? '$arabic / $english' : '$arabic\n$english';
    }
  }

  /// Applies the same language filtering to document-level strings such as
  /// header, subheader, number prefix, terms, and footer.
  static String documentText(
    String? text,
    ReceiptLanguageMode mode, {
    String? englishFallback,
    String? arabicFallback,
  }) {
    final raw = _clean(text);
    if (mode.isBilingual) {
      // Document-level API fields are single strings (unlike display options,
      // which carry `default` and `value`). When a configured value contains
      // only one script, retain it and add the renderer's safe counterpart so
      // bilingual output does not silently become one-language output.
      final hasArabic = _hasArabic(raw);
      final hasLatin = RegExp(r'[A-Za-z]').hasMatch(raw);
      if (raw.isEmpty) {
        final english = _clean(englishFallback);
        final arabic = _clean(arabicFallback);
        if (english.isNotEmpty && arabic.isNotEmpty) {
          return '$arabic\n$english';
        }
        return english.isNotEmpty ? english : arabic;
      }
      if (hasArabic &&
          !hasLatin &&
          _clean(englishFallback).isNotEmpty &&
          !_hasArabic(_clean(englishFallback))) {
        return '$raw\n${_clean(englishFallback)}';
      }
      if (hasLatin &&
          !hasArabic &&
          _clean(arabicFallback).isNotEmpty &&
          _hasArabic(_clean(arabicFallback))) {
        return '$raw\n${_clean(arabicFallback)}';
      }
      return raw;
    }
    if (mode.isEnglish) {
      return _withoutArabic(raw).isNotEmpty
          ? _withoutArabic(raw)
          : _withoutArabic(englishFallback);
    }
    return _withArabic(raw).isNotEmpty
        ? _withArabic(raw)
        : _withArabic(arabicFallback);
  }

  static String _clean(dynamic value) => value?.toString().trim() ?? '';

  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _withoutArabic(String? value) {
    final clean = _clean(value);
    return _hasArabic(clean) ? '' : clean;
  }

  static String _withArabic(String? value) {
    final clean = _clean(value);
    return _hasArabic(clean) ? clean : '';
  }

  static bool _hasArabic(String value) => RegExp(r'[؀-ۿ]').hasMatch(value);

  static String _englishFallbackForArabic(String value) =>
      const {
        'اسم المتجر': 'STORE NAME',
        'وصف المتجر': 'DESCRIPTION',
        'العنوان': 'ADDRESS',
        'فاتورة': 'INVOICE',
        'معلومات FSSAI / الضريبة': 'FSSAI / TAX INFORMATION',
        'الهاتف': 'Telephone',
        'هاتف التوصيل:': 'Delivery Phone:',
        'البريد الإلكتروني': 'Email',
        'العميل:': 'Customer:',
        'الهاتف:': 'Phone:',
        'الدفع:': 'Payment:',
        'العنوان:': 'Address:',
        'تعليق:': 'Comment:',
        'التوصيل:': 'Delivery:',
        'الرقم الضريبي للعميل:': 'Customer VAT:',
        'السجل التجاري للعميل:': 'Customer CR:',
        'العدد': 'Items',
        'إجمالي الكمية': 'Total Qty',
        'المجموع': 'NET TOTAL',
        'الخصم': 'DISCOUNT',
        'الضريبة': 'VAT',
        'المبلغ الاجمالي': 'GRAND TOTAL',
        'لقد وفرت:': 'You Saved:',
        'الرصيد السابق': 'Previous Balance',
        'المبلغ المدفوع': 'Paid Amount',
        'الرصيد الحالي': 'Current Balance',
        'السابق': 'Previous',
        'المدفوع': 'Paid',
        'الحالي': 'Current',
        'نقدي': 'Cash',
        'متبقي': 'CHANGE',
        'فاتورة الكترونية': 'ZATCA E-Invoice QR',
        'امسح للدفع': 'Scan to Pay',
        'رقم إشعار الائتمان:': 'Credit Note No:',
        'تاريخ إشعار الائتمان:': 'Credit Note Date:',
        'السبب:': 'Reason:',
        'اسم العميل:': 'Customer Name:',
        'عنوان الفاتورة:': 'Billing Address:',
        'البيان': 'PARTICULARS',
        'الكمية': 'QTY',
        'السعر': 'RATE',
        'الإجمالي': 'TOTAL',
        'إجمالي العناصر:': 'Total Items:',
        'عناصر المرتجع:': 'Return Items:',
        'المبلغ الإجمالي:': 'Total Amount:',
        'إجمالي المرتجع:': 'Return Total:',
        'إجمالي إشعار الائتمان:': 'Credit Note Total:',
        'صافي مبلغ الإرجاع:': 'Return Net Amount:',
        'إجمالي الطلب': 'ORDER TOTAL',
        'المبلغ النهائي': 'FINAL TOTAL',
        'المرتجعات': 'RETURNS',
        'الضمان': 'Warranty',
        'البنك': 'Bank',
        'تفاصيل البنك': 'BANK DETAILS',
        'اسم الحساب': 'Account Name',
        'رقم الحساب': 'Account Number',
        'الآيبان': 'IBAN',
        'سويفت': 'SWIFT',
        'الرقم الضريبي': 'VAT No',
        'السجل التجاري': 'CR No',
      }[value.trim()] ??
      '';

  static String _arabicFallbackForEnglish(String value) =>
      const {
        'STORE NAME': 'اسم المتجر',
        'DESCRIPTION': 'وصف المتجر',
        'ADDRESS': 'العنوان',
        'INVOICE': 'فاتورة',
        'FSSAI / TAX INFORMATION': 'معلومات FSSAI / الضريبة',
        'Telephone': 'الهاتف',
        'Delivery Phone:': 'هاتف التوصيل:',
        'Email': 'البريد الإلكتروني',
        'Customer:': 'العميل:',
        'Phone:': 'الهاتف:',
        'Payment:': 'الدفع:',
        'Address:': 'العنوان:',
        'Comment:': 'تعليق:',
        'Delivery:': 'التوصيل:',
        'Customer VAT:': 'الرقم الضريبي للعميل:',
        'Customer CR:': 'السجل التجاري للعميل:',
        'Items': 'العدد',
        'Total Qty': 'إجمالي الكمية',
        'NET TOTAL': 'المجموع',
        'NET TOTAL (Exc Tax)': 'المجموع',
        'DISCOUNT': 'الخصم',
        'DISCOUNTS': 'الخصم',
        'VAT': 'الضريبة',
        'GRAND TOTAL': 'المبلغ الاجمالي',
        'You Saved:': 'لقد وفرت:',
        'Previous Balance': 'الرصيد السابق',
        'Paid Amount': 'المبلغ المدفوع',
        'Current Balance': 'الرصيد الحالي',
        'Previous': 'السابق',
        'Paid': 'المدفوع',
        'Current': 'الحالي',
        'Cash': 'نقدي',
        'CHANGE': 'متبقي',
        'ZATCA E-Invoice QR': 'فاتورة الكترونية',
        'Scan to Pay': 'امسح للدفع',
        'Credit Note No:': 'رقم إشعار الائتمان:',
        'Credit Note Date:': 'تاريخ إشعار الائتمان:',
        'Reason:': 'السبب:',
        'Customer Name:': 'اسم العميل:',
        'Billing Address:': 'عنوان الفاتورة:',
        'PARTICULARS': 'البيان',
        'QTY': 'الكمية',
        'RATE': 'السعر',
        'TOTAL': 'الإجمالي',
        'Total Items:': 'إجمالي العناصر:',
        'Return Items:': 'عناصر المرتجع:',
        'Total Amount:': 'المبلغ الإجمالي:',
        'Return Total:': 'إجمالي المرتجع:',
        'Credit Note Total:': 'إجمالي إشعار الائتمان:',
        'Return Net Amount:': 'صافي مبلغ الإرجاع:',
        'ORDER TOTAL': 'إجمالي الطلب',
        'RETURN TOTAL': 'إجمالي المرتجع',
        'FINAL TOTAL': 'المبلغ النهائي',
        'RETURNS': 'المرتجعات',
        'Warranty': 'الضمان',
        'Bank': 'البنك',
        'BANK DETAILS': 'تفاصيل البنك',
        'Account Name': 'اسم الحساب',
        'Account Number': 'رقم الحساب',
        'IBAN': 'الآيبان',
        'SWIFT': 'سويفت',
        'VAT No': 'الرقم الضريبي',
        'CR No': 'السجل التجاري',
      }[value.trim()] ??
      '';
}
