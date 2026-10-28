import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_invoice_pdf_share.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:share_plus/share_plus.dart';

import 'detail_command_helpers.dart';
import 'handle_detail_windows_sharing.dart';

Future<void> shareDetailPdf(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;
  final customerDetails = controller.customer;

  final orderNumber = controller.orderNumber;
  final tokenNumber = controller.tokenNumber;

  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    if (orderDetailsModelData == null ||
        orderDetailsModelData.cart?.cartItems == null) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_no_pdf_data'.tr,
        );
      }
      return;
    }

    final appSettingsProvider = services.settings;
    final docConfigProvider = services.documents;

    final appSettings = appSettingsProvider.appSettings;

    final billDocumentConfig =
        resolveDetailPdfConfig(docConfigProvider, orderDetailsModelData);

    if (appSettings == null || billDocumentConfig == null) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_no_app_settings'.tr,
        );
      }
      return;
    }

    String? customerAlternatePhone = customerDetails?.alternatePhone;
    String? paymentMethod = orderDetailsModelData.paymentDetails?.paymentMethod;
    String? deliveryMethod = orderDetailsModelData.deliveryMethodName;

    String? orderComment;
    if (orderDetailsModelData.orderProps != null) {
      try {
        final commentProp = orderDetailsModelData.orderProps!.firstWhere(
          (prop) => prop.propsCode == "COMMENT",
          orElse: () => OrderDetailsModelDataOrderProp(),
        );
        orderComment = commentProp.propsValue;
      } catch (e) {
        // ignore
      }
    }

    final standardPrinter = StandardPrinter(context);

    final storeSessionForShare = services.store;
    final storeForShare = await storeSessionForShare.resolveActiveStore();
    if (!context.mounted) return;
    final File? pdfFile = await standardPrinter.generateThemedPDFForSharing(
      cartItems: orderDetailsModelData.cart!.cartItems!,
      formattedTotal:
          orderDetailsModelData.priceSummary?.netPayable?.toString() ??
              orderDetailsModelData.priceSummary?.netTotal?.toString() ??
              '0.00',
      savedTotal:
          orderDetailsModelData.priceSummary?.savedTotal?.toString() ?? '0.00',
      discountAmount:
          orderDetailsModelData.priceSummary?.discount?.toString() ?? '0.00',
      orderDate:
          orderDetailsModelData.orderDate ?? DateHelper.now().toIso8601String(),
      orderNumber: orderNumber,
      isFromLocalStorage: false,
      billDocumentConfig: billDocumentConfig,
      customerCareNumber: appSettings.customerCarePhone,
      customerCareEmail: appSettings.customerCareEmail,
      customerName: customerDetails?.name,
      customerPhone: customerDetails?.phone,
      customerEmail: customerDetails?.email,
      customerAddress: orderDetailsModelData.getCustomerAddressForDisplay(),
      orderReturns: orderDetailsModelData.orderReturns,
      customerAlternatePhone: customerAlternatePhone,
      paymentMethod: paymentMethod,
      orderComment: orderComment,
      deliveryMethod: deliveryMethod,
      customerVatNumber: orderDetailsModelData.kycInfo?.vatNumber,
      customerCrNumber: orderDetailsModelData.kycInfo?.crNumber,
      customerType: orderDetailsModelData.customerDetails?.customerType,
      // Same values the print path (PrintService) passes.
      paymentBreakdown: orderDetailsModelData.payments,
      paidAmount:
          PrintService.paidAmountFromPayments(orderDetailsModelData.payments),
      customerCurrentBalance: customerDetails?.customerBalance,
      isDefaultCustomer:
          isDetailDefaultCustomerPhone(customerDetails?.phone, services),
      hideDefaultCustomerPhone: appSettings.hideDefaultPhone,
      netExcTax:
          orderDetailsModelData.cart?.priceSummary?.netExcTax?.toString(),
      apiTotalTax: orderDetailsModelData.priceSummary?.totalTax?.toDouble(),
      tokenNumber: tokenNumber,
      deliveryPhone: orderDetailsModelData.getDeliveryPhoneForDisplay(),
      returnBillDocumentConfig:
          resolveDetailReturnConfig(docConfigProvider, orderDetailsModelData),
      storeName: orderDetailsModelData.cart?.storeName,
      storeLocation: storeForShare?.location,
      storePhone: storeForShare?.phone,
      storeEmail: storeForShare?.email,
    );
    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    if (pdfFile == null) {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_pdf_failed'.tr,
        );
      }
      return;
    }

    final result = await shareInvoicePdf(
      pdfFile,
      text: 'sales_order_details.msg_share_pdf_text'
          .trParams({'orderNumber': orderNumber}),
      subject: 'Invoice #$orderNumber',
    );
    if (!context.mounted) return;

    if (result == null) {
      if (Platform.isWindows) {
        handleDetailWindowsSharing(context, controller, services, pdfFile);
      } else {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_pdf_share_error'.tr,
        );
      }
      return;
    }

    // Windows never reports the outcome (always unavailable).
    switch (result.status) {
      case ShareResultStatus.success:
        showScaffold(
          context: context,
          message: 'sales_order_details.msg_pdf_shared'.tr,
        );
      case ShareResultStatus.dismissed:
        showScaffold(
          context: context,
          message: 'sales_order_details.msg_sharing_cancelled'.tr,
        );
      case ShareResultStatus.unavailable:
        break;
    }
  } catch (e) {
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    debugPrint('Error sharing PDF invoice: $e');
    if (context.mounted) {
      showScaffoldError(
        context: context,
        message: 'sales_order_details.msg_pdf_share_error'.tr,
      );
    }
  }
}
