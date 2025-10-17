import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
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
import 'package:pos_machine/models/order_details.dart';

class StandardPrinter {
  final BuildContext context;

  StandardPrinter(this.context);

  // Removed _maskPhone - now using StringHelper.maskStringShowLast4

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
    OrderReturns? orderReturns, // Add this parameter
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
      debugPrint(
          "billDocumentConfig Updated At: ${billDocumentConfig.updatedAt}");
      debugPrint(
          "billDocumentConfig Has Display Config: ${billDocumentConfig.displayConfiguration != null}");
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

//display returns
      debugPrint(
          "showReturnSLNumber: ${updatedSettings?['showReturnSLNumber']?.visible}");
      debugPrint(
          "showReturnParticulars: ${updatedSettings?['showReturnParticulars']?.visible}");
      debugPrint(
          "showReturnQty: ${updatedSettings?['showReturnQty']?.visible}");
      debugPrint(
          "showReturnRate: ${updatedSettings?['showReturnRate']?.visible}");
      debugPrint(
          "showReturnTotal: ${updatedSettings?['showReturnTotal']?.visible}");
      debugPrint(
          "showReturnNetAmount: ${updatedSettings?['showReturnNetAmount']?.visible}");
      debugPrint(
          "showReturnTotalAmount: ${updatedSettings?['showReturnTotalAmount']?.visible}");
      debugPrint(
          "showReturnItemsCount: ${updatedSettings?['showReturnItemsCount']?.visible}");
      debugPrint(
          "showFinalNetAmount: ${updatedSettings?['showFinalNetAmount']?.visible}");
      debugPrint(
          "showFinalPurchase: ${updatedSettings?['showFinalPurchase']?.visible}");
      debugPrint(
          "showFinalReturn: ${updatedSettings?['showFinalReturn']?.visible}");
      debugPrint(
          "showFinalAmountInWords: ${updatedSettings?['showFinalAmountInWords']?.visible}");

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
                      updatedSettings?['showDescription']?.value as String? ??
                          billDocumentConfig.subheader ??
                          '',
                      style: pw.TextStyle(
                        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                      ),
                    ),

                  // Store address - compact display
                  if (updatedSettings?['showStoreAddress']?.visible ==
                      true) ...[
                    if ((updatedSettings?['showStoreAddress']?.value as String?)
                            ?.isNotEmpty ==
                        true)
                      pw.Text(
                        updatedSettings!['showStoreAddress']!.value as String,
                        style: bodyStyle,
                      ),
                  ],

                  // FSSAI info - compact display
                  if (updatedSettings?['showFssaiInfo']?.visible == true) ...[
                    if ((updatedSettings?['showFssaiInfo']?.value as String?)
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
                    if (updatedSettings?['showInvoiceTitle']?.visible == true)
                      pw.Text(
                          updatedSettings?['showInvoiceTitle']?.value
                                  as String? ??
                              billDocumentConfig.header ??
                              'INVOICE',
                          style: subheaderStyle),
                    if (updatedSettings?['showInvoiceNumber']?.visible == true)
                      pw.Text(
                          (billDocumentConfig.numberPrefix != null &&
                                  billDocumentConfig.numberPrefix!.isNotEmpty)
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
                child: _buildPdfItemsTable(
                  tableHeaderStyle,
                  bodyStyle,
                  updatedSettings,
                  cartItems,
                  isFromLocalStorage,
                  billDocumentConfig,
                ),
              ),

            // Cart Total Row - added after items table
            _buildCartTotalRow(
                selectedPaperSize, cartItems, isFromLocalStorage, summaryStyle),

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

                    // Add Amount in words under order summary when there are no returns
                    if (updatedSettings?['showAmountInWords']?.visible ==
                            true &&
                        (orderReturns == null ||
                            orderReturns.returnItems?.isEmpty == true))
                      pw.Column(
                        children: [
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Amount in words:', style: summaryStyle),
                              pw.Expanded(
                                child: pw.Text(
                                  '${AmountHelper().convertNumberToWords(double.parse(formattedTotal))} Only.',
                                  style: summaryStyle,
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // Add Order Returns section if orderReturns is not null and has items
            if (orderReturns != null &&
                (orderReturns.returnItems?.isNotEmpty ?? false)) ...[
              pw.SizedBox(height: 5), // Add spacing before return section
              _buildOrderReturnsSection(
                selectedPaperSize,
                orderReturns,
                subheaderStyle,
                bodyStyle,
                tableHeaderStyle,
                summaryStyle,
                netTotalStyle,
                cartItems, // Pass cartItems to match return items with original prices
                isFromLocalStorage,
                updatedSettings, // Pass displayConfig
                billDocumentConfig, // Pass billDocumentConfig for resolved_labels
              ),
            ],

            // Add Total Summary section ONLY when there are returns
            if (orderReturns != null &&
                orderReturns.returnItems != null &&
                orderReturns.returnItems!.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              _buildTotalSummarySection(
                selectedPaperSize,
                formattedTotal,
                orderReturns,
                cartItems,
                isFromLocalStorage,
                subheaderStyle,
                summaryStyle,
                netTotalStyle,
                updatedSettings,
              ),
              pw.SizedBox(height: 10),
            ],

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
                              .replaceAll('{formattedTotal}', formattedTotal)
                              .replaceAll('{orderNumber}', orderNumber),
                          width: selectedPaperSize == 'A5' ? 80 : 100,
                          height: selectedPaperSize == 'A5' ? 80 : 100,
                        ),
                        pw.SizedBox(height: 3), // Reduced from 5
                        pw.Text(
                          updatedSettings?['showQRCode']?.value as String? ??
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
                if (updatedSettings?['showThankYouMessage']?.visible == true)
                  pw.Center(
                    child: pw.Text(
                      updatedSettings?['showThankYouMessage']?.value
                              as String? ??
                          'Thank You... Visit Again',
                      style: pw.TextStyle(
                        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),

                // Terms & Conditions - compact design
                if (updatedSettings?['showTermsConditions']?.visible ==
                    true) ...[
                  if (_hasTermsData(updatedSettings, billDocumentConfig)) ...[
                    _buildTermsConditionsBoxPDF(
                        selectedPaperSize, updatedSettings, billDocumentConfig),
                  ],
                ],
              ],
            ),
          ],
        ),
      );

      // Save PDF to documents/epos folder for better organization
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedOrderNumber =
          orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
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
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final slLabel =
          (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSLNumber']!.value as String
              : (billDocumentConfig?.resolvedLabels?.slNumber?.isNotEmpty ==
                      true
                  ? billDocumentConfig!.resolvedLabels!.slNumber!
                  : 'SL#');
      tableHeaders.add(slLabel);
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(1); // Smaller width for serial number
    }
    if (displayConfig?['showParticulars']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label = (displayConfig?['showParticulars']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showParticulars']!.value as String
          : (billDocumentConfig?.resolvedLabels?.particulars?.isNotEmpty == true
              ? billDocumentConfig!.resolvedLabels!.particulars!
              : 'PARTICULARS');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(
          5); // Much larger width for product names to accommodate long names
    }
    if (displayConfig?['showMRP']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : (billDocumentConfig?.resolvedLabels?.mrp?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.mrp!
                  : 'MRP');
      tableHeaders.add(mrpLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showQty']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : (billDocumentConfig?.resolvedLabels?.qty?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.qty!
                  : 'QTY');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Compact for quantity
    }
    if (displayConfig?['showRate']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : (billDocumentConfig?.resolvedLabels?.rate?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.rate!
                  : 'RATE');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showTotal']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : (billDocumentConfig?.resolvedLabels?.total?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.total!
                  : 'TOTAL');
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
      if (displayConfig?['showMRP']?.visible == true) {
        rowData.add(mrp);
      }
      if (displayConfig?['showQty']?.visible == true) {
        rowData.add(quantity);
      }
      if (displayConfig?['showRate']?.visible == true) {
        rowData.add(unitPrice);
      }
      if (displayConfig?['showTotal']?.visible == true) {
        rowData.add(totalPrice);
      }

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
    double discountAmountValue =
        double.tryParse(discountAmount ?? '0.0') ?? 0.0;
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

    // Display You Saved - only show if value is greater than 0
    if (displayConfig?['showSaved']?.visible == true && savedTotalValue > 0) {
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
      debugPrint(
          "  * visible: ${value.visible} (${value.visible.runtimeType})");
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
      fontSize:
          selectedPaperSize == 'A5' ? 8.0 : 10.0, // Increased from bodyStyle
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          vertical: 8, horizontal: 8), // Increased vertical padding
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
            pw.Text(
                '$customerName - ${StringHelper.maskStringShowLast4(customerPhone)}',
                style: customerDetailStyle)
          else ...[
            if (customerName != null && customerName.isNotEmpty)
              pw.Text(customerName, style: customerDetailStyle),
            if (customerPhone != null && customerPhone.isNotEmpty)
              pw.Text(StringHelper.maskStringShowLast4(customerPhone),
                  style: customerDetailStyle),
          ],
          // if (customerEmail != null && customerEmail.isNotEmpty)
          //   pw.Text('Email: $customerEmail', style: customerDetailStyle),
          if (customerAddress != null && customerAddress.isNotEmpty)
            pw.Text(customerAddress, style: customerDetailStyle),
        ],
      ),
    );
  }

  // Add this new method to build the order returns section
  pw.Widget _buildOrderReturnsSection(
    String selectedPaperSize,
    OrderReturns orderReturns,
    pw.TextStyle subheaderStyle,
    pw.TextStyle bodyStyle,
    pw.TextStyle tableHeaderStyle,
    pw.TextStyle summaryStyle,
    pw.TextStyle netTotalStyle,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    Map<String, DisplayOption>? displayConfig,
    DocumentConfig? billDocumentConfig, // Add this parameter
  ) {
    // Create headers for the return table using configuration
    final List<String> tableHeaders = [];
    final Map<int, pw.Alignment> cellAlignmentsMap = {};
    final List<double> columnWidths = [];
    int visibleColIndex = 0;

    // Use configured labels with fallback: displayConfig > resolved_labels > default
    final slLabel =
        (displayConfig?['showReturnSLNumber']?.value as String?)?.isNotEmpty ==
                true
            ? displayConfig!['showReturnSLNumber']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnSlNumber?.isNotEmpty ==
                    true
                ? billDocumentConfig!.resolvedLabels!.returnSlNumber!
                : 'Sl#');

    final particularsLabel = (displayConfig?['showReturnParticulars']?.value
                    as String?)
                ?.isNotEmpty ==
            true
        ? displayConfig!['showReturnParticulars']!.value as String
        : (billDocumentConfig?.resolvedLabels?.returnParticulars?.isNotEmpty ==
                true
            ? billDocumentConfig!.resolvedLabels!.returnParticulars!
            : 'DESCRIPTION');

    final qtyLabel =
        (displayConfig?['showReturnQty']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showReturnQty']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnQty?.isNotEmpty == true
                ? billDocumentConfig!.resolvedLabels!.returnQty!
                : 'QTY');

    final rateLabel =
        (displayConfig?['showReturnRate']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showReturnRate']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnRate?.isNotEmpty ==
                    true
                ? billDocumentConfig!.resolvedLabels!.returnRate!
                : 'RATE');

    final totalLabel = (displayConfig?['showReturnTotal']?.value as String?)
                ?.isNotEmpty ==
            true
        ? displayConfig!['showReturnTotal']!.value as String
        : (billDocumentConfig?.resolvedLabels?.returnTotal?.isNotEmpty == true
            ? billDocumentConfig!.resolvedLabels!.returnTotal!
            : 'AMOUNT');

    final mrpLabel =
        (displayConfig?['showReturnMRP']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showReturnMRP']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnMrp?.isNotEmpty == true
                ? billDocumentConfig!.resolvedLabels!.returnMrp!
                : 'MRP');

    if (displayConfig?['showReturnSLNumber']?.visible == true) {
      tableHeaders.add(slLabel);
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(1);
    }
    if (displayConfig?['showReturnParticulars']?.visible == true) {
      tableHeaders.add(particularsLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(5);
    }
    if (displayConfig?['showReturnMRP']?.visible == true) {
      tableHeaders.add(mrpLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }
    if (displayConfig?['showReturnQty']?.visible == true) {
      tableHeaders.add(qtyLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }
    if (displayConfig?['showReturnRate']?.visible == true) {
      tableHeaders.add(rateLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }
    if (displayConfig?['showReturnTotal']?.visible == true) {
      tableHeaders.add(totalLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }

    // Create table data for return items
    List<List<String>> tableData = [];
    double calculatedReturnTotal = 0.0;

    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final itemQuantity = returnItem.quantity ?? 0;

      String itemMrp = '0.00';
      String itemRate = '0.00';
      String itemAmount = '0.00';

      // Look for matching item in cartItems
      for (var cartItem in cartItems) {
        String cartItemProductName = '';
        String cartItemUnitPrice = '0.00';

        if (isFromLocalStorage) {
          cartItemProductName = cartItem['productName'] ?? '';
          cartItemUnitPrice =
              (double.tryParse(cartItem['unitPrice']?.toString() ?? '0') ?? 0.0)
                  .toStringAsFixed(2);
        } else {
          if (cartItem is Map<String, dynamic>) {
            cartItemProductName = cartItem['product_name']?.toString() ??
                cartItem['productName']?.toString() ??
                '';
            cartItemUnitPrice = (double.tryParse(
                        cartItem['unit_price']?.toString() ??
                            cartItem['unitPrice']?.toString() ??
                            '0') ??
                    0.0)
                .toStringAsFixed(2);
          } else {
            try {
              cartItemProductName = cartItem.productName?.toString() ?? '';
              cartItemUnitPrice =
                  (double.tryParse(cartItem.unitPrice?.toString() ?? '0') ??
                          0.0)
                      .toStringAsFixed(2);
            } catch (e) {
              cartItemProductName = '';
              cartItemUnitPrice = '0.00';
            }
          }
        }

        if (cartItemProductName == returnItem.productName) {
          itemRate = cartItemUnitPrice;
          
          // Fetch MRP from cartItem
          if (isFromLocalStorage) {
            itemMrp = (double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
          } else {
            if (cartItem is Map<String, dynamic>) {
              itemMrp = (double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0)
                  .toStringAsFixed(2);
            } else {
              try {
                itemMrp = (double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0)
                    .toStringAsFixed(2);
              } catch (e) {
                itemMrp = '0.00';
              }
            }
          }
          
          final amount = itemQuantity * (double.tryParse(itemRate) ?? 0.0);
          itemAmount = amount.toStringAsFixed(2);
          calculatedReturnTotal += amount;
          break;
        }
      }

      // If no match found, fall back to average rate calculation
      if (itemRate == '0.00' && itemAmount == '0.00') {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;
        int totalQuantity = 0;
        for (var item in orderReturns.returnItems!) {
          totalQuantity += item.quantity ?? 0;
        }
        final averageRate =
            totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
        final amount = itemQuantity * averageRate;
        itemRate = averageRate.toStringAsFixed(2);
        itemAmount = amount.toStringAsFixed(2);
        calculatedReturnTotal += amount;
      }

      List<String> rowData = [];
      if (displayConfig?['showReturnSLNumber']?.visible == true) {
        rowData.add((i + 1).toString());
      }
      if (displayConfig?['showReturnParticulars']?.visible == true) {
        rowData.add(returnItem.productName ?? '');
      }
      if (displayConfig?['showReturnMRP']?.visible == true) {
        rowData.add(itemMrp);
      }
      if (displayConfig?['showReturnQty']?.visible == true) {
        rowData.add(returnItem.quantity?.toString() ?? '');
      }
      if (displayConfig?['showReturnRate']?.visible == true) {
        rowData.add(itemRate);
      }
      if (displayConfig?['showReturnTotal']?.visible == true) {
        rowData.add(itemAmount);
      }

      tableData.add(rowData);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 20),
          pw.Text('RETURNS', style: subheaderStyle),
          pw.SizedBox(height: 10),
          // Return Items Table
          if (tableHeaders.isNotEmpty && tableData.isNotEmpty)
            pw.Table.fromTextArray(
              headers: tableHeaders,
              data: tableData,
              headerStyle: tableHeaderStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headerHeight: 20,
              cellStyle: bodyStyle,
              cellHeight: 18,
              cellAlignments: cellAlignmentsMap,
              cellPadding: const pw.EdgeInsets.all(3),
              border: const pw.TableBorder(
                top: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                left: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                right: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                horizontalInside:
                    pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                verticalInside:
                    pw.BorderSide(color: PdfColors.grey700, width: 0.5),
              ),
              columnWidths: {
                for (var i in columnWidths.asMap().keys)
                  i: pw.FlexColumnWidth(columnWidths[i])
              },
            )
          else
            pw.Text('No return items to display', style: bodyStyle),
          pw.SizedBox(height: 15),
          // Return Summary
          if (displayConfig?['showReturnNetAmount']?.visible == true ||
              displayConfig?['showReturnTotalAmount']?.visible == true ||
              displayConfig?['showReturnItemsCount']?.visible == true)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RETURN SUMMARY', style: subheaderStyle),
                pw.SizedBox(height: 3),
                // Display Item Count
                if (displayConfig?['showReturnItemsCount']?.visible == true)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Items:', style: summaryStyle),
                      pw.Text(orderReturns.returnItems!.length.toString(),
                          style: summaryStyle),
                    ],
                  ),
                if (displayConfig?['showReturnItemsCount']?.visible == true)
                  pw.SizedBox(height: 2),
                // Display Total MRP
                if (displayConfig?['showReturnTotalAmount']?.visible == true)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total MRP:', style: summaryStyle),
                      pw.Text(calculatedReturnTotal.toStringAsFixed(2),
                          style: summaryStyle),
                    ],
                  ),
                if (displayConfig?['showReturnTotalAmount']?.visible == true)
                  pw.SizedBox(height: 2),
                // Display Net Total
                if (displayConfig?['showReturnNetAmount']?.visible == true) ...[
                  pw.Divider(color: PdfColors.black),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Total:', style: netTotalStyle),
                      pw.Text(calculatedReturnTotal.toStringAsFixed(2),
                          style: netTotalStyle),
                    ],
                  ),
                ],
              ],
            ),
          pw.SizedBox(height: 15),
        ],
      ),
    );
  }

  // Add this new method to build the total summary section
  pw.Widget _buildTotalSummarySection(
    String selectedPaperSize,
    String formattedTotal,
    OrderReturns? orderReturns,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    pw.TextStyle subheaderStyle,
    pw.TextStyle summaryStyle,
    pw.TextStyle netTotalStyle,
    Map<String, DisplayOption>? displayConfig, // Add this parameter
  ) {
    double orderTotal = double.tryParse(formattedTotal) ?? 0.0;
    double returnTotal = 0.0;

    // Calculate return total (same logic as before)
    if (orderReturns != null &&
        orderReturns.returnItems != null &&
        orderReturns.returnItems!.isNotEmpty) {
      for (var i = 0; i < orderReturns.returnItems!.length; i++) {
        final returnItem = orderReturns.returnItems![i];
        final itemQuantity = returnItem.quantity ?? 0;
        String itemRate = '0.00';

        for (var cartItem in cartItems) {
          String cartItemProductName = '';
          String cartItemUnitPrice = '0.00';

          if (isFromLocalStorage) {
            cartItemProductName = cartItem['productName'] ?? '';
            cartItemUnitPrice =
                (double.tryParse(cartItem['unitPrice']?.toString() ?? '0') ??
                        0.0)
                    .toStringAsFixed(2);
          } else {
            if (cartItem is Map<String, dynamic>) {
              cartItemProductName = cartItem['product_name']?.toString() ??
                  cartItem['productName']?.toString() ??
                  '';
              cartItemUnitPrice = (double.tryParse(
                          cartItem['unit_price']?.toString() ??
                              cartItem['unitPrice']?.toString() ??
                              '0') ??
                      0.0)
                  .toStringAsFixed(2);
            } else {
              try {
                cartItemProductName = cartItem.productName?.toString() ?? '';
                cartItemUnitPrice =
                    (double.tryParse(cartItem.unitPrice?.toString() ?? '0') ??
                            0.0)
                        .toStringAsFixed(2);
              } catch (e) {
                cartItemProductName = '';
                cartItemUnitPrice = '0.00';
              }
            }
          }

          if (cartItemProductName == returnItem.productName) {
            itemRate = cartItemUnitPrice;
            final amount = itemQuantity * (double.tryParse(itemRate) ?? 0.0);
            returnTotal += amount;
            break;
          }
        }

        if (itemRate == '0.00' && orderReturns.returnTotalAmount != null) {
          final totalReturnAmount =
              double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;
          int totalQuantity = 0;
          for (var item in orderReturns.returnItems!) {
            totalQuantity += item.quantity ?? 0;
          }
          final averageRate =
              totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
          final amount = itemQuantity * averageRate;
          returnTotal += amount;
        }
      }
    }

    double finalTotal = orderTotal - returnTotal;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('FINAL SUMMARY', style: subheaderStyle),
          pw.SizedBox(height: 5),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Display Order Total
              if (displayConfig?['showFinalPurchase']?.visible == true)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Purchase:', style: summaryStyle),
                    pw.Text(orderTotal.toStringAsFixed(2), style: summaryStyle),
                  ],
                ),
              if (displayConfig?['showFinalPurchase']?.visible == true)
                pw.SizedBox(height: 2),
              // Display Return Total
              if (displayConfig?['showFinalReturn']?.visible == true &&
                  orderReturns != null &&
                  orderReturns.returnItems != null &&
                  orderReturns.returnItems!.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Return:', style: summaryStyle),
                    pw.Text(returnTotal.toStringAsFixed(2),
                        style: summaryStyle),
                  ],
                ),
              if (displayConfig?['showFinalReturn']?.visible == true &&
                  orderReturns != null &&
                  orderReturns.returnItems != null &&
                  orderReturns.returnItems!.isNotEmpty)
                pw.SizedBox(height: 2),
              // Display Final Total
              if (displayConfig?['showFinalNetAmount']?.visible == true) ...[
                pw.Divider(color: PdfColors.black),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Net Total:', style: netTotalStyle),
                    pw.Text(finalTotal.toStringAsFixed(2),
                        style: netTotalStyle),
                  ],
                ),
              ],
              // Amount in words
              if (displayConfig?['showFinalAmountInWords']?.visible ==
                  true) ...[
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount in words:', style: summaryStyle),
                    pw.Text(
                      '${AmountHelper().convertNumberToWords(finalTotal)} Only.',
                      style: summaryStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ],
            ],
          ),
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
        itemTotal =
            double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0;
      } else {
        if (item is Map<String, dynamic>) {
          itemTotal = double.tryParse(item['total_price']?.toString() ??
                  item['totalPrice']?.toString() ??
                  '0') ??
              0.0;
        } else {
          try {
            itemTotal =
                double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0;
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
    OrderReturns? orderReturns,
  }) async {
    try {
      // Ensure billDocumentConfig is loaded before generating PDF
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        return null;
      }

      final displayConfig = billDocumentConfig.displayConfiguration?.options;

      // Debug the document configuration being used
      debugPrint("===== DOCUMENT CONFIG BEING USED FOR SHARING =====");
      debugPrint("billDocumentConfig ID: ${billDocumentConfig.id}");
      debugPrint("billDocumentConfig Type: ${billDocumentConfig.type}");
      debugPrint(
          "billDocumentConfig Updated At: ${billDocumentConfig.updatedAt}");
      debugPrint(
          "billDocumentConfig Has Display Config: ${billDocumentConfig.displayConfiguration != null}");
      debugPrint("Display Config Options Count: ${displayConfig?.length ?? 0}");
      if (displayConfig != null) {
        debugPrint("Display Config Keys: ${displayConfig.keys.toList()}");
      }
      debugPrint("===== END DOCUMENT CONFIG INFO =====");

      _debugPrintTemplateSettings(displayConfig);

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
                _buildCartTotalRow(selectedPaperSize, cartItems,
                    isFromLocalStorage, summaryStyle),

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

                // Order Returns section - added when returns exist
                if (orderReturns != null &&
                    (orderReturns.returnItems?.isNotEmpty ?? false)) ...[
                  pw.SizedBox(height: 5), // Add spacing before return section
                  _buildOrderReturnsSection(
                    selectedPaperSize,
                    orderReturns,
                    subheaderStyle,
                    bodyStyle,
                    tableHeaderStyle,
                    summaryStyle,
                    netTotalStyle,
                    cartItems,
                    isFromLocalStorage,
                    updatedSettings,
                    billDocumentConfig, // Pass billDocumentConfig for resolved_labels
                  ),
                ],

                // Total Summary section - ONLY when there are returns
                if (orderReturns != null &&
                    (orderReturns.returnItems?.isNotEmpty ?? false)) ...[
                  pw.SizedBox(height: 5),
                  _buildTotalSummarySection(
                    selectedPaperSize,
                    formattedTotal,
                    orderReturns,
                    cartItems,
                    isFromLocalStorage,
                    subheaderStyle,
                    summaryStyle,
                    netTotalStyle,
                    updatedSettings,
                  ),
                ],

                // Amount in words - consistent with summary layout
                // Only show when there are NO returns (when returns exist, it's shown in Total Summary)
                if (updatedSettings?['showAmountInWords']?.visible == true &&
                    (orderReturns == null ||
                        orderReturns.returnItems == null ||
                        orderReturns.returnItems!.isEmpty))
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
