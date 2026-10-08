import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:share_plus/share_plus.dart';

import 'sales_document_files.dart';
import 'sales_page_services.dart';
import 'sales_windows_sharing.dart';

Future<void> shareSalesPdf(BuildContext context, SalesPageServices services,
    ListOrderModelData order) async {
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

    // Fetch order details
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
    final storeSessionForPdfShare1 = services.store;
    final storeForPdfShare1 =
        await storeSessionForPdfShare1.resolveActiveStore();
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

    // Use the cart items directly without conversion since the PDF method expects the original objects
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
      storeLocation: storeForPdfShare1?.location,
      storePhone: storeForPdfShare1?.phone,
      storeEmail: storeForPdfShare1?.email,
    );
    if (!context.mounted) return;

    // Close loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    if (pdfFile == null) {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.failed_generate_pdf'.tr,
        );
      }
      return;
    }

    // Debug information

    // Share the PDF file using modern ShareParams API

    if (Platform.isWindows) {
      // The native Windows Share sheet (used by share_plus) only works for
      // packaged (MSIX) apps. For this unpackaged Win32 build it returns
      // ShareResultStatus.unavailable and shows an OS "Try that again" dialog.
      // Go straight to our own sharing options dialog instead.
      showSalesWindowsSharing(context, services, pdfFile, order);
      return;
    } else {
      // On other platforms, use enhanced sharing with context
      final enhancedXFile = XFile(
        pdfFile.path,
        name: 'Invoice_${order.orderNumber}.pdf',
        mimeType: 'application/pdf',
      );

      final params = ShareParams(
        text:
            'Please find attached the invoice for order #${order.orderNumber}',
        files: [enhancedXFile],
      );
      await SharePlus.instance.share(params);
      if (!context.mounted) return;
    }

    if (context.mounted) {
      showScaffold(
        context: context,
        message: 'sales.pdf_shared_success'.tr,
      );
    }
  } catch (e) {
    // Close loading dialog if still showing
    if (!context.mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales.err_share_pdf'.tr,
      );
    }
  }
}
