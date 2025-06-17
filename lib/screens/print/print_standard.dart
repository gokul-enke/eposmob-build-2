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

class StandardPrinter {
  final BuildContext context;

  StandardPrinter(this.context);

  Future<void> generateAndPrintPDF({
    required BluetoothPrinter? selectedPrinter,
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
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

      // Define styles with adjustments for A5 vs A4
      final headerStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 16.0 : 18.0,
        fontWeight: pw.FontWeight.bold,
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 12.0 : 14.0,
        fontWeight: pw.FontWeight.bold,
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.0 : 11.0,
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
        fontWeight: pw.FontWeight.bold,
      );

      // Add content to a multi-page PDF so overflow flows to new pages
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(30),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
          build: (pw.Context context) => [
            // Wrap entire content in a Column so it flows
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with store information
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

                      // Store description (subheader from DocumentConfig or value from displayConfig)
                      if (updatedSettings?['showDescription']?.visible == true)
                        pw.Text(
                          updatedSettings?['showDescription']?.value
                                  as String? ??
                              billDocumentConfig.subheader ??
                              'Mini Supermarket',
                          style: pw.TextStyle(
                            fontSize: selectedPaperSize == 'A5' ? 10.0 : 12.0,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),

                      // Store address - Only show if data is available
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

                      // FSSAI info - Only show if data is available
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

                      // Contact information (Tel and Email)
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

                pw.SizedBox(height: 20),

                // Invoice information in a framed box
                if ((updatedSettings?['showInvoiceTitle']?.visible == true) ||
                    (updatedSettings?['showInvoiceNumber']?.visible == true))
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1, color: PdfColors.grey300),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
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
                            if (updatedSettings?['showInvoiceNumber']
                                    ?.visible ==
                                true)
                              // Use numberPrefix from DocumentConfig if available
                              pw.Text(
                                  (billDocumentConfig.numberPrefix != null &&
                                          billDocumentConfig
                                              .numberPrefix!.isNotEmpty)
                                      ? '${billDocumentConfig.numberPrefix}$orderNumber'
                                      : 'No: $orderNumber',
                                  style: subheaderStyle),
                          ],
                        ),
                        if (updatedSettings?['showDateHeader']?.visible ==
                            true) ...[
                          // Assuming showDateHeader controls date in PDF header box
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                  'Date: ${DateHelper.formatISODate(orderDate)}',
                                  style: bodyStyle),
                              pw.Text(
                                  'Time: ${DateHelper.formatISODateToIST(orderDate)}',
                                  style: bodyStyle),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                pw.SizedBox(height: 15),

                // Date and Time Row (above items table)
                _buildDateTimeRowPDF(selectedPaperSize, orderDate),

                pw.SizedBox(height: 15),

                // Items table in a framed box
                if ((updatedSettings?['showSLNumber']?.visible == true) ||
                    (updatedSettings?['showParticulars']?.visible == true) ||
                    (updatedSettings?['showMRP']?.visible == true) ||
                    (updatedSettings?['showQty']?.visible == true) ||
                    (updatedSettings?['showRate']?.visible == true) ||
                    (updatedSettings?['showTotal']?.visible == true))
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1, color: PdfColors.grey300),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ITEM DETAILS', style: subheaderStyle),
                        pw.SizedBox(height: 10),
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

                pw.SizedBox(height: 15),

                // Summary in a framed box
                if ((updatedSettings?['showItemsCount']?.visible == true) ||
                    (updatedSettings?['showMRPTotal']?.visible == true) ||
                    (updatedSettings?['showSaved']?.visible == true) ||
                    (updatedSettings?['showDiscount']?.visible == true) ||
                    (updatedSettings?['showNetAmount']?.visible == true))
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1, color: PdfColors.grey300),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ORDER SUMMARY', style: subheaderStyle),
                        pw.SizedBox(height: 10),
                        _buildPdfSummary(
                            bodyStyle,
                            updatedSettings,
                            formattedTotal,
                            savedTotal,
                            cartItems.length,
                            billDocumentConfig),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 10),

                // Amount in words
                if (updatedSettings?['showAmountInWords']?.visible == true)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 10),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey300),
                        bottom: pw.BorderSide(color: PdfColors.grey300),
                      ),
                    ),
                    child: pw.Text(
                      'Amount in words: ${AmountHelper().convertNumberToWords(double.parse(formattedTotal))} Only.',
                      style: pw.TextStyle(
                        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),

                pw.SizedBox(height: 10),

                // Footer section
                pw.Column(
                  children: [
                    // Thank You message
                    if (updatedSettings?['showThankYouMessage']?.visible ==
                        true)
                      pw.Center(
                        child: pw.Text(
                          updatedSettings?['showThankYouMessage']?.value
                                  as String? ??
                              'Thank You... Visit Again',
                          style: subheaderStyle,
                        ),
                      ),

                    pw.SizedBox(height: 10),

                    // QR Code for payment - Only show if enabled in settings
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
                              width: selectedPaperSize == 'A5' ? 100 : 120,
                              height: selectedPaperSize == 'A5' ? 100 : 120,
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              updatedSettings?['showQRCode']?.value
                                      as String? ??
                                  'Scan to Pay',
                              style: pw.TextStyle(
                                fontSize:
                                    selectedPaperSize == 'A5' ? 9.0 : 11.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),
                    ],

                    // Order ID Barcode (just before Terms & Conditions)
                    _buildOrderBarcodePDF(selectedPaperSize, orderNumber),

                    // Terms & Conditions - Only show if enabled and data is available
                    if (updatedSettings?['showTermsConditions']?.visible ==
                        true) ...[
                      // Get terms from displayConfig value first, then fallback to billDocumentConfig
                      if (_hasTermsData(
                          updatedSettings, billDocumentConfig)) ...[
                        _buildTermsConditionsBoxPDF(selectedPaperSize,
                            updatedSettings, billDocumentConfig),
                        pw.SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Save PDF to a temporary file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Receipt-$orderNumber.pdf');
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
        await Share.shareFiles(
          [file.path],
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
      final slLabel = (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true 
          ? displayConfig!['showSLNumber']!.value as String
          : 'SL#';
      tableHeaders.add(slLabel);
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(1); // Smaller width for serial number
    }
    if (displayConfig?['showParticulars']?.visible == true) {
      final label = (displayConfig?['showParticulars']?.value as String?)?.isNotEmpty == true 
          ? displayConfig!['showParticulars']!.value as String
          : 'PARTICULARS';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(
          5); // Much larger width for product names to accommodate long names
    }
    if (displayConfig?['showMRP']?.visible == true) {
      final mrpLabel = (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true 
          ? displayConfig!['showMRP']!.value as String
          : 'MRP';
      tableHeaders.add(mrpLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showQty']?.visible == true) {
      final label = (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true 
          ? displayConfig!['showQty']!.value as String
          : 'QTY';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Compact for quantity
    }
    if (displayConfig?['showRate']?.visible == true) {
      final label = (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true 
          ? displayConfig!['showRate']!.value as String
          : 'RATE';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showTotal']?.visible == true) {
      final label = (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true 
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
        productName = item.productName ?? '';
        mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        totalPrice =
            (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
      }

      // Use full product name without truncation for PDF
      String displayProductName = productName;

      List<String> rowData = [];
      if (displayConfig?['showSLNumber']?.visible == true)
        rowData.add((i + 1).toString());
      if (displayConfig?['showParticulars']?.visible == true)
        rowData.add(displayProductName);
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
      headerHeight: 25,
      cellStyle: contentStyle,
      cellHeight: 25,
      cellAlignments: cellAlignmentsMap,
      cellPadding: const pw.EdgeInsets.all(5),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      columnWidths: Map.fromIterable(columnWidths.asMap().keys,
          key: (i) => i, value: (i) => pw.FlexColumnWidth(columnWidths[i])),
    );
  }

  pw.Widget _buildPdfSummary(
      pw.TextStyle style,
      Map<String, DisplayOption>? displayConfig,
      String formattedTotal,
      String? savedTotal,
      int itemCount,
      DocumentConfig? billDocumentConfig) {
    double savedTotalValue = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double formattedTotalValue = double.tryParse(formattedTotal) ?? 0.0;
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
      summaryWidgets.add(pw.SizedBox(height: 5));
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
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    // Display You Saved / Discount
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
      summaryWidgets.add(pw.SizedBox(height: 5));
    } else if (displayConfig?['showDiscount']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Discount:', style: style),
            pw.Text(savedTotalValue.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    // Display Net Total (Amount)
    if (displayConfig?['showNetAmount']?.visible == true) {
      const label = 'Net Total';
      summaryWidgets.add(pw.Divider(color: PdfColors.grey300));
      summaryWidgets.add(pw.SizedBox(height: 5));
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$label:',
                style: pw.TextStyle(
                  fontSize: 12.0,
                  fontWeight: pw.FontWeight.bold,
                )),
            pw.Text(formattedTotalValue.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 12.0,
                  fontWeight: pw.FontWeight.bold,
                )),
          ],
        ),
      );
    }

    return pw.Column(children: summaryWidgets);
  }

  List<pw.Widget> _buildTermsConditionsList(
      String termsText, pw.TextStyle style) {
    List<String> terms = termsText.split('\n');
    List<pw.Widget> termWidgets = [];

    for (int i = 0; i < terms.length; i++) {
      termWidgets.add(
        pw.Text(
          terms[i],
          style: style,
        ),
      );

      if (i < terms.length - 1) {
        termWidgets.add(pw.SizedBox(height: 2));
      }
    }

    return termWidgets;
  }

  // Date and Time Row for PDF
  pw.Widget _buildDateTimeRowPDF(String selectedPaperSize, String orderDate) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.symmetric(
          horizontal: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Date: ${DateHelper.formatISODate(orderDate)}',
            style: pw.TextStyle(
              fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Time: ${DateHelper.formatISODateToIST(orderDate)}',
            style: pw.TextStyle(
              fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Order ID Barcode for PDF
  pw.Widget _buildOrderBarcodePDF(
      String selectedPaperSize, String orderNumber) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'Order ID:',
            style: pw.TextStyle(
              fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: orderNumber,
            width: selectedPaperSize == 'A5' ? 120 : 150, // Smaller size
            height: selectedPaperSize == 'A5' ? 30 : 40, // Smaller height
          ),
          pw.SizedBox(height: 10),
        ],
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

  // Terms & Conditions in a Box for PDF
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
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              'Terms & Conditions',
              style: pw.TextStyle(
                fontSize: selectedPaperSize == 'A5' ? 9.0 : 12.0,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 5),
          ...terms!.split('\n').map((term) {
            if (term.trim().isEmpty) return pw.SizedBox(height: 2);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                '• $term',
                style: pw.TextStyle(
                  fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
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

    debugPrint("Current display settings (from Bill config):");
    displayConfig.forEach((key, value) {
      debugPrint("- $key: visible=${value.visible}, value=${value.value}");
    });
  }
}
