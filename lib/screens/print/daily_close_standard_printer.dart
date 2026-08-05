import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

/// Daily Close Standard Printer
/// Generates A4/A5 PDF for Daily Sales Close Report
class DailyCloseStandardPrinter {
  final BuildContext context;

  DailyCloseStandardPrinter(this.context);

  // Cache for fonts
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  // Load font (with caching)
  Future<pw.Font> _loadRegularFont() async {
    if (_regularFont != null) return _regularFont!;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _regularFont = pw.Font.ttf(fontData);
      return _regularFont!;
    } catch (e) {
      debugPrint('Error loading font: $e');
      rethrow;
    }
  }

  Future<pw.Font> _loadBoldFont() async {
    if (_boldFont != null) return _boldFont!;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      _boldFont = pw.Font.ttf(fontData);
      return _boldFont!;
    } catch (e) {
      debugPrint('Error loading bold font: $e');
      rethrow;
    }
  }

  // Get the epos directory for saving PDFs
  Future<Directory> _getEposDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final eposDir = Directory('${documentsDir.path}/epos');
      if (!await eposDir.exists()) {
        await eposDir.create(recursive: true);
      }
      return eposDir;
    } catch (e) {
      debugPrint('Could not access Documents/epos directory, using temp: $e');
      return await getTemporaryDirectory();
    }
  }

  /// Generate and print/open Daily Close PDF
  Future<void> generateAndPrintDailyClosePDF({
    required DailySalesCloseData data,
    required String selectedPaperSize,
    required bool includeTransactions,
  }) async {
    try {
      debugPrint("===== DAILY CLOSE STANDARD PDF GENERATION =====");
      debugPrint("Paper size: $selectedPaperSize");

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Generating Daily Close PDF...",
        );
      }

      // Load fonts
      final regularFont = await _loadRegularFont();
      final boldFont = await _loadBoldFont();

      // Create PDF document
      final pdf = pw.Document();

      // Page format
      final pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;
      final isA5 = selectedPaperSize == 'A5';

      // Styles
      final headerStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 18.0 : 24.0,
        fontWeight: pw.FontWeight.bold,
      );
      final subheaderStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 12.0 : 14.0,
        fontWeight: pw.FontWeight.bold,
      );
      final bodyStyle = pw.TextStyle(
        font: regularFont,
        fontSize: isA5 ? 10.0 : 12.0,
      );
      final labelStyle = pw.TextStyle(
        font: regularFont,
        fontSize: isA5 ? 10.0 : 12.0,
        color: PdfColors.grey700,
      );
      final valueStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 10.0 : 12.0,
      );
      final sectionTitleStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 14.0 : 16.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey800,
      );

      // Add page
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(isA5 ? 20 : 40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('DAILY CLOSE REPORT', style: headerStyle),
                      if (data.store?.name != null) ...[
                        pw.SizedBox(height: 5),
                        pw.Text(data.store!.name!, style: subheaderStyle),
                      ],
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Generated on: ${DateHelper.getCurrentFormattedTimeWithAMPM()}',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: isA5 ? 8.0 : 10.0,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 20),

                // Info Section
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Opening', _formatDateTime(data.openingDate, data.openingTime), labelStyle, valueStyle),
                          _buildInfoRow('Closing', _formatDateTime(data.closingDate, data.closingTime), labelStyle, valueStyle),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Sales Executive', data.salesExecutive?.name ?? '-', labelStyle, valueStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Sales Summary Section
                pw.Text('SALES SUMMARY', style: sectionTitleStyle),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(5),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildSummaryItem('Total Orders', data.totalOrders?.toString() ?? '0', labelStyle, valueStyle),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildSummaryItem('Total Sales', data.totalSales ?? '0.00', labelStyle, valueStyle, isHighlight: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Total Returns', data.totalReturns ?? '0.00', bodyStyle),
                    _buildTableRow('Total Refunds', data.totalRefunds ?? '0.00', bodyStyle),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Payment Breakdown Section
                pw.Text('PAYMENT BREAKDOWN', style: sectionTitleStyle),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Cash Sales', data.totalCash ?? '0.00', bodyStyle),
                    _buildTableRow('Online Sales', data.totalOnline ?? '0.00', bodyStyle),
                    _buildTableRow('Credit Amount', data.totalCredit ?? '0.00', bodyStyle),
                    _buildTableRow('Credit Collected', data.totalCreditCollected ?? '0.00', bodyStyle),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Expenses Breakdown Section
                pw.Text('EXPENSES BREAKDOWN', style: sectionTitleStyle),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Cash Expenses', data.cashExpenses ?? '0.00', bodyStyle),
                    _buildTableRow('Bank Expenses', data.bankExpenses ?? '0.00', bodyStyle),
                    _buildTableRow('Total Expenses', data.totalExpenses ?? '0.00', bodyStyle),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Cash Summary Section
                if (data.cashSummary != null) ...[
                  pw.Text('CASH SUMMARY', style: sectionTitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _buildTableRow('Opening Cash In Hand', data.cashSummary?.openingCashInHand ?? '0.00', bodyStyle),
                      _buildTableRow('Cash Refunds', data.cashSummary?.cashRefunds ?? '0.00', bodyStyle),
                      _buildTableRow('Cash Drop Amount', data.cashSummary?.cashDropAmount ?? '0.00', bodyStyle),
                      _buildTableRow('Expected Closing Cash', data.cashSummary?.expectedClosingCash ?? '0.00', bodyStyle),
                      _buildTableRow('Today Cash Collection', data.cashSummary?.todayCashCollection ?? '0.00', bodyStyle),
                      _buildTableRow('Closing Cash In Hand', data.cashSummary?.closingCashInHand ?? '0.00', bodyStyle),
                      _buildTableRow('Short Cash', data.cashSummary?.shortCash ?? '0.00', bodyStyle),
                      _buildTableRow('Excess Cash', data.cashSummary?.excessCash ?? '0.00', bodyStyle),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Totals Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blueGrey200),
                    borderRadius: pw.BorderRadius.circular(5),
                    color: PdfColors.blue50,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Payment Received', style: labelStyle),
                          pw.SizedBox(height: 5),
                          pw.Text(data.totalPaymentReceived ?? '0.00', style: sectionTitleStyle),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Collected on Sale', style: labelStyle),
                          pw.SizedBox(height: 5),
                          pw.Text(data.totalAmountCollectedOnSale ?? '0.00', style: sectionTitleStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Transactions Section
                if (includeTransactions &&
                  data.transactions != null &&
                  data.transactions!.isNotEmpty) ...[
                  pw.Text('TRANSACTIONS', style: sectionTitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(30), // SL
                      1: const pw.FlexColumnWidth(2),   // Order No
                      2: const pw.FlexColumnWidth(2),   // Customer
                      3: const pw.FlexColumnWidth(1),   // Amount
                      4: const pw.FlexColumnWidth(1),   // Paid
                      5: const pw.FlexColumnWidth(1),   // Type
                      6: const pw.FlexColumnWidth(1),   // Time
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildTableHeaderCell('#', labelStyle),
                          _buildTableHeaderCell('Order No', labelStyle),
                          _buildTableHeaderCell('Customer', labelStyle),
                          _buildTableHeaderCell('Amount', labelStyle),
                          _buildTableHeaderCell('Paid', labelStyle),
                          _buildTableHeaderCell('Type', labelStyle),
                          _buildTableHeaderCell('Time', labelStyle),
                        ],
                      ),
                      // Data Rows
                      ...data.transactions!.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final tx = entry.value;
                        return pw.TableRow(
                          children: [
                            _buildTableCell(index.toString(), bodyStyle),
                            _buildTableCell(tx.orderNumber ?? '-', bodyStyle),
                            _buildTableCell(tx.customerName ?? '-', bodyStyle),
                            _buildTableCell(tx.orderAmount?.toString() ?? '0', bodyStyle),
                            _buildTableCell(tx.paidAmount?.toString() ?? '0', bodyStyle),
                            _buildTableCell(tx.paymentType ?? '-', bodyStyle),
                            _buildTableCell(tx.time ?? '-', bodyStyle),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ] else if (includeTransactions && (data.totalOrders ?? 0) > 0) ...[
                  pw.Text('TRANSACTIONS', style: sectionTitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Text('(No transaction details available)', style: bodyStyle),
                ],
              ],
            );
          },
        ),
      );

      // Save PDF
      final output = await _getEposDirectory();
      String dateStr = data.closingDate?.replaceAll('-', '') ?? 'unknown';
      final file = File('${output.path}/DailyClose_$dateStr.pdf');
      await file.writeAsBytes(await pdf.save());

      debugPrint("Daily Close PDF saved to: ${file.path}");

      // Open the PDF
      final bool isWindows = Platform.isWindows;

      if (isWindows) {
        await _handleWindowsPdf(file);
      } else {
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            await _sharePdfFallback(file);
          } else {
            if (context.mounted) {
              showScaffold(context: context, message: "PDF opened");
            }
          }
        } catch (e) {
          await _sharePdfFallback(file);
        }
      }

      debugPrint("Daily Close PDF generation complete!");
    } catch (e, stackTrace) {
      debugPrint("ERROR generating Daily Close PDF: $e");
      debugPrint("Stack trace: $stackTrace");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: $e",
        );
      }
    }
  }

  /// Generate and share Daily Close PDF
  Future<void> generateAndShareDailyClosePDF({
    required DailySalesCloseData data,
    required String selectedPaperSize,
    required bool includeTransactions,
  }) async {
    try {
      debugPrint("===== DAILY CLOSE STANDARD PDF GENERATION (SHARE) =====");
      debugPrint("Paper size: $selectedPaperSize");

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Generating Daily Close PDF...",
        );
      }

      // Load fonts
      final regularFont = await _loadRegularFont();
      final boldFont = await _loadBoldFont();

      // Create PDF document
      final pdf = pw.Document();

      // Page format
      final pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;
      final isA5 = selectedPaperSize == 'A5';

      // Styles
      final headerStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 18.0 : 24.0,
        fontWeight: pw.FontWeight.bold,
      );
      final subheaderStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 12.0 : 14.0,
        fontWeight: pw.FontWeight.bold,
      );
      final bodyStyle = pw.TextStyle(
        font: regularFont,
        fontSize: isA5 ? 10.0 : 12.0,
      );
      final labelStyle = pw.TextStyle(
        font: regularFont,
        fontSize: isA5 ? 10.0 : 12.0,
        color: PdfColors.grey700,
      );
      final valueStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 10.0 : 12.0,
      );
      final sectionTitleStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 14.0 : 16.0,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey800,
      );

      // Add page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(isA5 ? 20 : 40),
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          build: (pw.Context context) => [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('DAILY CLOSE REPORT', style: headerStyle),
                      if (data.store?.name != null) ...[
                        pw.SizedBox(height: 5),
                        pw.Text(data.store!.name!, style: subheaderStyle),
                      ],
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Generated on: ${DateHelper.getCurrentFormattedTimeWithAMPM()}',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: isA5 ? 8.0 : 10.0,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 20),

                // Info Section
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Opening', _formatDateTime(data.openingDate, data.openingTime), labelStyle, valueStyle),
                          _buildInfoRow('Closing', _formatDateTime(data.closingDate, data.closingTime), labelStyle, valueStyle),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Sales Executive', data.salesExecutive?.name ?? '-', labelStyle, valueStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Sales Summary Section
                pw.Text('SALES SUMMARY', style: sectionTitleStyle),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(5),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildSummaryItem('Total Orders', data.totalOrders?.toString() ?? '0', labelStyle, valueStyle),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildSummaryItem('Total Sales', data.totalSales ?? '0.00', labelStyle, valueStyle, isHighlight: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Total Returns', data.totalReturns ?? '0.00', bodyStyle),
                    _buildTableRow('Total Refunds', data.totalRefunds ?? '0.00', bodyStyle),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Payment Breakdown Section
                pw.Text('PAYMENT BREAKDOWN', style: sectionTitleStyle),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Cash Sales', data.totalCash ?? '0.00', bodyStyle),
                    _buildTableRow('Online Sales', data.totalOnline ?? '0.00', bodyStyle),
                    _buildTableRow('Credit Amount', data.totalCredit ?? '0.00', bodyStyle),
                    _buildTableRow('Credit Collected', data.totalCreditCollected ?? '0.00', bodyStyle),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Expenses Breakdown Section
                pw.Text('EXPENSES BREAKDOWN', style: sectionTitleStyle),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Cash Expenses', data.cashExpenses ?? '0.00', bodyStyle),
                    _buildTableRow('Bank Expenses', data.bankExpenses ?? '0.00', bodyStyle),
                    _buildTableRow('Total Expenses', data.totalExpenses ?? '0.00', bodyStyle),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Cash Summary Section
                if (data.cashSummary != null) ...[
                  pw.Text('CASH SUMMARY', style: sectionTitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _buildTableRow('Opening Cash In Hand', data.cashSummary?.openingCashInHand ?? '0.00', bodyStyle),
                      _buildTableRow('Cash Refunds', data.cashSummary?.cashRefunds ?? '0.00', bodyStyle),
                      _buildTableRow('Cash Drop Amount', data.cashSummary?.cashDropAmount ?? '0.00', bodyStyle),
                      _buildTableRow('Expected Closing Cash', data.cashSummary?.expectedClosingCash ?? '0.00', bodyStyle),
                      _buildTableRow('Today Cash Collection', data.cashSummary?.todayCashCollection ?? '0.00', bodyStyle),
                      _buildTableRow('Closing Cash In Hand', data.cashSummary?.closingCashInHand ?? '0.00', bodyStyle),
                      _buildTableRow('Short Cash', data.cashSummary?.shortCash ?? '0.00', bodyStyle),
                      _buildTableRow('Excess Cash', data.cashSummary?.excessCash ?? '0.00', bodyStyle),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Totals Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blueGrey200),
                    borderRadius: pw.BorderRadius.circular(5),
                    color: PdfColors.blue50,
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Payment Received', style: labelStyle),
                          pw.SizedBox(height: 5),
                          pw.Text(data.totalPaymentReceived ?? '0.00', style: sectionTitleStyle),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Collected on Sale', style: labelStyle),
                          pw.SizedBox(height: 5),
                          pw.Text(data.totalAmountCollectedOnSale ?? '0.00', style: sectionTitleStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Transactions Section
                if (includeTransactions &&
                  data.transactions != null &&
                  data.transactions!.isNotEmpty) ...[
                  pw.Text('TRANSACTIONS', style: sectionTitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(30), // SL
                      1: const pw.FlexColumnWidth(2),   // Order No
                      2: const pw.FlexColumnWidth(2),   // Customer
                      3: const pw.FlexColumnWidth(1),   // Amount
                      4: const pw.FlexColumnWidth(1),   // Paid
                      5: const pw.FlexColumnWidth(1),   // Type
                      6: const pw.FlexColumnWidth(1),   // Time
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildTableHeaderCell('#', labelStyle),
                          _buildTableHeaderCell('Order No', labelStyle),
                          _buildTableHeaderCell('Customer', labelStyle),
                          _buildTableHeaderCell('Amount', labelStyle),
                          _buildTableHeaderCell('Paid', labelStyle),
                          _buildTableHeaderCell('Type', labelStyle),
                          _buildTableHeaderCell('Time', labelStyle),
                        ],
                      ),
                      // Data Rows
                      ...data.transactions!.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final tx = entry.value;
                        return pw.TableRow(
                          children: [
                            _buildTableCell(index.toString(), bodyStyle),
                            _buildTableCell(tx.orderNumber ?? '-', bodyStyle),
                            _buildTableCell(tx.customerName ?? '-', bodyStyle),
                            _buildTableCell(tx.orderAmount?.toString() ?? '0', bodyStyle),
                            _buildTableCell(tx.paidAmount?.toString() ?? '0', bodyStyle),
                            _buildTableCell(tx.paymentType ?? '-', bodyStyle),
                            _buildTableCell(tx.time ?? '-', bodyStyle),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ] else if (includeTransactions && (data.totalOrders ?? 0) > 0) ...[
                  pw.Text('TRANSACTIONS', style: sectionTitleStyle),
                  pw.SizedBox(height: 10),
                  pw.Text('(No transaction details available)', style: bodyStyle),
                ],
              ],
        ),
      );

      // Save PDF
      final output = await _getEposDirectory();
      String dateStr = data.closingDate?.replaceAll('-', '') ?? 'unknown';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${output.path}/DailyClose_${dateStr}_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      debugPrint("Daily Close PDF saved to: ${file.path}");

      if (Platform.isWindows) {
        // On Windows — just open the PDF file directly
        // using open_file package (already in project)
        await OpenFile.open(file.path);

        if (context.mounted) {
          showScaffold(context: context, message: "PDF opened");
        }
      } else {
        // On Android/iOS — use share_plus
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Daily Close Report',
        );

        if (context.mounted) {
          showScaffold(context: context, message: "PDF shared");
        }
      }

      debugPrint("Daily Close PDF generation complete!");
    } catch (e, stackTrace) {
      debugPrint("ERROR generating Daily Close PDF: $e");
      debugPrint("Stack trace: $stackTrace");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: $e",
        );
      }
    }
  }

  String _formatDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null) return '-';
    
    try {
      // Parse date (yyyy-MM-dd)
      DateTime date = DateTime.parse(dateStr);
      
      // If time is provided, combine
      if (timeStr != null) {
        // timeStr is usually HH:mm:ss
        List<String> parts = timeStr.split(':');
        if (parts.length >= 2) {
          date = DateTime(
            date.year, 
            date.month, 
            date.day, 
            int.parse(parts[0]), 
            int.parse(parts[1]), 
            parts.length > 2 ? int.parse(parts[2]) : 0
          );
        }
      }
      
      return DateFormat('dd-MM-yyyy hh:mm a').format(date);
    } catch (e) {
      // Fallback
      return '$dateStr ${timeStr ?? ''}'.trim();
    }
  }

  pw.Widget _buildInfoRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text('$label:', style: labelStyle)),
          pw.Text(value, style: valueStyle),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle, {bool isHighlight = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: labelStyle),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: isHighlight ? valueStyle.copyWith(fontSize: valueStyle.fontSize! + 4, color: PdfColors.blue800) : valueStyle,
        ),
      ],
    );
  }

  pw.Widget _buildTableHeaderCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: style.copyWith(fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildTableCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: style),
    );
  }

  pw.TableRow _buildTableRow(String label, String value, pw.TextStyle style) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: style, textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  // Handle Windows PDF opening
  Future<void> _handleWindowsPdf(File file) async {
    try {
      final result = await Process.run('cmd', ['/c', 'start', '', file.path]);
      if (result.exitCode == 0) {
        if (context.mounted) {
          showScaffold(context: context, message: "PDF opened");
        }
      } else {
        if (context.mounted) {
          showScaffold(
            context: context,
            message: "PDF saved: ${file.path}",
          );
        }
      }
    } catch (e) {
      debugPrint("Error opening PDF on Windows: $e");
      if (context.mounted) {
        showScaffold(
          context: context,
          message: "PDF saved: ${file.path}",
        );
      }
    }
  }

  // Fallback to sharing PDF
  Future<void> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share PDF as fallback...");
      // Only try to share on non-Windows platforms
      if (!Platform.isWindows) {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Daily Close Report',
          text: 'Daily Sales Close Report',
        );

        if (context.mounted) {
          showScaffold(context: context, message: "PDF shared");
        }
      } else {
        if (context.mounted) {
          showScaffold(context: context, message: "PDF saved: ${file.path}");
        }
      }
    } catch (e) {
      debugPrint("Error sharing PDF: $e");
      if (context.mounted) {
        showScaffold(
          context: context,
          message: "PDF saved: ${file.path}",
        );
      }
    }
  }
}
