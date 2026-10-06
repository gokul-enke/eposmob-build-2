import 'package:flutter/material.dart';

import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/print.dart';

/// Everything a sales receipt prints, gathered in one place so every source
/// (a server order reprinted from Sales, a locally confirmed sale from
/// Billing) hands [PrintPage] exactly the same set of fields.
///
/// Build it with `PrintService.receiptRequestFromOrderDetails` or
/// `PrintService.receiptRequestFromSavedOrder`, then call [send].
class ReceiptPrintRequest {
  const ReceiptPrintRequest({
    required this.cartItems,
    required this.formattedTotal,
    required this.orderDate,
    required this.orderNumber,
    this.storeName,
    this.savedTotal,
    this.discountAmount,
    this.tokenNumber,
    this.isFromLocalStorage = false,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.customerAlternatePhone,
    this.customerVatNumber,
    this.customerCrNumber,
    this.customerType,
    this.paymentMethod,
    this.paymentBreakdown,
    this.paidAmount,
    this.customerOldBalance,
    this.customerCurrentBalance,
    this.isDefaultCustomer = false,
    this.orderComment,
    this.deliveryMethod,
    this.deliveryPhone,
    this.orderReturns,
    this.netExcTax,
    this.apiTotalTax,
    this.documentConfigType = 'Bill',
  });

  final List<dynamic> cartItems;
  final String formattedTotal;
  final String orderDate;
  final String orderNumber;
  final String? storeName;
  final String? savedTotal;
  final String? discountAmount;
  final String? tokenNumber;
  final bool isFromLocalStorage;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? customerAlternatePhone;
  final String? customerVatNumber;
  final String? customerCrNumber;
  final String? customerType;
  final String? paymentMethod;
  final Map<String, dynamic>? paymentBreakdown;
  final double? paidAmount;
  final double? customerOldBalance;
  final double? customerCurrentBalance;
  final bool isDefaultCustomer;
  final String? orderComment;
  final String? deliveryMethod;
  final String? deliveryPhone;
  final OrderReturns? orderReturns;
  final String? netExcTax;
  final double? apiTotalTax;
  final String documentConfigType;

  /// Prints on the default printer; when that is not possible, opens
  /// [PrintPage] so the cashier can pick one. Returns whether the automatic
  /// print succeeded.
  Future<bool> send(BuildContext context) async {
    final autoPrintSuccess = await PrintPage.autoPrint(
      context,
      storeName: storeName,
      cartItems: cartItems,
      formattedTotal: formattedTotal,
      savedTotal: savedTotal,
      discountAmount: discountAmount,
      orderDate: orderDate,
      orderNumber: orderNumber,
      tokenNumber: tokenNumber,
      isFromLocalStorage: isFromLocalStorage,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      customerAlternatePhone: customerAlternatePhone,
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
      customerType: customerType,
      paymentMethod: paymentMethod,
      paymentBreakdown: paymentBreakdown,
      orderComment: orderComment,
      deliveryMethod: deliveryMethod,
      deliveryPhone: deliveryPhone,
      orderReturns: orderReturns,
      paidAmount: paidAmount,
      customerOldBalance: customerOldBalance,
      customerCurrentBalance: customerCurrentBalance,
      isDefaultCustomer: isDefaultCustomer,
      netExcTax: netExcTax,
      apiTotalTax: apiTotalTax,
      documentConfigType: documentConfigType,
    );

    if (!autoPrintSuccess && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: storeName,
            cartItems: cartItems,
            formattedTotal: formattedTotal,
            savedTotal: savedTotal,
            discountAmount: discountAmount,
            orderDate: orderDate,
            orderNumber: orderNumber,
            tokenNumber: tokenNumber,
            isFromLocalStorage: isFromLocalStorage,
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            customerAddress: customerAddress,
            customerAlternatePhone: customerAlternatePhone,
            customerVatNumber: customerVatNumber,
            customerCrNumber: customerCrNumber,
            customerType: customerType,
            paymentMethod: paymentMethod,
            paymentBreakdown: paymentBreakdown,
            orderComment: orderComment,
            deliveryMethod: deliveryMethod,
            deliveryPhone: deliveryPhone,
            orderReturns: orderReturns,
            paidAmount: paidAmount,
            customerOldBalance: customerOldBalance,
            customerCurrentBalance: customerCurrentBalance,
            isDefaultCustomer: isDefaultCustomer,
            netExcTax: netExcTax,
            apiTotalTax: apiTotalTax,
            documentConfigType: documentConfigType,
          ),
        ),
      );
    }

    return autoPrintSuccess;
  }
}
