import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
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
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReturnBillStandardPrinter {
  final BuildContext context;

  ReturnBillStandardPrinter(this.context);

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
    required List<OrderReturnItem> returnItems,
    required String returnTotalAmount,
    required String orderDate,
    required String orderNumber,
    required String selectedPaperSize,
    required DocumentConfig? returnBillDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerBalance,
  }) async {
    try {
      // Ensure returnBillDocumentConfig is loaded before printing
      if (returnBillDocumentConfig == null) {
        debugPrint("ERROR: Return Bill document configuration not loaded yet.");
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

      final displayConfig =
          returnBillDocumentConfig.displayConfiguration?.options;
        final bool isArabicLanguage =
          (returnBillDocumentConfig.language ?? '').toLowerCase() == 'ar';

      debugPrint("===== RETURN BILL PDF GENERATION =====");
      debugPrint("returnBillDocumentConfig ID: ${returnBillDocumentConfig.id}");
      debugPrint(
          "returnBillDocumentConfig Type: ${returnBillDocumentConfig.type}");
      debugPrint("Display Config Options Count: ${displayConfig?.length ?? 0}");

      if (context.mounted) {
        showScaffold(
          context: context,
          message:
              "Preparing $selectedPaperSize Return Bill document for printing...",
        );
      }

      // Create a PDF document
      final pdf = pw.Document();

      // Access Payment Gateways Provider for QR code link
      final paymentGatewaysProvider =
          Provider.of<PaymentGatewaysProvider>(context, listen: false);
      final currencySymbol =
          Provider.of<AppSettingsProvider>(context, listen: false)
                  .appSettings
                  ?.currency ??
              'Rs.';
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

      // Fetch ZATCA credentials before PDF build
      final zatcaPrefs = await SharedPreferences.getInstance();
      final zatcaVatNum = zatcaPrefs.getString('zatca_vat_number');
      final zatcaCompName = zatcaPrefs.getString('zatca_company_name');
      final bool hasZatcaCredentials = zatcaVatNum != null &&
          zatcaVatNum.isNotEmpty &&
          zatcaCompName != null &&
          zatcaCompName.isNotEmpty;

      // Pre-compute QR data
      String returnQrData = '';
      if (hasZatcaCredentials) {
        returnQrData = ZatcaQrHelper().generateQrForInvoice(
          sellerName: zatcaCompName,
          vatNumber: zatcaVatNum,
          invoiceDate: orderDate, // Pass true UTC ISO string
          totalAmount: double.tryParse(returnTotalAmount) ?? 0.0,
          vatAmount: 0.0,
        );
        debugPrint('[ReturnBillPDF] ZATCA QR generated for return bill');
      } else if (manualPaymentGateway.link.isNotEmpty) {
        returnQrData = manualPaymentGateway.link;
      }

      // Determine page format based on paper size
      PdfPageFormat pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;

      // Define styles with adjustments for A5 vs A4
      final headerStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 16.0 : 18.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
        color: PdfColors.black,
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 5.0 : 7.0,
        color: PdfColors.black,
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final summaryStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final netTotalStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );

      // Add content to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(15),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6),
              textAlign: pw.TextAlign.center,
            ),
          ),
          build: (pw.Context context) => [
            // Header with store information
            pw.Center(
              child: pw.Column(
                children: [
                  // Store name
                  if (displayConfig?['showStoreName']?.visible == true)
                    pw.Text(
                      displayConfig?['showStoreName']?.value as String? ??
                          'STORE NAME',
                      style: headerStyle,
                    ),

                  // Store description
                  if (displayConfig?['showDescription']?.visible == true)
                    pw.Text(
                      displayConfig?['showDescription']?.value as String? ?? '',
                      style: pw.TextStyle(
                          fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0),
                    ),

                  // Store address
                  if (displayConfig?['showStoreAddress']?.visible == true) ...[
                    if ((displayConfig?['showStoreAddress']?.value as String?)
                            ?.isNotEmpty ==
                        true)
                      pw.Text(
                        displayConfig!['showStoreAddress']!.value as String,
                        style: bodyStyle,
                      ),
                  ],

                  // FSSAI info
                  if (displayConfig?['showFssaiInfo']?.visible == true) ...[
                    if ((displayConfig?['showFssaiInfo']?.value as String?)
                            ?.isNotEmpty ==
                        true)
                      pw.Text(
                        displayConfig!['showFssaiInfo']!.value as String,
                        style: bodyStyle,
                      ),
                  ],

                  // Contact information
                  if (displayConfig?['showTel']?.visible == true)
                    pw.Text(
                      displayConfig?['showTel']?.value as String? ??
                          customerCareNumber,
                      style: bodyStyle,
                    ),

                  if (displayConfig?['showEmail']?.visible == true)
                    pw.Text(
                      displayConfig?['showEmail']?.value as String? ??
                          customerCareEmail,
                      style: bodyStyle,
                    ),
                ],
              ),
            ),

            pw.SizedBox(height: 5),

            // Invoice information
            if ((displayConfig?['showInvoiceTitle']?.visible == true) ||
                (displayConfig?['showInvoiceNumber']?.visible == true))
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (displayConfig?['showInvoiceTitle']?.visible == true)
                      pw.Text('RETURN BILL', style: subheaderStyle),
                    if (displayConfig?['showInvoiceNumber']?.visible == true)
                      pw.Text('Bill No: $orderNumber', style: subheaderStyle),
                  ],
                ),
              ),

            pw.SizedBox(height: 5),

            // Customer Details
            if ((customerName != null && customerName.isNotEmpty) ||
                (customerPhone != null && customerPhone.isNotEmpty) ||
                (customerBalance != null && customerBalance.isNotEmpty))
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (displayConfig?['showCustomerNameAndPhone']?.visible ==
                        true) ...[
                      if (customerName != null && customerName.isNotEmpty)
                        pw.Text('Customer: $customerName', style: bodyStyle),
                      if (customerPhone != null && customerPhone.isNotEmpty)
                        pw.Text(
                          'Phone: ${StringHelper.maskStringShowLast4(customerPhone)}',
                          style: bodyStyle,
                        ),
                    ],
                    if (customerBalance != null &&
                        customerBalance.isNotEmpty &&
                        displayConfig?['showCustomerBalance']?.visible == true)
                      pw.Text('Balance: $customerBalance', style: summaryStyle),
                  ],
                ),
              ),

            pw.SizedBox(height: 5),

            // Return Items Table
            _buildReturnItemsTable(
              returnItems,
              displayConfig,
              returnBillDocumentConfig,
              tableHeaderStyle,
              bodyStyle,
            ),

            pw.SizedBox(height: 8),

            // Total Summary - matching sale bill style
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RETURN TOTAL:', style: summaryStyle),
                  pw.SizedBox(height: 8),

                  // Return Total Amount
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('$currencySymbol ', style: netTotalStyle),
                      pw.Text(returnTotalAmount, style: netTotalStyle),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // ORDER SUMMARY section - matching sale bill
                  pw.Text('ORDER SUMMARY', style: subheaderStyle),
                  pw.SizedBox(height: 5),

                  // Total Items
                  if (displayConfig?['showReturnItemsCount']?.visible == true)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Items:', style: bodyStyle),
                        pw.Text('${returnItems.length}', style: bodyStyle),
                      ],
                    ),

                  pw.SizedBox(height: 3),

                  // Total MRP (calculated from return items)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total MRP:', style: bodyStyle),
                      pw.Text(_calculateTotalMRP(returnItems),
                          style: bodyStyle),
                    ],
                  ),

                  pw.SizedBox(height: 3),

                  // You Saved (difference between MRP and return amount)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('You Saved:', style: bodyStyle),
                      pw.Text(_calculateSaved(returnItems, returnTotalAmount),
                          style: bodyStyle),
                    ],
                  ),

                  pw.SizedBox(height: 3),

                  // Discount
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Discount:', style: bodyStyle),
                      pw.Text('0.00', style: bodyStyle),
                    ],
                  ),

                  pw.Divider(color: PdfColors.black),

                  // Net Total
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Total:', style: netTotalStyle),
                      pw.Text(returnTotalAmount, style: netTotalStyle),
                    ],
                  ),

                  // Amount in words
                  if (displayConfig?['showReturnAmountInWords']?.visible ==
                      true) ...[
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            isArabicLanguage
                                ? 'المبلغ بالكلمات:'
                                : 'Amount in words:',
                            style: bodyStyle),
                        pw.Expanded(
                          child: pw.Text(
                            '${AmountHelper().convertNumberToWords(double.tryParse(returnTotalAmount) ?? 0.0, language: isArabicLanguage ? 'ar' : 'en')}${isArabicLanguage ? ' فقط.' : ' Only.'}',
                            style: bodyStyle,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 5),

            // QR Code - ZATCA or payment gateway
            if (displayConfig?['showQRCode']?.visible == true &&
                returnQrData.isNotEmpty)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      hasZatcaCredentials
                          ? 'ZATCA E-Invoice QR'
                          : (displayConfig?['showQRCode']?.value?.toString() ??
                              'Scan QR to Pay'),
                      style: bodyStyle,
                    ),
                    pw.SizedBox(height: 3),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: returnQrData,
                      width: 80,
                      height: 80,
                    ),
                  ],
                ),
              ),

            pw.SizedBox(height: 5),

            // Date and Time - matching sale bill format
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${DateHelper.formatISODate(orderDate)}',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Time: ${DateHelper.formatISODateToIST(orderDate)}',
                    style: pw.TextStyle(
                      fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 5),

            // Order Barcode - matching sale bill format
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Column(
                  children: [
                    pw.BarcodeWidget(
                      textPadding: 2,
                      barcode: pw.Barcode.code128(),
                      data: orderNumber,
                      width: selectedPaperSize == 'A5' ? 100 : 120,
                      height: selectedPaperSize == 'A5' ? 25 : 30,
                    ),
                    pw.SizedBox(height: 5),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 5),

            // Terms & Conditions
            if (displayConfig?['showTermsConditions']?.visible == true) ...[
              pw.Text('Terms & Conditions:', style: subheaderStyle),
              pw.Text(
                displayConfig?['showTermsConditions']?.value?.toString() ??
                    returnBillDocumentConfig.terms ??
                    '',
                style: smallStyle,
              ),
              pw.SizedBox(height: 5),
            ],

            // Thank You Message - matching sale bill format
            if (displayConfig?['showThankYouMessage']?.visible == true)
              pw.Center(
                child: pw.Text(
                  displayConfig?['showThankYouMessage']?.value?.toString() ??
                      '*** THANK YOU FOR SHOPPING WITH US ***',
                  style: pw.TextStyle(
                    fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
          ],
        ),
      );

      // Save and handle PDF
      await _savePDFAndOpen(pdf, orderNumber);
    } catch (e) {
      debugPrint("ERROR generating Return Bill PDF: $e");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: ${e.toString()}",
        );
      }
    }
  }

  pw.Widget _buildReturnItemsTable(
    List<OrderReturnItem> returnItems,
    Map<String, DisplayOption>? displayConfig,
    DocumentConfig? returnBillDocumentConfig,
    pw.TextStyle tableHeaderStyle,
    pw.TextStyle bodyStyle,
  ) {
    // Create headers for the table based on visibility and resolved labels
    final List<String> tableHeaders = [];
    final Map<int, pw.Alignment> cellAlignmentsMap = {};
    int visibleColIndex = 0;

    if (displayConfig?['showReturnSLNumber']?.visible == true) {
      final label = (displayConfig?['showReturnSLNumber']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnSLNumber']!.value as String
          : (returnBillDocumentConfig
                      ?.resolvedLabels?.returnSlNumber?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnSlNumber!
              : 'SL#');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
    }

    if (displayConfig?['showReturnParticulars']?.visible == true) {
      final label = (displayConfig?['showReturnParticulars']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnParticulars']!.value as String
          : (returnBillDocumentConfig
                      ?.resolvedLabels?.returnParticulars?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnParticulars!
              : 'DESCRIPTION');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
    }

    // Add MRP column
    if (displayConfig?['showReturnMRP']?.visible == true) {
      final label = (displayConfig?['showReturnMRP']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnMRP']!.value as String
          : (returnBillDocumentConfig?.resolvedLabels?.returnMrp?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnMrp!
              : 'MRP');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
    }

    if (displayConfig?['showReturnQty']?.visible == true) {
      final label = (displayConfig?['showReturnQty']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnQty']!.value as String
          : (returnBillDocumentConfig?.resolvedLabels?.returnQty?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnQty!
              : 'QTY');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
    }

    if (displayConfig?['showReturnRate']?.visible == true) {
      final label = (displayConfig?['showReturnRate']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnRate']!.value as String
          : (returnBillDocumentConfig?.resolvedLabels?.returnRate?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnRate!
              : 'RATE');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
    }

    if (displayConfig?['showReturnTotal']?.visible == true) {
      final label =
          (displayConfig?['showReturnTotal']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showReturnTotal']!.value as String
              : (returnBillDocumentConfig
                          ?.resolvedLabels?.returnTotal?.isNotEmpty ==
                      true
                  ? returnBillDocumentConfig!.resolvedLabels!.returnTotal!
                  : 'AMOUNT');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
    }

    // Create table data
    List<List<String>> tableData = [];
    for (var i = 0; i < returnItems.length; i++) {
      final returnItem = returnItems[i];
      List<String> rowData = [];

      if (displayConfig?['showReturnSLNumber']?.visible == true) {
        rowData.add('${i + 1}');
      }

      if (displayConfig?['showReturnParticulars']?.visible == true) {
        rowData.add(returnItem.productName ?? 'Unknown');
      }

      if (displayConfig?['showReturnMRP']?.visible == true) {
        // Calculate MRP based on return amount divided by quantity
        double returnAmount = double.tryParse(returnItems.fold<String>(
                '0',
                (prev, item) =>
                    (double.tryParse(prev) ?? 0.0 + (item.quantity ?? 0) * 20.0)
                        .toString())) ??
            0.0;
        double itemMrp = returnItem.quantity != null && returnItem.quantity! > 0
            ? returnAmount / returnItem.quantity!
            : 0.0;
        rowData.add(itemMrp.toStringAsFixed(2));
      }

      if (displayConfig?['showReturnQty']?.visible == true) {
        rowData.add('${returnItem.quantity ?? 0}');
      }

      if (displayConfig?['showReturnRate']?.visible == true) {
        // For now, use a default rate or calculate based on return amount
        rowData.add('-');
      }

      if (displayConfig?['showReturnTotal']?.visible == true) {
        // For now, use a default total or calculate
        rowData.add('-');
      }

      tableData.add(rowData);
    }

    return pw.Table.fromTextArray(
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
        horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
      ),
    );
  }

  // Helper method to calculate total MRP from return items
  String _calculateTotalMRP(List<OrderReturnItem> returnItems) {
    double totalMrp = 0.0;
    for (var item in returnItems) {
      // Estimate MRP as 1.2 times the return amount per item
      totalMrp += (item.quantity ?? 0) * 20.0; // Default MRP estimation
    }
    return totalMrp.toStringAsFixed(2);
  }

  // Helper method to calculate saved amount
  String _calculateSaved(
      List<OrderReturnItem> returnItems, String returnTotalAmount) {
    double totalMrp = double.tryParse(_calculateTotalMRP(returnItems)) ?? 0.0;
    double returnAmount = double.tryParse(returnTotalAmount) ?? 0.0;
    double saved = totalMrp - returnAmount;
    return saved > 0 ? saved.toStringAsFixed(2) : '0.00';
  }

  Future<void> _savePDFAndOpen(pw.Document pdf, String orderNumber) async {
    try {
      final bytes = await pdf.save();
      final dir = await _getEposDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'return_bill_${orderNumber}_$timestamp.pdf';
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(bytes);
      debugPrint('Return Bill PDF saved to: ${file.path}');

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Return Bill PDF generated successfully",
        );
      }

      // Open the PDF file
      if (!kIsWeb) {
        if (Platform.isWindows) {
          await OpenFile.open(file.path);
        } else if (Platform.isAndroid || Platform.isIOS) {
          await Share.shareXFiles([XFile(file.path)],
              text: 'Return Bill $orderNumber');
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving/opening PDF: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error saving PDF: ${e.toString()}",
        );
      }
    }
  }

  void _debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    debugPrint("===== RETURN BILL TEMPLATE SETTINGS =====");
    if (displayConfig != null) {
      displayConfig.forEach((key, value) {
        debugPrint("$key: visible=${value.visible}, value=${value.value}");
      });
    } else {
      debugPrint("Display config is null");
    }
    debugPrint("=====================================");
  }
}
