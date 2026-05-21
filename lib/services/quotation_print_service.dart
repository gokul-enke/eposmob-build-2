import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/screens/print/print.dart';

class QuotationPrintService {
  const QuotationPrintService();

  Future<bool> printQuotationDetails(
    BuildContext context,
    QuotationDetailsData details, {
    String? paymentMethod,
    Map<String, dynamic>? paymentBreakdown,
    double? paidAmount,
    String? deliveryMethod,
    String? customerType,
    bool isDefaultCustomer = false,
    double? customerOldBalance,
  }) async {
    final printPayload = buildPrintPayload(
      details,
      paymentMethod: paymentMethod,
      paymentBreakdown: paymentBreakdown,
      paidAmount: paidAmount,
      deliveryMethod: deliveryMethod,
      customerType: customerType,
      isDefaultCustomer: isDefaultCustomer,
      customerOldBalance: customerOldBalance,
    );

    debugPrint(
        '🧾 QUOTATION PRINT SERVICE PAYLOAD: ${json.encode(printPayload)}');

    final autoPrintSuccess = await PrintPage.autoPrint(
      context,
      storeName: printPayload['storeName'] as String?,
      cartItems: printPayload['cartItems'] as List<dynamic>,
      formattedTotal: printPayload['formattedTotal'] as String,
      discountAmount: printPayload['discountAmount'] as String?,
      orderDate: printPayload['orderDate'] as String,
      orderNumber: printPayload['orderNumber'] as String,
      isFromLocalStorage: true,
      customerName: printPayload['customerName'] as String?,
      customerPhone: printPayload['customerPhone'] as String?,
      customerOldBalance: printPayload['customerOldBalance'] as double?,
      paidAmount: printPayload['paidAmount'] as double?,
      paymentMethod: printPayload['paymentMethod'] as String?,
      paymentBreakdown:
          printPayload['paymentBreakdown'] as Map<String, dynamic>?,
      customerType: printPayload['customerType'] as String?,
      documentTitleOverride: printPayload['documentTitleOverride'] as String?,
      orderComment: printPayload['orderComment'] as String?,
      deliveryMethod: printPayload['deliveryMethod'] as String?,
      isDefaultCustomer: printPayload['isDefaultCustomer'] == true,
      netExcTax: printPayload['netExcTax'] as String?,
    );

    if (!autoPrintSuccess && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: printPayload['storeName'] as String?,
            cartItems: printPayload['cartItems'] as List<dynamic>,
            formattedTotal: printPayload['formattedTotal'] as String,
            discountAmount: printPayload['discountAmount'] as String?,
            orderDate: printPayload['orderDate'] as String,
            orderNumber: printPayload['orderNumber'] as String,
            isFromLocalStorage: true,
            customerName: printPayload['customerName'] as String?,
            customerPhone: printPayload['customerPhone'] as String?,
            customerOldBalance: printPayload['customerOldBalance'] as double?,
            paidAmount: printPayload['paidAmount'] as double?,
            paymentMethod: printPayload['paymentMethod'] as String?,
            paymentBreakdown:
                printPayload['paymentBreakdown'] as Map<String, dynamic>?,
            customerType: printPayload['customerType'] as String?,
            documentTitleOverride:
                printPayload['documentTitleOverride'] as String?,
            orderComment: printPayload['orderComment'] as String?,
            deliveryMethod: printPayload['deliveryMethod'] as String?,
            isDefaultCustomer: printPayload['isDefaultCustomer'] == true,
            netExcTax: printPayload['netExcTax'] as String?,
          ),
        ),
      );
    }

    return autoPrintSuccess;
  }

  Map<String, dynamic> buildPrintPayload(
    QuotationDetailsData details, {
    String? paymentMethod,
    Map<String, dynamic>? paymentBreakdown,
    double? paidAmount,
    String? deliveryMethod,
    String? customerType,
    bool isDefaultCustomer = false,
    double? customerOldBalance,
  }) {
    final cartItems = (details.items ?? [])
        .map((item) => {
              'productName': item.productName ?? 'NA',
              'product_name': item.productName ?? 'NA',
              'quantity': item.quantity ?? '0',
              'productUnit': item.unit ?? '',
              'product_unit': item.unit ?? '',
              'unit': item.unit ?? '',
              'unitPrice': item.unitPrice ?? '0',
              'unit_price': item.unitPrice ?? '0',
              'tax_amount': item.taxAmount ?? '0',
              'taxAmount': item.taxAmount ?? '0',
              'totalPrice': item.totalPrice ?? '0',
              'total_price': item.totalPrice ?? '0',
            })
        .toList();

    final quotationNumber = details.quotationNumber?.trim().isNotEmpty == true
        ? details.quotationNumber!.trim()
        : 'Quotation-${details.id ?? ''}';
    final quotationDate = details.quotationDate?.trim().isNotEmpty == true
        ? details.quotationDate!.trim()
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    return {
      'cartItems': cartItems,
      'formattedTotal': details.grandTotal ?? '0.00',
      'discountAmount': details.discount ?? '0.00',
      'orderDate': quotationDate,
      'orderNumber': quotationNumber,
      'storeName': details.store?.name,
      'customerName': details.customer?.name,
      'customerPhone': details.customer?.phone,
      'customerOldBalance': customerOldBalance,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'paymentBreakdown': paymentBreakdown,
      'customerType': customerType,
      'documentTitleOverride': 'QUOTATION',
      'orderComment': details.expiryDate?.trim().isNotEmpty == true
          ? 'Valid until: ${details.expiryDate}'
          : null,
      'deliveryMethod': deliveryMethod,
      'isDefaultCustomer': isDefaultCustomer,
      'netExcTax': details.subTotal,
    };
  }
}
