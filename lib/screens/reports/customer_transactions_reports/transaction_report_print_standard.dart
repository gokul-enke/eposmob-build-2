import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
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

class TransactionReportStandardPrinter {
  final BuildContext context;

  TransactionReportStandardPrinter(this.context);

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

  Future<void> generateAndPrintTransactionReportPDF({
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
    String? fromDate,
    String? toDate,
  }) async {
    debugPrint("===== PDF GENERATION DEBUG INFO =====");
    debugPrint("Customer data received:");
    debugPrint("  Name: $customerName");
    debugPrint("  Phone: $customerPhone");
    debugPrint("  Email: $customerEmail");
    debugPrint("  Address: $customerAddress");
    debugPrint("  fromDate: $fromDate");
    debugPrint("  toDate: $toDate");
    debugPrint("===== END PDF GENERATION DEBUG INFO =====");

    // Calculate date range from cart items if not provided
    if ((fromDate == null || fromDate.isEmpty) &&
        (toDate == null || toDate.isEmpty) &&
        cartItems.isNotEmpty) {
      debugPrint("Calculating date range from cart items...");

      List<String> dates = [];
      for (var item in cartItems) {
        String? itemDate;

        if (isFromLocalStorage) {
          itemDate = item['date']?.toString();
        } else if (item is Map<String, dynamic>) {
          itemDate = item['date']?.toString();
        } else {
          try {
            itemDate = item.date?.toString();
          } catch (e) {
            debugPrint('Error accessing date: $e');
          }
        }

        if (itemDate != null && itemDate.isNotEmpty && itemDate != 'N/A') {
          dates.add(itemDate);
        }
      }

      if (dates.isNotEmpty) {
        // Sort dates to get first and last
        dates.sort();
        fromDate = DateHelper.formatISODate(dates.first);
        toDate = DateHelper.formatISODate(dates.last);
        debugPrint("Calculated fromDate: $fromDate");
        debugPrint("Calculated toDate: $toDate");
      }
    }

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

      final displayConfig = billDocumentConfig.displayConfiguration?.options;

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
        debugPrint(
            "Display Configuration options: ${billDocumentConfig.displayConfiguration!.options}");
        debugPrint(
            "Display Configuration options type: ${billDocumentConfig.displayConfiguration!.options.runtimeType}");
      } else {
        debugPrint("❌ Display Configuration object is NULL");
      }

      debugPrint("Display Config Options Count: ${displayConfig?.length ?? 0}");
      if (displayConfig != null) {
        debugPrint("Display Config Keys: ${displayConfig.keys.toList()}");
        // Debug each option
        displayConfig.forEach((key, value) {
          debugPrint("  $key: visible=${value.visible}, value=${value.value}");
        });
      } else {
        debugPrint("❌ Display Config Options is NULL");
      }
      debugPrint("===== END DOCUMENT CONFIG INFO =====");

      // Verify we're using Customer Statement config
      if (billDocumentConfig.type != "Customer Statement") {
        debugPrint(
            "⚠️ WARNING: Expected 'Customer Statement' but got '${billDocumentConfig.type}'");
      }

      // Validate Customer Statement display configuration fields
      debugPrint("===== CUSTOMER STATEMENT FIELD VALIDATION =====");
      final expectedFields = [
        'showHeader',
        'showSubheader',
        'showFooter',
        'showDates',
        'showCustomerName',
        'showCustomerEmail',
        'showCustomerPhone',
        'showCustomerAddress',
        'showTotalCredit',
        'showTotalDebit',
        'showBalance',
        'showOrderNumber',
        'showStatus',
        'showTax'
      ];

      for (String field in expectedFields) {
        if (displayConfig?.containsKey(field) == true) {
          debugPrint(
              "✅ $field: visible=${displayConfig![field]!.visible}, value=${displayConfig[field]!.value}");
        } else {
          debugPrint("❌ $field: NOT FOUND in display configuration");
        }
      }
      debugPrint("===== END FIELD VALIDATION =====");

      _debugPrintTemplateSettings(displayConfig);

      // Create fallback display configuration if null
      Map<String, DisplayOption>? updatedSettings = displayConfig;
      if (updatedSettings == null) {
        debugPrint(
            "⚠️ Display configuration is null, creating fallback configuration");
        updatedSettings = _createFallbackDisplayConfig();
        debugPrint(
            "✅ Created fallback configuration with ${updatedSettings.length} options");
      }

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Preparing $selectedPaperSize document for printing...",
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
          "showCustomerName: ${updatedSettings?['showCustomerName']?.visible}");
      debugPrint(
          "showCustomerEmail: ${updatedSettings?['showCustomerEmail']?.visible}");
      debugPrint(
          "showCustomerPhone: ${updatedSettings?['showCustomerPhone']?.visible}");
      debugPrint(
          "showCustomerAddress: ${updatedSettings?['showCustomerAddress']?.visible}");
      debugPrint(
          "showTotalCredit: ${updatedSettings?['showTotalCredit']?.visible}");
      debugPrint(
          "showTotalDebit: ${updatedSettings?['showTotalDebit']?.visible}");
      debugPrint("showBalance: ${updatedSettings?['showBalance']?.visible}");
      debugPrint(
          "showOrderNumber: ${updatedSettings?['showOrderNumber']?.visible}");
      debugPrint("showStatus: ${updatedSettings?['showStatus']?.visible}");
      debugPrint("showTax: ${updatedSettings?['showTax']?.visible}");

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
        fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
        color: PdfColors.black,
        height: 2, // Add line height for better spacing between lines
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
        color: PdfColors.grey600,
        height: 2, // Add line height for better spacing between lines
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.0 : 12.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        height: 1.5, // Reduced line height for A5
      );
      final tableDataStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 6.5 : 11.0,
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
                    billDocumentConfig.footer ??
                        'This is a computer-generated document. No signature is required.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
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
                          billDocumentConfig.header ?? 'EPosenke',
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
                          billDocumentConfig.subheader ??
                              'Customer Statement',
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
                    fromDate,
                    toDate,
                    updatedSettings,
                  ),

                // Add date range information outside customer card and align to right
                // Only show if showDates is enabled
                if ((updatedSettings?['showDates']?.visible ?? true) &&
                    ((fromDate != null && fromDate.isNotEmpty) ||
                        (toDate != null && toDate.isNotEmpty)))
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'From: ${fromDate ?? 'N/A'},',
                              style: pw.TextStyle(
                                  fontSize:
                                      selectedPaperSize == 'A5' ? 9.0 : 12.0,
                                  color: PdfColors.black,
                                  fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(
                                height: 4), // Add spacing between date lines
                            pw.Text(
                              'To : ${toDate ?? 'N/A'},',
                              style: pw.TextStyle(
                                  fontSize:
                                      selectedPaperSize == 'A5' ? 9.0 : 12.0,
                                  color: PdfColors.black,
                                  fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 15),

                // Items table - professional design with borders to match PHP template
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 15, horizontal: 0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfTransactionReportItemsTable(
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

                pw.SizedBox(height: 15),
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
      final file =
          File('${output.path}/TransactionReport_$sanitizedOrderNumber.pdf');
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
                // Navigation is handled by the parent TransactionReportPrintPage
              }
            }
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context, message: "PDF opened for printing");
              // Navigation is handled by the parent TransactionReportPrintPage
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
              // Navigation is handled by the parent TransactionReportPrintPage
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

      // Always show success message on Windows, regardless of result
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        // Navigation is handled by the parent TransactionReportPrintPage
      }
    } catch (e) {
      debugPrint("Windows PDF handling error: $e");
      // Still show success message on error
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        // Navigation is handled by the parent TransactionReportPrintPage
      }
    }
  }

  // Show information about file location (for Windows) - Now unused but kept for reference
  void _showFileLocationInfo(File file) {
    if (context.mounted) {
      // Navigation is handled by the parent TransactionReportPrintPage
      showScaffold(context: context, message: "PDF created successfully");
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
              'Transaction Report #${file.path.split('/').last.replaceAll('.pdf', '').replaceAll('TransactionReport-', '')}',
          text: 'Your transaction report',
        );

        if (context.mounted) {
          showScaffold(
              context: context, message: "PDF shared. Please open it to print");
          // Navigation is handled by the parent TransactionReportPrintPage
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

  pw.Widget _buildPdfTransactionReportItemsTable(
      pw.TextStyle headerStyle,
      pw.TextStyle contentStyle,
      Map<String, DisplayOption>? displayConfig,
      List<dynamic> cartItems,
      bool isFromLocalStorage,
      DocumentConfig? billDocumentConfig) {
    // Calculate running balance
    double runningBalance = 0.0;

    // Create table data based on visibility with smart product name handling
    List<List<pw.Widget>> tableData = [];
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      String orderNumber = '';
      String transactionType = '';
      String type = '';
      double amount = 0.0;
      String tax = '0.00';
      String status = '';
      String date = '';

      if (isFromLocalStorage) {
        // Handle local storage data
        orderNumber = item['orderNumber'] ?? 'N/A';
        transactionType = item['transactionType'] ?? 'N/A';
        type = item['type'] ?? 'N/A';
        amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
        status = item['status'] ?? 'N/A';
        date = item['date'] ?? 'N/A';
      } else {
        // Handle different object types - check if it's a Map or an object
        if (item is Map<String, dynamic>) {
          // Handle Map case (from API responses or converted data)
          orderNumber = item['order_number']?.toString() ??
              item['orderNumber']?.toString() ??
              item['order_id']?.toString() ??
              item['orderId']?.toString() ??
              'N/A';
          transactionType = item['transaction_type']?.toString() ??
              item['transactionType']?.toString() ??
              'N/A';
          type = item['type']?.toString() ?? 'N/A';
          amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          status = item['status']?.toString() ?? 'N/A';
          date = item['date']?.toString() ?? 'N/A';
        } else {
          // Handle object case (ListTransaction or similar)
          try {
            // Try to access orderNumber property - ensure it's not null or empty
            String? tempOrderNumber = item.orderNumber?.toString();
            if (tempOrderNumber == null ||
                tempOrderNumber.isEmpty ||
                tempOrderNumber == 'null') {
              // Fallback to orderId if orderNumber is not available
              tempOrderNumber = item.orderId?.toString();
            }
            orderNumber = tempOrderNumber ?? 'N/A';

            transactionType = item.transactionType?.toString() ?? 'N/A';
            type = item.type?.toString() ?? 'N/A';
            amount = double.tryParse(item.amount?.toString() ?? '0') ?? 0.0;
            status = item.status?.toString() ?? 'N/A';
            date = item.date?.toString() ?? 'N/A';

            debugPrint(
                'PDF Object case - Order Number: $orderNumber, Order ID: ${item.orderId}');
          } catch (e) {
            debugPrint('Error accessing cart item properties: $e');
            debugPrint('Item type: ${item.runtimeType}');
            debugPrint('Item: $item');
            // Fallback to safe defaults
            orderNumber = 'N/A';
            transactionType = 'N/A';
            type = 'N/A';
            amount = 0.0;
            status = 'N/A';
            date = 'N/A';
          }
        }
      }

      // Update transaction type display to match PHP template
      String displayTransactionType = transactionType;
      if (transactionType == 'Invoice') {
        displayTransactionType = 'Invoice';
      } else if (transactionType == 'Receipt') {
        displayTransactionType = 'Receipt';
      } else if (transactionType == 'Voucher') {
        displayTransactionType = 'Voucher';
      }

      // Update running balance and format amounts
      String formattedAmount = amount.toStringAsFixed(2);
      String debitAmount =
          (type.toLowerCase() == 'debit') ? formattedAmount : '-';
      String creditAmount =
          (type.toLowerCase() == 'credit') ? formattedAmount : '-';

      if (type.toLowerCase() == 'debit') {
        runningBalance -= amount;
      } else if (type.toLowerCase() == 'credit') {
        runningBalance += amount;
      }

      // Format date to show only date (no time)
      String formattedDate = date;
      try {
        // Try to parse and format the date if it's in a standard format
        formattedDate = DateHelper.formatISODate(date);
      } catch (e) {
        // Keep original date if parsing fails
        formattedDate = date;
      }

      // Build row data
      List<pw.Widget> rowData = [];

      // Add Sl.No
      rowData.add(pw.Text((i + 1).toString(), style: contentStyle));

      // Add Date
      rowData.add(pw.Text(formattedDate, style: contentStyle));

      // Add Reference (combined Transaction Type + Order Number)
      String reference = '$displayTransactionType - $orderNumber';
      rowData.add(pw.Text(reference, style: contentStyle));

      // Add Debit column with red color for debit amounts
      rowData.add(pw.Text(debitAmount,
          style: pw.TextStyle(
              color: PdfColors.red800,
              fontSize: contentStyle.fontSize,
              fontWeight: pw.FontWeight.bold,
              height: contentStyle.height))); // Inherit line height

      // Add Credit column with green color for credit amounts
      rowData.add(pw.Text(creditAmount,
          style: pw.TextStyle(
              color: PdfColors.green800,
              fontSize: contentStyle.fontSize,
              fontWeight: pw.FontWeight.bold,
              height: contentStyle.height))); // Inherit line height

      // Add Tax if enabled
      if (displayConfig?['showTax']?.visible == true) {
        rowData.add(pw.Text(tax, style: contentStyle));
      }

      // Add Balance
      rowData.add(pw.Text(runningBalance.toStringAsFixed(2),
          style: pw.TextStyle(
              color: runningBalance < 0
                  ? PdfColors.red800
                  : runningBalance > 0
                      ? PdfColors.green800
                      : contentStyle.color,
              fontSize: contentStyle.fontSize,
              height: contentStyle.height))); // Inherit line height

      // Add Status if enabled
      if (displayConfig?['showStatus']?.visible == true) {
        // Format status to match PHP template
        String displayStatus = status;
        if (status == 'SUCC') {
          displayStatus = 'Paid';
        } else if (status == 'FAIL') {
          displayStatus = 'Pending';
        } else if (status == 'INIT') {
          displayStatus = 'Initiated';
        }

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
                height: contentStyle.height))); // Inherit line height
      }

      tableData.add(rowData);
    }

    // Create headers for the table based on visibility and resolved labels
    final List<pw.Widget> tableHeaders = [];

    // Get resolved labels from document config with fallbacks
    final resolvedLabels = billDocumentConfig?.resolvedLabels;
    final String slNumberLabel = resolvedLabels?.slNumber ?? 'Sl No';
    final String dateLabel = resolvedLabels?.date ?? 'Date';
    final String referenceLabel =
        resolvedLabels?.orderNumber ?? 'Reference'; // Combined Order Number + Transaction Type
    final String debitLabel = resolvedLabels?.debit ?? 'Debit';
    final String creditLabel = resolvedLabels?.credit ?? 'Credit';
    final String taxLabel = resolvedLabels?.tax ?? 'Tax';
    final String balanceLabel = resolvedLabels?.balance ?? 'Balance';
    final String statusLabel = resolvedLabels?.status ?? 'Status';

    debugPrint("PDF: Using resolved labels from document config:");
    debugPrint("  Sl.No: '$slNumberLabel'");
    debugPrint("  Date: '$dateLabel'");
    debugPrint("  Reference: '$referenceLabel' (Combined Order Number + Type)");
    debugPrint("  Debit: '$debitLabel'");
    debugPrint("  Credit: '$creditLabel'");
    debugPrint("  Tax: '$taxLabel'");
    debugPrint("  Balance: '$balanceLabel'");
    debugPrint("  Status: '$statusLabel'");

    // Add Sl.No column
    tableHeaders.add(pw.Text(slNumberLabel, style: headerStyle));

    // Add Date column
    tableHeaders.add(pw.Text(dateLabel, style: headerStyle));

    // Add Reference column (combined Order Number + Transaction Type)
    tableHeaders.add(pw.Text(referenceLabel, style: headerStyle));

    // Add Debit column
    tableHeaders.add(pw.Text(debitLabel, style: headerStyle));

    // Add Credit column
    tableHeaders.add(pw.Text(creditLabel, style: headerStyle));

    // Add Tax column (if enabled)
    if (displayConfig?['showTax']?.visible == true) {
      tableHeaders.add(pw.Text(taxLabel, style: headerStyle));
    }

    // Add Balance column
    tableHeaders.add(pw.Text(balanceLabel, style: headerStyle));

    // Add Status column (if enabled)
    if (displayConfig?['showStatus']?.visible == true) {
      tableHeaders.add(pw.Text(statusLabel, style: headerStyle));
    }

    // Define column widths - adjust based on paper size
    final bool isA5 = contentStyle.fontSize! <= 7.0; // Detect A5 by font size
    final Map<int, pw.TableColumnWidth> columnWidths = {
      // Sl.No column - narrow
      0: pw.FixedColumnWidth(isA5 ? 30 : 60),
      // Date column - medium
      1: pw.FixedColumnWidth(isA5 ? 60 : 100),
      // Reference column (combined Order Number + Type) - wider
      2: pw.FixedColumnWidth(isA5 ? 135 : 210),
      // Debit column - narrow
      3: pw.FixedColumnWidth(isA5 ? 45 : 70),
      // Credit column - narrow
      4: pw.FixedColumnWidth(isA5 ? 45 : 70),
      // Tax column (if enabled) - narrow
      5: pw.FixedColumnWidth(isA5 ? 30 : 50),
      // Balance column - medium
      6: pw.FixedColumnWidth(isA5 ? 50 : 80),
      // Status column (if enabled) - medium
      7: pw.FixedColumnWidth(isA5 ? 45 : 70),
    };

    // Adjust column indices if Tax or Status columns are not visible
    int taxColumnIndex = displayConfig?['showTax']?.visible == true ? 5 : -1;
    int statusColumnIndex = displayConfig?['showStatus']?.visible == true
        ? (displayConfig?['showTax']?.visible == true ? 7 : 6)
        : -1;

    // Remove Tax column width if not visible
    if (taxColumnIndex == -1) {
      columnWidths.remove(5);
      // Adjust Status column index if needed
      if (statusColumnIndex != -1) {
        columnWidths.remove(7);
        columnWidths[6] =
            const pw.FixedColumnWidth(80); // Move Status to index 6
      }
    } else if (statusColumnIndex == -1) {
      // Remove Status column width if not visible
      columnWidths.remove(7);
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
                    padding: pw.EdgeInsets.symmetric(
                      horizontal: isA5 ? 4 : 8,
                      vertical: isA5 ? 6 : 12, // Reduced padding for A5
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
                      padding: pw.EdgeInsets.symmetric(
                        horizontal: isA5 ? 4 : 8,
                        vertical: isA5 ? 6 : 12, // Reduced padding for A5
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
            pw.Text('Total Transactions:', style: style),
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
            pw.Text('Total Amount:', style: style),
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
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Date: ${DateHelper.formatISODate(orderDate)}',
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

  // Date Range Row for PDF - same format as date and time row
  pw.Widget _buildDateRangeRowPDF(
      String selectedPaperSize, String? fromDate, String? toDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          vertical: 0, horizontal: 8), // Same padding as date/time row
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'From: ${fromDate ?? 'N/A'}',
            style: pw.TextStyle(
              fontSize: selectedPaperSize == 'A5'
                  ? 7.0
                  : 9.0, // Same font size as date/time row
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'To: ${toDate ?? 'N/A'}',
            style: pw.TextStyle(
              fontSize: selectedPaperSize == 'A5'
                  ? 7.0
                  : 9.0, // Same font size as date/time row
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
      debugPrint(
          "  * value: ${value.value} (${value.value?.runtimeType ?? 'null'})");
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
      debugPrint(
          "  * Value type: ${discountConfig.value?.runtimeType ?? 'null'}");
      debugPrint("  * Object hashCode: ${discountConfig.hashCode}");
    } else {
      debugPrint("\n⚠️ showDiscount key NOT FOUND in displayConfig!");
    }
    debugPrint("===== END DISPLAY CONFIGURATION DEBUG =====");
  }

  // Customer Details Section for PDF - matching screenshot design
  pw.Widget _buildCustomerDetailsPDF(
    String selectedPaperSize,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    pw.TextStyle headerStyle,
    pw.TextStyle bodyStyle,
    String? fromDate,
    String? toDate,
    Map<String, DisplayOption>? displayConfig,
  ) {
    // Create styles to match screenshot
    final customerDetailStyle = pw.TextStyle(
      fontSize: selectedPaperSize == 'A5' ? 8.0 : 12.0,
      color: PdfColors.black,
    );

    // Create a style for customer information header
    final customerInfoHeaderStyle = pw.TextStyle(
      fontSize: selectedPaperSize == 'A5' ? 9.0 : 14.0,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
    );

    debugPrint("===== PDF CUSTOMER DETAILS DEBUG =====");
    debugPrint("Building customer details section for PDF:");
    debugPrint("  customerName: '$customerName'");
    debugPrint("  customerPhone: '$customerPhone'");
    debugPrint("  customerEmail: '$customerEmail'");
    debugPrint("  customerAddress: '$customerAddress'");
    debugPrint("  fromDate: '$fromDate'");
    debugPrint("  toDate: '$toDate'");
    debugPrint("  Display Config visibility:");
    debugPrint(
        "    showCustomerName: ${displayConfig?['showCustomerName']?.visible}");
    debugPrint(
        "    showCustomerPhone: ${displayConfig?['showCustomerPhone']?.visible}");
    debugPrint(
        "    showCustomerEmail: ${displayConfig?['showCustomerEmail']?.visible}");
    debugPrint(
        "    showCustomerAddress: ${displayConfig?['showCustomerAddress']?.visible}");
    debugPrint("===== END PDF CUSTOMER DETAILS DEBUG =====");

    // Check if any customer field should be shown based on visibility settings
    bool showName = (displayConfig?['showCustomerName']?.visible ?? true) &&
        customerName != null &&
        customerName.isNotEmpty;
    bool showEmail = (displayConfig?['showCustomerEmail']?.visible ?? true) &&
        customerEmail != null &&
        customerEmail.isNotEmpty;
    bool showPhone = (displayConfig?['showCustomerPhone']?.visible ?? true) &&
        customerPhone != null &&
        customerPhone.isNotEmpty;
    bool showAddress =
        (displayConfig?['showCustomerAddress']?.visible ?? true) &&
            customerAddress != null &&
            customerAddress.isNotEmpty;

    // Build list of visible customer detail widgets
    List<pw.Widget> customerDetailWidgets = [];

    if (showName) {
      customerDetailWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(customerName, style: customerDetailStyle),
        ),
      );
    }

    if (showPhone) {
      customerDetailWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(customerPhone, style: customerDetailStyle),
        ),
      );
    }

    if (showEmail) {
      customerDetailWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(customerEmail, style: customerDetailStyle),
        ),
      );
    }

    if (showAddress) {
      customerDetailWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(customerAddress, style: customerDetailStyle),
        ),
      );
    }

    // If no details to show, add N/A
    if (customerDetailWidgets.isEmpty) {
      customerDetailWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('N/A', style: customerDetailStyle),
        ),
      );
    }

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
          // Add a header for customer details
          pw.Text(
            'Customer Information',
            style: customerInfoHeaderStyle,
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
                  children: customerDetailWidgets,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to calculate cart total from items
  double _calculateCartTotal(List<dynamic> cartItems, bool isFromLocalStorage) {
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var item in cartItems) {
      double amount = 0.0;
      String type = '';

      if (isFromLocalStorage) {
        amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
        type = item['type']?.toString() ?? '';
      } else {
        if (item is Map<String, dynamic>) {
          amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          type = item['type']?.toString() ?? '';
        } else {
          try {
            amount = double.tryParse(item.amount?.toString() ?? '0') ?? 0.0;
            type = item.type?.toString() ?? '';
          } catch (e) {
            debugPrint('Error accessing item amount/type: $e');
            amount = 0.0;
            type = '';
          }
        }
      }

      if (type.toLowerCase() == 'credit') {
        totalCredit += amount;
      } else if (type.toLowerCase() == 'debit') {
        totalDebit += amount;
      }
    }

    return totalCredit - totalDebit;
  }

  // Helper method to build cart total row after items table
  pw.Widget _buildCartTotalRow(
    String selectedPaperSize,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    pw.TextStyle summaryStyle,
  ) {
    // Calculate totals
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var item in cartItems) {
      double amount = 0.0;
      String type = '';

      if (isFromLocalStorage) {
        amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
        type = item['type']?.toString() ?? '';
      } else {
        if (item is Map<String, dynamic>) {
          amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          type = item['type']?.toString() ?? '';
        } else {
          try {
            amount = double.tryParse(item.amount?.toString() ?? '0') ?? 0.0;
            type = item.type?.toString() ?? '';
          } catch (e) {
            debugPrint('Error accessing item amount/type: $e');
            amount = 0.0;
            type = '';
          }
        }
      }

      if (type.toLowerCase() == 'credit') {
        totalCredit += amount;
      } else if (type.toLowerCase() == 'debit') {
        totalDebit += amount;
      }
    }

    double balance = totalCredit - totalDebit;

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
                .grey50, // Light grey background similar to customer details
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Total Credit
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Credit: ',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 8.0 : 12.0,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    '${totalCredit.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 8.0 : 12.0,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              // Total Debit
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Debit: ',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 8.0 : 12.0,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    '${totalDebit.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 8.0 : 12.0,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              // Balance
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Balance: ',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 9.0 : 13.0,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    '${balance.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 9.0 : 13.0,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Generate PDF for sharing without printing
  Future<File?> generateTransactionReportPDFForSharing({
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
    String? fromDate,
    String? toDate,
  }) async {
    // Calculate date range from cart items if not provided
    if ((fromDate == null || fromDate.isEmpty) &&
        (toDate == null || toDate.isEmpty) &&
        cartItems.isNotEmpty) {
      debugPrint("Sharing: Calculating date range from cart items...");

      List<String> dates = [];
      for (var item in cartItems) {
        String? itemDate;

        if (isFromLocalStorage) {
          itemDate = item['date']?.toString();
        } else if (item is Map<String, dynamic>) {
          itemDate = item['date']?.toString();
        } else {
          try {
            itemDate = item.date?.toString();
          } catch (e) {
            debugPrint('Error accessing date: $e');
          }
        }

        if (itemDate != null && itemDate.isNotEmpty && itemDate != 'N/A') {
          dates.add(itemDate);
        }
      }

      if (dates.isNotEmpty) {
        // Sort dates to get first and last
        dates.sort();
        fromDate = DateHelper.formatISODate(dates.first);
        toDate = DateHelper.formatISODate(dates.last);
        debugPrint("Sharing: Calculated fromDate: $fromDate");
        debugPrint("Sharing: Calculated toDate: $toDate");
      }
    }

    try {
      // Ensure billDocumentConfig is loaded before generating PDF
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        return null;
      }

      final displayConfig = billDocumentConfig.displayConfiguration?.options;
      _debugPrintTemplateSettings(displayConfig);

      // Create fallback display configuration if null
      Map<String, DisplayOption>? updatedSettings = displayConfig;
      if (updatedSettings == null) {
        debugPrint(
            "⚠️ Display configuration is null in sharing method, creating fallback configuration");
        updatedSettings = _createFallbackDisplayConfig();
        debugPrint(
            "✅ Created fallback configuration for sharing with ${updatedSettings.length} options");
      }

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
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 14.0 : 16.0,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.grey700,
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
        color: PdfColors.black,
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
        color: PdfColors.grey600,
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.0 : 12.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );
      final tableDataStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 6.5 : 11.0,
        color: PdfColors.black,
      );
      final summaryStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 10.0 : 12.0,
        fontWeight: pw.FontWeight.normal,
        color: PdfColors.grey700,
      );
      final netTotalStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 11.0 : 13.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );

      // Add content to a multi-page PDF with minimal margins and optimized spacing
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
                // Show footer if enabled - use billDocumentConfig values as fallback
                if (updatedSettings?['showFooter']?.visible == true)
                  pw.Text(
                    (updatedSettings?['showFooter']?.value as String?) ??
                        billDocumentConfig.footer ??
                        'This is a computer-generated document. No signature is required.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
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
                          billDocumentConfig.header ?? 'EPosenke',
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
                          billDocumentConfig.subheader ??
                              'Customer Statement',
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
                    fromDate,
                    toDate,
                    updatedSettings,
                  ),

                // Add date range information outside customer card and align to right
                // Only show if showDates is enabled
                if ((updatedSettings?['showDates']?.visible ?? true) &&
                    ((fromDate != null && fromDate.isNotEmpty) ||
                        (toDate != null && toDate.isNotEmpty)))
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'From: ${fromDate ?? 'N/A'},',
                              style: pw.TextStyle(
                                fontSize:
                                    selectedPaperSize == 'A5' ? 9.0 : 12.0,
                                color: PdfColors.black,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(
                                height: 4), // Add spacing between date lines
                            pw.Text(
                              'To : ${toDate ?? 'N/A'},',
                              style: pw.TextStyle(
                                fontSize:
                                    selectedPaperSize == 'A5' ? 9.0 : 12.0,
                                color: PdfColors.black,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 15),

                // Items table - professional design with borders to match PHP template
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 15, horizontal: 0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfTransactionReportItemsTable(
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
          File('${output.path}/TransactionReport_$sanitizedOrderNumber.pdf');

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

  // Create fallback display configuration when API config is null
  // Based on Customer Statement API response structure
  Map<String, DisplayOption> _createFallbackDisplayConfig() {
    return {
      'showHeader': DisplayOption(visible: true, value: 'EPosenke'),
      'showSubheader':
          DisplayOption(visible: true, value: 'Customer Transaction Report'),
      'showFooter': DisplayOption(
          visible: true,
          value:
              'This is a computer-generated document. No signature is required.'),
      'showDates': DisplayOption(visible: true, value: null),
      'showCustomerName': DisplayOption(visible: true, value: null),
      'showCustomerEmail': DisplayOption(visible: true, value: null),
      'showCustomerPhone': DisplayOption(visible: true, value: null),
      'showCustomerAddress': DisplayOption(visible: true, value: null),
      'showTotalCredit': DisplayOption(visible: true, value: null),
      'showTotalDebit': DisplayOption(visible: true, value: null),
      'showBalance': DisplayOption(visible: true, value: null),
      'showOrderNumber': DisplayOption(visible: true, value: null),
      'showStatus': DisplayOption(visible: true, value: null),
      'showTax': DisplayOption(visible: true, value: null),
    };
  }
}
