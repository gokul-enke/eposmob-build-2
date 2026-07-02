import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/document_configurations.dart';
import '../../../../models/supplier_voucher.dart';
import '../../../../helpers/date_helper.dart';
import '../../../../helpers/number_to_words_helper.dart';

/// Builds an A4 PDF that matches the Supplier Voucher template design.
///
/// Uses [DocumentConfig] (from `document-configs?type=supplier_voucher`) for styling.
/// Uses [SupplierVoucher] for actual voucher data.
class SupplierVoucherTemplatePdfBuilder {
  /// Generates the Supplier Voucher template PDF and returns the [File].
  ///
  /// Returns `null` if PDF generation fails.
  static Future<File?> generate({
    required SupplierVoucher details,
    required DocumentConfig config,
    required String currency,
    required String companyName,
    String? companyAddress,
  }) async {
    try {
      // ── Parse accent color ──────────────────────────────────────────────
      final PdfColor accentColor = _parseHexColor(
        config.accentColor ?? '#3C92F5', // Default voucher accent color is blue
      );

      // ── Header info ───────────────────────────────────────────
      final String documentTitle = config.header ?? 'Supplier Voucher';
      final String subheader = config.subheader ?? 'Payment Voucher';
      final String terms = config.terms ?? '';
      final String footer = config.footer ?? '';

      // ── Build Document Logo ─────────────────────────────────────────────
      pw.Widget? logoWidget;
      if (config.logo != null && config.logo!.isNotEmpty) {
        try {
          final response = await HttpClient().getUrl(Uri.parse(config.logo!));
          final fileResponse = await response.close();
          final bytes = await fileResponse.fold<List<int>>([], (a, b) => a..addAll(b));
          if (bytes.isNotEmpty) {
            final image = pw.MemoryImage(Uint8List.fromList(bytes));
            logoWidget = pw.Image(image, width: 80, height: 40, fit: pw.BoxFit.contain);
          }
        } catch (e) {
          // Silent catch
        }
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          build: (pw.Context context) {
            return [
              // ── Title, Logo & Header Row ──────────────────────────────────
              _buildHeaderRow(
                accentColor: accentColor,
                title: documentTitle,
                subheader: subheader,
                logoWidget: logoWidget,
                voucherNumber: details.voucherNumber,
                voucherDate: details.voucherDate,
                config: config,
              ),
              pw.SizedBox(height: 15),
              pw.Divider(color: PdfColors.grey200, height: 0.5),
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

              // ── Voucher dates/meta row ───────────────────────────────
              _buildPaymentInformation(
                details: details,
                accentColor: accentColor,
                config: config,
              ),
              pw.SizedBox(height: 35),

              // ── Items Table ───────────────────────────────────
              _buildItemsTable(
                items: details.items,
                accentColor: accentColor,
                currency: currency,
              ),
              pw.SizedBox(height: 15),

              // ── Total Row ───────────────────────────────────────
              _buildTotalRow(
                total: details.amount,
                currency: currency,
                accentColor: accentColor,
              ),
              pw.SizedBox(height: 15),

              // ── Amount in words ─────────────────────────────────
              _buildAmountInWordsRow(
                amount: double.tryParse(details.amount.toString()) ?? 0.0,
                currency: currency,
              ),
              pw.SizedBox(height: 35),

              // ── Signatures ──────────────────────────────────────
              if (_showOption(config, 'showSignatureBoxes', defaultValue: true)) ...[
                _buildSignatures(details),
                pw.SizedBox(height: 35),
              ],

              // ── Terms ───────────────────────────────────────────
              if (terms.isNotEmpty) ...[
                pw.Text(
                  'Terms & Conditions:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  terms,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
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
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: footer.isNotEmpty
                  ? pw.Text(
                      footer,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    )
                  : pw.Text(
                      'Thank you for your business!',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
            );
          },
        ),
      );

      // Save PDF to temp directory
      final output = await getTemporaryDirectory();
      final File file = File('${output.path}/SupplierVoucher_${details.voucherNumber}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      return file;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Renders a premium header layout matching the web template
  static pw.Widget _buildHeaderRow({
    required PdfColor accentColor,
    required String title,
    required String subheader,
    required pw.Widget? logoWidget,
    required String voucherNumber,
    required String voucherDate,
    required DocumentConfig config,
  }) {
    final bool showHeader = _showOption(config, 'showHeader', defaultValue: true);
    final bool showSubheader = _showOption(config, 'showSubheader', defaultValue: true);
    final bool showDate = _showOption(config, 'showDate', defaultValue: true) && _showOption(config, 'showDates', defaultValue: true);
    final bool showVoucherNum = _showOption(config, 'showReceiptNumber', defaultValue: true) || _showOption(config, 'showInvoiceNumber', defaultValue: true);

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
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              if (showSubheader && subheader.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  subheader,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Right Column (Voucher Number and Date)
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (showVoucherNum)
                pw.Text(
                  '#$voucherNumber',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              if (showDate) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Date: $voucherDate',
                  style: const pw.TextStyle(
                    fontSize: 10,
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

  /// "From:" (company) on the left, "Pay To:" (supplier) on the right
  static pw.Widget _buildBillingInfo({
    required SupplierVoucher details,
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
            fontSize: 11,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          companyName,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        if (companyAddress != null && companyAddress.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            companyAddress,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ],
    );

    final customerColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Pay To:',
          style: pw.TextStyle(
            fontSize: 11,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          details.supplier.name,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        if (details.supplier.phone.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Phone: ${details.supplier.phone}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
        if (details.supplier.email.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Email: ${details.supplier.email}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
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

  /// Payment Information full width block
  static pw.Widget _buildPaymentInformation({
    required SupplierVoucher details,
    required PdfColor accentColor,
    required DocumentConfig config,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFAFA),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Payment Information',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetaItem('Payment Method', details.paymentMethod),
              ),
              pw.Expanded(
                child: _buildMetaItem('Reference', 'N/A'), // Reference not available in model
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey500,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value.isNotEmpty ? value : 'N/A',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  /// Items table matching the mock design
  static pw.Widget _buildItemsTable({
    required List<VoucherItemData> items,
    required PdfColor accentColor,
    required String currency,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Expense Details',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: const pw.TableBorder(
            bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
            horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),   // Si#
            1: const pw.FlexColumnWidth(3),   // Items
            2: const pw.FlexColumnWidth(1.5), // Quantity
            3: const pw.FlexColumnWidth(2),   // Price
            4: const pw.FlexColumnWidth(2),   // Tax
            5: const pw.FlexColumnWidth(2),   // Amount
          },
          children: [
            // Header Row
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              children: [
                _buildTableCell('Si#', isHeader: true, align: pw.TextAlign.left),
                _buildTableCell('Items', isHeader: true, align: pw.TextAlign.left),
                _buildTableCell('Quantity', isHeader: true, align: pw.TextAlign.right),
                _buildTableCell('Price', isHeader: true, align: pw.TextAlign.right),
                _buildTableCell('Tax', isHeader: true, align: pw.TextAlign.right),
                _buildTableCell('Amount', isHeader: true, align: pw.TextAlign.right),
              ],
            ),
            // Data Rows
            ...items.asMap().entries.map((entry) {
              final int index = entry.key;
              final VoucherItemData item = entry.value;
              return pw.TableRow(
                children: [
                  _buildTableCell('${(index + 1).toString().padLeft(3, '0')}', align: pw.TextAlign.left),
                  _buildTableCell(item.itemName, align: pw.TextAlign.left),
                  _buildTableCell(item.quantity, align: pw.TextAlign.right),
                  _buildTableCell('$currency ${item.unitAmount}', align: pw.TextAlign.right),
                  _buildTableCell('$currency ${item.tax}', align: pw.TextAlign.right),
                  _buildTableCell('$currency ${item.totalAmount}', align: pw.TextAlign.right),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }
  
  static pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.black : PdfColors.grey800,
        ),
      ),
    );
  }

  /// Simple total on the right side
  static pw.Widget _buildTotalRow({
    required String total,
    required String currency,
    required PdfColor accentColor,
  }) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            'Total Amount:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            '$currency$total',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatures(SupplierVoucher details) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Signature',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey400,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 25), // Space for physical signature
          pw.Text(
            details.supplier.name, 
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Recipient',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Received by',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey400,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parses a hex color string (e.g. "#3C92F5") into a [PdfColor].
  static PdfColor _parseHexColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // add alpha
      }
      final int value = int.parse(hex, radix: 16);
      return PdfColor.fromInt(value);
    } catch (_) {
      return const PdfColor.fromInt(0xFF3C92F5); // default accent
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
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAFAFA),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Amount in words: ',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.black,
              ),
            ),
            pw.TextSpan(
              text: words,
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.black,
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
