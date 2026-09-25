import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_bidi_text.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/services/common_print_settings.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import '../logo_loader.dart';
import 'standard_pdf_layout.dart';

/// Centered Simplified Tax Invoice PDF layout — Saudi ZATCA "Simplified Tax
/// Invoice" design with a three-column bilingual letterhead.
///
/// Visual structure (top → bottom):
///   • Header band: Arabic header lines (left), centered logo and English
///     header lines (right), the document header / subheader, closed by a
///     thick accent rule.
///   • Title band: extra heading 2 (left) | invoice title (center) | FSSAI
///     (right).
///   • Info band: customer box (left) + invoice box (middle) + QR (right).
///   • Items table with Arabic-over-English column headers.
///   • Amount in words / comment / payment / balance / saved (left) +
///     bilingual totals box (right).
///   • Returns + final summary, terms and the thank-you message.
///   • Signature band + accent rule.
///   • Footer band: bank details, VAT and order-number footers.
///
/// Every text comes from the shared [ReceiptLayoutParams] / [ReceiptSections]
/// helpers, so a configuration prints the same labels, values and language
/// lines here as on the thermal receipt and every other A4/A5 template. This
/// file only decides where each row is drawn.
class CenteredSimplifiedTaxInvoiceStandardPdfLayout
    implements StandardPdfLayout {
  @override
  String get layoutId => 'centered_simplified_tax_invoice';

  @override
  String get displayName => 'Centered Simplified Tax Invoice';

  /// Dark teal accent used for the header/footer rules.
  static const PdfColor _accent = PdfColor.fromInt(0xFF1F6E68);

  // ── Font cache ──────────────────────────────────────────────────────
  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;

  Future<pw.Font> _loadArabicFont() async {
    if (_arabicFont != null) return _arabicFont!;
    final fontData =
        await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    _arabicFont = pw.Font.ttf(fontData);
    return _arabicFont!;
  }

  Future<pw.Font> _loadArabicFontBold() async {
    if (_arabicFontBold != null) return _arabicFontBold!;
    final fontData =
        await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
    _arabicFontBold = pw.Font.ttf(fontData);
    return _arabicFontBold!;
  }

  // ── File helpers ────────────────────────────────────────────────────
  Future<Directory> _getEposDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final epos = Directory('${dir.path}/epos');
      if (!await epos.exists()) await epos.create(recursive: true);
      return epos;
    } catch (_) {
      return await getTemporaryDirectory();
    }
  }

  Future<void> _handleWindowsPdf(File file) async {
    try {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } catch (e) {
      debugPrint('Error opening PDF on Windows: $e');
    }
  }

  Future<pw.MemoryImage?> _fetchNetworkPdfImage(String? url) async {
    return PrintLogoLoader.loadPdfLogo(url,
        tag: '[centered_simplified_tax_invoice_standard_pdf_layout]');
  }

  String _formatMoney(String currency, num amount) {
    final currencyPrefix =
        currency.trim().toUpperCase() == 'INR' ? 'Rs.' : currency.trim();
    if (currencyPrefix.isEmpty) return amount.toStringAsFixed(2);
    return '$currencyPrefix ${amount.toStringAsFixed(2)}';
  }

  // ── Public interface ────────────────────────────────────────────────
  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    final pdf = await buildPdfDocument(params);
    if (params.selectedPrinter.isDevelopment) {
      final savedFile = await DevelopmentPrinterService.savePdf(
        bytes: await pdf.save(),
        orderNumber: params.orderNumber,
        layoutId: layoutId,
      );
      if (params.context.mounted) {
        showScaffold(
          context: params.context,
          message: 'Development PDF saved to ${savedFile.path}',
        );
      }
      return;
    }

    if (await StandardPdfDirectPrintService.printDocument(
      document: pdf,
      selectedPrinter: params.selectedPrinter,
      paperSize: params.selectedPaperSize,
      jobName: 'Simplified Tax Invoice ${params.orderNumber}',
    )) {
      return;
    }

    final sanitized = params.orderNumber.replaceAll('/', '_');
    final output = await _getEposDirectory();
    final file =
        File('${output.path}/CenteredSimplifiedTaxInvoice_$sanitized.pdf');
    await file.writeAsBytes(await pdf.save());

    if (Platform.isWindows) {
      await _handleWindowsPdf(file);
    } else {
      try {
        await OpenFile.open(file.path);
      } catch (e) {
        debugPrint('Error opening PDF: $e');
      }
    }
  }

  @override
  Future<pw.Document> buildPdfDocument(ReceiptLayoutParams params) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    // ── Providers & Config ──────────────────────────────────────────
    // Resolve providers — and the shared section data, whose title fallback
    // reads a provider — before any await, so the BuildContext is not used
    // across async gaps.
    final appSettings =
        Provider.of<AppSettingsProvider>(params.context, listen: false)
            .appSettings;
    final paymentGateways =
        Provider.of<PaymentGatewaysProvider>(params.context, listen: false)
            .paymentGateways;
    final currency = appSettings?.currency ?? '';
    final config = params.billDocumentConfig;
    final isA5 = params.selectedPaperSize.toUpperCase() == 'A5';
    final pageFormat = isA5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
    final qrSize = isA5 ? 56.0 : 72.0;

    // ── QR (ZATCA priority, payment-gateway fallback) ───────────────
    final qrData = _qrData(params, paymentGateways);
    final showQr = params.isVisible('showQRCode') && qrData.isNotEmpty;

    // ── Shared section data ─────────────────────────────────────────
    final arabicHeaderLines = params.headerColumnLines(arabic: true);
    final englishHeaderLines = params.headerColumnLines(arabic: false);
    final documentLines = [
      params.documentText(config.header),
      params.documentText(config.subheader),
    ].where((text) => text.isNotEmpty).toList();
    final extraHeading2 =
        params.headerTextParts('showExtraHeading2').joined(inline: true);
    final storeFssai =
        params.headerTextParts('showFssaiInfo').joined(inline: true);
    final invoiceTitle = params.invoiceTitleText.toUpperCase();
    final customerRows = params.customerInfoRows;
    final orderRows = params.orderInfoRows;
    final qrCaption = params.qrCaption;
    final wordsLines = params.isVisible('showAmountInWords')
        ? params.amountInWordsLines(params.netAmountValue, currency: currency)
        : const <String>[];
    final commentText = params.commentText;
    final paymentRows = params.paymentBreakdownRows;
    final balanceRows = params.customerBalanceRows;
    final savedLabel = params.savedLabel;
    final totalsRows = params.totalsRows;
    final termsText = params.termsText;
    final thankYouText = params.thankYouText;
    final bankRows = params.bankDetailRows;
    final vatFooterText = params.vatFooterText;
    final orderNumberFooterText = params.orderNumberFooterText;
    // Arabic and bilingual documents print their (Arabic) signature caption
    // right of the underline.
    final captionRight = !params.receiptLanguageMode.isEnglish;

    // ── Fonts ───────────────────────────────────────────────────────
    // This template is laid out left-to-right by design, so the page
    // direction is always LTR; Arabic runs get their own RTL direction from
    // [pdfText].
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();

    double fs(double value) => (isA5 ? value * 0.78 : value);

    // ── Text styles ─────────────────────────────────────────────────
    final headerCompanyStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(14), fontWeight: pw.FontWeight.bold);
    final headerDetailStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8));
    final titleStyle = pw.TextStyle(
        font: fontBold,
        fontSize: fs(12),
        fontWeight: pw.FontWeight.bold,
        decoration: pw.TextDecoration.underline);
    final bandStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);
    final infoLabel = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final infoValue =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final itemsHeaderEn = pw.TextStyle(
        font: fontBold, fontSize: fs(8), fontWeight: pw.FontWeight.bold);
    final itemsHeaderAr =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));
    final itemsBodyStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final totalsLabelEn = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);
    final totalsLabelAr =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8));
    final totalsValueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(9));
    final totalsValueBold = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final footerStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8));
    final footerBold = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final wordsStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final wordsBold = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final signatureStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);
    final smallStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));

    // A text may hold 'Arabic\nEnglish' (or a typed line break): one Text per
    // line so each language keeps its own direction on this LTR page.
    pw.Widget modeText(String text, pw.TextStyle style,
            [pw.CrossAxisAlignment align = pw.CrossAxisAlignment.center]) =>
        pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: align,
          children: [
            for (final line in text.split('\n'))
              pdfText(line,
                  style: style,
                  textAlign: align == pw.CrossAxisAlignment.center
                      ? pw.TextAlign.center
                      : null),
          ],
        );

    // ── Logo ────────────────────────────────────────────────────────
    pw.MemoryImage? logoImage;
    if (config.showLogo == 1 &&
        config.logo != null &&
        config.logo.toString().isNotEmpty) {
      logoImage = await _fetchNetworkPdfImage(config.logo.toString());
    }

    // ══════════════════════════════════════════════════════════════════
    // BUILD PDF
    // ══════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: await CommonPrintSettings.resolvePdfMargins(
          pw.EdgeInsets.only(
            left: isA5 ? 14 : 22,
            right: isA5 ? 14 : 22,
            top: isA5 ? 12 : 18,
            bottom: isA5 ? 12 : 18,
          ),
        ),
        footer: (ctx) => pw.Center(
          child: pdfText(params.pageNumberText(ctx.pageNumber, ctx.pagesCount),
              style: pw.TextStyle(font: font, fontSize: fs(6))),
        ),
        build: (pw.Context ctx) {
          return [
            // ═══════════════════════════════════════════════════════
            // SECTION 1: HEADER — Arabic | centered logo | English
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: _configuredHeaderBlock(
                    arabicHeaderLines,
                    headingStyle: headerCompanyStyle,
                    detailStyle: headerDetailStyle,
                    alignment: pw.CrossAxisAlignment.start,
                    textAlign: pw.TextAlign.left,
                  ),
                ),
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: logoImage == null
                        ? pw.SizedBox()
                        : pw.Container(
                            height: isA5 ? 52 : 72,
                            width: isA5 ? 72 : 100,
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                  ),
                ),
                pw.Expanded(
                  child: _configuredHeaderBlock(
                    englishHeaderLines,
                    headingStyle: headerCompanyStyle,
                    detailStyle: headerDetailStyle,
                    alignment: pw.CrossAxisAlignment.end,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            // Document-level header / subheader text.
            for (final text in documentLines)
              pw.Center(child: modeText(text, headerDetailStyle)),
            pw.SizedBox(height: 6),
            pw.Container(height: 3, color: _accent),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 2: TITLE BAND — extra heading 2 | title | FSSAI
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: extraHeading2.isNotEmpty
                        ? modeText(extraHeading2, bandStyle,
                            pw.CrossAxisAlignment.start)
                        : pw.SizedBox(),
                  ),
                ),
                if (invoiceTitle.isNotEmpty) modeText(invoiceTitle, titleStyle),
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: storeFssai.isNotEmpty
                        ? modeText(
                            storeFssai, bandStyle, pw.CrossAxisAlignment.end)
                        : pw.SizedBox(),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(height: 0, thickness: 0.8),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 3: INFO BAND — customer | invoice | QR
            // ═══════════════════════════════════════════════════════
            if (customerRows.isNotEmpty || orderRows.isNotEmpty || showQr) ...[
              pw.Container(
                decoration:
                    pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          for (final row in customerRows)
                            _infoRow(row, infoLabel, infoValue),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          for (final row in orderRows)
                            _infoRow(row, infoLabel, infoValue),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    if (showQr)
                      pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          if (qrCaption.isNotEmpty) ...[
                            pw.SizedBox(
                              width: qrSize,
                              child: pdfText(qrCaption,
                                  style: smallStyle,
                                  textAlign: pw.TextAlign.center),
                            ),
                            pw.SizedBox(height: 2),
                          ],
                          pw.Container(
                            width: qrSize,
                            height: qrSize,
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
            ],

            // ═══════════════════════════════════════════════════════
            // SECTION 4: ITEMS TABLE (config-driven columns)
            // ═══════════════════════════════════════════════════════
            if (!params.isReturnOnly) ...[
              _buildItemsTable(
                  params, itemsHeaderEn, itemsHeaderAr, itemsBodyStyle),
              pw.SizedBox(height: 6),
            ],

            // ═══════════════════════════════════════════════════════
            // SECTION 5: LEFT INFO + TOTALS BOX
            // ═══════════════════════════════════════════════════════
            if (!params.isReturnOnly) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        for (final line in wordsLines)
                          pdfText(line, style: wordsBold),
                        pw.SizedBox(height: 4),
                        if (commentText.isNotEmpty)
                          pdfText(commentText, style: wordsStyle),
                        for (final row in paymentRows)
                          _labelValueLine(row.$1,
                              _formatMoney(currency, row.$2), wordsStyle,
                              wordsStyle),
                        for (final row in balanceRows)
                          _labelValueLine(
                              row.$1,
                              _formatMoney(currency, row.$2),
                              row.$3 ? wordsBold : wordsStyle,
                              row.$3 ? wordsBold : wordsStyle),
                        if (savedLabel.isNotEmpty)
                          _labelValueLine(
                              savedLabel,
                              _formatMoney(currency, params.savedAmountValue),
                              wordsBold,
                              wordsBold),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 4,
                    child: totalsRows.isEmpty
                        ? pw.SizedBox()
                        : pw.Table(
                            border: pw.TableBorder.all(width: 0.5),
                            columnWidths: const {
                              0: pw.FlexColumnWidth(2.2),
                              1: pw.FlexColumnWidth(2.0),
                              2: pw.FlexColumnWidth(1.8),
                            },
                            children: [
                              for (final row in totalsRows)
                                _totalsRow(
                                  row.label,
                                  row.text ?? _formatMoney(currency, row.amount),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  row.emphasised
                                      ? totalsValueBold
                                      : totalsValueStyle,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
            ],

            // ═══════════════════════════════════════════════════════
            // SECTION 5b: RETURNS TABLE + FINAL SUMMARY
            // ═══════════════════════════════════════════════════════
            ..._buildReturnsPdfSection(params, currency, font, fontBold, isA5),
            if (!params.isReturnOnly)
              ..._buildFinalSummaryPdfSection(
                  params, currency, font, fontBold, isA5),

            // ═══════════════════════════════════════════════════════
            // TERMS & CONDITIONS
            // ═══════════════════════════════════════════════════════
            if (termsText.isNotEmpty) ...[
              for (final line in termsText.split('\n'))
                pdfText(line, style: smallStyle),
              pw.SizedBox(height: 4),
            ],

            // ═══════════════════════════════════════════════════════
            // THANK YOU
            // ═══════════════════════════════════════════════════════
            if (thankYouText.isNotEmpty)
              pw.Center(child: modeText(thankYouText, footerBold)),
            pw.SizedBox(height: 10),

            // ═══════════════════════════════════════════════════════
            // SECTION 6: SIGNATURES
            // ═══════════════════════════════════════════════════════
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signature(params.customerSignatureLabel, signatureStyle,
                    captionRight: captionRight),
                _signature(params.salesmanSignatureLabel, signatureStyle,
                    captionRight: captionRight),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 3, color: _accent),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 7: FOOTER BAND — bank details + VAT / order number
            // Store name / address / VAT / CR / extra headings are
            // rendered in the top header band instead of here.
            // ═══════════════════════════════════════════════════════
            if (bankRows.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  modeText(params.bankDetailsHeading, footerBold),
                  for (final row in bankRows)
                    _labelValueLine(row.$1, row.$2, footerStyle, footerStyle),
                ],
              ),
            if (vatFooterText.isNotEmpty)
              pdfText(vatFooterText, style: footerStyle),
            if (orderNumberFooterText.isNotEmpty)
              pw.Center(
                  child: pdfText(orderNumberFooterText, style: footerStyle)),
          ];
        },
      ),
    );

    return pdf;
  }

  // ══════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS (drawing only — text comes from the shared helpers)
  // ══════════════════════════════════════════════════════════════════

  /// ZATCA QR when the store is registered, else the manual payment gateway.
  String _qrData(
      ReceiptLayoutParams params, List<PaymentGateway> paymentGateways) {
    if (params.hasZatcaCredentials) {
      final zatca = ZatcaQrHelper().generateQrForInvoice(
        sellerName: params.zatcaCompanyName!,
        vatNumber: params.zatcaVatNumber!,
        invoiceDate: params.orderDate,
        totalAmount: params.netAmountValue,
        vatAmount: params.totalTax,
      );
      if (zatca.isNotEmpty) return zatca;
    }
    for (final gateway in paymentGateways) {
      if (gateway.code != 'MANUAL_PAYMENT_GATEWAY') continue;
      final link = gateway.link;
      if (link.isEmpty) return '';
      if (link.contains('{formattedTotal}') || link.contains('{orderNumber}')) {
        return link
            .replaceAll('{formattedTotal}', params.formattedTotal)
            .replaceAll('{orderNumber}', params.orderNumber);
      }
      if (link.contains('@')) {
        return 'upi://pay?pa=$link&am=${params.formattedTotal}&tn=${params.orderNumber}&cu=INR';
      }
      return link;
    }
    return '';
  }

  /// Renders one side of the three-column header. The first line is treated
  /// as the company name; remaining lines use compact detail styling.
  pw.Widget _configuredHeaderBlock(
    List<String> lines, {
    required pw.TextStyle headingStyle,
    required pw.TextStyle detailStyle,
    required pw.CrossAxisAlignment alignment,
    required pw.TextAlign textAlign,
  }) {
    return pw.Column(
      crossAxisAlignment: alignment,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          pw.Container(
            width: double.infinity,
            child: pdfText(
              lines[i],
              style: i == 0 ? headingStyle : detailStyle,
              textAlign: textAlign,
              maxLines: 2,
            ),
          ),
          if (i < lines.length - 1) pw.SizedBox(height: 2),
        ],
      ],
    );
  }

  /// Customer / invoice box row: a fixed-width label cell (the Arabic line
  /// above the English line, each its own run so it keeps its direction),
  /// then the value as its own left-to-right run so dates, numbers and names
  /// are never reordered by an Arabic label. A row without a label (the
  /// invoice number) prints the value alone.
  pw.Widget _infoRow(
      ReceiptInfoRow row, pw.TextStyle labelStyle, pw.TextStyle valueStyle,
      {double labelWidth = 96}) {
    final ReceiptInfoRow(:label, :value) = row;
    final labelLines = [
      for (final part in [label.arabic, label.english])
        for (final line in ReceiptConfigurationContract.withoutTrailingColon(
                part)
            .split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
    ];
    final valueText = pdfText(value,
        style: valueStyle,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
        // Arabic values run RTL; keep every value flush left like the rest.
        textAlign: pw.TextAlign.left,
        textDirection: pw.TextDirection.ltr);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: labelLines.isEmpty
          ? valueText
          : pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: labelWidth,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (final line in labelLines)
                        pdfText(line,
                            style: labelStyle,
                            maxLines: 1,
                            softWrap: false,
                            overflow: pw.TextOverflow.clip,
                            textDirection: pdfTextDirectionOf(line)),
                    ],
                  ),
                ),
                // Keep a gap: an RTL label hugs the right edge of its box.
                pw.SizedBox(width: 6),
                pw.Expanded(child: valueText),
              ],
            ),
    );
  }

  /// `label: value` drawn as two runs so an Arabic label never reorders the
  /// value next to it.
  pw.Widget _labelValueLine(String label, String value, pw.TextStyle labelStyle,
      pw.TextStyle valueStyle) {
    final clean = ReceiptConfigurationContract.withoutTrailingColon(label);
    if (clean.isEmpty) return pdfText(value, style: valueStyle);
    final arabicLabel = pdfHasArabic(clean);
    final labelText = pdfText('$clean:', style: labelStyle);
    final valueText = pdfText(value,
        style: valueStyle, textDirection: pw.TextDirection.ltr);
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: arabicLabel
          ? [valueText, pw.SizedBox(width: 4), labelText]
          : [labelText, pw.SizedBox(width: 4), valueText],
    );
  }

  /// Totals box row: English label | Arabic label | value.
  pw.TableRow _totalsRow(ReceiptLabelParts label, String value,
      pw.TextStyle enStyle, pw.TextStyle arStyle, pw.TextStyle valueStyle) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pdfText(label.english, style: enStyle),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pdfText(label.arabic,
              style: arStyle, textDirection: pdfTextDirectionOf(label.arabic)),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pdfText(value,
              style: valueStyle, textDirection: pw.TextDirection.ltr),
        ),
      ),
    ]);
  }

  /// A signature caption beside its underline; Arabic captions sit on the
  /// right of the line.
  pw.Widget _signature(String caption, pw.TextStyle style,
      {required bool captionRight}) {
    const line = '____________________';
    return pw.Row(
      children: captionRight
          ? [
              pdfText(line, style: style),
              pw.SizedBox(width: 6),
              pdfText(caption, style: style),
            ]
          : [
              pdfText('$caption: ', style: style),
              pdfText(line, style: style),
            ],
    );
  }

  pw.Widget _buildItemsTable(
    ReceiptLayoutParams params,
    pw.TextStyle headerEn,
    pw.TextStyle headerAr,
    pw.TextStyle bodyStyle,
  ) {
    final columns = params.itemColumns;
    if (columns.isEmpty) return pw.SizedBox();
    // Column widths matching the reference proportions.
    const flex = <String, double>{
      'showSLNumber': 0.6,
      'showParticulars': 4.2,
      'showMRP': 1.1,
      'showQty': 0.9,
      'showRate': 1.3,
      'showRateExcTax': 1.2,
      'showUnit': 0.8,
      'showTaxHeader': 1.1,
      'showTotal': 1.5,
    };
    final warranty = params.warrantyLabel;

    // Header cell: Arabic line on top, English line below (reference order).
    pw.Widget header(ReceiptItemColumn column) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (column.label.arabic.isNotEmpty)
                pdfText(column.label.arabic,
                    style: headerAr,
                    textDirection: pdfTextDirectionOf(column.label.arabic),
                    textAlign: pw.TextAlign.center),
              if (column.label.english.isNotEmpty)
                pdfText(column.label.english,
                    style: headerEn, textAlign: pw.TextAlign.center),
            ],
          ),
        );

    // Item name: one run per name line so each language keeps its own
    // direction; right-aligned whenever the name carries Arabic.
    pw.Widget nameCell(ReceiptItemLine line) {
      final alignRight = line.nameLines.any(pdfHasArabic);
      final textAlign = alignRight ? pw.TextAlign.right : pw.TextAlign.left;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: alignRight
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: [
            for (final name in line.nameLines)
              pdfText(name,
                  style: bodyStyle,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  textAlign: textAlign,
                  textDirection: pdfTextDirectionOf(name)),
            if (line.hasWarranty && warranty.isNotEmpty)
              pdfText(warranty, style: bodyStyle, textAlign: textAlign),
          ],
        ),
      );
    }

    pw.Widget valueCell(String key, String text) => _dataCell(
          text,
          bodyStyle,
          align: key == 'showUnit' || key == 'showSLNumber'
              ? pw.Alignment.center
              : pw.Alignment.centerRight,
        );

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: pw.FlexColumnWidth(flex[columns[i].key] ?? 1.0),
      },
      children: [
        pw.TableRow(repeat: true, children: [
          for (final column in columns) header(column),
        ]),
        for (final line in params.itemLines)
          pw.TableRow(children: [
            for (final column in columns)
              column.key == 'showParticulars'
                  ? nameCell(line)
                  : valueCell(column.key, line.valueFor(column.key)),
          ]),
      ],
    );
  }

  /// Data cell for items table.
  pw.Widget _dataCell(String text, pw.TextStyle style,
      {pw.Alignment align = pw.Alignment.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Align(
        alignment: align,
        child: pdfText(
          text,
          style: style,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          textDirection: pw.TextDirection.ltr,
        ),
      ),
    );
  }

  // ── Returns / final summary ───────────────────────────────────────────

  List<pw.Widget> _buildReturnsPdfSection(
    ReceiptLayoutParams params,
    String currency,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
  ) {
    final section = params.returnsSection;
    if (section == null) return const [];
    double fs(double v) => isA5 ? v * 0.78 : v;

    final labelStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final valueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final headerStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8), fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final sectionHeadingStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);

    pw.Widget cell(String text, pw.TextStyle style,
            {pw.Alignment align = pw.Alignment.center}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Align(alignment: align, child: pdfText(text, style: style)),
        );

    const flex = <String, double>{
      'showReturnSLNumber': 0.6,
      'showReturnParticulars': 4.2,
      'showReturnMRP': 1.1,
      'showReturnQty': 0.9,
      'showReturnRate': 1.3,
      'showReturnTotal': 1.5,
    };

    final wordsLines = params.returnsWordsLines(currency);
    return [
      pw.SizedBox(height: 6),
      pw.Divider(height: 0, thickness: 0.8),
      pw.SizedBox(height: 4),
      if (section.heading.isNotEmpty) ...[
        pdfText(section.heading, style: titleStyle),
        pw.SizedBox(height: 4),
      ],
      if (section.creditNoteRows.isNotEmpty) ...[
        pdfText(section.creditNoteHeading, style: sectionHeadingStyle),
        pw.SizedBox(height: 2),
        for (final row in section.creditNoteRows)
          _labelValueLine(row.$1, row.$2, labelStyle, valueStyle),
        pw.SizedBox(height: 4),
      ],
      if (section.customerRows.isNotEmpty) ...[
        pdfText(section.customerHeading, style: sectionHeadingStyle),
        pw.SizedBox(height: 2),
        for (final row in section.customerRows)
          _labelValueLine(row.$1, row.$2, labelStyle, valueStyle),
        pw.SizedBox(height: 4),
      ],
      if (section.itemsHeading.isNotEmpty) ...[
        pdfText(section.itemsHeading, style: sectionHeadingStyle),
        pw.SizedBox(height: 2),
      ],
      if (section.columns.isNotEmpty) ...[
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            for (var i = 0; i < section.columns.length; i++)
              i: pw.FlexColumnWidth(flex[section.columns[i].key] ?? 1.0),
          },
          children: [
            pw.TableRow(repeat: true, children: [
              for (final column in section.columns)
                cell(column.label.joined(inline: true), headerStyle),
            ]),
            for (final line in section.lines)
              pw.TableRow(children: [
                for (final column in section.columns)
                  cell(
                    line[column.key] ?? '',
                    valueStyle,
                    align: column.key == 'showReturnParticulars'
                        ? pw.Alignment.centerLeft
                        : pw.Alignment.centerRight,
                  ),
              ]),
          ],
        ),
        pw.SizedBox(height: 4),
      ],
      if (section.countRow != null)
        _labelValueLine(
            section.countRow!.$1, section.countRow!.$2, labelStyle, labelStyle),
      for (final row in section.totalRows)
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _labelValueLine(
              row.$1, _formatMoney(currency, row.$2), labelStyle, valueStyle),
        ),
      if (wordsLines.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pdfText(section.wordsHeading, style: labelStyle),
        for (final line in wordsLines) pdfText(line, style: valueStyle),
      ],
    ];
  }

  List<pw.Widget> _buildFinalSummaryPdfSection(
    ReceiptLayoutParams params,
    String currency,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
  ) {
    final rows = params.finalSummaryRows;
    if (rows.isEmpty) return const [];
    double fs(double v) => isA5 ? v * 0.78 : v;

    final labelStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);
    final valueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(9));
    final valueBold = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final wordsBold = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);

    return [
      pw.SizedBox(height: 6),
      pw.Divider(height: 0, thickness: 0.8),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          for (final row in rows)
            pw.TableRow(children: [
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: pdfText(row.label.joined(inline: true), style: labelStyle),
              ),
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pdfText(_formatMoney(currency, row.amount),
                      style: row.emphasised ? valueBold : valueStyle,
                      textDirection: pw.TextDirection.ltr),
                ),
              ),
            ]),
        ],
      ),
      for (final line in params.finalSummaryWordsLines(currency))
        pdfText(line, style: wordsBold),
    ];
  }
}
