import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:flutter/foundation.dart';

class StandardPrinter {
  final BuildContext context;

  StandardPrinter(this.context);

  // Helper method to get or create the epos directory
  Future<Directory> _getEposDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final eposDir = Directory('${documentsDir.path}/epos');
      if (!await eposDir.exists()) {
        await eposDir.create(recursive: true);
        debugPrint('Created epos directory: ${eposDir.path}');
      }
      return eposDir;
    } catch (e) {
      debugPrint('Could not access Documents/epos directory, using temp: $e');
      return await getTemporaryDirectory();
    }
  }

  Future<void> generateAndPrintPDF({
    required BluetoothPrinter? selectedPrinter,
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
  }) async {
    try {
      // Ensure billDocumentConfig is loaded before printing
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: "Document configurations not loaded. Please wait.",
          );
        }
        return;
      }

      // Check if printer is selected before proceeding
      if (selectedPrinter == null) {
        debugPrint("ERROR: No printer selected for printing");
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: "No Printer Selected",
          );
        }
        return;
      }

      final displayConfig = billDocumentConfig.displayConfiguration?.options;
      
      // Debug the document configuration being used
      debugPrint("===== DOCUMENT CONFIG BEING USED FOR PRINTING =====");
      debugPrint("billDocumentConfig ID: ${billDocumentConfig.id}");
      debugPrint("billDocumentConfig Type: ${billDocumentConfig.type}");
      debugPrint("billDocumentConfig Updated At: ${billDocumentConfig.updatedAt}");
      debugPrint("billDocumentConfig Has Display Config: ${billDocumentConfig.displayConfiguration != null}");
      debugPrint("Display Config Options Count: ${displayConfig?.length ?? 0}");
      if (displayConfig != null) {
        debugPrint("Display Config Keys: ${displayConfig.keys.toList()}");
      }
      debugPrint("===== END DOCUMENT CONFIG INFO =====");
      
      _debugPrintTemplateSettings(displayConfig);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Preparing $selectedPaperSize document for printing...",
        );
      }

      // Create a PDF document
      final pdf = pw.Document();

      // Get settings from the loaded display configuration
      final updatedSettings = displayConfig;

      debugPrint("PDF Generation - Using user settings:");
      debugPrint(
          "showStoreName: ${updatedSettings?['showStoreName']?.visible}");
      debugPrint(
          "showDescription: ${updatedSettings?['showDescription']?.visible}");
      debugPrint(
          "showStoreAddress: ${updatedSettings?['showStoreAddress']?.visible}");
      debugPrint(
          "showFssaiInfo: ${updatedSettings?['showFssaiInfo']?.visible}");
      debugPrint("showTel: ${updatedSettings?['showTel']?.visible}");
      debugPrint("showEmail: ${updatedSettings?['showEmail']?.visible}");
      debugPrint(
          "showInvoiceTitle: ${updatedSettings?['showInvoiceTitle']?.visible}");
      debugPrint(
          "showInvoiceNumber: ${updatedSettings?['showInvoiceNumber']?.visible}");
      debugPrint(
          "showDateHeader: ${updatedSettings?['showDateHeader']?.visible}");
      debugPrint("showSLNumber: ${updatedSettings?['showSLNumber']?.visible}");
      debugPrint(
          "showParticulars: ${updatedSettings?['showParticulars']?.visible}");
      debugPrint("showMRP: ${updatedSettings?['showMRP']?.visible}");
      debugPrint("showQty: ${updatedSettings?['showQty']?.visible}");
      debugPrint("showRate: ${updatedSettings?['showRate']?.visible}");
      debugPrint("showTotal: ${updatedSettings?['showTotal']?.visible}");
      debugPrint("showDiscount: ${updatedSettings?['showDiscount']?.visible}");
      debugPrint(
          "showNetAmount: ${updatedSettings?['showNetAmount']?.visible}");
      debugPrint("showMRPTotal: ${updatedSettings?['showMRPTotal']?.visible}");
      debugPrint("showSaved: ${updatedSettings?['showSaved']?.visible}");
      debugPrint(
          "showAmountInWords: ${updatedSettings?['showAmountInWords']?.visible}");
      debugPrint(
          "showItemsCount: ${updatedSettings?['showItemsCount']?.visible}");
      debugPrint(
          "showThankYouMessage: ${updatedSettings?['showThankYouMessage']?.visible}");
      debugPrint("showQRCode: ${updatedSettings?['showQRCode']?.visible}");
      debugPrint(
          "showTermsConditions: ${updatedSettings?['showTermsConditions']?.visible}");

      // Access Payment Gateways Provider for QR code link
      final paymentGatewaysProvider =
          Provider.of<PaymentGatewaysProvider>(context, listen: false);
      final manualPaymentGateway = paymentGatewaysProvider.paymentGateways
          .firstWhere((gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY",
              orElse: () => PaymentGateway(
                    id: 0,
                    name: "",
                    code: "",
                    label: "",
                    link: "",
                    image: "",
                    status: "",
                    isWebActive: 0,
                    isAndroidActive: 0,
                    isIosActive: 0,
                    contactEmail: "",
                    contactPhone: "",
                    createdAt: "",
                    updatedAt: "",
                  ));

      // Determine page format based on paper size
      PdfPageFormat pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;

      // Define styles with adjustments for A5 vs A4 - optimized for space and professional look
      final headerStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 16.0
            : 18.0, // Increased for better hierarchy
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table text
        color: PdfColors.black,
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 5.0 : 7.0, // Reduced further
        color: PdfColors.black,
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table headers
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final summaryStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 8.0
            : 10.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final netTotalStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );

      // Add content to a multi-page PDF with minimal margins and optimized spacing
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(15), // Reduced from 30
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5), // Reduced from 10
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6), // Reduced from 8
              textAlign: pw.TextAlign.center,
            ),
          ),
          build: (pw.Context context) => [
            // Wrap entire content in a Column so it flows
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with store information - compact design
                pw.Center(
                  child: pw.Column(
                    children: [
                      // Store name
                      if (updatedSettings?['showStoreName']?.visible == true)
                        pw.Text(
                          updatedSettings?['showStoreName']?.value as String? ??
                              billDocumentConfig.header ??
                              'STORE NAME',
                          style: headerStyle,
                        ),

                      // Store description
                      if (updatedSettings?['showDescription']?.visible == true)
                        pw.Text(
                          updatedSettings?['showDescription']?.value
                                  as String? ??
                              billDocumentConfig.subheader ??
                              '',
                          style: pw.TextStyle(
                            fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                          ),
                        ),

                      // Store address - compact display
                      if (updatedSettings?['showStoreAddress']?.visible ==
                          true) ...[
                        if ((updatedSettings?['showStoreAddress']?.value
                                    as String?)
                                ?.isNotEmpty ==
                            true)
                          pw.Text(
                            updatedSettings!['showStoreAddress']!.value
                                as String,
                            style: bodyStyle,
                          ),
                      ],

                      // FSSAI info - compact display
                      if (updatedSettings?['showFssaiInfo']?.visible ==
                          true) ...[
                        if ((updatedSettings?['showFssaiInfo']?.value
                                    as String?)
                                ?.isNotEmpty ==
                            true)
                          pw.Text(
                            updatedSettings!['showFssaiInfo']!.value as String,
                            style: bodyStyle,
                          ),
                      ],

                      // Contact information - compact display
                      if (updatedSettings?['showTel']?.visible == true)
                        pw.Text(
                          updatedSettings?['showTel']?.value as String? ??
                              customerCareNumber,
                          style: bodyStyle,
                        ),

                      if (updatedSettings?['showEmail']?.visible == true)
                        pw.Text(
                          updatedSettings?['showEmail']?.value as String? ??
                              customerCareEmail,
                          style: bodyStyle,
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 5), // Reduced from 10

                // Invoice information - minimal design without borders
                if ((updatedSettings?['showInvoiceTitle']?.visible == true) ||
                    (updatedSettings?['showInvoiceNumber']?.visible == true))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8), // Reduced padding
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        if (updatedSettings?['showInvoiceTitle']?.visible ==
                            true)
                          pw.Text(
                              updatedSettings?['showInvoiceTitle']?.value
                                      as String? ??
                                  billDocumentConfig.header ??
                                  'INVOICE',
                              style: subheaderStyle),
                        if (updatedSettings?['showInvoiceNumber']?.visible ==
                            true)
                          pw.Text(
                              (billDocumentConfig.numberPrefix != null &&
                                      billDocumentConfig
                                          .numberPrefix!.isNotEmpty)
                                  ? '${billDocumentConfig.numberPrefix}$orderNumber'
                                  : 'No: $orderNumber',
                              style: subheaderStyle),
                      ],
                    ),
                  ),

                // Date and Time Row - minimal design
                _buildDateTimeRowPDF(selectedPaperSize, orderDate),

                // Customer Information Section - if available
                if (customerName != null ||
                    customerPhone != null ||
                    customerEmail != null ||
                    customerAddress != null)
                  _buildCustomerDetailsPDF(
                    selectedPaperSize,
                    customerName,
                    customerPhone,
                    customerEmail,
                    customerAddress,
                    subheaderStyle,
                    bodyStyle,
                  ),

                // Items table - minimal design without borders
                if ((updatedSettings?['showSLNumber']?.visible == true) ||
                    (updatedSettings?['showParticulars']?.visible == true) ||
                    (updatedSettings?['showMRP']?.visible == true) ||
                    (updatedSettings?['showQty']?.visible == true) ||
                    (updatedSettings?['showRate']?.visible == true) ||
                    (updatedSettings?['showTotal']?.visible == true))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8), // Reduced padding
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfItemsTable(
                            tableHeaderStyle,
                            bodyStyle,
                            updatedSettings,
                            cartItems,
                            isFromLocalStorage,
                            billDocumentConfig),
                      ],
                    ),
                  ),

                // Cart Total Row - added after items table
                _buildCartTotalRow(selectedPaperSize, cartItems, isFromLocalStorage, summaryStyle),

                pw.SizedBox(height: 5), // Reduced from 8

                // Summary - minimal design without borders
                if ((updatedSettings?['showItemsCount']?.visible == true) ||
                    (updatedSettings?['showMRPTotal']?.visible == true) ||
                    (updatedSettings?['showSaved']?.visible == true) ||
                    (updatedSettings?['showDiscount']?.visible == true) ||
                    (updatedSettings?['showNetAmount']?.visible == true))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8), // Reduced padding
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ORDER SUMMARY', style: subheaderStyle),
                        pw.SizedBox(height: 5), // Reduced from 10
                        _buildPdfSummary(
                            summaryStyle,
                            netTotalStyle,
                            updatedSettings,
                            formattedTotal,
                            savedTotal,
                            discountAmount,
                            cartItems.length,
                            billDocumentConfig),
                      ],
                    ),
                  ),

                // Amount in words - consistent with summary layout
                if (updatedSettings?['showAmountInWords']?.visible == true)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8), // Same padding as summary
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Amount in words:',
                          style:
                              summaryStyle, // Same style as other summary items
                        ),
                        pw.Text(
                          '${AmountHelper().convertNumberToWords(double.parse(formattedTotal))} Only.',
                          style:
                              summaryStyle, // Same style as other summary items
                          textAlign: pw.TextAlign.right,
                        ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 5), // Reduced from 10

                // Footer section - compact design
                pw.Column(
                  children: [
                    // QR Code for payment - compact size
                    if (updatedSettings?['showQRCode']?.visible == true) ...[
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: manualPaymentGateway.link
                                  .replaceAll(
                                      '{formattedTotal}', formattedTotal)
                                  .replaceAll('{orderNumber}', orderNumber),
                              width: selectedPaperSize == 'A5'
                                  ? 80
                                  : 100, // Reduced size
                              height: selectedPaperSize == 'A5'
                                  ? 80
                                  : 100, // Reduced size
                            ),
                            pw.SizedBox(height: 3), // Reduced from 5
                            pw.Text(
                              updatedSettings?['showQRCode']?.value
                                      as String? ??
                                  'Scan to Pay',
                              style: pw.TextStyle(
                                fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 5), // Reduced from 10
                    ],

                    // Order ID Barcode - compact size
                    _buildOrderBarcodePDF(selectedPaperSize, orderNumber),

                    // Thank You message - reduced font size
                    if (updatedSettings?['showThankYouMessage']?.visible ==
                        true)
                      pw.Center(
                        child: pw.Text(
                          updatedSettings?['showThankYouMessage']?.value
                                  as String? ??
                              'Thank You... Visit Again',
                          style: pw.TextStyle(
                            fontSize: selectedPaperSize == 'A5'
                                ? 8.0
                                : 10.0, // Reduced from subheaderStyle
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),

                    // Terms & Conditions - compact design
                    if (updatedSettings?['showTermsConditions']?.visible ==
                        true) ...[
                      if (_hasTermsData(
                          updatedSettings, billDocumentConfig)) ...[
                        _buildTermsConditionsBoxPDF(selectedPaperSize,
                            updatedSettings, billDocumentConfig),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Save PDF to documents/epos folder for better organization
      final output = await _getEposDirectory();
      
      // Sanitize filename for Windows compatibility
      String sanitizedOrderNumber = orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/Receipt_$sanitizedOrderNumber.pdf');
      await file.writeAsBytes(await pdf.save());

      // Determine if running on Windows
      final bool isWindows = Platform.isWindows;

      if (isWindows) {
        await _handleWindowsPdf(file);
      } else {
        // Try to open the PDF directly for non-Windows platforms
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            if (!isWindows) {
              await _sharePdfFallback(file);
            } else {
              if (context.mounted) {
                showScaffold(
                    context: context, message: "PDF created successfully");
                Navigator.pop(context);
                SideBarController sideBarController =
                    Get.put(SideBarController());
                sideBarController.index.value = 46;
              }
            }
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context, message: "PDF opened for printing");
              Navigator.pop(context);
              SideBarController sideBarController =
                  Get.put(SideBarController());
              sideBarController.index.value = 46;
            }
          }
        } catch (e) {
          debugPrint("Error opening PDF: ${e.toString()}");
          if (!isWindows) {
            await _sharePdfFallback(file);
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context, message: "PDF created successfully");
              Navigator.pop(context);
              SideBarController sideBarController =
                  Get.put(SideBarController());
              sideBarController.index.value = 46;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error generating PDF: ${e.toString()}");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: ${e.toString()}",
        );
      }
    }
  }

  // Windows-specific handling for PDF
  Future<void> _handleWindowsPdf(File file) async {
    try {
      // First try to open with the default Windows PDF viewer
      final result = await OpenFile.open(file.path);

      // Always close the page on Windows, regardless of result
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e) {
      debugPrint("Windows PDF handling error: $e");
      // Still close the page on error
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    }
  }

  // Show information about file location (for Windows) - Now unused but kept for reference
  void _showFileLocationInfo(File file) {
    if (context.mounted) {
      // Just close the page instead of showing dialog
      Navigator.pop(context);
      SideBarController sideBarController = Get.put(SideBarController());
      sideBarController.index.value = 46;
    }
  }

  // Fallback method to share PDF if direct opening fails (for mobile platforms)
  Future<void> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share PDF as fallback...");
      // Only try to share on non-Windows platforms
      if (!Platform.isWindows) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject:
              'Receipt #${file.path.split('/').last.replaceAll('.pdf', '').replaceAll('Receipt-', '')}',
          text: 'Your receipt for order',
        );

        if (context.mounted) {
          showScaffold(
              context: context, message: "PDF shared. Please open it to print");
          Navigator.pop(context);
          SideBarController sideBarController = Get.put(SideBarController());
          sideBarController.index.value = 46;
        }
      } else {
        // For Windows, show the file location
        _showFileLocationInfo(file);
      }
    } catch (e) {
      debugPrint("Error sharing PDF fallback: ${e.toString()}");
      if (context.mounted) {
        if (Platform.isWindows) {
          // Show file location on Windows
          _showFileLocationInfo(file);
        } else {
          showScaffoldError(
            context: context,
            message:
                "Unable to open or share PDF: ${e.toString()}. Please check app permissions.",
          );
        }
      }
    }
  }

  pw.Widget _buildPdfItemsTable(
      pw.TextStyle headerStyle,
      pw.TextStyle contentStyle,
      Map<String, DisplayOption>? displayConfig,
      List<dynamic> cartItems,
      bool isFromLocalStorage,
      DocumentConfig? billDocumentConfig) {
    // Create headers for the table based on visibility and resolved labels
    final List<String> tableHeaders = [];
    final Map<int, pw.Alignment> cellAlignmentsMap = {};
    final List<double> columnWidths = [];
    int visibleColIndex = 0;

    if (displayConfig?['showSLNumber']?.visible == true) {
      final slLabel =
          (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSLNumber']!.value as String
              : 'SL#';
      tableHeaders.add(slLabel);
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(1); // Smaller width for serial number
    }
    if (displayConfig?['showParticulars']?.visible == true) {
      final label =
          (displayConfig?['showParticulars']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showParticulars']!.value as String
              : 'PARTICULARS';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(
          5); // Much larger width for product names to accommodate long names
    }
    if (displayConfig?['showMRP']?.visible == true) {
      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : 'MRP';
      tableHeaders.add(mrpLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showQty']?.visible == true) {
      final label =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : 'QTY';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Compact for quantity
    }
    if (displayConfig?['showRate']?.visible == true) {
      final label =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : 'RATE';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showTotal']?.visible == true) {
      final label =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : 'TOTAL';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for total values
    }

    // Create table data based on visibility with smart product name handling
    List<List<String>> tableData = [];
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';

      if (isFromLocalStorage) {
        productName = item['productName'] ?? '';
        mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        quantity = item['quantity'] ?? '0';
        unitPrice =
            (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
        totalPrice =
            (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
      } else {
        // Handle different object types - check if it's a Map or an object
        if (item is Map<String, dynamic>) {
          // Handle Map case (from API responses or converted data)
          productName = item['product_name']?.toString() ??
              item['productName']?.toString() ??
              '';
          mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
          quantity = item['quantity']?.toString() ?? '0';
          unitPrice = (double.tryParse(item['unit_price']?.toString() ??
                      item['unitPrice']?.toString() ??
                      '0') ??
                  0.0)
              .toStringAsFixed(2);
          totalPrice = (double.tryParse(item['total_price']?.toString() ??
                      item['totalPrice']?.toString() ??
                      '0') ??
                  0.0)
              .toStringAsFixed(2);
        } else {
          // Handle object case (OrderDetailsModelDataCartItem or similar)
          try {
            productName = item.productName?.toString() ?? '';
            mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
            quantity = item.quantity?.toString() ?? '0';
            unitPrice =
                (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
                    .toStringAsFixed(2);
            totalPrice =
                (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
                    .toStringAsFixed(2);
          } catch (e) {
            debugPrint('Error accessing cart item properties: $e');
            debugPrint('Item type: ${item.runtimeType}');
            debugPrint('Item: $item');
            // Fallback to safe defaults
            productName = 'Unknown Product';
            mrp = '0.00';
            quantity = '0';
            unitPrice = '0.00';
            totalPrice = '0.00';
          }
        }
      }

      // Use full product name without truncation for PDF
      String displayProductName = productName;

      List<String> rowData = [];
      if (displayConfig?['showSLNumber']?.visible == true) {
        rowData.add((i + 1).toString());
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        rowData.add(displayProductName);
      }
      if (displayConfig?['showMRP']?.visible == true) rowData.add(mrp);
      if (displayConfig?['showQty']?.visible == true) rowData.add(quantity);
      if (displayConfig?['showRate']?.visible == true) rowData.add(unitPrice);
      if (displayConfig?['showTotal']?.visible == true) rowData.add(totalPrice);

      tableData.add(rowData);
    }

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      headerStyle: headerStyle,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      headerHeight: 20, // Reduced from 25
      cellStyle: contentStyle,
      cellHeight: 18, // Reduced from 25
      cellAlignments: cellAlignmentsMap,
      cellPadding: const pw.EdgeInsets.all(3), // Reduced from 5
      border: const pw.TableBorder(
        top: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        left: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        right: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
      ),
      columnWidths: {
        for (var i in columnWidths.asMap().keys)
          i: pw.FlexColumnWidth(columnWidths[i])
      },
    );
  }

  pw.Widget _buildPdfSummary(
      pw.TextStyle style,
      pw.TextStyle netTotalStyle,
      Map<String, DisplayOption>? displayConfig,
      String formattedTotal,
      String? savedTotal,
      String? discountAmount,
      int itemCount,
      DocumentConfig? billDocumentConfig) {
    double savedTotalValue = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double formattedTotalValue = double.tryParse(formattedTotal) ?? 0.0;
    double discountAmountValue = double.tryParse(discountAmount ?? '0.0') ?? 0.0;
    double totalMRP = savedTotalValue + formattedTotalValue;

    List<pw.Widget> summaryWidgets = [];

    // Display Item Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total Items:', style: style),
            pw.Text(itemCount.toString(), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 3)); // Reduced from 5
    }

    // Display Total MRP
    if (displayConfig?['showMRPTotal']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total MRP:', style: style),
            pw.Text(totalMRP.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 3)); // Reduced from 5
    }

    // Display You Saved
    if (displayConfig?['showSaved']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('You Saved:', style: style),
            pw.Text(savedTotalValue.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 3)); // Reduced from 5
    }

    // Display Discount
    if (displayConfig?['showDiscount']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Discount:', style: style),
            pw.Text(discountAmountValue.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 3)); // Reduced from 5
    }

    // Display Net Total (Amount)
    if (displayConfig?['showNetAmount']?.visible == true) {
      const label = 'Net Total';
      summaryWidgets.add(pw.Divider(color: PdfColors.black));
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$label:', style: netTotalStyle),
            pw.Text(formattedTotalValue.toStringAsFixed(2),
                style: netTotalStyle),
          ],
        ),
      );
    }

    return pw.Column(children: summaryWidgets);
  }

  // Date and Time Row for PDF - minimal design
  pw.Widget _buildDateTimeRowPDF(String selectedPaperSize, String orderDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          vertical: 0, horizontal: 8), // Reduced padding
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Date: ${DateHelper.formatISODate(orderDate)}',
            style: pw.TextStyle(
              fontSize:
                  selectedPaperSize == 'A5' ? 7.0 : 9.0, // Reduced font size
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Time: ${DateHelper.formatISODateToIST(orderDate)}',
            style: pw.TextStyle(
              fontSize:
                  selectedPaperSize == 'A5' ? 7.0 : 9.0, // Reduced font size
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Order ID Barcode for PDF - compact design with vertical padding
  pw.Widget _buildOrderBarcodePDF(
      String selectedPaperSize, String orderNumber) {
    return pw.Center(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            vertical: 5), // Added vertical padding
        child: pw.Column(
          children: [
            pw.BarcodeWidget(
              textPadding: 2,
              barcode: pw.Barcode.code128(),
              data: orderNumber,
              width: selectedPaperSize == 'A5' ? 100 : 120, // Smaller size
              height: selectedPaperSize == 'A5' ? 25 : 30, // Smaller height
            ),
            pw.SizedBox(height: 5), // Reduced from 10
          ],
        ),
      ),
    );
  }

  // Helper method to check if terms data is available
  bool _hasTermsData(Map<String, DisplayOption>? displayConfig,
      DocumentConfig billDocumentConfig) {
    // Get terms from displayConfig value first, then fallback to billDocumentConfig
    String? terms = displayConfig?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      // Fallback to billDocumentConfig terms
      terms = billDocumentConfig.terms;
    }
    return terms != null && terms.trim().isNotEmpty;
  }

  // Terms & Conditions in a Box for PDF - minimal design
  pw.Widget _buildTermsConditionsBoxPDF(
      String selectedPaperSize,
      Map<String, DisplayOption>? displayConfig,
      DocumentConfig billDocumentConfig) {
    // Get terms from displayConfig value first, then fallback to billDocumentConfig
    String? terms = displayConfig?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      terms = billDocumentConfig.terms;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5), // Reduced padding
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: PdfColors.black),
          ...terms!.split('\n').map((term) {
            if (term.trim().isEmpty) {
              return pw.SizedBox(height: 1); // Reduced from 2
            }
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2), // Reduced from 3
              child: pw.Text(
                term,
                style: pw.TextStyle(
                  fontSize: selectedPaperSize == 'A5'
                      ? 7.0
                      : 7.0, // Reduced font size
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    if (displayConfig == null) {
      debugPrint("ERROR: Display configuration is null!");
      return;
    }

    debugPrint("===== DISPLAY CONFIGURATION DEBUG ANALYSIS =====");
    debugPrint("DisplayConfig Map Type: ${displayConfig.runtimeType}");
    debugPrint("DisplayConfig Keys Count: ${displayConfig.keys.length}");
    debugPrint("DisplayConfig Keys: ${displayConfig.keys.toList()}");
    
    debugPrint("\nDETAILED DISPLAY CONFIGURATION:");
    displayConfig.forEach((key, value) {
      debugPrint("- $key:");
      debugPrint("  * visible: ${value.visible} (${value.visible.runtimeType})");
      debugPrint("  * value: ${value.value} (${value.value.runtimeType})");
      debugPrint("  * DisplayOption object: $value");
    });
    
    // Special focus on showDiscount
    if (displayConfig.containsKey('showDiscount')) {
      final discountConfig = displayConfig['showDiscount']!;
      debugPrint("\n🔍 SHOWDISCOUNT DETAILED ANALYSIS:");
      debugPrint("  * Raw object: $discountConfig");
      debugPrint("  * Visible field: ${discountConfig.visible}");
      debugPrint("  * Visible type: ${discountConfig.visible.runtimeType}");
      debugPrint("  * Value field: ${discountConfig.value}");
      debugPrint("  * Value type: ${discountConfig.value.runtimeType}");
      debugPrint("  * Object hashCode: ${discountConfig.hashCode}");
    } else {
      debugPrint("\n⚠️ showDiscount key NOT FOUND in displayConfig!");
    }
    debugPrint("===== END DISPLAY CONFIGURATION DEBUG =====");
  }

  // Customer Details Section for PDF - compact design with increased font size
  pw.Widget _buildCustomerDetailsPDF(
    String selectedPaperSize,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    pw.TextStyle headerStyle,
    pw.TextStyle bodyStyle,
  ) {
    // Create a larger style for customer details
    final customerDetailStyle = pw.TextStyle(
      fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0, // Increased from bodyStyle
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );
    
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Increased vertical padding
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Add a header for customer details
          // pw.Text(
          //   'CUSTOMER DETAILS',
          //   style: pw.TextStyle(
          //     fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
          //     fontWeight: pw.FontWeight.bold,
          //     color: PdfColors.black,
          //   ),
          // ),
          // pw.SizedBox(height: 5),
          // Show Name and Phone on a single line without labels when both are present
          if ((customerName != null && customerName.isNotEmpty) &&
              (customerPhone != null && customerPhone.isNotEmpty))
            pw.Text('$customerName - $customerPhone', style: customerDetailStyle)
          else ...[
            if (customerName != null && customerName.isNotEmpty)
              pw.Text(customerName, style: customerDetailStyle),
            if (customerPhone != null && customerPhone.isNotEmpty)
              pw.Text(customerPhone, style: customerDetailStyle),
          ],
          // if (customerEmail != null && customerEmail.isNotEmpty)
          //   pw.Text('Email: $customerEmail', style: customerDetailStyle),
          if (customerAddress != null && customerAddress.isNotEmpty)
            pw.Text(customerAddress, style: customerDetailStyle),
        ],
      ),
    );
  }

  // Helper method to calculate cart total from items
  double _calculateCartTotal(List<dynamic> cartItems, bool isFromLocalStorage) {
    double total = 0.0;
    
    for (var item in cartItems) {
      double itemTotal = 0.0;
      
      if (isFromLocalStorage) {
        itemTotal = double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0;
      } else {
        if (item is Map<String, dynamic>) {
          itemTotal = double.tryParse(item['total_price']?.toString() ?? 
                                    item['totalPrice']?.toString() ?? '0') ?? 0.0;
        } else {
          try {
            itemTotal = double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0;
          } catch (e) {
            debugPrint('Error accessing item totalPrice: $e');
            itemTotal = 0.0;
          }
        }
      }
      
      total += itemTotal;
    }
    
    return total;
  }

  // Helper method to build cart total row after items table
  pw.Widget _buildCartTotalRow(
    String selectedPaperSize,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    pw.TextStyle summaryStyle,
  ) {
    final cartTotal = _calculateCartTotal(cartItems, isFromLocalStorage);
    
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TOTAL:',
            style: pw.TextStyle(
              fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.Text(
            'Rs. ${cartTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Generate PDF for sharing without printing
  Future<File?> generatePDFForSharing({
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
  }) async {
    try {
      // Ensure billDocumentConfig is loaded before generating PDF
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        return null;
      }

      final displayConfig = billDocumentConfig.displayConfiguration?.options;
      _debugPrintTemplateSettings(displayConfig);

      // Create a PDF document
      final pdf = pw.Document();

      // Get settings from the loaded display configuration
      final updatedSettings = displayConfig;

      // Access Payment Gateways Provider for QR code link
      final paymentGatewaysProvider =
          Provider.of<PaymentGatewaysProvider>(context, listen: false);
      final manualPaymentGateway = paymentGatewaysProvider.paymentGateways
          .firstWhere((gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY",
              orElse: () => PaymentGateway(
                    id: 0,
                    name: "",
                    code: "",
                    label: "",
                    link: "",
                    image: "",
                    status: "",
                    isWebActive: 0,
                    isAndroidActive: 0,
                    isIosActive: 0,
                    contactEmail: "",
                    contactPhone: "",
                    createdAt: "",
                    updatedAt: "",
                  ));

      // Determine page format based on paper size
      PdfPageFormat pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;

      // Define styles with adjustments for A5 vs A4 - optimized for space and professional look
      final headerStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 16.0
            : 18.0, // Increased for better hierarchy
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table text
        color: PdfColors.black,
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 5.0 : 7.0, // Reduced further
        color: PdfColors.black,
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table headers
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final summaryStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 8.0
            : 10.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final netTotalStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );

      // Add content to a multi-page PDF with minimal margins and optimized spacing
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(15), // Reduced from 30
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5), // Reduced from 10
            child: pw.Column(
              children: [
                // QR Code (if enabled)
                if (updatedSettings?['showQRCode']?.visible == true &&
                    manualPaymentGateway.link.isNotEmpty)
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: manualPaymentGateway.link,
                      width: selectedPaperSize == 'A5' ? 40 : 50,
                      height: selectedPaperSize == 'A5' ? 40 : 50,
                    ),
                  ),
                pw.SizedBox(height: 5),
                // Thank You Message
                if (updatedSettings?['showThankYouMessage']?.visible == true)
                  pw.Center(
                    child: pw.Text(
                      'Thank you for your purchase!',
                      style: smallStyle,
                    ),
                  ),
                // Customer Care Information
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (customerCareNumber.isNotEmpty)
                        pw.Text(
                          'Customer Care: $customerCareNumber',
                          style: smallStyle,
                        ),
                      if (customerCareEmail.isNotEmpty)
                        pw.Text(
                          'Email: $customerCareEmail',
                          style: smallStyle,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          build: (context) => [
            // Store Name Header
            if (updatedSettings?['showStoreName']?.visible == true)
              pw.Center(
                child: pw.Text(
                  (updatedSettings?['showStoreName']?.value as String?) ??
                      'Store Name',
                  style: headerStyle,
                ),
              ),
            // Description
            if (updatedSettings?['showDescription']?.visible == true)
              pw.Center(
                child: pw.Text(
                  (updatedSettings?['showDescription']?.value as String?) ??
                      'Description',
                  style: subheaderStyle,
                ),
              ),
            // Store Address
            if (updatedSettings?['showStoreAddress']?.visible == true)
              pw.Center(
                child: pw.Text(
                  (updatedSettings?['showStoreAddress']?.value as String?) ??
                      'Store Address',
                  style: bodyStyle,
                ),
              ),
            // FSSAI Info
            if (updatedSettings?['showFssaiInfo']?.visible == true)
              pw.Center(
                child: pw.Text(
                  (updatedSettings?['showFssaiInfo']?.value as String?) ??
                      'FSSAI Info',
                  style: bodyStyle,
                ),
              ),
            // Tel
            if (updatedSettings?['showTel']?.visible == true)
              pw.Center(
                child: pw.Text(
                  'Tel: ${(updatedSettings?['showTel']?.value as String?) ?? 'Tel Number'}',
                  style: bodyStyle,
                ),
              ),
            // Email
            if (updatedSettings?['showEmail']?.visible == true)
              pw.Center(
                child: pw.Text(
                  'Email: ${(updatedSettings?['showEmail']?.value as String?) ?? 'Email Address'}',
                  style: bodyStyle,
                ),
              ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.black),
            // Invoice Title
            if (updatedSettings?['showInvoiceTitle']?.visible == true)
              pw.Center(
                child: pw.Text(
                  (updatedSettings?['showInvoiceTitle']?.value as String?) ??
                      'INVOICE',
                  style: subheaderStyle,
                ),
              ),
            // Invoice Number
            if (updatedSettings?['showInvoiceNumber']?.visible == true)
              pw.Center(
                child: pw.Text(
                  'Invoice No: $orderNumber',
                  style: bodyStyle,
                ),
              ),
            // Date Header
            if (updatedSettings?['showDateHeader']?.visible == true)
              _buildDateTimeRowPDF(selectedPaperSize, orderDate),
            // Customer Details
            if (customerName != null ||
                customerPhone != null ||
                customerEmail != null ||
                customerAddress != null)
              _buildCustomerDetailsPDF(
                selectedPaperSize,
                customerName,
                customerPhone,
                customerEmail,
                customerAddress,
                headerStyle,
                bodyStyle,
              ),
            pw.SizedBox(height: 10),
            // Items Table
            _buildPdfItemsTable(
              tableHeaderStyle,
              bodyStyle,
              updatedSettings,
              cartItems,
              isFromLocalStorage,
              billDocumentConfig,
            ),
            pw.SizedBox(height: 10),
            // Cart Total Row
            _buildCartTotalRow(selectedPaperSize, cartItems, isFromLocalStorage, summaryStyle),
            // Summary Section
            _buildPdfSummary(
              summaryStyle,
              netTotalStyle,
              updatedSettings,
              formattedTotal,
              savedTotal,
              discountAmount,
              cartItems.length,
              billDocumentConfig,
            ),
            // Amount in Words
            if (updatedSettings?['showAmountInWords']?.visible == true)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Text(
                  'Amount in words: ${AmountHelper().convertNumberToWords(double.tryParse(formattedTotal) ?? 0.0)}',
                  style: bodyStyle,
                ),
              ),
            // Items Count
            if (updatedSettings?['showItemsCount']?.visible == true)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Text(
                  'Total Items: ${cartItems.length}',
                  style: bodyStyle,
                ),
              ),
            // Terms & Conditions
            if (updatedSettings?['showTermsConditions']?.visible == true &&
                _hasTermsData(updatedSettings, billDocumentConfig))
              _buildTermsConditionsBoxPDF(
                selectedPaperSize,
                updatedSettings,
                billDocumentConfig,
              ),
            // Order Barcode
            _buildOrderBarcodePDF(selectedPaperSize, orderNumber),
          ],
        ),
      );

      // Save PDF to a more accessible location for sharing in documents/epos folder
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedOrderNumber =
          orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/Invoice_$sanitizedOrderNumber.pdf');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      // Verify file was created successfully
      final fileExists = await file.exists();
      final fileSize = fileExists ? await file.length() : 0;

      debugPrint('PDF generated for sharing: ${file.path}');
      debugPrint(
          'PDF directory type: ${output.path.contains('epos') ? 'Documents/epos' : (output.path.contains('Documents') ? 'Documents' : 'Temp')}');
      debugPrint('PDF file exists: $fileExists');
      debugPrint('PDF file size: $fileSize bytes');

      if (!fileExists || fileSize == 0) {
        debugPrint('ERROR: PDF file was not created properly');
        return null;
      }

      return file;
    } catch (e) {
      debugPrint("Error generating PDF for sharing: ${e.toString()}");
      return null;
    }
  }
}
