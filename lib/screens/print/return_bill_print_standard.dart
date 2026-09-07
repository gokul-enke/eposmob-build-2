import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/return_bill_layout_params_builder.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';

class ReturnBillStandardPrinter {
  final BuildContext context;

  ReturnBillStandardPrinter(this.context);

  Future<void> generateAndPrintPDF({
    required BluetoothPrinter? selectedPrinter,
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
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
    required String theme,
  }) async {
    if (returnBillDocumentConfig == null) {
      debugPrint('ERROR: Return Bill document configuration not loaded yet.');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'voucher_print.document_config_missing'.tr,
        );
      }
      return;
    }

    if (selectedPrinter == null) {
      debugPrint('ERROR: No printer selected for printing');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'voucher_print.select_printer_first'.tr,
        );
      }
      return;
    }

    try {
      if (context.mounted) {
        showScaffold(
          context: context,
          message:
              'voucher_print.preparing_return_document'.trParams(
                  {'paperSize': selectedPaperSize}),
        );
      }

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
        customerVatNumber: customerVatNumber,
        customerCrNumber: customerCrNumber,
        customerType: customerType,
      );

      final layout = StandardPdfLayoutFactory.getLayout(theme);
      await layout.generateAndPrintPdf(params);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'voucher_print.return_bill_pdf_generated'.tr,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('ERROR generating return bill PDF: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'voucher_print.error_generating_pdf'.trParams({'error': '$e'}),
        );
      }
    }
  }
}
