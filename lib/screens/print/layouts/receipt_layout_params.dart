import 'package:flutter/material.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';

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
    this.paymentBreakdown,
    this.zatcaVatNumber,
    this.zatcaCompanyName,
    this.isDefaultCustomer = false,
    this.hideDefaultCustomerPhone = true,
    this.netExcTax,
  });

  /// Get the display configuration options from the document config
  Map<String, DisplayOption>? get displayConfig =>
      billDocumentConfig.displayConfiguration?.options;

  /// Check if the document is configured for RTL (Arabic)
  bool get isRtl {
    final configLanguage = billDocumentConfig.language;
    return configLanguage == 'ar';
  }

  /// Check if the document is configured for English
  bool get isEnglish {
    final configLanguage = billDocumentConfig.language;
    return configLanguage == null || configLanguage == 'en';
  }

  /// Check if the document is bilingual
  bool get isBilingual {
    final configLanguage = billDocumentConfig.language;
    return configLanguage == 'bilingual';
  }

  /// Get the active theme, defaulting to 'classic'
  String get activeTheme => billDocumentConfig.activeTheme ?? 'classic';

  /// Check if this is a thermal paper size (58mm or 80mm)
  bool get isThermal =>
      selectedPaperSize == '58mm' || selectedPaperSize == '80mm';

  /// Check if this is 58mm paper
  bool get is58mm => selectedPaperSize == '58mm';

  /// Get print width for image-based printing
  double get printWidth => is58mm ? 384.0 : 576.0;

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
}
