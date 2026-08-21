import 'package:flutter/material.dart';
import 'package:pos_machine/models/bank.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/receipt_customer_segment.dart';
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

  const ReceiptLayoutParams({
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
    this.customerAddress,
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
  });

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
        defaultValue: options['showInvoiceTitle']?.defaultValue,
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
          defaultValue: options['showInvoiceTitle']?.defaultValue,
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
  }) {
    return ReceiptConfigurationContract.label(
      options: null,
      key: '__renderer_text__',
      mode: receiptLanguageMode,
      englishFallback: english,
      arabicFallback: arabic,
      inlineBilingual: inlineBilingual,
    );
  }

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

  /// Returns bank detail lines enabled by the document configuration.
  ///
  /// `showBankInfo` is the master switch. The individual fields are controlled
  /// by `showBankName`, `showAccountName`, `showAccountNumber`, `showIBAN`, and
  /// `showSwiftCode`, matching the API's `display_configuration` keys.
  List<String> visibleBankAccountDetailLines(
      Map<String, DisplayOption>? displayConfig) {
    bool isVisible(String key) =>
        ReceiptConfigurationContract.isVisible(displayConfig, key);

    if (!isVisible('showBankInfo')) return const [];

    final bank = primaryBank;
    final account = primaryBankAccount;
    final lines = <String>[];

    void addLine(bool visible, String label, String? value) {
      if (!visible) return;
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        lines.add('$label: $trimmed');
      }
    }

    addLine(isVisible('showBankName'), 'Bank Name', bank?.bankName);
    addLine(isVisible('showAccountName'), 'Account Name',
        account?.accountHolderName);
    addLine(isVisible('showAccountNumber'), 'Account Number',
        account?.accountNumber);
    addLine(isVisible('showIBAN'), 'IBAN', account?.iban);
    addLine(isVisible('showSwiftCode'), 'SWIFT Code', account?.swiftCode);

    return lines;
  }
}
