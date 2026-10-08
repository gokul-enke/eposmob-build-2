import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';

import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'package:websafe_svg/websafe_svg.dart';

import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_sales_order.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'package:pos_machine/screens/sales/widgets/cancel_order_modal.dart';
import 'package:pos_machine/screens/sales/widgets/change_order_status_modal.dart';
import 'package:pos_machine/screens/sales/widgets/change_payment_status_modal.dart';

import 'package:pos_machine/core/ui/ui.dart';

/// Retained row workflows shared by Sales and the existing Online Orders screen.
mixin SalesOrderActions<T extends StatefulWidget> on State<T> {
  bool get onlineSales;
  bool get useSharedSalesActions => false;
  Future<void> refreshSalesOrders({bool preserveOnlineFilter = false});
  DocumentConfig? _resolvePdfBillDocumentConfig(
    DocumentConfigProvider docConfigProvider,
    OrderDetailsModelData? orderData,
  ) {
    final hasReturns = orderData?.orderReturns != null &&
        orderData!.orderReturns!.returnItems != null &&
        orderData.orderReturns!.returnItems!.isNotEmpty;

    if (hasReturns) {
      return docConfigProvider.getDocumentConfig("Sales and Return Bill A4") ??
          docConfigProvider.getDocumentConfig("Sales and Return Bill") ??
          docConfigProvider.getDocumentConfig("Bill A4") ??
          docConfigProvider.getDocumentConfig("Bill");
    }

    return docConfigProvider.getDocumentConfig("Bill A4") ??
        docConfigProvider.getDocumentConfig("Bill");
  }

  /// Credit-note config for the return section, resolved like the print flow
  /// (PrintPage.autoPrint); null when the order has no returns.
  DocumentConfig? _resolveReturnBillDocumentConfig(
    DocumentConfigProvider docConfigProvider,
    OrderDetailsModelData? orderData,
  ) {
    final hasReturns =
        orderData?.orderReturns?.returnItems?.isNotEmpty ?? false;
    if (!hasReturns) return null;
    return docConfigProvider.getDocumentConfig("Credit Note") ??
        docConfigProvider.getDocumentConfig("Return Bill");
  }

  Future<Directory> _getEposDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final eposDirectory = Directory('${documentsDirectory.path}/epos');

    // Create epos directory if it doesn't exist
    if (!await eposDirectory.exists()) {
      await eposDirectory.create(recursive: true);
      debugPrint('Created epos directory: ${eposDirectory.path}');
    }

    return eposDirectory;
  }

  Future<void> downloadFile(String invoiceHash) async {
    final context = this.context;
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

      // URL of the PDF file
      final url = '${APPUrl.baseURL}/invoice-download/$invoiceHash';
      debugPrint('Attempting to download from: $url');

      // Get the epos directory
      final eposDirectory = await _getEposDirectory();

      // Create a file path for the PDF in the epos folder
      final filePath = '${eposDirectory.path}/invoice_$invoiceHash.pdf';

      // Configure Dio with options
      final dio = Dio();
      dio.options.validateStatus =
          (status) => status! < 500; // Don't throw on 4xx errors

      // Use Dio to download the file
      final response = await dio.download(url, filePath,
          onReceiveProgress: (received, total) {
        if (total != -1) {
          debugPrint(
              'Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
        }
      });

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        showScaffold(
          context: context,
          message: 'sales.invoice_downloaded'
              .tr
              .replaceAll('@path', eposDirectory.path),
        );
        debugPrint('File downloaded successfully to $filePath');
      } else if (response.statusCode == 404) {
        showScaffoldError(
          context: context,
          message: 'sales.invoice_not_found'.tr,
        );
        debugPrint('Invoice not found: ${response.statusCode}');
      } else {
        showScaffoldError(
          context: context,
          message: 'sales.failed_download_invoice'
              .tr
              .replaceAll('@code', response.statusCode.toString()),
        );
        debugPrint('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      if (!context.mounted) return;
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // More detailed error message based on error type
      String errorMessage = 'sales.err_download_file_default'.tr;
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'sales.err_connection_timeout'.tr;
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'sales.err_connection_error'.tr;
        } else if (e.response?.statusCode == 500) {
          errorMessage = 'sales.err_server_error'.tr;
        } else {
          errorMessage = 'sales.err_download_error'
              .tr
              .replaceAll('@message', e.message.toString());
        }
      } else {
        errorMessage =
            'sales.err_downloading_file'.tr.replaceAll('@error', e.toString());
      }

      showScaffoldError(
        context: context,
        message: errorMessage,
      );
      debugPrint('Error downloading file: $e');
    }
  }

  Future<void> sharePDFInvoice(ListOrderModelData order) async {
    final context = this.context;
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
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      final orderDetailsResponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (!context.mounted) return;
      if (orderDetailsResponse["status"] != "success") {
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
          OrderDetailsModel.fromJson(orderDetailsResponse);
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
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      final appSettings = appSettingsProvider.appSettings;

      final billDocumentConfig = _resolvePdfBillDocumentConfig(
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
      final storeSessionForPdfShare1 =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final storeForPdfShare1 =
          await storeSessionForPdfShare1.resolveActiveStore();

      if (!context.mounted) return;
      String? customerAlternatePhone =
          orderData.customerDetails?.alternatePhone;
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
            orderData.priceSummary?.netTotal.toString() ??
            order.grantTotal ??
            '0.00',
        savedTotal: orderData.priceSummary?.savedTotal?.toString() ?? '0.00',
        discountAmount: orderData.priceSummary?.discount?.toString() ?? '0.00',
        orderDate: orderData.orderDate ?? DateTime.now().toIso8601String(),
        orderNumber: orderData.customerReceiptNumber ??
            order.customerReceiptNumber ??
            '',
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
            _resolveReturnBillDocumentConfig(docConfigProvider, orderData),
        storeName: orderData.cart?.storeName,
        storeLocation: storeForPdfShare1?.location,
        storePhone: storeForPdfShare1?.phone,
        storeEmail: storeForPdfShare1?.email,
      );

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!context.mounted) return;
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
      debugPrint('PDF file generated successfully: ${pdfFile.path}');
      debugPrint('PDF file size: ${await pdfFile.length()} bytes');
      debugPrint('PDF file exists: ${await pdfFile.exists()}');

      // Share the PDF file using modern ShareParams API
      debugPrint('Starting PDF share process...');
      if (Platform.isWindows) {
        debugPrint('Sharing on Windows platform');
        // The native Windows Share sheet (used by share_plus) only works for
        // packaged (MSIX) apps. For this unpackaged Win32 build it returns
        // ShareResultStatus.unavailable and shows an OS "Try that again" dialog.
        // Go straight to our own sharing options dialog instead.
        _handleWindowsAlternativeSharing(pdfFile, order);
        return;
      } else {
        debugPrint('Sharing on non-Windows platform');
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

        final result = await SharePlus.instance.share(params);
        debugPrint('Non-Windows share completed with status: ${result.status}');
      }

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'sales.pdf_shared_success'.tr,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      debugPrint('Error sharing PDF invoice: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.err_share_pdf'.tr,
        );
      }
    }
  }

  Future<void> shareViaWhatsAppBot(ListOrderModelData order) async {
    final context = this.context;
    try {
      final whatsappProvider =
          Provider.of<WhatsappProvider>(context, listen: false);

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

      // Check WhatsApp connection
      if (!whatsappProvider.isWhatsAppAvailable()) {
        Navigator.of(context, rootNavigator: true).pop();

        // Show connection dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text('sales.wa_not_connected_title'.tr),
              ],
            ),
            content: Text(
              '${'sales.wa_not_connected_body'.tr}\n\n'
              '${'sales.wa_status_label'.tr} ${whatsappProvider.connectionStatus}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('general.cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Navigate to WhatsApp settings
                  Get.find<SideBarController>().index.value =
                      63; // Adjust this index to your WhatsApp settings page
                },
                child: Text('sales.btn_connect_wa'.tr),
              ),
            ],
          ),
        );
        return;
      }

      // Fetch order details
      final String ordersId = order.orderNumber.toString();
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      final orderDetailsResponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (!context.mounted) return;
      if (orderDetailsResponse["status"] != "success") {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'sales.unable_fetch_order_details'.tr,
          );
        }
        return;
      }

      final OrderDetailsModel details =
          OrderDetailsModel.fromJson(orderDetailsResponse);
      final orderData = details.data;

      if (orderData?.customerDetails?.phone == null ||
          orderData!.customerDetails!.phone!.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'sales.customer_phone_not_available'.tr,
          );
        }
        return;
      }

      // Prepare customer info
      final customerPhone = orderData.customerDetails!.phone!;
      final customerName = orderData.customerDetails?.name ?? 'Valued Customer';
      final totalAmount = orderData.priceSummary?.netPayable?.toString() ??
          orderData.priceSummary?.netTotal.toString() ??
          order.grantTotal ??
          '0.00';
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'INR';

      // Create invoice URL if available
      String? invoiceUrl;
      if (order.invoiceHash != null) {
        invoiceUrl = '${APPUrl.baseURL}/invoice-download/${order.invoiceHash}';
      }

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // Show options dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.message, color: Color(0xFF25D366)),
              const SizedBox(width: 8),
              Text('sales.title_send_wa_bot'.tr),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${'sales.label_customer'.tr} $customerName'),
              Text('${'sales.label_phone_wa'.tr} $customerPhone'),
              Text('${'sales.label_order'.tr} #${order.orderNumber}'),
              Text('${'sales.label_amount'.tr} $currency $totalAmount'),
              const SizedBox(height: 16),
              Text(
                'sales.label_choose_what'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('general.cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Send invoice message with URL
                final success = await whatsappProvider.sendInvoiceMessage(
                  phoneNumber: customerPhone,
                  orderNumber: order.orderNumber.toString(),
                  customerName: customerName,
                  totalAmount: '$currency $totalAmount',
                  invoiceUrl: invoiceUrl,
                );

                if (context.mounted) {
                  if (success) {
                    showScaffold(
                      context: context,
                      message: 'sales.invoice_sent_whatsapp'
                          .tr
                          .replaceAll('@phone', customerPhone),
                    );
                  } else {
                    showScaffoldError(
                      context: context,
                      message: 'sales.failed_send_whatsapp'
                          .tr
                          .replaceAll('@error', whatsappProvider.lastError),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              child: Text('sales.btn_send_invoice_link'.tr),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _sendWhatsAppWithPDF(order, whatsappProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('sales.btn_send_with_pdf'.tr),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      debugPrint('Error in WhatsApp bot sharing: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.err_sending_whatsapp'.tr,
        );
      }
    }
  }

  Future<void> _sendWhatsAppWithPDF(
      ListOrderModelData order, WhatsappProvider whatsappProvider) async {
    final context = this.context;
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
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      final orderDetailsResponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (!context.mounted) return;
      if (orderDetailsResponse["status"] != "success") {
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
          OrderDetailsModel.fromJson(orderDetailsResponse);
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
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      final appSettings = appSettingsProvider.appSettings;

      final billDocumentConfig = _resolvePdfBillDocumentConfig(
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
      debugPrint('🔄 Starting PDF generation for WhatsApp sharing...');
      final standardPrinter = StandardPrinter(context);
      final storeSessionForPdfShare2 =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final storeForPdfShare2 =
          await storeSessionForPdfShare2.resolveActiveStore();

      if (!context.mounted) return;
      String? customerAlternatePhone =
          orderData.customerDetails?.alternatePhone;
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
            orderData.priceSummary?.netTotal.toString() ??
            order.grantTotal ??
            '0.00',
        savedTotal: orderData.priceSummary?.savedTotal?.toString() ?? '0.00',
        discountAmount: orderData.priceSummary?.discount?.toString() ?? '0.00',
        orderDate: orderData.orderDate ?? DateTime.now().toIso8601String(),
        orderNumber: orderData.customerReceiptNumber ??
            order.customerReceiptNumber ??
            '',
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
            _resolveReturnBillDocumentConfig(docConfigProvider, orderData),
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
      debugPrint('✅ PDF generated: ${pdfFile.path}');

      // Wait for file system to sync (important for WhatsApp sharing)
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify PDF file integrity before sharing
      final exists = await pdfFile.exists();
      if (!context.mounted) return;
      if (!exists) {
        Navigator.of(context, rootNavigator: true).pop();
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
      debugPrint('📄 PDF file size: $fileSize bytes');

      if (fileSize < 100) {
        debugPrint('⚠️  WARNING: PDF file is too small ($fileSize bytes)');
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'sales.pdf_corrupted'
                .tr
                .replaceAll('@size', fileSize.toString()),
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
        debugPrint(
            '✅ PDF file verification successful: ${testBytes.length} bytes');
      } catch (e) {
        if (!context.mounted) return;
        debugPrint('❌ PDF file verification failed: $e');
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
          orderData.priceSummary?.netTotal.toString() ??
          order.grantTotal ??
          '0.00';
      final currency = appSettings.currency;

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      debugPrint('🚀 Starting WhatsApp PDF sharing...');
      debugPrint('📱 Target phone: $customerPhone');
      debugPrint('📄 PDF file ready: ${pdfFile.path}');
      debugPrint('📄 File size: ${await pdfFile.length()} bytes');

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

      if (context.mounted) {
        if (success) {
          showScaffold(
            context: context,
            message: 'sales.invoice_pdf_sent_whatsapp'
                .tr
                .replaceAll('@phone', customerPhone)
                .replaceAll('@file', pdfFile.path.split('/').last)
                .replaceAll('@size', fileSize.toString()),
          );

          // Optionally open the PDF file location
          if (Platform.isWindows) {
            try {
              await Process.start(
                'explorer.exe',
                ['/select,', pdfFile.path.replaceAll('/', '\\')],
                mode: ProcessStartMode.detached,
              );
            } catch (e) {
              debugPrint('Could not open file location: $e');
            }
          }
        } else {
          // If PDF sending failed, try fallback with message and PDF info
          debugPrint('🔄 PDF file sending failed, trying fallback approach...');

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
      if (!context.mounted) return;
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      debugPrint('Error sending WhatsApp with PDF: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales.err_generating_sending_pdf'.tr,
        );
      }
    }
  }

  Future<void> _handleWindowsAlternativeSharing(
      File pdfFile, ListOrderModelData order) async {
    final context = this.context;
    debugPrint('Using alternative Windows sharing approach');

    if (context.mounted) {
      // Show dialog with multiple options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('sales.title_pdf_ready'.tr),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${'sales.label_invoice'.tr} ${order.orderNumber}'),
              const SizedBox(height: 8),
              Text('${'sales.label_file'.tr} ${pdfFile.path.split('/').last}'),
              const SizedBox(height: 16),
              Text(
                'sales.label_choose_share_pdf'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            // Option 1: Open file location
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  // Open file explorer to the file location
                  await Process.start(
                    'explorer.exe',
                    ['/select,', pdfFile.path.replaceAll('/', '\\')],
                    mode: ProcessStartMode.detached,
                  );
                  if (context.mounted) {
                    showScaffold(
                      context: context,
                      message: 'sales.file_location_opened'.tr,
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening file location: $e');
                }
              },
              icon: const Icon(Icons.folder_open),
              label: Text('sales.btn_open_file_location'.tr),
            ),
            // Option 2: Open PDF directly
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Process.start(
                    'cmd',
                    ['/c', 'start', '""', pdfFile.path],
                    mode: ProcessStartMode.detached,
                  );
                  if (context.mounted) {
                    showScaffold(
                      context: context,
                      message: 'sales.pdf_opened'.tr,
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening PDF: $e');
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text('sales.btn_open_pdf'.tr),
            ),
            // Option 3: Copy path
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Clipboard.setData(ClipboardData(text: pdfFile.path));
                  if (context.mounted) {
                    showScaffold(
                      context: context,
                      message: 'sales.file_path_copied'.tr,
                    );
                  }
                } catch (e) {
                  debugPrint('Error copying to clipboard: $e');
                }
              },
              icon: const Icon(Icons.copy),
              label: Text('sales.btn_copy_path'.tr),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    if (useSharedSalesActions) {
      return AppSquareIconButton(
        icon: icon,
        size: AppSizes.compactControl,
        foreground: AppColors.primary,
        tooltip: (icon == Icons.visibility
                ? 'sales.view_order'
                : icon == Icons.print
                    ? 'sales.print_order'
                    : 'sales.more_actions')
            .tr,
        onPressed: onPressed,
      );
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onPressed,
      ),
    );
  }

  Widget buildSalesOrderActions(
      ListOrderModelData order, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      spacing: useSharedSalesActions ? 6 : 0,
      children: [
        _buildActionIcon(
          icon: Icons.visibility,
          color: ColorManager.kPrimaryColor,
          onPressed: () {
            final provider = Provider.of<SalesProvider>(context, listen: false);
            provider.setOrderNumber(order.orderNumber ?? "0");
            provider.isOnlineSalesNavigation = onlineSales;
            Get.find<SideBarController>().index.value = 11;
          },
        ),
        // if (order.status == "new")
        //   IconButton(
        //     icon: Icon(Icons.edit, size: 18, color: Colors.orange),
        //     onPressed: () {
        //       Provider.of<CartProvider>(context, listen: false)
        //           .setCartIDForOrder(int.parse(order.cartId.toString()));
        //       Provider.of<SalesProvider>(context, listen: false)
        //           .setOrderNumber(order.orderNumber.toString());
        //       Provider.of<SalesProvider>(context, listen: false)
        //           .setOrderId(order.id.toString());
        //       Get.find<SideBarController>().index.value = 51;
        //     },
        //   ),
        _buildActionIcon(
          icon: Icons.print,
          color: Colors.blue,
          onPressed: () async {
            try {
              final orderNumber = order.orderNumber?.toString();
              if (orderNumber == null || orderNumber.isEmpty) return;

              await const PrintService().printOrderByIdWithOptions(
                context,
                orderNumber,
              );
            } catch (error) {
              debugPrint(error.toString());
            }
          },
        ),
        _buildActionIcon(
          icon: Icons.more_vert,
          color: Colors.blue,
          onPressed: () async {
            // Show bottom sheet with options instead of popup menu
            if (!context.mounted) return;
            await showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          'sales.title_more_options'.tr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: ColorManager.kPrimaryColor
                                .withValues(alpha: 0.12),
                            child: const Icon(Icons.share,
                                color: ColorManager.kPrimaryColor),
                          ),
                          title: Text('sales.btn_share'.tr),
                          onTap: () async {
                            Navigator.pop(ctx);
                            // Handle share option - show share modal
                            try {
                              String? invoiceHash = order.invoiceHash;
                              if (invoiceHash == null) {
                                if (context.mounted) {
                                  showScaffoldError(
                                    context: context,
                                    message:
                                        'sales.invoice_not_available_sharing'
                                            .tr,
                                  );
                                }
                                return;
                              }

                              // Build message with invoice link
                              final String invoiceUrl =
                                  "${APPUrl.baseURL}/invoice-download/$invoiceHash";
                              final String message =
                                  "Here is the link for your invoice: $invoiceUrl";

                              // Try to fetch customer phone/email from order details (for direct share targets)
                              String? customerPhone;
                              String? customerEmail;
                              try {
                                final String ordersId =
                                    order.orderNumber.toString();
                                final String? accessToken =
                                    Provider.of<AuthModel>(context,
                                            listen: false)
                                        .token;
                                final orderDetailsResponse =
                                    await SalesProvider().listOrderDetails(
                                        context, ordersId, accessToken ?? "");
                                if (!context.mounted) return;
                                if (orderDetailsResponse["status"] ==
                                    "success") {
                                  final OrderDetailsModel details =
                                      OrderDetailsModel.fromJson(
                                          orderDetailsResponse);
                                  customerPhone =
                                      details.data?.customerDetails?.phone;
                                  customerEmail =
                                      details.data?.customerDetails?.email;
                                }
                              } catch (e) {
                                debugPrint(
                                    'Could not fetch order details for phone: $e');
                              }

                              // Sanitize phone for WhatsApp wa.me format (digits only, international format preferred)
                              String? intlPhone;
                              if (customerPhone != null &&
                                  customerPhone.trim().isNotEmpty) {
                                final digits = customerPhone.replaceAll(
                                    RegExp(r'[^0-9]'), '');
                                if (digits.isNotEmpty) intlPhone = digits;
                              }

                              if (!context.mounted) return;
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                ),
                                builder: (ctx) {
                                  return SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 4,
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          Text(
                                            'sales.title_share_invoice_sheet'
                                                .tr,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 8),
                                          const Divider(height: 1),
                                          ListTile(
                                            leading: CircleAvatar(
                                              radius: 18,
                                              backgroundColor: ColorManager
                                                  .kPrimaryColor
                                                  .withValues(alpha: 0.12),
                                              child: const Icon(Icons.share,
                                                  color: ColorManager
                                                      .kPrimaryColor),
                                            ),
                                            title: Text('sales.btn_share'.tr),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              // On Windows, sharing a file tends to open the native Share UI more reliably
                                              if (Platform.isWindows) {
                                                final Uint8List data =
                                                    Uint8List.fromList(
                                                        utf8.encode(message));
                                                final XFile note =
                                                    XFile.fromData(
                                                  data,
                                                  mimeType: 'text/plain',
                                                  name:
                                                      'Invoice_${order.orderNumber}.txt',
                                                );
                                                await Share.shareXFiles(
                                                  [note],
                                                  text: message,
                                                  subject:
                                                      'Invoice #${order.orderNumber}',
                                                );
                                              } else {
                                                await Share.share(
                                                  message,
                                                  subject:
                                                      'Invoice #${order.orderNumber}',
                                                );
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: const CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Color(
                                                  0x1A1E88E5), // ~10% opacity blue
                                              child: Icon(Icons.email,
                                                  color: Color(0xFF1E88E5)),
                                            ),
                                            title: Text(
                                              (customerEmail != null &&
                                                      customerEmail.isNotEmpty)
                                                  ? '${'sales.opt_share_email'.tr} ($customerEmail)'
                                                  : 'sales.opt_share_email'.tr,
                                            ),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              final uri = Uri(
                                                scheme: 'mailto',
                                                path: (customerEmail != null &&
                                                        customerEmail
                                                            .isNotEmpty)
                                                    ? customerEmail
                                                    : '',
                                                queryParameters: <String,
                                                    String>{
                                                  'subject':
                                                      'Invoice #${order.orderNumber}',
                                                  'body': message,
                                                },
                                              );
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri,
                                                    mode: LaunchMode
                                                        .externalApplication);
                                              } else {
                                                if (context.mounted) {
                                                  showScaffoldError(
                                                    context: context,
                                                    message:
                                                        'sales.no_email_app'.tr,
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: CircleAvatar(
                                              radius: 18,
                                              backgroundColor: const Color(
                                                  0x1A25D366), // ~10% opacity WhatsApp green
                                              child: WebsafeSvg.asset(
                                                ImageAssets.whatsappIcon,
                                                colorFilter:
                                                    const ColorFilter.mode(
                                                  Colors.green,
                                                  BlendMode.srcIn,
                                                ),
                                                fit: BoxFit.none,
                                              ),
                                            ),
                                            title: Text(
                                              intlPhone != null
                                                  ? '${'sales.opt_share_whatsapp'.tr} ($intlPhone)'
                                                  : 'sales.opt_share_whatsapp'
                                                      .tr,
                                            ),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await shareViaWhatsAppBot(order);
                                            },
                                          ),
                                          ListTile(
                                            leading: const CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Color(
                                                  0x1AE53E3E), // ~10% opacity red
                                              child: Icon(
                                                  Icons.picture_as_pdf_outlined,
                                                  color: Color(0xFFE53E3E)),
                                            ),
                                            title:
                                                Text('sales.opt_share_pdf'.tr),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await sharePDFInvoice(order);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            } catch (error) {
                              debugPrint('Error sharing invoice: $error');
                              if (context.mounted) {
                                showScaffoldError(
                                  context: context,
                                  message: 'sales.err_sharing_invoice'.tr,
                                );
                              }
                            }
                          },
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Color(0x1AE53E3E), // ~10% opacity red
                            child: Icon(Icons.assignment_return,
                                color: Color(0xFFE53E3E)),
                          ),
                          title: Text('sales.btn_return'.tr),
                          onTap: () async {
                            Navigator.pop(ctx);

                            try {
                              debugPrint(
                                  'Preparing return for order #${order.orderNumber}');

                              // Store order details in providers
                              Provider.of<SalesProvider>(context, listen: false)
                                  .setOrderNumber(order.orderNumber.toString());
                              Provider.of<SalesProvider>(context, listen: false)
                                  .setOrderId(order.id.toString());

                              if (order.cartId != null) {
                                Provider.of<CartProvider>(context,
                                        listen: false)
                                    .setCartIDForOrder(
                                        int.parse(order.cartId.toString()));
                              }

                              // Navigate to sales return page
                              Get.find<SideBarController>().index.value = 49;

                              // Show success message
                              if (context.mounted) {
                                showScaffold(
                                  context: context,
                                  message: 'sales.preparing_return'
                                      .tr
                                      .replaceAll('@number',
                                          order.orderNumber.toString()),
                                );
                              }
                            } catch (error) {
                              debugPrint(
                                  'Error preparing order return: $error');
                              if (context.mounted) {
                                showScaffoldError(
                                  context: context,
                                  message: 'sales.err_preparing_return'.tr,
                                );
                              }
                            }
                          },
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Color(0x1AE53E3E), // ~10% opacity red
                            child: Icon(Icons.cancel_outlined,
                                color: Color(0xFFE53E3E)),
                          ),
                          title: Text('sales.btn_cancel_order'.tr),
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => CancelOrderModal(
                                isUnpaidCod: order.isUnpaidCod,
                                initialRefundAmount:
                                    order.priceSummary?.grandTotal ??
                                        order.grantTotal ??
                                        '',
                                onConfirm: (paymentMethodId, refundAmount,
                                    deliveryChargeRefundable) async {
                                  try {
                                    final authModel = Provider.of<AuthModel>(
                                        context,
                                        listen: false);
                                    final salesProvider =
                                        Provider.of<SalesProvider>(context,
                                            listen: false);

                                    await salesProvider.cancelOrder(
                                      accessToken: authModel.token ?? "",
                                      orderId: order.id.toString(),
                                      paymentMethod: paymentMethodId,
                                      refundAmount: refundAmount,
                                      deliveryChargeRefundable:
                                          deliveryChargeRefundable,
                                    );

                                    if (context.mounted) {
                                      showScaffold(
                                        context: context,
                                        message:
                                            'sales.order_cancelled_success'.tr,
                                      );
                                      // Refresh orders
                                      try {
                                        await refreshSalesOrders(
                                            preserveOnlineFilter: true);
                                      } catch (refreshError) {
                                        if (context.mounted) {
                                          showScaffoldError(
                                            context: context,
                                            message:
                                                SalesProvider.apiErrorMessage(
                                              refreshError,
                                              fallback:
                                                  'sales.orders_load_failed'.tr,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showScaffoldError(
                                        context: context,
                                        message: SalesProvider.apiErrorMessage(
                                          e,
                                          fallback:
                                              'sales.failed_cancel_order'.tr,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Color(0x1A6A1B9A), // ~10% opacity purple
                            child: Icon(Icons.swap_horiz_outlined,
                                color: Color(0xFF6A1B9A)),
                          ),
                          title: Text('sales.btn_change_order_status'.tr),
                          onTap: () async {
                            Navigator.pop(ctx);
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => ChangeOrderStatusModal(
                                currentStatus: order.status ?? 'pending',
                                orderTotal: order.grantTotal?.toString() ?? '0',
                                onConfirm: ({
                                  required newStatus,
                                  refundAmount,
                                  paymentMethod,
                                  deliveryChargeRefundable,
                                  deliveryLogistics,
                                }) async {
                                  try {
                                    final authModel = Provider.of<AuthModel>(
                                        context,
                                        listen: false);
                                    final salesProvider =
                                        Provider.of<SalesProvider>(context,
                                            listen: false);

                                    await salesProvider.changeOrderStatus(
                                      accessToken: authModel.token ?? "",
                                      orderId: order.id.toString(),
                                      status: newStatus,
                                      refundAmount: refundAmount,
                                      paymentMethod: paymentMethod,
                                      deliveryChargeRefundable:
                                          deliveryChargeRefundable,
                                      deliveryLogistics: deliveryLogistics,
                                    );

                                    if (context.mounted) {
                                      showScaffold(
                                        context: context,
                                        message: 'sales.order_status_updated'
                                            .tr
                                            .replaceAll('@status',
                                                newStatus.toString()),
                                      );
                                      try {
                                        await refreshSalesOrders(
                                            preserveOnlineFilter: false);
                                      } catch (refreshError) {
                                        if (context.mounted) {
                                          showScaffoldError(
                                            context: context,
                                            message:
                                                SalesProvider.apiErrorMessage(
                                              refreshError,
                                              fallback:
                                                  'sales.orders_load_failed'.tr,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showScaffoldError(
                                        context: context,
                                        message: SalesProvider.apiErrorMessage(
                                          e,
                                          fallback:
                                              'sales.failed_update_order_status'
                                                  .tr,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Color(0x1A1E88E5), // ~10% opacity blue
                            child: Icon(Icons.payment_outlined,
                                color: Color(0xFF1E88E5)),
                          ),
                          title: Text('sales.btn_change_payment_status'.tr),
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => ChangePaymentStatusModal(
                                currentPaymentStatus:
                                    order.paymentStatus ?? 'unpaid',
                                grandTotal: order.grantTotal?.toString() ?? '0',
                                onConfirm: (newStatus, amount) async {
                                  try {
                                    final authModel = Provider.of<AuthModel>(
                                        context,
                                        listen: false);
                                    final salesProvider =
                                        Provider.of<SalesProvider>(context,
                                            listen: false);

                                    await salesProvider.changePaymentStatus(
                                      accessToken: authModel.token ?? "",
                                      orderId: order.id.toString(),
                                      status: newStatus,
                                      amount: amount,
                                    );

                                    if (context.mounted) {
                                      showScaffold(
                                        context: context,
                                        message: 'sales.payment_status_updated'
                                            .tr
                                            .replaceAll('@status',
                                                newStatus.toString()),
                                      );
                                      try {
                                        await refreshSalesOrders(
                                            preserveOnlineFilter: false);
                                      } catch (refreshError) {
                                        if (context.mounted) {
                                          showScaffoldError(
                                            context: context,
                                            message:
                                                SalesProvider.apiErrorMessage(
                                              refreshError,
                                              fallback:
                                                  'sales.orders_load_failed'.tr,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showScaffoldError(
                                        context: context,
                                        message: SalesProvider.apiErrorMessage(
                                          e,
                                          fallback:
                                              'sales.failed_update_payment_status'
                                                  .tr,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                        // ListTile(
                        //   leading: const CircleAvatar(
                        //     radius: 18,
                        //     backgroundColor:
                        //         Color(0x1A3F51B5), // ~10% opacity indigo
                        //     child:
                        //         Icon(Icons.download, color: Color(0xFF3F51B5)),
                        //   ),
                        //   title: const Text('Download Invoice'),
                        //   onTap: () {
                        //     Navigator.pop(ctx);
                        //     // Handle download option
                        //     String? invoiceHash = order.invoiceHash;
                        //     if (invoiceHash != null) {
                        //       downloadFile(invoiceHash);
                        //     } else {
                        //       if (context.mounted) {
                        //         showScaffoldError(
                        //           context: context,
                        //           message:
                        //               'Invoice not available for download.',
                        //         );
                        //       }
                        //     }
                        //   },
                        // ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
