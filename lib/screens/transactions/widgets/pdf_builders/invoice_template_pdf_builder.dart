import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/document_configurations.dart';
import '../../../../models/invoice_details.dart';
import '../../../../providers/document_config_provider.dart';
import '../../../../helpers/number_to_words_helper.dart';

/// Builds an A4 PDF that matches the Invoice template design
/// from the Document Templates web dashboard.
///
/// Uses [DocumentConfig] (from `document-configs?type=Invoice`) for styling:
/// - accent color, column names, logo, terms, footer
///
/// Uses [InvoiceDetails] for actual invoice data:
/// - customer info, line items, totals
class InvoiceTemplatePdfBuilder {
  /// Generates the Invoice template PDF and returns the [File].
  ///
  /// Returns `null` if PDF generation fails.
  static Future<File?> generate({
    required InvoiceDetails details,
    required DocumentConfig config,
    required String currency,
    String? companyAddress,
  }) async {
    try {
      // ── Parse accent color ──────────────────────────────────────────────
      final PdfColor accentColor = _parseHexColor(
        config.accentColor ?? '#5b5cff',
      );

      // ── Resolve column labels from config ───────────────────────────────
      final String colItems =
          config.resolvedLabels?.itemName ?? config.itemName?.option ?? 'Items';
      final String colQuantity =
          config.resolvedLabels?.unitName ?? config.unitName?.option ?? 'Quantity';
      final String colPrice =
          config.resolvedLabels?.priceName ?? config.priceName?.option ?? 'Price';
      final String colTax =
          config.resolvedLabels?.taxName ?? config.taxName?.option ?? 'Tax';
      final String colAmount =
          config.resolvedLabels?.amountName ?? config.amountName?.option ?? 'Amount';

      // ── Company / header info ───────────────────────────────────────────
      final String companyName = details.company.name;
      final String documentTitle = config.header ?? 'Invoice';
      final String subheader = config.subheader ?? '';
      final String terms = config.terms ?? '';
      final String footer = config.footer ?? 'All rights reserved';

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
                companyName: companyName,
                title: documentTitle,
                subheader: subheader,
                logoWidget: logoWidget,
                invoiceNumber: details.invoiceNumber,
                config: config,
              ),
              pw.SizedBox(height: 30),

              // ── Billed To / Billed From ─────────────────────────
              _buildBillingInfo(
                details: details,
                companyAddress: companyAddress,
                companyName: companyName,
                config: config,
              ),
              pw.SizedBox(height: 25),

              // ── Invoice dates row ──────────────────────────────────
              _buildInvoiceMeta(
                details: details,
                config: config,
              ),
              pw.SizedBox(height: 30),

              // ── Items Table ─────────────────────────────────────
              _buildItemsTable(
                items: details.invoiceItems,
                accentColor: accentColor,
                currency: currency,
                colItems: colItems,
                colQuantity: colQuantity,
                colPrice: colPrice,
                colTax: colTax,
                colAmount: colAmount,
              ),
              pw.SizedBox(height: 20),

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
          '${eposDir.path}/Invoice_${details.invoiceNumber}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      debugPrint(
          '[InvoiceTemplatePdf] Generated: $filePath (${await file.length()} bytes)');
      return file;
    } catch (e) {
      debugPrint('[InvoiceTemplatePdf] Error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Renders a premium header layout
  static pw.Widget _buildHeaderRow({
    required PdfColor accentColor,
    required String companyName,
    required String title,
    required String subheader,
    required pw.Widget? logoWidget,
    required String invoiceNumber,
    required DocumentConfig config,
  }) {
    final bool showCompany = _showOption(config, 'showCompanyDetails', defaultValue: true) && _showOption(config, 'showStoreName', defaultValue: true);
    final bool showSubheader = _showOption(config, 'showSubheader', defaultValue: true);
    final bool showHeader = _showOption(config, 'showHeader', defaultValue: true);
    final bool showInvoiceNum = _showOption(config, 'showInvoiceNumber', defaultValue: true);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Column (Logo & Store info)
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoWidget != null) ...[
                logoWidget,
                pw.SizedBox(height: 8),
              ],
              if (showCompany)
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900,
                  ),
                ),
              if (showSubheader && subheader.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  subheader,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Right Column (Invoice Title & Invoice Number)
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (showHeader)
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              if (showInvoiceNum) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  '#$invoiceNumber',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Billed To:" (customer) on the left, "Billed From:" (company) on the right
  static pw.Widget _buildBillingInfo({
    required InvoiceDetails details,
    required String? companyAddress,
    required String companyName,
    required DocumentConfig config,
  }) {
    final bool showCompany = _showOption(config, 'showCompanyDetails', defaultValue: true) && _showOption(config, 'showStoreName', defaultValue: true);
    final bool showCustomer = _showOption(config, 'showCustomerDetails', defaultValue: true) && _showOption(config, 'showCustomerName', defaultValue: true);

    final customerColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Billed To:',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          details.customer.name,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (details.customer.phone.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            details.customer.phone,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
        if (details.customer.email.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            details.customer.email,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ],
    );

    final companyColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Billed From:',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
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
      ],
    );

    if (showCompany && showCustomer) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: customerColumn),
          pw.Expanded(child: companyColumn),
        ],
      );
    } else if (showCustomer) {
      return customerColumn;
    } else if (showCompany) {
      return companyColumn;
    } else {
      return pw.SizedBox();
    }
  }

  /// Invoice metadata (Invoice Date & Due Date) formatted cleanly
  static pw.Widget _buildInvoiceMeta({
    required InvoiceDetails details,
    required DocumentConfig config,
  }) {
    final bool showDate = _showOption(config, 'showDate', defaultValue: true) && _showOption(config, 'showDates', defaultValue: true);
    if (!showDate) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice Date',
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                details.invoiceDate,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Due Date',
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                details.dueDate,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Items table with custom borders (clean horizontal grid lines, no vertical ones)
  static pw.Widget _buildItemsTable({
    required List<InvoiceItem> items,
    required PdfColor accentColor,
    required String currency,
    required String colItems,
    required String colQuantity,
    required String colPrice,
    required String colTax,
    required String colAmount,
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
        0: const pw.FlexColumnWidth(3), // Items
        1: const pw.FlexColumnWidth(1.2), // Quantity
        2: const pw.FlexColumnWidth(1.5), // Price
        3: const pw.FlexColumnWidth(1.2), // Tax
        4: const pw.FlexColumnWidth(1.5), // Amount
      },
      headers: [colItems, colQuantity, colPrice, colTax, colAmount],
      data: items.map((item) {
        return [
          item.itemName,
          item.quantity.toString(),
          '$currency ${item.unitAmount}',
          '${item.tax}%',
          '$currency ${item.totalAmount}',
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
              'Total:',
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

  /// Parses a hex color string (e.g. "#5b5cff") into a [PdfColor].
  static PdfColor _parseHexColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // add alpha
      }
      final int value = int.parse(hex, radix: 16);
      return PdfColor.fromInt(value);
    } catch (_) {
      return const PdfColor.fromInt(0xFF5B5CFF); // default accent
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
