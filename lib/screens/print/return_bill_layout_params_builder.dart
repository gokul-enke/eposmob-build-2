import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/bank_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

/// Builds [ReceiptLayoutParams] for return-only bills so they can reuse the
/// same premium / simplified tax invoice layouts as sales bills.
class ReturnBillLayoutParamsBuilder {
  const ReturnBillLayoutParamsBuilder._();

  static Future<ReceiptLayoutParams> build({
    required BuildContext context,
    required BluetoothPrinter selectedPrinter,
    required List<OrderReturnItem> returnItems,
    List<OrderDetailsModelDataCartItem>? originalCartItems,
    required String returnTotalAmount,
    required String orderDate,
    required String orderNumber,
    required String selectedPaperSize,
    required DocumentConfig returnBillDocumentConfig,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerBalance,
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final zatcaVatNumber = prefs.getString('zatca_vat_number');
    final zatcaCompanyName = prefs.getString('zatca_company_name');

    if (!context.mounted) {
      throw StateError('Context is no longer mounted');
    }

    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final storeSession =
        Provider.of<StoreSessionProvider>(context, listen: false);
    final store = await storeSession.resolveActiveStore();
    final bankProvider = Provider.of<BankProvider>(context, listen: false);

    final fallbackCartItems =
        _returnItemsToCartItems(returnItems, returnTotalAmount);
    final cartItems =
        (originalCartItems != null && originalCartItems.isNotEmpty)
            ? originalCartItems
            : fallbackCartItems;
    final totalAmount = double.tryParse(returnTotalAmount) ?? 0.0;
    final documentTitle = _resolveDocumentTitle(returnBillDocumentConfig);
    final orderReturns = OrderReturns(
      returnTotalAmount: totalAmount.toStringAsFixed(2),
      returnItems: returnItems,
    );

    double? customerCurrentBalance;
    if (customerBalance != null && customerBalance.trim().isNotEmpty) {
      customerCurrentBalance = double.tryParse(customerBalance);
    }

    return ReceiptLayoutParams(
      context: context,
      selectedPrinter: selectedPrinter,
      cartItems: cartItems,
      formattedTotal: totalAmount.toStringAsFixed(2),
      savedTotal: '0.00',
      discountAmount: '0.00',
      orderDate: orderDate,
      orderNumber: orderNumber,
      isFromLocalStorage: false,
      selectedPaperSize: selectedPaperSize,
      billDocumentConfig: returnBillDocumentConfig,
      customerCareNumber: appSettings?.customerCarePhone ?? '',
      customerCareEmail: appSettings?.customerCareEmail ?? '',
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
      customerType: customerType,
      orderReturns: orderReturns,
      customerCurrentBalance: customerCurrentBalance,
      documentTitleOverride: documentTitle,
      zatcaVatNumber: zatcaVatNumber,
      zatcaCompanyName: zatcaCompanyName,
      hideDefaultCustomerPhone: appSettings?.hideDefaultPhone ?? true,
      netExcTax: totalAmount.toStringAsFixed(2),
      apiTotalTax: 0,
      bankDetails: bankProvider.banks,
      storeName: returnBillDocumentConfig.header ?? store?.storeName,
      storeLocation: store?.location,
      storePhone: store?.phone,
      storeEmail: store?.email,
      isReturnOnly: true,
      returnBillDocumentConfig: returnBillDocumentConfig,
    );
  }

  static String _resolveDocumentTitle(DocumentConfig config) {
    final configuredTitle =
        config.displayConfiguration?.options?['showInvoiceTitle']?.value;
    if (configuredTitle != null &&
        configuredTitle.toString().trim().isNotEmpty) {
      return configuredTitle.toString().trim();
    }
    return 'Sales Return';
  }

  static List<OrderDetailsModelDataCartItem> _returnItemsToCartItems(
    List<OrderReturnItem> returnItems,
    String returnTotalAmount,
  ) {
    final totalAmount = double.tryParse(returnTotalAmount) ?? 0.0;
    final totalQty = returnItems.fold<num>(
      0,
      (sum, item) => sum + (item.quantity ?? 0),
    );

    return returnItems.map((item) {
      final qty = item.quantity ?? 0;
      final lineTotal = totalQty > 0 ? totalAmount * qty / totalQty : 0.0;
      final unitPrice = qty > 0 ? lineTotal / qty : 0.0;

      return OrderDetailsModelDataCartItem(
        productName: item.productName,
        quantity: qty,
        unitPrice: unitPrice.toStringAsFixed(2),
        totalPrice: lineTotal.toStringAsFixed(2),
        mrp: unitPrice.toStringAsFixed(2),
        taxAmount: '0.00',
      );
    }).toList();
  }
}
