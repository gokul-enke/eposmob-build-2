import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
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
import 'package:pos_machine/services/standard_pdf_direct_print_service.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:flutter/foundation.dart';

class SupplierTransactionReportStandardPrinter {
  final BuildContext context;

  SupplierTransactionReportStandardPrinter(this.context);

  // Helper method to get label from resolved labels with fallback
  String _getLabel(DocumentConfig? config, String field, String fallback) {
    final resolvedLabels = config?.resolvedLabels;
    if (resolvedLabels == null) return fallback;
    
    switch (field) {
      case 'sl_number':
        return resolvedLabels.slNumber ?? fallback;
      case 'date':
        return resolvedLabels.date ?? fallback;
      case 'item':
        return resolvedLabels.item ?? fallback;
      case 'debit':
        return resolvedLabels.debit ?? fallback;
      case 'credit':
        return resolvedLabels.credit ?? fallback;
      case 'status':
        return resolvedLabels.status ?? fallback;
      default:
        return fallback;
    }
  }

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

  Future<void> generateAndPrintSupplierTransactionReportPDF({
    required BluetoothPrinter? selectedPrinter,
    required List<SupplierTransaction> cartItems,
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
    String? supplierName,
    String? supplierPhone,
    String? supplierEmail,
    String? supplierAddress,
    String? fromDate,
    String? toDate,
  }) async {
    debugPrint("===== SUPPLIER PDF GENERATION DEBUG INFO =====");
    debugPrint("Supplier data received:");
    debugPrint("  Name: $supplierName");
    debugPrint("  Phone: $supplierPhone");
    debugPrint("  Email: $supplierEmail");
    debugPrint("  Address: $supplierAddress");
    debugPrint("===== END SUPPLIER PDF GENERATION DEBUG INFO =====");

    try {
      // Ensure billDocumentConfig is loaded before printing
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'voucher_print.document_config_missing'.tr,
          );
        }
        return;
      }

      final apiDisplayConfig = billDocumentConfig.displayConfiguration?.options;

      // Debug the document configuration being used
      debugPrint("===== DOCUMENT CONFIG BEING USED FOR PRINTING =====");
      debugPrint("billDocumentConfig ID: ${billDocumentConfig.id}");
      debugPrint("billDocumentConfig Type: ${billDocumentConfig.type}");
      debugPrint(
          "billDocumentConfig Updated At: ${billDocumentConfig.updatedAt}");

      debugPrint(
          "billDocumentConfig Has Display Config: ${billDocumentConfig.displayConfiguration != null}");
      
      // Additional debugging for display configuration
      if (billDocumentConfig.displayConfiguration != null) {
        debugPrint("Display Configuration object exists");
        debugPrint("Display Configuration options: ${billDocumentConfig.displayConfiguration!.options}");
        debugPrint("Display Configuration options type: ${billDocumentConfig.displayConfiguration!.options.runtimeType}");
      } else {
        debugPrint("❌ Display Configuration object is NULL");
      }
      
      debugPrint("Display Config Options Count: ${apiDisplayConfig?.length ?? 0}");
      if (apiDisplayConfig != null) {
        debugPrint("Display Config Keys: ${apiDisplayConfig.keys.toList()}");
        // Debug each option
        apiDisplayConfig.forEach((key, value) {
          debugPrint("  $key: visible=${value.visible}, value=${value.value}");
        });
      } else {
        debugPrint("❌ Display Config Options is NULL");
      }
      debugPrint("===== END DOCUMENT CONFIG INFO =====");

      _debugPrintTemplateSettings(apiDisplayConfig);

      // Ensure complete display configuration by merging API config with fallback
      final updatedSettings = _ensureCompleteDisplayConfig(apiDisplayConfig);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'voucher_print.preparing_document'.trParams(
              {'paperSize': selectedPaperSize}),
        );
      }

      // Create a PDF document
      final pdf = pw.Document();

      debugPrint("PDF Generation - Using user settings:");
      debugPrint("showHeader: ${updatedSettings?['showHeader']?.visible}");
      debugPrint(
          "showSubheader: ${updatedSettings?['showSubheader']?.visible}");
      debugPrint("showFooter: ${updatedSettings?['showFooter']?.visible}");
      debugPrint(
          "showSupplierName: ${updatedSettings?['showSupplierName']?.visible}");
      debugPrint(
          "showSupplierEmail: ${updatedSettings?['showSupplierEmail']?.visible}");
      debugPrint(
          "showSupplierPhone: ${updatedSettings?['showSupplierPhone']?.visible}");
      debugPrint(
          "showSupplierAddress: ${updatedSettings?['showSupplierAddress']?.visible}");
      debugPrint(
          "showTotalCredit: ${updatedSettings?['showTotalCredit']?.visible}");
      debugPrint(
          "showTotalDebit: ${updatedSettings?['showTotalDebit']?.visible}");
      debugPrint("showBalance: ${updatedSettings?['showBalance']?.visible}");
      debugPrint("showStatus: ${updatedSettings?['showStatus']?.visible}");

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

      // Define styles to match the screenshot design
      final headerStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 18.0 : 22.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
        height: 2, // Add line height for better spacing between lines
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 14.0 : 16.0,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.grey700,
        height: 2, // Add line height for better spacing between lines
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.5 : 9.0,
        color: PdfColors.black,
        height: 2, // Add line height for better spacing between lines
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
        color: PdfColors.grey600,
        height: 2, // Add line height for better spacing between lines
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 5.0 : 8.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        height: 1.5, // Reduced line height for A5
      );
      final tableDataStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 4.5 : 7.5,
        color: PdfColors.black,
        height: 1.5, // Reduced line height for A5
      );
      final summaryStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 10.0 : 12.0,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.grey700,
        height: 2, // Add line height for better spacing between lines
      );
      final netTotalStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 11.0 : 13.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
        height: 2, // Add line height for better spacing between lines
      );

      // Add content to a multi-page PDF with styling to match PHP template
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(20),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Column(
              children: [
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 5),
                // Show footer if enabled
                if (updatedSettings?['showFooter']?.visible == true)
                  pw.Text(
                    billDocumentConfig?.footer ??
                        'This is a computer-generated document. No signature is required.',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
          ),
          build: (pw.Context context) => [
            // Header with store information - professional design to match PHP template
            pw.Center(
              child: pw.Column(
                children: [
                  // Show header if enabled
                  if (updatedSettings?['showHeader']?.visible == true)
                    pw.Text(
                      billDocumentConfig?.header ?? 'EPosenke',
                      style: pw.TextStyle(
                        fontSize: selectedPaperSize == 'A5' ? 20.0 : 24.0,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  pw.SizedBox(height: 5),
                  // Show subheader if enabled
                  if (updatedSettings?['showSubheader']?.visible == true)
                    pw.Text(
                      billDocumentConfig?.subheader ??
                          'Supplier Transaction Report',
                      style: pw.TextStyle(
                        fontSize: selectedPaperSize == 'A5' ? 14.0 : 18.0,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    height: 2,
                    color: PdfColors.grey800,
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15),

            // Supplier Information Section - if available
            if (supplierName != null ||
                supplierPhone != null ||
                supplierEmail != null ||
                supplierAddress != null)
              _buildSupplierDetailsPDF(
                selectedPaperSize,
                supplierName,
                supplierPhone,
                supplierEmail,
                supplierAddress,
                subheaderStyle,
                bodyStyle,
                fromDate,
                toDate,
                updatedSettings,
              ),

            // Add date range information outside supplier card and align to right
            if ((fromDate != null && fromDate.isNotEmpty) ||
                (toDate != null && toDate.isNotEmpty))
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (updatedSettings?['showDates']?.visible == true) ...[
                        pw.Text(
                          'From: ${fromDate ?? 'N/A'}',
                          style: pw.TextStyle(
                              fontSize:
                                  selectedPaperSize == 'A5' ? 7.5 : 10.0,
                              color: PdfColor.fromHex('#2d3748'),
                              fontWeight: pw.FontWeight.bold,
                              height: 2),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'To: ${toDate ?? 'N/A'}',
                          style: pw.TextStyle(
                              fontSize:
                                  selectedPaperSize == 'A5' ? 7.5 : 10.0,
                              color: PdfColor.fromHex('#2d3748'),
                              fontWeight: pw.FontWeight.bold,
                              height: 2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

            pw.SizedBox(height: 15),

            // Items table - professional design with borders to match PHP template
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  vertical: 15, horizontal: 0),
              child: _buildPdfSupplierTransactionReportItemsTable(
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
              selectedPaperSize,
              cartItems,
              isFromLocalStorage,
              summaryStyle,
              updatedSettings,
            ),

            pw.SizedBox(height: 15),
          ],
        ),
      );

      // Save PDF to documents/epos folder for better organization
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedOrderNumber =
          orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file =
          File('${output.path}/SupplierTransactionReport_$sanitizedOrderNumber.pdf');
      await file.writeAsBytes(await pdf.save());

      if (selectedPrinter != null) {
        final printed = await StandardPdfDirectPrintService.printBytes(
          pdfBytes: await file.readAsBytes(),
          selectedPrinter: selectedPrinter,
          paperSize: selectedPaperSize,
          jobName: 'Supplier Transaction Report $sanitizedOrderNumber',
        );
        if (printed) {
          if (context.mounted) {
            showScaffold(
              context: context,
              message: 'Report sent to ${selectedPrinter.deviceName}',
            );
          }
          return;
        }
      }

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
                    context: context,
                    message: 'voucher_print.pdf_created_successfully'.tr);
                Navigator.pop(context);
              }
            }
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context,
                  message: 'voucher_print.pdf_opened_for_printing'.tr);
              Navigator.pop(context);
            }
          }
        } catch (e) {
          debugPrint("Error opening PDF: ${e.toString()}");
          if (!isWindows) {
            await _sharePdfFallback(file);
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context,
                  message: 'voucher_print.pdf_created_successfully'.tr);
              Navigator.pop(context);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error generating PDF: ${e.toString()}");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'voucher_print.error_generating_pdf'
              .trParams({'error': e.toString()}),
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
        showScaffold(
            context: context,
            message: 'voucher_print.pdf_created_successfully'.tr);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Windows PDF handling error: $e");
      // Still close the page on error
      if (context.mounted) {
        showScaffold(
            context: context,
            message: 'voucher_print.pdf_created_successfully'.tr);
        Navigator.pop(context);
      }
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
              'Supplier Transaction Report #${file.path.split('/').last.replaceAll('.pdf', '').replaceAll('SupplierTransactionReport-', '')}',
          text: 'Your supplier transaction report',
        );

        if (context.mounted) {
          showScaffold(
              context: context,
              message: 'voucher_print.pdf_shared_open_to_print'.tr);
          Navigator.pop(context);
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

  // Show information about file location (for Windows) - Now unused but kept for reference
  void _showFileLocationInfo(File file) {
    if (context.mounted) {
      // Just close the page instead of showing dialog
      Navigator.pop(context);
    }
  }

  pw.Widget _buildSupplierDetailsPDF(
    String selectedPaperSize,
    String? supplierName,
    String? supplierPhone,
    String? supplierEmail,
    String? supplierAddress,
    pw.TextStyle headerStyle,
    pw.TextStyle bodyStyle,
    String? fromDate,
    String? toDate,
    Map<String, DisplayOption>? displayConfig,
  ) {
    // Create styles to match screenshot
    final supplierDetailStyle = pw.TextStyle(
      fontSize: selectedPaperSize == 'A5' ? 7.0 : 10.0,
      color: PdfColors.black,
      height: 2, // Add line height for better spacing between lines
    );

    // Create a style for supplier information header
    final supplierInfoHeaderStyle = pw.TextStyle(
      fontSize: selectedPaperSize == 'A5' ? 8.0 : 12.0,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
      height: 2, // Add line height for better spacing between lines
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      margin: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(
              color: PdfColors.grey400, width: 0.5), // Slightly thicker border
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          color: PdfColors.grey50 // blueGrey100 with 30% opacity
          ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Add a header for supplier details
          pw.Text(
            'voucher_print.supplier_information'.tr,
            style: supplierInfoHeaderStyle,
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 0.3,
            color: PdfColors.grey400,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Display supplier information with better spacing
                    if (displayConfig?['showSupplierName']?.visible == true &&
                        supplierName != null &&
                        supplierName.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(
                            bottom: 8), // Increased spacing
                        child: pw.Text(
                          supplierName,
                          style: supplierDetailStyle,
                        ),
                      ),
                    if (displayConfig?['showSupplierPhone']?.visible == true &&
                        supplierPhone != null &&
                        supplierPhone.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(
                            bottom: 8), // Increased spacing
                        child: pw.Text(
                          supplierPhone,
                          style: supplierDetailStyle,
                        ),
                      ),
                    if (displayConfig?['showSupplierEmail']?.visible == true &&
                        supplierEmail != null &&
                        supplierEmail.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(
                            bottom: 8), // Increased spacing
                        child: pw.Text(
                          supplierEmail,
                          style: supplierDetailStyle,
                        ),
                      ),
                    if (displayConfig?['showSupplierAddress']?.visible == true &&
                        supplierAddress != null &&
                        supplierAddress.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(
                            bottom: 8), // Increased spacing
                        child: pw.Text(
                          supplierAddress,
                          style: supplierDetailStyle,
                        ),
                      )
                    else if (supplierName == null || supplierName.isEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(
                            bottom: 8), // Increased spacing
                        child: pw.Text(
                          'N/A',
                          style: supplierDetailStyle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSupplierTransactionReportItemsTable(
      pw.TextStyle headerStyle,
      pw.TextStyle contentStyle,
      Map<String, DisplayOption>? displayConfig,
      List<SupplierTransaction> cartItems,
      bool isFromLocalStorage,
      DocumentConfig? billDocumentConfig) {
    // Create table data based on visibility with smart product name handling
    List<List<pw.Widget>> tableData = [];
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      String type = item.type;
      String transactionType = item.transactionType;
      double amount = double.tryParse(item.amount) ?? 0.0;
      String status = item.status;
      String date = item.date;

      // Format amounts for Debit/Credit columns
      String formattedAmount = amount.toStringAsFixed(2);
      String debitAmount =
          (type.toLowerCase() == 'debit') ? formattedAmount : '-';
      String creditAmount =
          (type.toLowerCase() == 'credit') ? formattedAmount : '-';

      // Format date to show only date (not time)
      String formattedDate = date;
      try {
        // Try to parse and format the date if it's in a standard format
        formattedDate = DateHelper.formatISODate(date);
      } catch (e) {
        // Keep original date if parsing fails
        formattedDate = date;
      }
      
      // Format status to match image
      String displayStatus = status;
      if (status == 'SUCC') {
        displayStatus = 'Paid';
      } else if (status == 'FAIL') {
        displayStatus = 'Pending';
      } else if (status == 'INIT') {
        displayStatus = 'Initiated';
      }

      // Build row data - 6 columns: SL, Date, Type, Debit, Credit, Status
      List<pw.Widget> rowData = [];

      // Add Sl.No
      rowData.add(pw.Text((i + 1).toString(), style: contentStyle));

      // Add Date
      rowData.add(pw.Text(formattedDate, style: contentStyle));

      // Add Type column (transaction type)
      rowData.add(pw.Text(transactionType, style: contentStyle));

      // Add Debit column with red color for debit amounts
      rowData.add(pw.Text(debitAmount,
          style: pw.TextStyle(
              color: debitAmount != '-' ? PdfColors.red800 : contentStyle.color,
              fontSize: contentStyle.fontSize,
              fontWeight: debitAmount != '-' ? pw.FontWeight.bold : pw.FontWeight.normal,
              height: contentStyle.height)));

      // Add Credit column with green color for credit amounts
      rowData.add(pw.Text(creditAmount,
          style: pw.TextStyle(
              color: creditAmount != '-' ? PdfColors.green800 : contentStyle.color,
              fontSize: contentStyle.fontSize,
              fontWeight: creditAmount != '-' ? pw.FontWeight.bold : pw.FontWeight.normal,
              height: contentStyle.height)));

      // Add Status if enabled
      if (displayConfig?['showStatus']?.visible == true) {
        rowData.add(pw.Text(displayStatus,
            style: pw.TextStyle(
                color: status == 'SUCC'
                    ? PdfColors.green800
                    : status == 'FAIL'
                        ? PdfColors.red800
                        : status == 'INIT'
                            ? PdfColors.grey700
                            : contentStyle.color,
                fontWeight: status == 'SUCC'
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                fontSize: contentStyle.fontSize,
                height: contentStyle.height)));
      }

      tableData.add(rowData);
    }

    // Create headers for the table - matching image: SL, Date, Type, Debit, Credit, Status
    final List<pw.Widget> tableHeaders = [];

    // Add SL column - use resolved label
    tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'sl_number', 'SL'), style: headerStyle));

    // Add Date column - use resolved label
    tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'date', 'Date'), style: headerStyle));

    // Add Type column - use resolved label (item)
    tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'item', 'Type'), style: headerStyle));

    // Add Debit column - use resolved label
    tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'debit', 'Debit'), style: headerStyle));

    // Add Credit column - use resolved label
    tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'credit', 'Credit'), style: headerStyle));

    // Add Status column (if enabled) - use resolved label
    if (displayConfig?['showStatus']?.visible == true) {
      tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'status', 'Status'), style: headerStyle));
    }

    // Define column widths - 6 columns: SL, Date, Type, Debit, Credit, Status
    final Map<int, pw.TableColumnWidth> columnWidths = {
      // SL column - narrow
      0: const pw.FixedColumnWidth(40),
      // Date column - medium
      1: const pw.FixedColumnWidth(90),
      // Type column - medium
      2: const pw.FixedColumnWidth(90),
      // Debit column - medium
      3: const pw.FixedColumnWidth(80),
      // Credit column - medium
      4: const pw.FixedColumnWidth(80),
      // Status column (if enabled) - medium
      5: const pw.FixedColumnWidth(90),
    };

    // Remove Status column width if not visible
    if (displayConfig?['showStatus']?.visible != true) {
      columnWidths.remove(5);
    }

    return pw.Table(
      border: const pw.TableBorder(
        top: pw.BorderSide(color: PdfColors.grey400, width: 1),
        bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
        left: pw.BorderSide(color: PdfColors.grey400, width: 1),
        right: pw.BorderSide(color: PdfColors.grey400, width: 1),
        horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 1),
        verticalInside: pw.BorderSide(color: PdfColors.grey400, width: 1),
      ),
      columnWidths: columnWidths, // Add column widths to the table
      children: [
        // Header row with dark styling to match screenshot
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color:
                PdfColor.fromHex('#4a5568'), // Dark grey-blue like screenshot
          ),
          children: tableHeaders
              .map((header) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical:
                          12, // Increased vertical padding for better line spacing
                    ),
                    child: pw.Center(
                      child: header,
                    ),
                  ))
              .toList(),
        ),
        // Data rows with clean white background and better spacing
        ...tableData.asMap().entries.map((entry) {
          final int index = entry.key;
          final List<pw.Widget> row = entry.value;
          return pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
            children: row
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical:
                            12, // Increased vertical padding for better line spacing
                      ),
                      child: pw.Center(
                        child: cell,
                      ),
                    ))
                .toList(),
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildCartTotalRow(
    String selectedPaperSize,
    List<SupplierTransaction> cartItems,
    bool isFromLocalStorage,
    pw.TextStyle summaryStyle,
    Map<String, DisplayOption>? displayConfig,
  ) {
    // Calculate totals
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var item in cartItems) {
      double amount = double.tryParse(item.amount) ?? 0.0;
      String type = item.type;

      if (type.toLowerCase() == 'credit') {
        totalCredit += amount;
      } else if (type.toLowerCase() == 'debit') {
        totalDebit += amount;
      }
    }

    double balance = totalCredit - totalDebit;

    // Build list of visible summary items
    List<pw.Widget> summaryItems = [];

    // Total Credit - check visibility
    if (displayConfig?['showTotalCredit']?.visible == true) {
      summaryItems.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Total Credit: ',
              style: pw.TextStyle(
                fontSize: selectedPaperSize == 'A5' ? 7.0 : 10.0,
                color: PdfColors.grey700,
                height: 2,
              ),
            ),
            pw.Text(
              '${totalCredit.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: selectedPaperSize == 'A5' ? 7.0 : 10.0,
                color: PdfColors.grey700,
                height: 2,
              ),
            ),
          ],
        ),
      );
      summaryItems.add(pw.SizedBox(height: 4));
    }

    // Total Debit - check visibility
    if (displayConfig?['showTotalDebit']?.visible == true) {
      summaryItems.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Total Debit: ',
              style: pw.TextStyle(
                fontSize: selectedPaperSize == 'A5' ? 7.0 : 10.0,
                color: PdfColors.grey700,
                height: 2,
              ),
            ),
            pw.Text(
              '${totalDebit.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: selectedPaperSize == 'A5' ? 7.0 : 10.0,
                color: PdfColors.grey700,
                height: 2,
              ),
            ),
          ],
        ),
      );
      summaryItems.add(pw.SizedBox(height: 8));
    }

    // Balance - check visibility
    if (displayConfig?['showBalance']?.visible == true) {
      summaryItems.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Balance: ',
              style: pw.TextStyle(
                fontSize: selectedPaperSize == 'A5' ? 8.0 : 11.0,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
                height: 2,
              ),
            ),
            pw.Text(
              '${balance.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: selectedPaperSize == 'A5' ? 8.0 : 11.0,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
                height: 2,
              ),
            ),
          ],
        ),
      );
    }

    // Only show the container if at least one summary item is visible
    if (summaryItems.isEmpty) {
      return pw.SizedBox.shrink();
    }

    // Wrap the cart total in a card with limited width and centered alignment
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 130, // Set a fixed width for the card
          padding: const pw.EdgeInsets.all(15),
          margin: const pw.EdgeInsets.only(bottom: 20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors
                .grey50, // Light grey background similar to supplier details
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: summaryItems,
          ),
        ),
      ],
    );
  }

  void _debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    debugPrint("===== TEMPLATE SETTINGS DEBUG =====");
    if (displayConfig != null) {
      displayConfig.forEach((key, value) {
        debugPrint("$key: visible=${value.visible}, value=${value.value}");
      });
    } else {
      debugPrint("Display config is null");
    }
    debugPrint("===== END TEMPLATE SETTINGS DEBUG =====");
  }

  Map<String, DisplayOption> _createFallbackDisplayConfig() {
    debugPrint("⚠️ Creating fallback display configuration for Supplier Statement");
    return {
      // Header/Footer settings
      'showHeader': DisplayOption(visible: true, value: null),
      'showSubheader': DisplayOption(visible: true, value: null),
      'showFooter': DisplayOption(visible: true, value: null),
      'showDates': DisplayOption(visible: true, value: null),
      
      // Supplier details
      'showSupplierName': DisplayOption(visible: true, value: null),
      'showSupplierEmail': DisplayOption(visible: true, value: null),
      'showSupplierPhone': DisplayOption(visible: true, value: null),
      'showSupplierAddress': DisplayOption(visible: true, value: null),
      
      // Table column visibility - matching your image (SL, Date, Debit, Credit, Status)
      'showSlNumber': DisplayOption(visible: true, value: null),
      'showDate': DisplayOption(visible: true, value: null),
      'showReference': DisplayOption(visible: false, value: null), // HIDDEN
      'showTransactionType': DisplayOption(visible: false, value: null), // HIDDEN
      'showDebit': DisplayOption(visible: true, value: null),
      'showCredit': DisplayOption(visible: true, value: null),
      'showPaymentMethod': DisplayOption(visible: false, value: null), // HIDDEN
      'showBalanceColumn': DisplayOption(visible: false, value: null), // HIDDEN from table
      
      // Summary totals (shown at bottom, not in table)
      'showTotalCredit': DisplayOption(visible: true, value: null),
      'showTotalDebit': DisplayOption(visible: true, value: null),
      'showBalance': DisplayOption(visible: true, value: null),
      'showStatus': DisplayOption(visible: true, value: null),
    };
  }

  // Merge API config with fallback to ensure all required keys exist
  Map<String, DisplayOption> _ensureCompleteDisplayConfig(Map<String, DisplayOption>? apiConfig) {
    final fallback = _createFallbackDisplayConfig();
    
    if (apiConfig == null || apiConfig.isEmpty) {
      debugPrint("⚠️ API config is null/empty, using complete fallback");
      return fallback;
    }
    
    // Merge: API config takes precedence, but fallback fills in missing keys
    final merged = Map<String, DisplayOption>.from(fallback);
    apiConfig.forEach((key, value) {
      merged[key] = value;
    });
    
    debugPrint("✅ Merged display config with ${merged.length} total options");
    return merged;
  }

  Future<File?> generateSupplierTransactionReportPDFForSharing({
    required List<SupplierTransaction> cartItems,
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
    String? supplierName,
    String? supplierPhone,
    String? supplierEmail,
    String? supplierAddress,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      // Ensure billDocumentConfig is loaded before generating PDF
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        return null;
      }

      final apiDisplayConfig = billDocumentConfig.displayConfiguration?.options;
      _debugPrintTemplateSettings(apiDisplayConfig);

      // Ensure complete display configuration by merging API config with fallback
      final updatedSettings = _ensureCompleteDisplayConfig(apiDisplayConfig);

      // Create a PDF document
      final pdf = pw.Document();

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

      // Define styles to match the screenshot design
      final headerStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 18.0 : 22.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
        height: 2, // Add line height for better spacing between lines
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 14.0 : 16.0,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.grey700,
        height: 2, // Add line height for better spacing between lines
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.5 : 9.0,
        color: PdfColors.black,
        height: 2, // Add line height for better spacing between lines
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
        color: PdfColors.grey600,
        height: 2, // Add line height for better spacing between lines
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 5.0 : 8.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        height: 1.5, // Reduced line height for A5
      );
      final tableDataStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 4.5 : 7.5,
        color: PdfColors.black,
        height: 1.5, // Reduced line height for A5
      );
      final summaryStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 10.0 : 12.0,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.grey700,
        height: 2, // Add line height for better spacing between lines
      );
      final netTotalStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 11.0 : 13.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
        height: 2, // Add line height for better spacing between lines
      );

      // Add content to a multi-page PDF with styling to match PHP template
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(20),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Column(
              children: [
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 5),
                // Show footer if enabled
                if (updatedSettings?['showFooter']?.visible == true)
                  pw.Text(
                    billDocumentConfig?.footer ??
                        'This is a computer-generated document. No signature is required.',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                      height: 2, // Add line height for better spacing
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
          ),
          build: (pw.Context context) => [
            // Wrap entire content in a Column so it flows
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with store information - professional design to match PHP template
                pw.Center(
                  child: pw.Column(
                    children: [
                      // Show header if enabled
                      if (updatedSettings?['showHeader']?.visible == true)
                        pw.Text(
                          billDocumentConfig?.header ?? 'EPosenke',
                          style: pw.TextStyle(
                            fontSize: selectedPaperSize == 'A5' ? 20.0 : 24.0,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                            height: 2, // Add line height for better spacing
                          ),
                        ),
                      pw.SizedBox(height: 5),
                      // Show subheader if enabled
                      if (updatedSettings?['showSubheader']?.visible == true)
                        pw.Text(
                          billDocumentConfig?.subheader ??
                              'Supplier Transaction Report',
                          style: pw.TextStyle(
                            fontSize: selectedPaperSize == 'A5' ? 14.0 : 18.0,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                            height: 2, // Add line height for better spacing
                          ),
                        ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        height: 2,
                        color: PdfColors.grey800,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Supplier Information Section - if available
                if (supplierName != null ||
                    supplierPhone != null ||
                    supplierEmail != null ||
                    supplierAddress != null)
                  _buildSupplierDetailsPDF(
                    selectedPaperSize,
                    supplierName,
                    supplierPhone,
                    supplierEmail,
                    supplierAddress,
                    subheaderStyle,
                    bodyStyle,
                    fromDate,
                    toDate,
                    updatedSettings,
                  ),

                // Add date range information outside supplier card and align to right
                if ((fromDate != null && fromDate.isNotEmpty) ||
                    (toDate != null && toDate.isNotEmpty))
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (updatedSettings?['showDates']?.visible == true) ...[
                            pw.Text(
                              'From: ${fromDate ?? 'N/A'}',
                              style: pw.TextStyle(
                                  fontSize:
                                      selectedPaperSize == 'A5' ? 8.0 : 10.0,
                                  color: PdfColor.fromHex('#2d3748'),
                                  fontWeight: pw.FontWeight.bold,
                                  height: 2), // Add line height for better spacing
                            ),
                            pw.SizedBox(
                                height: 6), // Add spacing between date lines
                            pw.Text(
                              'To: ${toDate ?? 'N/A'}',
                              style: pw.TextStyle(
                                  fontSize:
                                      selectedPaperSize == 'A5' ? 8.0 : 10.0,
                                  color: PdfColor.fromHex('#2d3748'),
                                  fontWeight: pw.FontWeight.bold,
                                  height: 2), // Add line height for better spacing
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                pw.SizedBox(height: 15),

                // Items table - professional design with borders to match PHP template
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 15, horizontal: 0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfSupplierTransactionReportItemsTable(
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
                    isFromLocalStorage, summaryStyle, updatedSettings),

                pw.SizedBox(height: 15),
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
      final file =
          File('${output.path}/SupplierTransactionReport_$sanitizedOrderNumber.pdf');

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
