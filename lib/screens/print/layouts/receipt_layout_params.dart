import 'package:flutter/material.dart';
import 'package:pos_machine/models/bank.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/receipt_customer_segment.dart';

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
    this.customerAlternatePhone,
    this.paymentMethod,
    this.customerVatNumber,
    this.customerCrNumber,
    this.customerType,
    this.documentTitleOverride,
    this.paymentBreakdown,
    this.zatcaVatNumber,
    this.zatcaCompanyName,
    this.isDefaultCustomer = false,
    this.hideDefaultCustomerPhone = true,
    this.netExcTax,
    this.bankDetails = const [],
    this.storeName,
    this.storeLocation,
    this.storePhone,
    this.storeEmail,
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
    final b2bTitleValue = b2bInvoiceTitle?.value?.toString().trim();
    debugPrint(
        '[ReceiptLayoutParams] B2B title check: customerType=${customerType ?? 'null'}, hasCustomerKyc=$hasKycDetails, key=$b2bTitleKey, visible=${b2bInvoiceTitle?.visible}, value=${b2bInvoiceTitle?.value}');
    if (b2bInvoiceTitle == null ||
        (b2bInvoiceTitle.visible != true &&
            (b2bTitleValue == null || b2bTitleValue.isEmpty))) {
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

  /// Check if the document is configured for RTL (Arabic)
  bool get isRtl {
    final configLanguage = billDocumentConfig.language;
    return (configLanguage ?? '').toLowerCase() == 'ar';
  }

  /// Check if the document is configured for English
  bool get isEnglish {
    final configLanguage = billDocumentConfig.language;
    return configLanguage == null || configLanguage.toLowerCase() == 'en';
  }

  /// Check if the document is bilingual
  bool get isBilingual {
    final configLanguage = billDocumentConfig.language;
    return (configLanguage ?? '').toLowerCase() == 'bilingual';
  }

  /// Get the active theme, defaulting to 'classic'
  String get activeTheme => billDocumentConfig.activeTheme ?? 'classic';

  /// Check if this is a thermal paper size (58mm, 80mm, or 112mm)
  bool get isThermal =>
      selectedPaperSize == '58mm' ||
      selectedPaperSize == '80mm' ||
      selectedPaperSize == '112mm';

  /// Check if this is 58mm paper
  bool get is58mm => selectedPaperSize == '58mm';

  /// Get print width for image-based printing
  double get printWidth =>
      is58mm ? 384.0 : (selectedPaperSize == '112mm' ? 832.0 : 576.0);

  /// Get base font size for image-based printing
  double get baseFontSize => selectedPaperSize == '80mm' ? 28.0 : 20.0;

  /// Calculate total tax from cart items
  double get totalTax {
    double tax = 0.0;
    for (var item in cartItems) {
      if (isFromLocalStorage) {
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
      if (isFromLocalStorage) {
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
}
