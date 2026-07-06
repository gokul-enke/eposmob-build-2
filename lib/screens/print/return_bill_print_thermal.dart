import 'package:flutter/material.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/layouts/premium2_receipt_layout.dart';
import 'package:pos_machine/screens/print/return_bill_layout_params_builder.dart';

class ReturnBillThermalPrinter {
  final BuildContext context;

  ReturnBillThermalPrinter(this.context);

  Future<void> printReturnBill({
    required BluetoothPrinter selectedPrinter,
    required List<OrderReturnItem> returnItems,
    List<OrderDetailsModelDataCartItem>? originalCartItems,
    required String returnTotalAmount,
    required String orderDate,
    required String orderNumber,
    required String selectedPaperSize,
    required DocumentConfig? returnBillDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerBalance,
  }) async {
    if (returnBillDocumentConfig == null) {
      debugPrint('ERROR: Return Bill document configuration not loaded yet.');
      return;
    }

    try {
      final params = await ReturnBillLayoutParamsBuilder.build(
        context: context,
        selectedPrinter: selectedPrinter,
        returnItems: returnItems,
        originalCartItems: originalCartItems,
        returnTotalAmount: returnTotalAmount,
        orderDate: orderDate,
        orderNumber: orderNumber,
        selectedPaperSize: selectedPaperSize,
        returnBillDocumentConfig: returnBillDocumentConfig,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        customerBalance: customerBalance,
      );

      await Premium2ReceiptLayout().printThermal(params);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Return Bill printed successfully',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('ERROR printing return bill: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error printing: $e',
        );
      }
    }
  }
}
