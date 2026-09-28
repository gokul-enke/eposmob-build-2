import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/models/customer_list.dart';
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
    String? customerVatNumber,
    String? customerCrNumber,
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
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
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
      customerVatNumber: printPayload['customerVatNumber'] as String?,
      customerCrNumber: printPayload['customerCrNumber'] as String?,
      documentConfigType: printPayload['documentConfigType'] as String?,
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
            customerVatNumber: printPayload['customerVatNumber'] as String?,
            customerCrNumber: printPayload['customerCrNumber'] as String?,
            documentConfigType: printPayload['documentConfigType'] as String?,
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

  /// Customer VAT number from a billing customer's KYC entries.
  static String? vatNumberFromKyc(List<Kyc>? kyc) =>
      QuotationCustomer.kycValue(_kycMaps(kyc), QuotationCustomer.vatKycKeys);

  /// Customer CR number from a billing customer's KYC entries.
  static String? crNumberFromKyc(List<Kyc>? kyc) =>
      QuotationCustomer.kycValue(_kycMaps(kyc), QuotationCustomer.crKycKeys);

  static List<Map<String, dynamic>>? _kycMaps(List<Kyc>? kyc) =>
      kyc?.map((item) => {'key': item.key, 'value': item.value}).toList();

  static String? _firstNonEmpty(String? primary, String? fallback) {
    final value = primary?.trim();
    if (value != null && value.isNotEmpty) return value;
    final other = fallback?.trim();
    return other == null || other.isEmpty ? null : other;
  }

  Map<String, dynamic> buildPrintPayload(
    QuotationDetailsData details, {
    String? paymentMethod,
    Map<String, dynamic>? paymentBreakdown,
    double? paidAmount,
    String? deliveryMethod,
    String? customerType,
    String? customerVatNumber,
    String? customerCrNumber,
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

    // Caller values come from the live billing customer; the quotation's own
    // customer covers reprints from the quotation list.
    final customer = details.customer;

    return {
      'cartItems': cartItems,
      'formattedTotal': details.grandTotal ?? '0.00',
      'discountAmount': details.discount ?? '0.00',
      'orderDate': quotationDate,
      'orderNumber': quotationNumber,
      'storeName': details.store?.name,
      'customerName': customer?.name,
      'customerPhone': customer?.phone,
      'customerOldBalance': customerOldBalance,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'paymentBreakdown': paymentBreakdown,
      'customerType': _firstNonEmpty(customerType, customer?.customerType),
      'customerVatNumber':
          _firstNonEmpty(customerVatNumber, customer?.vatNumber),
      'customerCrNumber': _firstNonEmpty(customerCrNumber, customer?.crNumber),
      'documentConfigType': 'Quotation',
      'orderComment': details.expiryDate?.trim().isNotEmpty == true
          ? 'Valid until: ${details.expiryDate}'
          : null,
      'deliveryMethod': deliveryMethod,
      'isDefaultCustomer': isDefaultCustomer,
      'netExcTax': details.subTotal,
    };
  }
}
