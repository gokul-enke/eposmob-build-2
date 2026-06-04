import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/list_sales_order.dart';
import '../../providers/auth_model.dart';
import '../../resources/app_url.dart';
import '../../resources/color_manager.dart';

import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/mobile_order_card.dart';
import 'widgets/mobile_filters.dart';
import 'widgets/cancel_order_modal.dart';
import 'widgets/change_order_status_modal.dart';
import 'widgets/change_payment_status_modal.dart';

class SalesScreen extends StatefulWidget {
  final bool isOnlineSales;
  const SalesScreen({super.key, this.isOnlineSales = false});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  String? selectedStatus;
  GetStoreModelData? storeSelected;
  DateTime? selectedDate;
  Key calendarPickerKey = UniqueKey();

  bool isInitLoading = false;
  String orderNumber = "";
  OrderDetailsModelData? orderDetailsModelData;
  List<OrderDetailsModelDataCartItem>? cartItems = [];

  bool initLoading = false;

  // Helper method to get or create the epos directory
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

  /// Helper method to check if a phone number matches the default customer phone from app settings
  bool _isDefaultCustomerPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";
    return defaultPhone.isNotEmpty && phone == defaultPhone;
  }

  final List<String> statusOptions = [
    'new',
    'pending',
    'confirmed',
    'cancelled'
  ];

  @override
  void initState() {
    loadInitData();
    super.initState();
    // Ensure filters are shown by default on desktop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isMobile = MediaQuery.of(context).size.width < 768;
      Provider.of<SalesProvider>(context, listen: false)
          .setFiltersVisibility(!isMobile);
    });
  }

  @override
  void dispose() {
    orderNumberController.dispose();
    customerNameController.dispose();
    dateController.dispose();
    amountController.dispose();
    emailController.dispose();
    phoneController.dispose();
    storeController.dispose();
    storeSearchController.dispose();
    statusController.dispose();
    super.dispose();
  }

  Future<void> downloadFile(String invoiceHash) async {
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
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        showScaffold(
          context: context,
          message: 'Invoice downloaded successfully to ${eposDirectory.path}',
        );
        debugPrint('File downloaded successfully to $filePath');
      } else if (response.statusCode == 404) {
        showScaffoldError(
          context: context,
          message:
              'Invoice not found. The order may not have a generated invoice.',
        );
        debugPrint('Invoice not found: ${response.statusCode}');
      } else {
        showScaffoldError(
          context: context,
          message: 'Failed to download invoice: Error ${response.statusCode}',
        );
        debugPrint('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // More detailed error message based on error type
      String errorMessage = 'Error downloading file';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage =
              'Connection timeout. Please check your internet connection.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage =
              'Connection error. Please check your internet connection.';
        } else if (e.response?.statusCode == 500) {
          errorMessage =
              'Server error. The invoice generation service may be unavailable.';
        } else {
          errorMessage = 'Download error: ${e.message}';
        }
      } else {
        errorMessage = 'Error downloading file: ${e.toString()}';
      }

      showScaffoldError(
        context: context,
        message: errorMessage,
      );
      debugPrint('Error downloading file: $e');
    }
  }

  Future<void> _sharePDFInvoice(ListOrderModelData order) async {
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
      final OrderDetailsresponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (OrderDetailsresponse["status"] != "success") {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Unable to fetch order details for PDF generation.',
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
            message: 'Order details not available for PDF generation.',
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

      // Check if orderReturns data is available to determine which config to use
      final billDocumentConfig = (orderData.orderReturns != null &&
              orderData.orderReturns!.returnItems != null &&
              orderData.orderReturns!.returnItems!.isNotEmpty)
          ? (docConfigProvider.getDocumentConfig("Sales and Return Bill") ??
              docConfigProvider.getDocumentConfig("Bill"))
          : docConfigProvider.getDocumentConfig("Bill");

      if (appSettings == null || billDocumentConfig == null) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'App settings or document configuration not loaded.',
          );
        }
        return;
      }

      // Create StandardPrinter instance and generate PDF
      final standardPrinter = StandardPrinter(context);

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
      final File? pdfFile = await standardPrinter.generatePDFForSharing(
        cartItems: orderData.cart!.cartItems!,
        formattedTotal: orderData.priceSummary?.netPayable?.toString() ??
            orderData.priceSummary?.netTotal?.toString() ??
            order.grantTotal ??
            '0.00',
        savedTotal: orderData.priceSummary?.savedTotal?.toString() ?? '0.00',
        discountAmount: orderData.priceSummary?.discount?.toString() ?? '0.00',
        orderDate: orderData.orderDate ?? DateTime.now().toIso8601String(),
        orderNumber:
            orderData.orderNumber?.toString() ?? order.orderNumber.toString(),
        isFromLocalStorage: false,
        selectedPaperSize: 'A4', // Default to A4 for sharing
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
      );

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to generate PDF invoice.',
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
        // On Windows, use modern ShareParams API with pure file sharing
        try {
          debugPrint('Attempting Windows share with ShareParams API...');
          // Create XFile with enhanced properties
          final enhancedXFile = XFile(
            pdfFile.path,
            name: 'Invoice_${order.orderNumber}.pdf',
            mimeType: 'application/pdf',
            length: await pdfFile.length(),
          );

          // Use modern ShareParams API - files only for Windows
          final params = ShareParams(
            files: [enhancedXFile],
          );

          final result = await SharePlus.instance.share(params);

          debugPrint('ShareParams API completed with status: ${result.status}');

          if (result.status == ShareResultStatus.success) {
            debugPrint('Windows file sharing succeeded!');
          } else if (result.status == ShareResultStatus.dismissed) {
            debugPrint('Windows sharing was dismissed by user');
            if (context.mounted) {
              showScaffold(
                context: context,
                message: 'Sharing cancelled by user.',
              );
            }
            return;
          } else {
            debugPrint('Windows sharing failed with status: ${result.status}');
            // Try alternative sharing approach
            _handleWindowsAlternativeSharing(pdfFile, order);
            return;
          }
        } catch (e) {
          debugPrint('ShareParams API failed: $e');
          // Alternative approach: Open the PDF file directly
          _handleWindowsAlternativeSharing(pdfFile, order);
          return;
        }
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
          message: 'PDF invoice shared successfully!',
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      debugPrint('Error sharing PDF invoice: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error generating or sharing PDF invoice. Please try again.',
        );
      }
    }
  }

  Future<void> _shareViaWhatsAppBot(ListOrderModelData order) async {
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
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('WhatsApp Not Connected'),
              ],
            ),
            content: Text(
              'WhatsApp bot is not connected. Would you like to connect now?\n\n'
              'Status: ${whatsappProvider.connectionStatus}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Navigate to WhatsApp settings
                  Get.find<SideBarController>().index.value =
                      63; // Adjust this index to your WhatsApp settings page
                },
                child: const Text('Connect WhatsApp'),
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
      final OrderDetailsresponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (OrderDetailsresponse["status"] != "success") {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Unable to fetch order details.',
          );
        }
        return;
      }

      final OrderDetailsModel details =
          OrderDetailsModel.fromJson(OrderDetailsresponse);
      final orderData = details.data;

      if (orderData?.customerDetails?.phone == null ||
          orderData!.customerDetails!.phone!.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Customer phone number not available.',
          );
        }
        return;
      }

      // Prepare customer info
      final customerPhone = orderData.customerDetails!.phone!;
      final customerName = orderData.customerDetails?.name ?? 'Valued Customer';
      final totalAmount = orderData.priceSummary?.netPayable?.toString() ??
          orderData.priceSummary?.netTotal?.toString() ??
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
      Navigator.of(context, rootNavigator: true).pop();

      // Show options dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.message, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Text('Send via WhatsApp Bot'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: $customerName'),
              Text('Phone: $customerPhone'),
              Text('Order: #${order.orderNumber}'),
              Text('Amount: $currency $totalAmount'),
              const SizedBox(height: 16),
              const Text(
                'Choose what to send:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
                      message: 'Invoice sent via WhatsApp to $customerPhone',
                    );
                  } else {
                    showScaffoldError(
                      context: context,
                      message:
                          'Failed to send WhatsApp message: ${whatsappProvider.lastError}',
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Invoice Link'),
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
              child: const Text('Send with PDF'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      debugPrint('Error in WhatsApp bot sharing: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error sending WhatsApp message. Please try again.',
        );
      }
    }
  }

  Future<void> _sendWhatsAppWithPDF(
      ListOrderModelData order, WhatsappProvider whatsappProvider) async {
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
      final OrderDetailsresponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (OrderDetailsresponse["status"] != "success") {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Unable to fetch order details for PDF generation.',
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
            message: 'Order details not available for PDF generation.',
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

      // Check if orderReturns data is available to determine which config to use
      final billDocumentConfig = (orderData.orderReturns != null &&
              orderData.orderReturns!.returnItems != null &&
              orderData.orderReturns!.returnItems!.isNotEmpty)
          ? (docConfigProvider.getDocumentConfig("Sales and Return Bill") ??
              docConfigProvider.getDocumentConfig("Bill"))
          : docConfigProvider.getDocumentConfig("Bill");

      if (appSettings == null || billDocumentConfig == null) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'App settings or document configuration not loaded.',
          );
        }
        return;
      }

      // Create StandardPrinter instance and generate PDF
      debugPrint('🔄 Starting PDF generation for WhatsApp sharing...');
      final standardPrinter = StandardPrinter(context);

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

      final File? pdfFile = await standardPrinter.generatePDFForSharing(
        cartItems: orderData.cart!.cartItems!,
        formattedTotal: orderData.priceSummary?.netPayable?.toString() ??
            orderData.priceSummary?.netTotal?.toString() ??
            order.grantTotal ??
            '0.00',
        savedTotal: orderData.priceSummary?.savedTotal?.toString() ?? '0.00',
        discountAmount: orderData.priceSummary?.discount?.toString() ?? '0.00',
        orderDate: orderData.orderDate ?? DateTime.now().toIso8601String(),
        orderNumber:
            orderData.orderNumber?.toString() ?? order.orderNumber.toString(),
        isFromLocalStorage: false,
        selectedPaperSize: 'A4',
        billDocumentConfig: billDocumentConfig,
        customerCareNumber: appSettings.customerCarePhone,
        customerCareEmail: appSettings.customerCareEmail,
        customerName: orderData.customerDetails?.name,
        customerPhone: orderData.customerDetails?.phone,
        customerEmail: orderData.customerDetails?.email,
        customerAddress: orderData.customerDetails?.address?.isNotEmpty == true
            ? orderData.customerDetails!.address!.join(', ')
            : null,
        orderReturns: orderData.orderReturns,
        customerAlternatePhone: customerAlternatePhone,
        paymentMethod: paymentMethod,
        orderComment: orderComment,
        deliveryMethod: deliveryMethod,
      );

      if (pdfFile == null) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to generate PDF invoice.',
          );
        }
        return;
      }

      // CRITICAL FIX: Ensure PDF file is completely written and accessible
      debugPrint('✅ PDF generated: ${pdfFile.path}');

      // Wait for file system to sync (important for WhatsApp sharing)
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify PDF file integrity before sharing
      if (!await pdfFile.exists()) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'PDF file was not created properly.',
          );
        }
        return;
      }

      final fileSize = await pdfFile.length();
      debugPrint('📄 PDF file size: $fileSize bytes');

      if (fileSize < 100) {
        debugPrint('⚠️  WARNING: PDF file is too small ($fileSize bytes)');
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message:
                'PDF file appears to be corrupted or empty ($fileSize bytes).',
          );
        }
        return;
      }

      // Test file readability
      try {
        final testBytes = await pdfFile.readAsBytes();
        if (testBytes.isEmpty) {
          throw Exception('PDF file is empty');
        }
        debugPrint(
            '✅ PDF file verification successful: ${testBytes.length} bytes');
      } catch (e) {
        debugPrint('❌ PDF file verification failed: $e');
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'PDF file verification failed: ${e.toString()}',
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
      final currency = appSettings.currency ?? 'INR';

      // Close loading dialog
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
            message:
                'Invoice PDF sent successfully via WhatsApp to $customerPhone!\n\nFile: ${pdfFile.path.split('/').last}\nSize: ${await pdfFile.length()} bytes',
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

          if (fallbackSuccess) {
            showScaffold(
              context: context,
              message:
                  'Invoice message sent via WhatsApp to $customerPhone\n\nPDF saved to: ${pdfFile.path}',
            );
          } else {
            showScaffoldError(
              context: context,
              message:
                  'Failed to send WhatsApp message: ${whatsappProvider.lastError}',
            );
          }
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      debugPrint('Error sending WhatsApp with PDF: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error generating or sending PDF. Please try again.',
        );
      }
    }
  }

  Future<void> _handleWindowsAlternativeSharing(
      File pdfFile, ListOrderModelData order) async {
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
              const Text('PDF Invoice Ready'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice: ${order.orderNumber}'),
              const SizedBox(height: 8),
              Text('File: ${pdfFile.path.split('/').last}'),
              const SizedBox(height: 16),
              const Text(
                'Choose how to share your PDF:',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                      message:
                          'File location opened. The PDF is saved in Documents/epos folder.',
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening file location: $e');
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Open File Location'),
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
                      message:
                          'PDF opened. You can now share it from your PDF viewer.',
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening PDF: $e');
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
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
                      message: 'File path copied to clipboard!',
                    );
                  }
                } catch (e) {
                  debugPrint('Error copying to clipboard: $e');
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Path'),
            ),
          ],
        ),
      );
    }
  }

  void loadInitData() async {
    debugPrint('=== LOAD INIT DATA START ===');
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final activeStoreId = storeSession.activeStore?.storeId?.toString();

      debugPrint(
          'Access Token Available: ${accessToken != null ? "Yes" : "No"}');
      debugPrint('Access Token Length: ${accessToken?.length ?? 0}');

      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      debugPrint('Calling fetchOrders with storeId: $activeStoreId');
      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        filterStore: activeStoreId,
        filterOnlineSales: widget.isOnlineSales ? true : null,
      );
      debugPrint('fetchOrders completed successfully');
    } catch (error, stackTrace) {
      debugPrint('=== LOAD INIT DATA ERROR ===');
      debugPrint('Error Type: ${error.runtimeType}');
      debugPrint('Error Message: $error');
      debugPrint('Stack Trace: $stackTrace');
    } finally {
      setState(() {
        initLoading = false;
      });
      debugPrint('=== LOAD INIT DATA END ===');
    }
  }

  void searchOrders(page) async {
    debugPrint('=== SEARCH ORDERS START ===');
    debugPrint('Requested Page: $page');
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final activeStoreId = storeSession.activeStore?.storeId?.toString();

      // Prepare filters
      final filters = {
        if (orderNumberController.text.isNotEmpty)
          'orderNumber': orderNumberController.text.trim().toUpperCase(),
        if (customerNameController.text.isNotEmpty)
          'filterName': customerNameController.text.trim(),
        if (amountController.text.isNotEmpty)
          'filterPrice': amountController.text.trim(),
        if (emailController.text.isNotEmpty)
          'filterEmail': emailController.text.trim(),
        if (phoneController.text.isNotEmpty)
          'filterPhone': phoneController.text.trim(),
        if (selectedDate != null)
          'date': DateFormat('yyyy-MM-dd').format(selectedDate!),
        if (activeStoreId != null) 'filterStore': activeStoreId,
        if (selectedStatus != null && selectedStatus != 'all')
          'filterStatus': selectedStatus!.trim(), // Add status filter
        'page': page.toString(),
      };

      debugPrint('Search filters: $filters');
      debugPrint('Calling fetchOrders with page: $page');
      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        orderNumber: filters['orderNumber'],
        filterName: filters['filterName'],
        filterPrice: filters['filterPrice'],
        filterEmail: filters['filterEmail'],
        filterPhone: filters['filterPhone'],
        date: filters['date'],
        filterStore: filters['filterStore'],
        filterStatus: filters['filterStatus'],
        page: int.tryParse(filters['page'] ?? '1') ?? 1,
        filterOnlineSales: widget.isOnlineSales ? true : null,
      );

      debugPrint('=== SEARCH ORDERS COMPLETED ===');
      debugPrint('Current Page: ${orderProvider.currentPage}');
      debugPrint('Total Pages: ${orderProvider.totalPages}');
      debugPrint('Orders Count: ${orderProvider.orders.length}');
    } catch (error, stackTrace) {
      debugPrint('Search error: $error');
      debugPrint('Stack trace: $stackTrace');
      showScaffoldError(
        context: context,
        message: 'No Orders Found',
      );
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      orderNumberController.clear();
      customerNameController.clear();
      amountController.clear();
      emailController.clear();
      phoneController.clear();
      storeController.clear();
      statusController.clear();
      storeSelected = null;
      selectedStatus = null;
      selectedDate = null;
      calendarPickerKey = UniqueKey();
    });
    searchOrders(1); // Trigger fresh search after reset

    // Optionally hide filters after reset on mobile
    if (_isMobile(context)) {
      Provider.of<SalesProvider>(context, listen: false)
          .setFiltersVisibility(false);
    }
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  // Helper method to check if device is mobile
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9, // Increased from s9
          0.18,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case 'new':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButtons(ListOrderModelData order, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility,
              size: 18, color: ColorManager.kPrimaryColor),
          onPressed: () {
            final provider = Provider.of<SalesProvider>(context, listen: false);
            provider.setOrderNumber(order.orderNumber ?? "0");
            provider.isOnlineSalesNavigation = widget.isOnlineSales;
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
        IconButton(
          icon: const Icon(Icons.print, size: 18, color: Colors.blue),
          onPressed: () async {
            try {
              String ordersId = order.orderNumber.toString();
              String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;

              final OrderDetailsresponse = await SalesProvider()
                  .listOrderDetails(context, ordersId, accessToken ?? "");

              if (OrderDetailsresponse["status"] == "success") {
                OrderDetailsModel orderDetails =
                    OrderDetailsModel.fromJson(OrderDetailsresponse);

                String formattedTotal = orderDetails
                        .data?.cart?.priceSummary?.netPayable
                        ?.toString() ??
                    orderDetails.data?.cart?.priceSummary?.netTotal
                        .toString() ??
                    "0.00";
                String? savedTotal = orderDetails
                    .data?.cart?.priceSummary?.savedTotal
                    .toString();
                String? discountAmount =
                    orderDetails.data?.priceSummary?.discount?.toString();

                String storeName = orderDetails.data!.cart!.storeName ?? "";
                String orderDate = orderDetails.data!.orderDate ?? "";

                // Extract customer details
                String? customerName = orderDetails.data?.customerDetails?.name;
                String? customerPhone =
                    orderDetails.data?.customerDetails?.phone;
                String? customerEmail =
                    orderDetails.data?.customerDetails?.email;
                String? customerAddress =
                    orderDetails.data?.getCustomerAddressForDisplay();
                String? customerAlternatePhone =
                    orderDetails.data?.customerDetails?.alternatePhone;
                String? customerType =
                    orderDetails.data?.customerDetails?.customerType;
                String? customerVatNumber =
                    orderDetails.data?.kycInfo?.vatNumber;
                String? customerCrNumber = orderDetails.data?.kycInfo?.crNumber;
                String? paymentMethod =
                    orderDetails.data?.paymentDetails?.paymentMethod;
                String? deliveryMethod = orderDetails.data?.deliveryMethodName;

                debugPrint(
                    "[SalesPrint] order=${orderDetails.data?.orderNumber}, customerType=${customerType ?? 'null'}");

                String? orderComment;
                if (orderDetails.data?.orderProps != null) {
                  try {
                    final commentProp =
                        orderDetails.data!.orderProps!.firstWhere(
                      (prop) => prop.propsCode == "COMMENT",
                      orElse: () => OrderDetailsModelDataOrderProp(),
                    );
                    orderComment = commentProp.propsValue;
                  } catch (e) {
                    debugPrint("Error extracting order comment: $e");
                  }
                }

                // Calculate Paid Amount and Payment Breakdown
                double paidAmount = 0.0;
                Map<String, dynamic> paymentBreakdown = {};

                if (orderDetails.data?.payments != null) {
                  // If payments map is available, use it directly
                  orderDetails.data!.payments!.forEach((key, value) {
                    double amount = double.tryParse(value.toString()) ?? 0.0;
                    paidAmount += amount;
                    if (amount > 0) {
                      paymentBreakdown[key] = amount;
                    }
                  });
                } else if (orderDetails.data?.paymentStatus?.toLowerCase() ==
                    'paid') {
                  // Fallback: If paid but no breakdown, assume full amount paid via paymentMethod
                  paidAmount = double.tryParse(formattedTotal) ?? 0.0;

                  if (paymentMethod != null && paymentMethod.isNotEmpty) {
                    // If multiple methods (comma separated), we can't split amount accurately
                    // so we just list them. But for PrintPage we need a map.
                    // If it's a single method, assign full amount.
                    if (!paymentMethod.contains(',')) {
                      paymentBreakdown[paymentMethod] = paidAmount;
                    } else {
                      // Multiple methods but no breakdown amounts available.
                      // We can't populate paymentBreakdown accurately.
                      // The PrintPage will fall back to displaying paymentMethod string.
                    }
                  }
                }

                // Calculate Balance from orderProps
                double? customerCurrentBalance;
                if (orderDetails.data?.orderProps != null) {
                  try {
                    final balanceProp =
                        orderDetails.data!.orderProps!.firstWhere(
                      (prop) => prop.propsCode == "BALANCE",
                      orElse: () => OrderDetailsModelDataOrderProp(),
                    );
                    if (balanceProp.propsValue != null) {
                      customerCurrentBalance =
                          double.tryParse(balanceProp.propsValue.toString());
                    }
                  } catch (e) {
                    debugPrint("Error extracting balance: $e");
                  }
                }

                // Debug: Verify cart items before printing
                final cartItemsForPrint =
                    orderDetails.data?.cart?.cartItems ?? [];
                debugPrint("===== SALES PRINT DEBUG =====");
                debugPrint(
                    "Order=${orderDetails.data?.orderNumber}, token=${orderDetails.data?.tokenNumber}, customer=$customerName");
                debugPrint(
                    "Totals: formattedTotal=$formattedTotal, savedTotal=$savedTotal, discountAmount=$discountAmount");
                debugPrint(
                    "Payment: method=$paymentMethod, breakdown=$paymentBreakdown, paidAmount=$paidAmount");
                debugPrint("Cart items count: ${cartItemsForPrint.length}");
                for (int i = 0; i < cartItemsForPrint.length; i++) {
                  final item = cartItemsForPrint[i];
                  debugPrint(
                      "Item $i: name=${item.productName}, qty=${item.quantity}, price=${item.totalPrice}, tax=${item.taxAmount}");
                }
                debugPrint("=============================");

                // Try auto-print with default printer first
                final autoPrintSuccess = await PrintPage.autoPrint(
                  context,
                  storeName: storeName,
                  cartItems: cartItemsForPrint,
                  formattedTotal: formattedTotal,
                  savedTotal: savedTotal,
                  discountAmount: discountAmount,
                  orderDate: orderDate,
                  orderNumber: orderDetails.data!.orderNumber.toString(),
                  tokenNumber: orderDetails.data?.tokenNumber,
                  customerName: customerName,
                  customerPhone: customerPhone,
                  customerEmail: customerEmail,
                  customerAddress: customerAddress,
                  customerAlternatePhone: customerAlternatePhone,
                  customerVatNumber: customerVatNumber,
                  customerCrNumber: customerCrNumber,
                  customerType: customerType,
                  paymentMethod: paymentMethod,
                  paymentBreakdown:
                      paymentBreakdown.isNotEmpty ? paymentBreakdown : null,
                  orderComment: orderComment,
                  deliveryMethod: deliveryMethod,
                  orderReturns: orderDetails.data?.orderReturns,
                  paidAmount: paidAmount > 0 ? paidAmount : null,
                  customerCurrentBalance: customerCurrentBalance,
                  isDefaultCustomer: _isDefaultCustomerPhone(customerPhone),
                  netExcTax: orderDetails.data?.cart!.priceSummary?.netExcTax
                      ?.toString(),
                );
                debugPrint(
                    "[SALES][PRINT] autoPrintSuccess=$autoPrintSuccess for order=${orderDetails.data?.orderNumber}");

                // Only show print page if auto-print failed
                if (!autoPrintSuccess && mounted) {
                  debugPrint(
                      "[SALES][PRINT] Opening PrintPage because auto print failed.");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrintPage(
                        storeName: storeName,
                        cartItems: orderDetails.data?.cart?.cartItems ?? [],
                        formattedTotal: formattedTotal,
                        savedTotal: savedTotal,
                        discountAmount: discountAmount,
                        orderDate: orderDate,
                        orderNumber: orderDetails.data!.orderNumber.toString(),
                        tokenNumber: orderDetails.data?.tokenNumber,
                        customerName: customerName,
                        customerPhone: customerPhone,
                        customerEmail: customerEmail,
                        customerAddress: customerAddress,
                        customerAlternatePhone: customerAlternatePhone,
                        customerVatNumber: customerVatNumber,
                        customerCrNumber: customerCrNumber,
                        customerType: customerType,
                        paymentMethod: paymentMethod,
                        paymentBreakdown: paymentBreakdown.isNotEmpty
                            ? paymentBreakdown
                            : null,
                        orderComment: orderComment,
                        deliveryMethod: deliveryMethod,
                        orderReturns: orderDetails.data?.orderReturns,
                        paidAmount: paidAmount > 0 ? paidAmount : null,
                        customerCurrentBalance: customerCurrentBalance,
                        isDefaultCustomer:
                            _isDefaultCustomerPhone(customerPhone),
                        netExcTax: orderDetails
                            .data?.cart!.priceSummary?.netExcTax
                            ?.toString(),
                      ),
                    ),
                  );
                }
              }
            } catch (error) {
              debugPrint(error.toString());
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.blue),
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
                        const Text(
                          'More Options',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                ColorManager.kPrimaryColor.withOpacity(0.12),
                            child: const Icon(Icons.share,
                                color: ColorManager.kPrimaryColor),
                          ),
                          title: const Text('Share'),
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
                                        'Invoice not available for sharing.',
                                  );
                                }
                                return;
                              }

                              // Build message with invoice link
                              final String invoiceUrl =
                                  "${APPUrl.baseURL}/invoice-download/$invoiceHash";
                              final String message =
                                  "Here is the link for your invoice: $invoiceUrl";
                              final String encodedMessage =
                                  Uri.encodeComponent(message);

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
                                final OrderDetailsresponse =
                                    await SalesProvider().listOrderDetails(
                                        context, ordersId, accessToken ?? "");
                                if (OrderDetailsresponse["status"] ==
                                    "success") {
                                  final OrderDetailsModel details =
                                      OrderDetailsModel.fromJson(
                                          OrderDetailsresponse);
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
                                          const Text(
                                            'Share invoice',
                                            style: TextStyle(
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
                                                  .withOpacity(0.12),
                                              child: const Icon(Icons.share,
                                                  color: ColorManager
                                                      .kPrimaryColor),
                                            ),
                                            title: const Text('Share'),
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
                                                  ? 'Share to Email ($customerEmail)'
                                                  : 'Share to Email',
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
                                                        'No email app found to share the invoice.',
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
                                                  ? 'Share to WhatsApp ($intlPhone)'
                                                  : 'Share to WhatsApp',
                                            ),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await _shareViaWhatsAppBot(order);
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
                                            title: const Text('Share as PDF'),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await _sharePDFInvoice(order);
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
                                  message:
                                      'Error sharing invoice. Please try again.',
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
                          title: const Text('Return'),
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

                              // Pre-fetch order details to ensure they're loaded
                              String? accessToken =
                                  Provider.of<AuthModel>(context, listen: false)
                                      .token;

                              // Navigate to sales return page
                              Get.find<SideBarController>().index.value = 49;

                              // Show success message
                              if (context.mounted) {
                                showScaffold(
                                  context: context,
                                  message:
                                      'Preparing return for order #${order.orderNumber}',
                                );
                              }
                            } catch (error) {
                              debugPrint(
                                  'Error preparing order return: $error');
                              if (context.mounted) {
                                showScaffoldError(
                                  context: context,
                                  message:
                                      'Error preparing order return. Please try again.',
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
                          title: const Text('Cancel Order'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => CancelOrderModal(
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
                                        message: "Order cancelled successfully",
                                      );
                                      // Refresh orders
                                      salesProvider.fetchOrders(
                                        accessToken: authModel.token ?? "",
                                        page: salesProvider.currentPage,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showScaffoldError(
                                        context: context,
                                        message: "Failed to cancel order: $e",
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
                          title: const Text('Change Order Status'),
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
                                        message:
                                            'Order status updated to $newStatus',
                                      );
                                      salesProvider.fetchOrders(
                                        accessToken: authModel.token ?? "",
                                        page: salesProvider.currentPage,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showScaffoldError(
                                        context: context,
                                        message:
                                            'Failed to update order status: $e',
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
                          title: const Text('Change Payment Status'),
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
                                        message:
                                            'Payment status updated to $newStatus',
                                      );
                                      salesProvider.fetchOrders(
                                        accessToken: authModel.token ?? "",
                                        page: salesProvider.currentPage,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showScaffoldError(
                                        context: context,
                                        message:
                                            'Failed to update payment status: $e',
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

  Widget _buildEmptyState(
      SalesProvider provider, List<ListOrderModelData> displayedOrders) {
    final hasFilters = orderNumberController.text.isNotEmpty ||
        customerNameController.text.isNotEmpty ||
        amountController.text.isNotEmpty ||
        emailController.text.isNotEmpty ||
        phoneController.text.isNotEmpty ||
        storeController.text.isNotEmpty ||
        statusController.text.isNotEmpty ||
        selectedDate != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            displayedOrders.isEmpty && provider.orders.isNotEmpty
                ? (widget.isOnlineSales
                    ? "No online orders available"
                    : "No orders match your filters")
                : "No orders available",
            style: const TextStyle(color: Colors.grey),
          ),
          if (hasFilters)
            TextButton(
              onPressed: resetSearch,
              child: const Text("Reset filters"),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderTable(
      SalesProvider provider, List<ListOrderModelData> displayedOrders) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 5),
      circleRadius: 7,
      offsetValue: const Offset(2, 2),
      blurRadius: 8.0,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: ColorManager.tableBGColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 2.0,
                ),
              ],
            ),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(60), // SI No
                1: FlexColumnWidth(2), // Order #
                2: FlexColumnWidth(3), // Customer
                3: FlexColumnWidth(2), // Date
                4: FlexColumnWidth(1.5), // Items
                5: FlexColumnWidth(2), // Amount
                6: FlexColumnWidth(1.8), // Status
                7: FixedColumnWidth(150), // Actions
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('SI No'),
                    _buildTableHeader('Order #'),
                    _buildTableHeader('Customer'),
                    _buildTableHeader('Date'),
                    _buildTableHeader('Items'),
                    _buildTableHeader('Amount'),
                    _buildTableHeader('Status'),
                    _buildTableHeader('Actions'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(60), // SI No
                      1: FlexColumnWidth(2), // Order #
                      2: FlexColumnWidth(3), // Customer
                      3: FlexColumnWidth(2), // Date
                      4: FlexColumnWidth(1.5), // Items
                      5: FlexColumnWidth(2), // Amount
                      6: FlexColumnWidth(1.8), // Status
                      7: FixedColumnWidth(150), // Actions
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...displayedOrders.asMap().entries.map((entry) {
                        int index = entry.key;
                        ListOrderModelData order = entry.value;
                        PriceSummary priceSummary =
                            order.priceSummary ?? PriceSummary();

                        // Calculate serial number based on pagination
                        int serialNumber = provider.paginationFrom + index;

                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.1),
                          ),
                          children: [
                            SizedBox(
                              height: 55, // Set your desired row height here
                              child: _buildTableCell("$serialNumber"),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell("#${order.orderNumber}"),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                (order.customerName?.isNotEmpty == true)
                                    ? order.customerName!
                                    : (order.customerDetails?.phone
                                                ?.isNotEmpty ==
                                            true
                                        ? order.customerDetails!.phone!
                                        : "NA"),
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  DateHelper.formatYearMonthDay(
                                      order.orderDate!)),
                            ),
                            SizedBox(
                              height: 55,
                              child: _buildTableCell(
                                  "${order.cartItems?.length ?? 0}"),
                            ),
                            SizedBox(
                              height: 55,
                              child: Consumer<AppSettingsProvider>(
                                builder: (context, appSettingsProvider, child) {
                                  final currency = appSettingsProvider
                                          .appSettings?.currency ??
                                      'INR';
                                  return _buildTableCell(
                                      "$currency ${AmountHelper.formatAmount(order.grantTotal ?? 0.0)}");
                                },
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Center(
                                  child: _buildStatusChip(
                                      order.status ?? "pending")),
                            ),
                            SizedBox(
                              height: 55,
                              child: Center(
                                  child: _buildActionButtons(order, context)),
                            ),
                          ],
                        );
                        ;
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile(context) ? 5 : 10,
            vertical: _isMobile(context) ? 10 : 20,
          ),
          padding: EdgeInsets.all(_isMobile(context) ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_isMobile(context) ? 12 : 22),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: _isMobile(context) ? 12.0 : 20.0,
              horizontal: _isMobile(context) ? 12.0 : 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isOnlineSales
                          ? "Online Orders List"
                          : "Orders List",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    Consumer<SalesProvider>(
                      builder: (context, salesProvider, child) {
                        final hasFilters =
                            orderNumberController.text.isNotEmpty ||
                                customerNameController.text.isNotEmpty ||
                                amountController.text.isNotEmpty ||
                                emailController.text.isNotEmpty ||
                                phoneController.text.isNotEmpty ||
                                storeController.text.isNotEmpty ||
                                statusController.text.isNotEmpty ||
                                selectedDate != null;

                        return Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                salesProvider.showFilters
                                    ? Icons.filter_alt
                                    : Icons.filter_alt_outlined,
                                color: ColorManager.kPrimaryColor,
                              ),
                              onPressed: () {
                                salesProvider.toggleFilters();
                              },
                              tooltip: salesProvider.showFilters
                                  ? 'Hide Filters'
                                  : 'Show Filters',
                            ),
                            if (hasFilters)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Search and Filter Section - Responsive (conditionally shown)
                Consumer<SalesProvider>(
                  builder: (context, salesProvider, child) {
                    if (!salesProvider.showFilters) {
                      return const SizedBox.shrink();
                    }

                    return _isMobile(context)
                        ? MobileFilters(
                            orderNumberController: orderNumberController,
                            customerNameController: customerNameController,
                            phoneController: phoneController,
                            amountController: amountController,
                            storeController: storeController,
                            storeSearchController: storeSearchController,
                            statusController: statusController,
                            selectedStatus: selectedStatus,
                            storeSelected: storeSelected,
                            selectedDate: selectedDate,
                            calendarPickerKey: calendarPickerKey,
                            storeList: storeList ?? [],
                            statusOptions: statusOptions,
                            onSearch: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  value.length > 2) {
                                searchOrders(1);
                              }
                            },
                            onStoreChanged:
                                (GetStoreModelData? storeModelData) {
                              setState(() {
                                if (storeModelData?.id == 0) {
                                  storeSelected = null;
                                  storeController.clear();
                                } else {
                                  storeSelected = storeModelData;
                                  if (storeModelData != null) {
                                    storeController.text =
                                        storeModelData.id.toString();
                                  } else {
                                    storeController.clear();
                                  }
                                }
                              });
                              searchOrders(1);
                            },
                            onStatusChanged: (String? status) {
                              setState(() {
                                selectedStatus = status;
                                if (status != null) {
                                  statusController.text = status;
                                } else {
                                  statusController.clear();
                                }
                              });
                              searchOrders(1);
                            },
                            onDateSelected: (DateTime date) {
                              setState(() {
                                selectedDate = date;
                              });
                              searchOrders(1);
                            },
                            onReset: resetSearch,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First row of filters with equal width
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Order #
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Order #",
                                            style: buildCustomStyle(
                                              FontWeightManager.regular,
                                              FontSize.s14,
                                              0.27,
                                              Colors.black.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        buildColumnWidgetForTextFields(
                                          height: 45,
                                          onchanged: (value) {
                                            if (value!.isEmpty ||
                                                value.length > 2) {
                                              searchOrders(1);
                                            }
                                          },
                                          controller: orderNumberController,
                                          size: size,
                                          hintText: 'Order Number',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Customer
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Customer",
                                            style: buildCustomStyle(
                                              FontWeightManager.regular,
                                              FontSize.s14,
                                              0.27,
                                              Colors.black.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        buildColumnWidgetForTextFields(
                                          height: 45,
                                          onchanged: (value) {
                                            if (value!.isEmpty ||
                                                value.length > 2) {
                                              searchOrders(1);
                                            }
                                          },
                                          controller: customerNameController,
                                          size: size,
                                          hintText: 'Customer Name',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Phone
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Phone",
                                            style: buildCustomStyle(
                                              FontWeightManager.regular,
                                              FontSize.s14,
                                              0.27,
                                              Colors.black.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        buildColumnWidgetForTextFields(
                                          height: 45,
                                          onchanged: (value) {
                                            if (value!.isEmpty ||
                                                value.length > 2) {
                                              searchOrders(1);
                                            }
                                          },
                                          controller: phoneController,
                                          size: size,
                                          hintText: 'Phone',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Date
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Date",
                                            style: buildCustomStyle(
                                              FontWeightManager.regular,
                                              FontSize.s14,
                                              0.27,
                                              Colors.black.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        BuildBoxShadowContainer(
                                          circleRadius: 7,
                                          height: 45,
                                          child: Center(
                                            child: CalendarPickerTableCell(
                                              key: calendarPickerKey,
                                              onDateSelected: (DateTime date) {
                                                setState(() {
                                                  selectedDate = date;
                                                });
                                                searchOrders(1);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Second row of filters with equal width
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Price
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Price",
                                            style: buildCustomStyle(
                                              FontWeightManager.regular,
                                              FontSize.s14,
                                              0.27,
                                              Colors.black.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        buildColumnWidgetForTextFields(
                                          height: 45,
                                          onchanged: (value) {
                                            if (value!.isEmpty ||
                                                value.length > 2) {
                                              searchOrders(1);
                                            }
                                          },
                                          controller: amountController,
                                          size: size,
                                          hintText: 'Price',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 15),

// Status Filter
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Status",
                                            style: buildCustomStyle(
                                              FontWeightManager.regular,
                                              FontSize.s14,
                                              0.27,
                                              Colors.black.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          height: 45,
                                          child: BuildBoxShadowContainer(
                                            circleRadius: 7,
                                            alignment: Alignment.centerLeft,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 0, vertical: 0),
                                            padding:
                                                const EdgeInsets.only(left: 15),
                                            color: Colors.white,
                                            child:
                                                DropdownButtonFormField<String>(
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              value: selectedStatus,
                                              dropdownColor: Colors.white,
                                              hint: Text(
                                                'Select Status',
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s10,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                              items: [
                                                DropdownMenuItem<String>(
                                                  value: null,
                                                  child: Text(
                                                    'All',
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s10,
                                                      0.27,
                                                      ColorManager.textColor
                                                          .withOpacity(.5),
                                                    ),
                                                  ),
                                                ),
                                                ...statusOptions
                                                    .map((String status) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: status,
                                                    child: Text(
                                                      status.toUpperCase(),
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s10,
                                                        0.27,
                                                        ColorManager.textColor
                                                            .withOpacity(.5),
                                                      ),
                                                    ),
                                                  );
                                                }).toList()
                                              ],
                                              onChanged: (String? status) {
                                                setState(() {
                                                  selectedStatus = status;
                                                  if (status != null) {
                                                    statusController.text =
                                                        status;
                                                  } else {
                                                    statusController.clear();
                                                  }
                                                });
                                                searchOrders(1);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 15),

                                  // Reset button
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 35.0),
                                      child: CustomRoundButton(
                                        title: "Reset",
                                        boxColor: Colors.white,
                                        textColor: ColorManager.kPrimaryColor,
                                        fct: resetSearch,
                                        height: 45,
                                        width: double
                                            .infinity, // Take full available width
                                        fontSize: FontSize.s12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                  },
                ),

                Consumer<SalesProvider>(
                  builder: (context, salesProvider, child) {
                    return salesProvider.showFilters
                        ? const SizedBox(height: 20)
                        : const SizedBox.shrink();
                  },
                ),
                Expanded(
                  child: Consumer<SalesProvider>(
                    builder: (context, orderProvider, child) {
                      if (initLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Frontend filtering for online sales
                      final displayedOrders = widget.isOnlineSales
                          ? orderProvider.orders
                              .where((order) => order.isOnline == true)
                              .toList()
                          : orderProvider.orders;

                      if (displayedOrders.isEmpty) {
                        // Pass displayedOrders to empty state for correct message
                        return _buildEmptyState(orderProvider, displayedOrders);
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: _isMobile(context)
                                ? ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: displayedOrders.length,
                                    itemBuilder: (context, index) {
                                      return MobileOrderCard(
                                        order: displayedOrders[index],
                                        index: index,
                                        onSharePDF: _sharePDFInvoice,
                                        onShareWhatsApp: _shareViaWhatsAppBot,
                                      );
                                    },
                                  )
                                : _buildOrderTable(
                                    orderProvider, displayedOrders),
                          ),
                          PaginationControl(
                            currentPage: orderProvider.currentPage,
                            totalPages: orderProvider.totalPages,
                            onPageChanged: (int page) {
                              debugPrint('=== PAGINATION CLICKED ===');
                              debugPrint('User clicked page: $page');
                              debugPrint(
                                  'Current provider page: ${orderProvider.currentPage}');
                              debugPrint(
                                  'Total pages: ${orderProvider.totalPages}');
                              searchOrders(page);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
