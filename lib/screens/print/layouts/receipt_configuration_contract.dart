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
    'showCustomerPhoneMasked': ['maskCustomerPhone'],
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
  /// `default` is English and `value` is Arabic. A same-script value is always
  /// preferred, but configured text is never dropped for being in the other
  /// script: when a store configures only Arabic on an English document, that
  /// Arabic is what prints. Renderer fallbacks apply only to keys the store
  /// left empty.
  ///
  /// [resolvedEnglish]/[resolvedArabic] come from the response's
  /// `resolved_labels`, which are master-data defaults keyed by concept rather
  /// than by display key — `resolved_labels.tax` mirrors `showTaxHeader` (the
  /// item-table column) yet every renderer also passes it for `showTax` (the
  /// totals row). They therefore rank *below* this key's own `default`/`value`:
  /// a label the store typed against this exact key must win over a master
  /// default derived from a different one.
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
    // A single-language document prints only its own language: the text the
    // store typed for that language, else the built-in text of that language.
    // It never borrows the other language's field — an Arabic document whose
    // Arabic field is empty prints the built-in Arabic, not the English the
    // store typed for English documents (and vice versa).
    final english = _firstNonEmpty([
      _withoutArabic(defaultValue),
      _withoutArabic(value),
      _withoutArabic(resolvedEnglish),
      _withoutArabic(resolvedArabic),
      // The renderer-owned fallback may be data (e.g. the store name).
      safeEnglishFallback,
    ]);
    final arabic = _firstNonEmpty([
      // `value` is the Arabic field: printed exactly as the store typed it.
      value,
      _withArabic(resolvedArabic),
      // The renderer-owned fallback may legitimately be transliterated or
      // contain only punctuation/numbers.
      _clean(safeArabicFallback),
    ]);
    // In bilingual API responses `value` is the Arabic label and `default` is
    // the English label. Each line prints only when the store typed it: a store
    // that fills every Arabic value but types English for just a few fields
    // wants English on those fields alone, so a missing `default` must never
    // be replaced by a master default or a renderer placeholder. Fallbacks
    // apply only when the store typed nothing for this key, and then the
    // Arabic one is preferred.
    final bilingualArabic = value;
    final bilingualEnglish = defaultValue;

    switch (mode) {
      case ReceiptLanguageMode.english:
        return english;
      case ReceiptLanguageMode.arabic:
        return arabic;
      case ReceiptLanguageMode.bilingual:
        if (bilingualArabic.isEmpty && bilingualEnglish.isEmpty) {
          // Nothing typed: Arabic only — never an English master label or
          // renderer placeholder.
          return _firstNonEmpty([
            _withArabic(resolvedArabic),
            _withArabic(safeArabicFallback),
            _clean(safeArabicFallback),
            _clean(resolvedArabic),
            safeEnglishFallback,
          ]);
        }
        if (bilingualArabic.isEmpty) return bilingualEnglish;
        if (bilingualEnglish.isEmpty ||
            bilingualArabic.toLowerCase() == bilingualEnglish.toLowerCase()) {
          return bilingualArabic;
        }
        return inlineBilingual
            ? '$bilingualArabic / $bilingualEnglish'
            : '$bilingualArabic\n$bilingualEnglish';
    }
  }

  /// [label] split into its language lines, for templates that print English
  /// and Arabic in separate cells. Each slot holds only what [label] would
  /// print for this document: on a bilingual document the English slot stays
  /// empty unless the store typed an English `default`, and a key with nothing
  /// typed resolves to the built-in Arabic fallback, exactly like the thermal
  /// receipt.
  static ReceiptLabelParts labelParts({
    required Map<String, DisplayOption>? options,
    required String key,
    required ReceiptLanguageMode mode,
    required String englishFallback,
    required String arabicFallback,
    String? resolvedEnglish,
    String? resolvedArabic,
  }) {
    String resolve(ReceiptLanguageMode forMode) => label(
          options: options,
          key: key,
          mode: forMode,
          englishFallback: englishFallback,
          arabicFallback: arabicFallback,
          resolvedEnglish: resolvedEnglish,
          resolvedArabic: resolvedArabic,
        );

    switch (mode) {
      case ReceiptLanguageMode.english:
        return ReceiptLabelParts(english: resolve(mode));
      case ReceiptLanguageMode.arabic:
        return ReceiptLabelParts(arabic: resolve(mode));
      case ReceiptLanguageMode.bilingual:
        final configured = option(options, key);
        final value = _clean(configured?.value);
        final defaultValue = _clean(configured?.defaultValue);
        if (value.isEmpty && defaultValue.isEmpty) {
          // Nothing typed: the fallback (built-in Arabic, or data such as the
          // store name) fills the Arabic slot — the primary line of a
          // bilingual document — so no English line is added.
          return ReceiptLabelParts(arabic: resolve(mode));
        }
        if (value.isEmpty) return ReceiptLabelParts(english: defaultValue);
        if (defaultValue.isEmpty ||
            value.toLowerCase() == defaultValue.toLowerCase()) {
          return ReceiptLabelParts(arabic: value);
        }
        return ReceiptLabelParts(arabic: value, english: defaultValue);
    }
  }

  /// Removes one trailing colon from every line so a template can add its own
  /// separator without printing `::` for a typed label such as `"Qty:"`.
  static String withoutTrailingColon(String label) => label
      .split('\n')
      .map((line) => line.trimRight().replaceFirst(RegExp(r'[:：]\s*$'), ''))
      .join('\n')
      .trim();

  /// `label: value`, or just the value when the label resolved to nothing.
  static String labelled(String label, String value) {
    final clean = withoutTrailingColon(label);
    return clean.isEmpty ? value : '$clean: $value';
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
    // Single-language modes print the configured string as the store wrote it.
    // Filtering it out by script would silently blank a header the client can
    // see in the configuration screen, so the fallback applies only when
    // nothing was configured at all.
    if (raw.isNotEmpty) return raw;
    return mode.isEnglish ? _clean(englishFallback) : _clean(arabicFallback);
  }

  /// Number prefixes are literal document configuration, not translated
  /// display labels. Preserve a configured prefix exactly once; only use the
  /// primary language's fallback when the API leaves it empty.
  static String numberPrefix(
    String? configured,
    ReceiptLanguageMode mode, {
    required String englishFallback,
    required String arabicFallback,
  }) {
    final prefix = _clean(configured);
    if (prefix.isNotEmpty) return prefix;
    // Bilingual documents add no English the store did not type.
    return mode.isEnglish ? _clean(englishFallback) : _clean(arabicFallback);
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

/// The Arabic and English lines of one resolved label. Either may be empty:
/// a bilingual document leaves [english] empty unless the store typed an
/// English `default`, and single-language documents fill only their own slot.
class ReceiptLabelParts {
  const ReceiptLabelParts({this.arabic = '', this.english = ''});

  final String arabic;
  final String english;

  bool get isEmpty => arabic.isEmpty && english.isEmpty;

  /// The same text [ReceiptConfigurationContract.label] prints: Arabic first.
  String joined({bool inline = false}) {
    if (arabic.isEmpty) return english;
    if (english.isEmpty) return arabic;
    return inline ? '$arabic / $english' : '$arabic\n$english';
  }
}
