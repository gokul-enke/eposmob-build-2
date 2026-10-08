import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'package:pos_machine/services/print_service.dart';

import 'sales_document_files.dart';
import 'sales_page_services.dart';

Future<void> sendSalesWhatsappPdf(
    BuildContext context,
    SalesPageServices services,
    ListOrderModelData order,
    WhatsappProvider whatsappProvider) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // Generate PDF (reuse the existing PDF generation logic)
    final String ordersId = order.orderNumber.toString();
    final String? accessToken = services.auth.token;
    final OrderDetailsresponse = await services.sales
        .listOrderDetails(context, ordersId, accessToken ?? "");
    if (!context.mounted) return;

    if (OrderDetailsresponse["status"] != "success") {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.unable_fetch_order_details_pdf'.tr,
        );
      }
      return;
    }

    final OrderDetailsModel details =
        OrderDetailsModel.fromJson(OrderDetailsresponse);
    final orderData = details.data;

    if (orderData == null || orderData.cart?.cartItems == null) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.order_details_not_available_pdf'.tr,
        );
      }
      return;
    }

    // Get app settings and document configuration
    final appSettingsProvider = services.settings;
    final docConfigProvider = services.documents;

    final appSettings = appSettingsProvider.appSettings;

    final billDocumentConfig = resolveSalesPdfConfig(
      docConfigProvider,
      orderData,
    );

    if (appSettings == null || billDocumentConfig == null) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.app_settings_not_loaded'.tr,
        );
      }
      return;
    }

    // Create StandardPrinter instance and generate PDF

    final standardPrinter = StandardPrinter(context);
    final storeSessionForPdfShare2 = services.store;
    final storeForPdfShare2 =
        await storeSessionForPdfShare2.resolveActiveStore();
    if (!context.mounted) return;

    String? customerAlternatePhone = orderData.customerDetails?.alternatePhone;
    String? paymentMethod = orderData.paymentDetails?.paymentMethod;
    String? deliveryMethod = orderData.deliveryMethodName;

    String? orderComment;
    if (orderData.orderProps != null) {
      try {
        final commentProp = orderData.orderProps!.firstWhere(
          (prop) => prop.propsCode == "COMMENT",
          orElse: () => OrderDetailsModelDataOrderProp(),
        );
        orderComment = commentProp.propsValue;
      } catch (e) {
        // ignore
      }
    }

    final File? pdfFile = await standardPrinter.generateThemedPDFForSharing(
      cartItems: orderData.cart!.cartItems!,
      formattedTotal: orderData.priceSummary?.netPayable?.toString() ??
          orderData.priceSummary?.netTotal?.toString() ??
          order.grantTotal ??
          '0.00',
      savedTotal: orderData.priceSummary?.savedTotal?.toString() ?? '0.00',
      discountAmount: orderData.priceSummary?.discount?.toString() ?? '0.00',
      orderDate: orderData.orderDate ?? DateTime.now().toIso8601String(),
      orderNumber:
          orderData.customerReceiptNumber ?? order.customerReceiptNumber ?? '',
      isFromLocalStorage: false,
      billDocumentConfig: billDocumentConfig,
      customerCareNumber: appSettings.customerCarePhone,
      customerCareEmail: appSettings.customerCareEmail,
      customerName: orderData.customerDetails?.name,
      customerPhone: orderData.customerDetails?.phone,
      customerEmail: orderData.customerDetails?.email,
      customerAddress: orderData.getCustomerAddressForDisplay(),
      orderReturns: orderData.orderReturns,
      customerAlternatePhone: customerAlternatePhone,
      paymentMethod: paymentMethod,
      orderComment: orderComment,
      deliveryMethod: deliveryMethod,
      customerVatNumber: orderData.kycInfo?.vatNumber,
      customerCrNumber: orderData.kycInfo?.crNumber,
      customerType: orderData.customerDetails?.customerType,
      // Same values the print path (PrintService) passes.
      paymentBreakdown: orderData.payments,
      paidAmount: PrintService.paidAmountFromPayments(orderData.payments),
      customerCurrentBalance: orderData.customerDetails?.customerBalance,
      isDefaultCustomer: PrintService.isDefaultCustomerPhone(
          context, orderData.customerDetails?.phone),
      hideDefaultCustomerPhone: appSettings.hideDefaultPhone,
      netExcTax: orderData.cart?.priceSummary?.netExcTax?.toString(),
      apiTotalTax: orderData.priceSummary?.totalTax?.toDouble(),
      tokenNumber: orderData.tokenNumber,
      deliveryPhone: orderData.getDeliveryPhoneForDisplay(),
      returnBillDocumentConfig:
          resolveSalesReturnConfig(docConfigProvider, orderData),
      storeName: orderData.cart?.storeName,
      storeLocation: storeForPdfShare2?.location,
      storePhone: storeForPdfShare2?.phone,
      storeEmail: storeForPdfShare2?.email,
    );
    if (!context.mounted) return;

    if (pdfFile == null) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.failed_generate_pdf'.tr,
        );
      }
      return;
    }

    // CRITICAL FIX: Ensure PDF file is completely written and accessible

    // Wait for file system to sync (important for WhatsApp sharing)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!context.mounted) return;

    // Verify PDF file integrity before sharing
    final exists = await pdfFile.exists();
    if (!context.mounted) return;
    if (!exists) {
      Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;

      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.pdf_not_created'.tr,
        );
      }
      return;
    }

    final fileSize = await pdfFile.length();
    if (!context.mounted) return;

    if (fileSize < 100) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message:
              'sales.pdf_corrupted'.tr.replaceAll('@size', fileSize.toString()),
        );
      }
      return;
    }

    // Test file readability
    try {
      final testBytes = await pdfFile.readAsBytes();
      if (!context.mounted) return;

      if (testBytes.isEmpty) {
        throw Exception('PDF file is empty');
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.pdf_verification_failed'
              .tr
              .replaceAll('@error', e.toString()),
        );
      }
      return;
    }

    // Send WhatsApp message with PDF info
    final customerPhone = orderData.customerDetails!.phone!;
    final customerName = orderData.customerDetails?.name ?? 'Valued Customer';
    final totalAmount = orderData.priceSummary?.netPayable?.toString() ??
        orderData.priceSummary?.netTotal?.toString() ??
        order.grantTotal ??
        '0.00';
    final currency = appSettings.currency;

    // Close loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    // Send via WhatsApp bot with actual PDF file
    final success = await whatsappProvider.sendPDFFile(
      phoneNumber: customerPhone,
      pdfFile: pdfFile,
      caption: '''🧾 *Invoice for Order #${order.orderNumber}*

Dear $customerName,

Thank you for your purchase!

📋 Order Number: #${order.orderNumber}
💰 Total Amount: $currency $totalAmount
📅 Date: ${DateHelper.formatDate(DateHelper.now())}

Please find your invoice attached.
---
Powered by CloudPOS''',
      showSuccessMessage: false, // Handle success message ourselves
    );
    if (!context.mounted) return;

    final sharedFileSize = await pdfFile.length();
    if (!context.mounted) return;
    if (context.mounted) {
      if (success) {
        showScaffold(
          context: context,
          message: 'sales.invoice_pdf_sent_whatsapp'
              .tr
              .replaceAll('@phone', customerPhone)
              .replaceAll('@file', pdfFile.path.split('/').last)
              .replaceAll('@size', sharedFileSize.toString()),
        );
        if (!context.mounted) return;

        // Optionally open the PDF file location
        if (Platform.isWindows) {
          try {
            await Process.start(
              'explorer.exe',
              ['/select,', pdfFile.path.replaceAll('/', '\\')],
              mode: ProcessStartMode.detached,
            );
            if (!context.mounted) return;
          } catch (e) {}
        }
      } else {
        // If PDF sending failed, try fallback with message and PDF info

        final fallbackSuccess = await whatsappProvider.sendMessageWithPDF(
          phoneNumber: customerPhone,
          message: '''🧾 *Invoice for Order #${order.orderNumber}*

Dear $customerName,

Thank you for your purchase!

📋 Order Number: #${order.orderNumber}
💰 Total Amount: $currency $totalAmount
📅 Date: ${DateHelper.formatDate(DateHelper.now())}

PDF invoice has been generated and saved.

We appreciate your business!

---
Powered by CloudPOS''',
          pdfFile: pdfFile,
        );
        if (!context.mounted) return;

        if (fallbackSuccess) {
          showScaffold(
            context: context,
            message: 'sales.invoice_message_sent_whatsapp'
                .tr
                .replaceAll('@phone', customerPhone)
                .replaceAll('@path', pdfFile.path),
          );
        } else {
          showScaffoldError(
            context: context,
            message:
                '${'sales.msg_wa_send_failed'.tr} ${whatsappProvider.lastError}',
          );
        }
      }
    }
  } catch (e) {
    // Close loading dialog if still showing
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales.err_generating_sending_pdf'.tr,
      );
    }
  }
}
