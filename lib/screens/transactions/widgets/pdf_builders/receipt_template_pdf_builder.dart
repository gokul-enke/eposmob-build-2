import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/document_configurations.dart';
import '../../../../models/receipt_details.dart';
import '../../../../providers/document_config_provider.dart';
import '../../../../helpers/date_helper.dart';
import '../../../../helpers/number_to_words_helper.dart';

/// Builds an A4 PDF that matches the Receipt template design
/// from the Document Templates web dashboard.
///
/// Uses [DocumentConfig] (from `document-configs?type=receipt`) for styling:
/// - accent color, logo, terms, footer
///
/// Uses [ReceiptData] for actual receipt data.
class ReceiptTemplatePdfBuilder {
  /// Generates the Receipt template PDF and returns the [File].
  ///
  /// Returns `null` if PDF generation fails.
  static Future<File?> generate({
    required dynamic details,
    required DocumentConfig config,
    required String currency,
    String? companyAddress,
  }) async {
    try {
      // ── Parse accent color ──────────────────────────────────────────────
      final PdfColor accentColor = _parseHexColor(
        config.accentColor ?? '#4F46E5', // Default receipt accent color is indigo
      );

      // ── Company / header info ───────────────────────────────────────────
      final String companyName = details.company.name;
      final String documentTitle = config.header ?? 'Receipt';
      final String subheader = config.subheader ?? 'Payment Received';
      final String terms = config.terms ?? '';
      final String footer = config.footer ?? 'Thank you for your business';

      // ── Resolve logo if showLogo is enabled ──────────────────────────────
      pw.Widget? logoWidget;
      if (config.showLogo == 1 &&
          config.logo != null &&
          config.logo.toString().trim().isNotEmpty) {
        final logoUrl = config.logo.toString().trim();
        final logoPath = await DocumentConfigProvider.getCachedLogoFilePath(logoUrl);
        if (logoPath != null && logoPath.isNotEmpty) {
          final file = File(logoPath);
          if (await file.exists()) {
            final logoBytes = await file.readAsBytes();
            final logoImage = pw.MemoryImage(logoBytes);
            logoWidget = pw.Image(
              logoImage,
              width: 80,
              height: 45,
              fit: pw.BoxFit.contain,
            );
          }
        }
      }

      // ── Build the PDF document ──────────────────────────────────────────
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          build: (pw.Context context) {
            return [
              // ── Title, Logo & Company Row ──────────────────────────────────
              _buildHeaderRow(
                accentColor: accentColor,
                title: documentTitle,
                subheader: subheader,
                logoWidget: logoWidget,
                receiptNumber: details.receiptNumber,
                receiptDate: details.createdAt,
                config: config,
              ),
              pw.SizedBox(height: 15),
              pw.Divider(color: PdfColors.grey300, height: 0.5),
              pw.SizedBox(height: 25),

              // ── Billed To / Billed From ─────────────────────────
              _buildBillingInfo(
                details: details,
                companyAddress: companyAddress,
                companyName: companyName,
                accentColor: accentColor,
                config: config,
              ),
              pw.SizedBox(height: 30),

              // ── Receipt dates/meta row ───────────────────────────────
              _buildReceiptMeta(
                details: details,
                paymentMethod: details.paymentMethod,
                reference: details.paymentReference,
                status: details.receiptStatus,
              ),
              pw.SizedBox(height: 35),

              // ── Payments Table ───────────────────────────────────
              _buildPaymentsTable(
                payments: details.receiptPayments,
                accentColor: accentColor,
                currency: currency,
                receiptDate: details.createdAt,
                details: details,
              ),
              pw.SizedBox(height: 25),

              // ── Total Row ───────────────────────────────────────
              _buildTotalRow(
                total: details.amount,
                currency: currency,
                accentColor: accentColor,
              ),
              pw.SizedBox(height: 18),

              // ── Amount in words ─────────────────────────────────
              _buildAmountInWordsRow(
                amount: double.tryParse(details.amount.toString()) ?? 0.0,
                currency: currency,
              ),
              pw.SizedBox(height: 35),

              // ── Terms ───────────────────────────────────────────
              if (terms.isNotEmpty) ...[
                pw.Text(
                  'Terms:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  terms,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            ];
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                footer,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            );
          },
        ),
      );

      // ── Save to file ────────────────────────────────────────────────────
      final dir = await getApplicationDocumentsDirectory();
      final eposDir = Directory('${dir.path}/epos');
      if (!await eposDir.exists()) {
        await eposDir.create(recursive: true);
      }

      final filePath =
          '${eposDir.path}/Receipt_${details.receiptNumber}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      debugPrint(
          '[ReceiptTemplatePdf] Generated: $filePath (${await file.length()} bytes)');
      return file;
    } catch (e) {
      debugPrint('[ReceiptTemplatePdf] Error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Renders a premium header layout matching the web template
  static pw.Widget _buildHeaderRow({
    required PdfColor accentColor,
    required String title,
    required String subheader,
    required pw.Widget? logoWidget,
    required String receiptNumber,
    required DateTime receiptDate,
    required DocumentConfig config,
  }) {
    final dateStr = DateHelper.formatDate(receiptDate);
    final bool showHeader = _showOption(config, 'showHeader', defaultValue: true);
    final bool showSubheader = _showOption(config, 'showSubheader', defaultValue: true);
    final bool showDate = _showOption(config, 'showDate', defaultValue: true) && _showOption(config, 'showDates', defaultValue: true);
    final bool showReceiptNum = _showOption(config, 'showReceiptNumber', defaultValue: true);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Column (Logo, Title, and Subtitle)
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoWidget != null) ...[
                logoWidget,
                pw.SizedBox(height: 12),
              ],
              if (showHeader)
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              if (showSubheader && subheader.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  subheader,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Right Column (Receipt Number and Date)
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (showReceiptNum)
                pw.Text(
                  '#$receiptNumber',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              if (showDate) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  dateStr,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "From:" (company) on the left, "Bill To:" (customer) on the right
  static pw.Widget _buildBillingInfo({
    required dynamic details,
    required String? companyAddress,
    required String companyName,
    required PdfColor accentColor,
    required DocumentConfig config,
  }) {
    final bool showCompany = _showOption(config, 'showCompanyDetails', defaultValue: true) && _showOption(config, 'showStoreName', defaultValue: true);
    final bool showCustomer = _showOption(config, 'showCustomerDetails', defaultValue: true) && _showOption(config, 'showCustomerName', defaultValue: true);

    final companyColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'From:',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          companyName,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (companyAddress != null && companyAddress.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            companyAddress,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
        if (details.company.webUrl.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Web: ${details.company.webUrl}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ],
    );

    final customerColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bill To:',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          details.customer.user.name,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (details.customer.user.phone.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Phone: ${details.customer.user.phone}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
        if (details.customer.user.email.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Email: ${details.customer.user.email}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ],
    );

    if (showCompany && showCustomer) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: companyColumn),
          pw.Expanded(child: customerColumn),
        ],
      );
    } else if (showCompany) {
      return companyColumn;
    } else if (showCustomer) {
      return customerColumn;
    } else {
      return pw.SizedBox();
    }
  }

  /// Receipt metadata layout structured exactly like the web templates
  static pw.Widget _buildReceiptMeta({
    required dynamic details,
    required String paymentMethod,
    required String reference,
    required String status,
  }) {
    final dateStr = DateHelper.formatDate(details.createdAt);
    return pw.Row(
      children: [
        // Left Box - Receipt Info
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMetaItem('Receipt Date', dateStr),
                pw.SizedBox(height: 8),
                _buildMetaItem('Receipt Number', details.receiptNumber),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Receipt Status',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  status.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: status.toLowerCase() == 'paid'
                        ? PdfColors.green700
                        : PdfColors.orange700,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 15),
        // Right Box - Payment Information
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Payment Information',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildMetaItem('Payment Method', paymentMethod),
                pw.SizedBox(height: 8),
                _buildMetaItem('Transaction ID', reference),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9.5,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.isNotEmpty ? value : 'N/A',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  /// Payments table with custom borders (clean horizontal grid lines, no vertical ones)
  static pw.Widget _buildPaymentsTable({
    required List<dynamic> payments,
    required PdfColor accentColor,
    required String currency,
    required DateTime receiptDate,
    required dynamic details,
  }) {
    return pw.Table.fromTextArray(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(color: accentColor),
      headerStyle: pw.TextStyle(
        fontSize: 10.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      columnWidths: {
        0: const pw.FlexColumnWidth(3), // Payment Date
        1: const pw.FlexColumnWidth(3.5), // Invoice Reference
        2: const pw.FlexColumnWidth(2), // Payment Method
        3: const pw.FlexColumnWidth(2), // Amount
      },
      headers: ['Payment Date', 'Invoice Reference', 'Method', 'Paid Amount'],
      data: payments.map((p) {
        final dateStr = DateHelper.formatDate(
          DateTime.tryParse(p.paymentDate.toString()) ?? receiptDate,
        );
        final invStr = p.invoiceId != null && p.invoiceId != 0
            ? 'INV-${p.invoiceId}'
            : 'General Payment';
            
        String method = 'N/A';
        try {
          method = p.paymentMethod.toString();
        } catch (_) {
          try {
            method = details.paymentMethod.toString();
          } catch (_) {}
        }
        
        return [
          dateStr,
          invStr,
          method,
          '$currency ${p.paidAmount}',
        ];
      }).toList(),
    );
  }

  /// Premium Total alignment on bottom right
  static pw.Widget _buildTotalRow({
    required String total,
    required String currency,
    required PdfColor accentColor,
  }) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'Total Paid:',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(width: 40),
            pw.Text(
              '$currency $total',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parses a hex color string (e.g. "#4F46E5") into a [PdfColor].
  static PdfColor _parseHexColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // add alpha
      }
      final int value = int.parse(hex, radix: 16);
      return PdfColor.fromInt(value);
    } catch (_) {
      return const PdfColor.fromInt(0xFF4F46E5); // default accent
    }
  }

  /// Builds a grey block containing the total amount spelled out in English words
  static pw.Widget _buildAmountInWordsRow({
    required double amount,
    required String currency,
  }) {
    final String words = NumberToWordsHelper.convertAmount(amount, currency);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Amount in words: ',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.TextSpan(
              text: words,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Evaluates config options settings and returns the visibility status.
  static bool _showOption(DocumentConfig config, String key, {bool defaultValue = true}) {
    if (config.displayConfiguration?.options != null) {
      final opt = config.displayConfiguration!.options![key];
      if (opt != null) {
        return opt.visible ?? defaultValue;
      }
    }
    return defaultValue;
  }
}
