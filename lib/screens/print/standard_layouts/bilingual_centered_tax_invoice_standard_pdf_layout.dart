import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_bidi_text.dart';
import 'return_pdf_support_sections.dart';
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

/// Bilingual centered tax invoice — Saudi ZATCA "Simplified Tax Invoice"
/// design with a three-column letterhead.
///
/// Visual structure (top → bottom):
///   • Header band: Arabic column (left), centered logo and English column
///     (right), closed by a thick accent rule.
///   • Title band: extra heading 2 (left) | invoice title (center) | FSSAI
///     (right).
///   • Info band: customer box (left) + invoice box (right).
///   • Items table with Arabic-over-English column headers.
///   • Summary row: bank details / comment / payments / balance / saved |
///     QR code | totals box, followed by the amount in words.
///   • Returns and final summary (orders with returns).
///   • Terms, thank-you, VAT and order-number footers, the signature band and
///     a closing accent rule; page numbers in the page footer.
///
/// Every text comes from the shared [ReceiptLayoutParams] / [ReceiptSections]
/// helpers, so a configuration prints the same labels, values and language
/// lines here as on the thermal receipt and every other A4/A5 template. This
/// file only decides where each row is drawn.
class BilingualCenteredTaxInvoiceStandardPdfLayout
    implements StandardPdfLayout {
  @override
  String get layoutId => 'bilingual_centered_tax_invoice';

  @override
  String get displayName => 'Bilingual Centered Tax Invoice';

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
        tag: '[bilingual_centered_tax_invoice_standard_pdf_layout]');
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
      jobName: 'Bilingual Tax Invoice ${params.orderNumber}',
    )) {
      return;
    }

    final sanitized = params.orderNumber.replaceAll('/', '_');
    final output = await _getEposDirectory();
    final file =
        File('${output.path}/BilingualCenteredTaxInvoice_$sanitized.pdf');
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

    // ── Providers & config ──────────────────────────────────────────
    // Resolve providers up-front (before any await) to avoid using the
    // BuildContext across async gaps.
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
    // The QR column is narrower after the summary row becomes a
    // bank-details | QR | totals layout. Keep the A5 QR inside that column.
    final summaryQrSize = isA5 ? 68.0 : 100.0;

    // ── Shared section data ─────────────────────────────────────────
    // Also resolved before any await: the invoice title's fallback reads the
    // app settings through the BuildContext.
    final documentTexts = [
      params.documentText(config.header),
      params.documentText(config.subheader),
    ];
    // Registration numbers belong beside the title in this theme, so omit
    // them from both upper language columns to avoid printing them twice.
    const headerKeys = [
      'showStoreName',
      'showDescription',
      'showStoreAddress',
      'showExtraHeading1',
      'showExtraHeading2',
      'showFssaiInfo',
      'showTel',
      'showEmail',
    ];
    final arabicHeaderLines =
        params.headerColumnFields(arabic: true, keys: headerKeys);
    final englishHeaderLines =
        params.headerColumnFields(arabic: false, keys: headerKeys);
    // The first header line is the store name only when the store name
    // prints in that column's language.
    final storeNameParts = params.headerTextParts('showStoreName');
    final storeCr = params.storeLineParts('showCRNumber');
    final storeVat = params.storeLineParts('showVatNumber');
    final invoiceTitle = params.invoiceTitleText.toUpperCase();
    final customerRows = params.customerInfoRows;
    final orderRows = params.orderInfoRows;
    final bankHeading = params.bankDetailsHeading;
    final bankRows = params.bankDetailRows;
    final commentText = params.commentText;
    final paymentRows = params.paymentBreakdownRows;
    final balanceRows = params.customerBalanceRows;
    final savedLabel = params.savedLabel;
    final totalsRows = params.totalsRows;
    final qrData = _qrData(params, paymentGateways);
    final showQr = params.isVisible('showQRCode') && qrData.isNotEmpty;
    final qrCaption = params.qrCaption;
    // Summary row: only draw the left box / QR cell when they have content.
    final hasLeftSummary = bankRows.isNotEmpty ||
        commentText.isNotEmpty ||
        paymentRows.isNotEmpty ||
        balanceRows.isNotEmpty ||
        savedLabel.isNotEmpty;
    final summaryWidths = <pw.TableColumnWidth>[
      // Nothing left of the totals: an empty spacer keeps them on the right.
      if (!hasLeftSummary && !showQr) const pw.FlexColumnWidth(8),
      if (hasLeftSummary) ...const [
        pw.FlexColumnWidth(5),
        pw.FixedColumnWidth(8),
      ],
      if (showQr) ...const [
        pw.FlexColumnWidth(3),
        pw.FixedColumnWidth(8),
      ],
      const pw.FlexColumnWidth(6),
    ];
    final wordsLines = params.isVisible('showAmountInWords')
        ? params.amountInWordsLines(params.netAmountValue, currency: currency)
        : const <String>[];
    final termsText = params.termsText;
    final thankYouText = params.thankYouText;
    final vatFooterText = params.vatFooterText;
    final orderNumberFooterText = params.orderNumberFooterText;
    // English documents print `Caption: ____`; Arabic and bilingual
    // documents print the (Arabic) caption on the right of the line.
    final captionRight = !params.receiptLanguageMode.isEnglish;

    // ── Fonts ───────────────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    // This template is laid out left-to-right by design, so the page
    // direction is always LTR. Arabic runs carry their own per-widget RTL
    // direction (pdfText forces it).

    double fs(double value) => (isA5 ? value * 0.78 : value);

    // ── Text styles ─────────────────────────────────────────────────
    final headerCompanyStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(14), fontWeight: pw.FontWeight.bold);
    final englishHeaderCompanyStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(11), fontWeight: pw.FontWeight.bold);
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
    final signatureArStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(9));
    final signatureCaptionStyle =
        captionRight ? signatureArStyle : signatureStyle;
    final smallStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));

    // A configured text may hold 'Arabic\nEnglish': one run per line so each
    // language keeps its own direction on this LTR page.
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

    final pdfMargins = await CommonPrintSettings.resolvePdfMargins(
      pw.EdgeInsets.only(
        left: isA5 ? 14 : 22,
        right: isA5 ? 14 : 22,
        top: isA5 ? 12 : 18,
        bottom: isA5 ? 12 : 18,
      ),
    );

    // ══════════════════════════════════════════════════════════════════
    // BUILD PDF
    // ══════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: pdfMargins,
        footer: (ctx) => pw.Center(
          child: pdfText(params.pageNumberText(ctx.pageNumber, ctx.pagesCount),
              style: pw.TextStyle(font: font, fontSize: fs(6))),
        ),
        build: (pw.Context ctx) => [
          // Document-level header / subheader (shared documentText rule).
          for (final text in documentTexts)
            if (text.isNotEmpty)
              pw.Center(child: modeText(text, headerDetailStyle)),

          // ═══════════════════════════════════════════════════════
          // SECTION 1: HEADER — Arabic | centered logo | English
          // ═══════════════════════════════════════════════════════
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _configuredHeaderBlock(
                      arabicHeaderLines,
                      hasHeading: storeNameParts.arabic.trim().isNotEmpty,
                      headingStyle: headerCompanyStyle,
                      detailStyle: headerDetailStyle,
                      alignment: pw.CrossAxisAlignment.start,
                      textAlign: pw.TextAlign.left,
                    ),
                  ],
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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _configuredHeaderBlock(
                      englishHeaderLines,
                      hasHeading: storeNameParts.english.trim().isNotEmpty,
                      headingStyle: englishHeaderCompanyStyle,
                      detailStyle: headerDetailStyle,
                      alignment: pw.CrossAxisAlignment.end,
                      textAlign: pw.TextAlign.right,
                      singleLineHeading: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 3, color: _accent),
          pw.SizedBox(height: 4),

          // ═══════════════════════════════════════════════════════
          // SECTION 2: TITLE BAND — CR registration | title | VAT registration
          // ═══════════════════════════════════════════════════════
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: !storeCr.isEmpty
                      ? pdfReceiptParts(storeCr,
                          style: bandStyle, textAlign: pw.TextAlign.left)
                      : pw.SizedBox(),
                ),
              ),
              if (invoiceTitle.isNotEmpty) modeText(invoiceTitle, titleStyle),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: !storeVat.isEmpty
                      ? pdfReceiptParts(storeVat,
                          style: bandStyle, textAlign: pw.TextAlign.right)
                      : pw.SizedBox(),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(height: 0, thickness: 0.8),
          pw.SizedBox(height: 6),

          // ═══════════════════════════════════════════════════════
          // SECTION 3: INFO BAND — customer | invoice
          // ═══════════════════════════════════════════════════════
          if (customerRows.isNotEmpty || orderRows.isNotEmpty) ...[
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              padding: const pw.EdgeInsets.all(2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: _infoColumn(customerRows, infoLabel, infoValue,
                        isA5: isA5),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(
                            width: 0.5,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                      padding: const pw.EdgeInsets.only(left: 8),
                      child: _infoColumn(orderRows, infoLabel, infoValue,
                          isA5: isA5),
                    ),
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
          // SECTION 5: BANK DETAILS | QR CODE | TOTALS
          // ═══════════════════════════════════════════════════════
          if (!params.isReturnOnly) ...[
            pw.Table(
              columnWidths: {
                for (var i = 0; i < summaryWidths.length; i++)
                  i: summaryWidths[i],
              },
              children: [
                pw.TableRow(
                  // Relaying out a spanning Column at the exact row height
                  // can discard its last child after text wraps. Keep each
                  // summary panel at its natural height so every row prints.
                  verticalAlignment: pw.TableCellVerticalAlignment.top,
                  children: [
                    if (!hasLeftSummary && !showQr) pw.SizedBox(),
                    if (hasLeftSummary) ...[
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5),
                        ),
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (bankRows.isNotEmpty) ...[
                              pw.Center(
                                child: pdfText(bankHeading,
                                    style: footerBold,
                                    textAlign: pw.TextAlign.center),
                              ),
                              pw.SizedBox(height: 3),
                              for (final row in bankRows)
                                _labelValueLine(
                                    row.$1, row.$2, footerStyle, footerStyle),
                            ],
                            if (commentText.isNotEmpty) ...[
                              if (bankRows.isNotEmpty) pw.SizedBox(height: 4),
                              pdfReceiptLine(params.commentLine,
                                  style: wordsStyle),
                            ],
                            for (final row in paymentRows)
                              _labelValueLine(
                                  row.$1,
                                  _formatMoney(currency, row.$2),
                                  wordsStyle,
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
                                  _formatMoney(
                                      currency, params.savedAmountValue),
                                  wordsBold,
                                  wordsBold),
                          ],
                        ),
                      ),
                      pw.SizedBox(),
                    ],
                    if (showQr) ...[
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5),
                        ),
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.center,
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            if (qrCaption.isNotEmpty) ...[
                              pdfText(qrCaption,
                                  style: smallStyle,
                                  textAlign: pw.TextAlign.center),
                              pw.SizedBox(height: 2),
                            ],
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              width: summaryQrSize,
                              height: summaryQrSize,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Table(
                          border: pw.TableBorder.all(width: 0.5),
                          // A5: a wider value column so amounts stay on
                          // one line.
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2.2),
                            1: const pw.FlexColumnWidth(2.0),
                            2: pw.FlexColumnWidth(isA5 ? 2.4 : 1.8),
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
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (wordsLines.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    for (final line in wordsLines)
                      pdfText(line,
                          style: wordsBold, textAlign: pw.TextAlign.right),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 6),
          ],

          // SECTION 5b: RETURNS TABLE + FINAL SUMMARY
          ..._buildReturnsPdfSection(params, currency, font, fontBold, isA5),
          ...buildReturnPdfSupportSections(
            params: params,
            style: pw.TextStyle(font: font, fontSize: isA5 ? 7 : 9),
            headingStyle: pw.TextStyle(font: fontBold, fontSize: isA5 ? 7 : 9),
            qrData: qrData,
          ),
          if (!params.isReturnOnly)
            ..._buildFinalSummaryPdfSection(
                params, currency, font, fontBold, isA5),

          // ═══════════════════════════════════════════════════════
          // TERMS & CONDITIONS / THANK YOU / VAT + ORDER-NUMBER FOOTERS
          // ═══════════════════════════════════════════════════════
          if (termsText.isNotEmpty) ...[
            modeText(termsText, smallStyle, pw.CrossAxisAlignment.start),
            pw.SizedBox(height: 4),
          ],
          if (thankYouText.isNotEmpty)
            pw.Center(child: modeText(thankYouText, footerBold)),
          if (vatFooterText.isNotEmpty)
            pw.Center(
                child:
                    pdfReceiptLine(params.vatFooterLine, style: footerStyle)),
          if (orderNumberFooterText.isNotEmpty)
            pw.Center(
                child: pdfReceiptLine(params.orderNumberFooterLine,
                    style: footerStyle)),
          pw.SizedBox(height: 10),

          // ═══════════════════════════════════════════════════════
          // SECTION 6: SIGNATURES
          // ═══════════════════════════════════════════════════════
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signature(params.customerSignatureLabel, signatureStyle,
                  signatureCaptionStyle,
                  captionRight: captionRight),
              _signature(params.salesmanSignatureLabel, signatureStyle,
                  signatureCaptionStyle,
                  captionRight: captionRight),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 3, color: _accent),
          pw.SizedBox(height: 4),
        ],
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
      // Registered invoice QR data must use its own known transaction date.
      // A missing date cannot become an unrelated payment QR under this caption.
      return zatca;
    }
    for (final gateway in paymentGateways) {
      if (gateway.code != 'MANUAL_PAYMENT_GATEWAY') continue;
      final link = gateway.link.trim();
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

  /// Renders one side of the three-column header. When [hasHeading] is set
  /// (the store name prints in this column) the first line is the company
  /// name; every other line uses compact detail styling.
  pw.Widget _configuredHeaderBlock(
    List<ReceiptTextLine> lines, {
    required bool hasHeading,
    required pw.TextStyle headingStyle,
    required pw.TextStyle detailStyle,
    required pw.CrossAxisAlignment alignment,
    required pw.TextAlign textAlign,
    bool singleLineHeading = false,
  }) {
    bool isHeading(int i) => hasHeading && i == 0;
    pw.Widget line(int i) => pdfReceiptLine(
          isHeading(i)
              ? ReceiptTextLine.text(
                  lines[i].text.replaceAll(RegExp(r'\s+'), ' ').trim())
              : lines[i],
          style: isHeading(i) ? headingStyle : detailStyle,
          textAlign: textAlign,
          maxLines: singleLineHeading && isHeading(i) ? 1 : 2,
          softWrap: !(singleLineHeading && isHeading(i)),
        );

    return pw.Column(
      crossAxisAlignment: alignment,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          pw.Container(
            width: double.infinity,
            child: singleLineHeading && isHeading(i)
                // Shrink an over-long heading rather than run off the page.
                ? pw.Align(
                    alignment: textAlign == pw.TextAlign.right
                        ? pw.Alignment.centerRight
                        : pw.Alignment.centerLeft,
                    child: pdfScaleDown(lines[i].text, line(i)),
                  )
                : line(i),
          ),
          if (i < lines.length - 1) pw.SizedBox(height: 2),
        ],
      ],
    );
  }

  /// One info-box column (customer or order rows). The column's layout is
  /// picked once so its rows line up: English labels left of the value,
  /// Arabic labels right of it, and both slots — English | value | Arabic —
  /// only when the column's rows carry both languages. A column with one
  /// language (every English or Arabic document) gives the value the
  /// remaining width, so narrow A5 columns do not break values mid-word.
  pw.Widget _infoColumn(
    List<ReceiptInfoRow> rows,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle, {
    required bool isA5,
  }) {
    String englishOf(ReceiptInfoRow row) =>
        ReceiptConfigurationContract.withoutTrailingColon(row.label.english);
    String arabicOf(ReceiptInfoRow row) =>
        ReceiptConfigurationContract.withoutTrailingColon(row.label.arabic);
    final hasEnglish = rows.any((row) => englishOf(row).isNotEmpty);
    final hasArabic = rows.any((row) => arabicOf(row).isNotEmpty);
    final bothSides = hasEnglish && hasArabic;
    final labelWidth = isA5 ? (bothSides ? 52.0 : 64.0) : 80.0;

    pw.Widget labelCell(String text, {required bool arabic}) => pw.SizedBox(
          width: labelWidth,
          child: pdfText(text,
              style: labelStyle,
              textAlign: arabic ? pw.TextAlign.right : pw.TextAlign.left,
              textDirection:
                  arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr),
        );

    pw.Widget valueCell(String value, pw.TextAlign align) => pw.Expanded(
          child: pdfText(value,
              style: valueStyle,
              textAlign: align,
              textDirection: pw.TextDirection.ltr),
        );

    pw.Widget infoRow(ReceiptInfoRow row) {
      if (row.field != null) {
        return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
            child: pdfReceiptLine(row.field!,
                style: valueStyle, textAlign: pw.TextAlign.center));
      }
      final List<pw.Widget> children;
      if (bothSides) {
        children = [
          labelCell(englishOf(row), arabic: false),
          valueCell(row.value, pw.TextAlign.center),
          labelCell(arabicOf(row), arabic: true),
        ];
      } else if (hasArabic) {
        children = [
          valueCell(row.value, pw.TextAlign.right),
          pw.SizedBox(width: 6),
          labelCell(arabicOf(row), arabic: true),
        ];
      } else if (hasEnglish) {
        children = [
          labelCell(englishOf(row), arabic: false),
          pw.SizedBox(width: 6),
          valueCell(row.value, pw.TextAlign.left),
        ];
      } else {
        children = [
          row.field == null
              ? valueCell(row.value, pw.TextAlign.center)
              : pdfReceiptLine(row.field!,
                  style: valueStyle, textAlign: pw.TextAlign.center)
        ];
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: children,
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) infoRow(row),
      ],
    );
  }

  /// `label: value` drawn as two runs so an Arabic label never reorders the
  /// value next to it; an Arabic label sits on the right of the value. Both
  /// runs wrap within the panel so a long label cannot squeeze out the value.
  pw.Widget _labelValueLine(String label, String value, pw.TextStyle labelStyle,
      pw.TextStyle valueStyle) {
    final clean = ReceiptConfigurationContract.withoutTrailingColon(label);
    if (clean.isEmpty) return pdfText(value, style: valueStyle);
    final arabicLabel = pdfHasArabic(clean);
    final labelText = pw.Flexible(child: pdfText('$clean:', style: labelStyle));
    final valueText = pw.Flexible(
      child: pdfText(value,
          style: valueStyle, textDirection: pw.TextDirection.ltr),
    );
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: arabicLabel
          ? [valueText, pw.SizedBox(width: 4), labelText]
          : [labelText, pw.SizedBox(width: 4), valueText],
    );
  }

  /// Totals box row: English label | Arabic label | value. A language with no
  /// label leaves its cell empty.
  pw.TableRow _totalsRow(ReceiptLabelParts label, String value,
      pw.TextStyle enStyle, pw.TextStyle arStyle, pw.TextStyle valueStyle) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pdfText(label.english,
            style: enStyle, textDirection: pdfTextDirectionOf(label.english)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pdfText(label.arabic,
              style: arStyle, textDirection: pw.TextDirection.rtl),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          // Shrink a long amount rather than wrap it mid-number.
          child: pdfScaleDown(
            value,
            pdfText(value,
                style: valueStyle,
                maxLines: 1,
                textDirection: pw.TextDirection.ltr),
          ),
        ),
      ),
    ]);
  }

  /// A signature caption beside its underline: `Caption: ____` when
  /// [captionRight] is false (English documents), otherwise the caption on
  /// the right of the line.
  pw.Widget _signature(
      String caption, pw.TextStyle lineStyle, pw.TextStyle captionStyle,
      {required bool captionRight}) {
    const line = '____________________';
    return pw.Row(
      children: captionRight
          ? [
              pdfText(line, style: lineStyle),
              pw.SizedBox(width: 6),
              pdfText(caption, style: captionStyle),
            ]
          : [
              pdfText('$caption: ', style: captionStyle),
              pdfText(line, style: lineStyle),
            ],
    );
  }

  pw.Widget _buildItemsTable(
    ReceiptLayoutParams params,
    pw.TextStyle headerEn,
    pw.TextStyle headerAr,
    pw.TextStyle bodyStyle,
  ) {
    // Tables need explicit column order on Arabic pages.
    final columns = params.isRtl
        ? params.itemColumns.reversed.toList()
        : params.itemColumns;
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

    // Header cell: Arabic line on top, English line below; a language with
    // no label prints no line.
    pw.Widget header(ReceiptItemColumn column) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (column.label.arabic.isNotEmpty)
                pdfText(column.label.arabic,
                    style: headerAr,
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center),
              if (column.label.english.isNotEmpty)
                pdfText(column.label.english,
                    style: headerEn, textAlign: pw.TextAlign.center),
            ],
          ),
        );

    // Item name: one run per language line so neither script reorders the
    // other; right-aligned when the name carries Arabic. The warranty label
    // prints under the name.
    pw.Widget nameCell(ReceiptItemLine line) {
      final arabicName = line.nameLines.any(pdfHasArabic);
      final textAlign = arabicName ? pw.TextAlign.right : pw.TextAlign.left;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: arabicName
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: [
            for (final name in line.nameLines)
              pdfText(name,
                  style: bodyStyle,
                  textAlign: textAlign,
                  textDirection: pdfTextDirectionOf(name)),
            if (line.hasWarranty && warranty.isNotEmpty)
              pdfText(warranty,
                  style: bodyStyle,
                  textAlign: textAlign,
                  textDirection: pdfTextDirectionOf(warranty)),
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
    // Tables do not inherit page direction; mirror return fields on Arabic.
    final columns =
        params.isRtl ? section.columns.reversed.toList() : section.columns;
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
      // Configured bilingual captions need room even when all columns show.
      'showReturnSLNumber': 1.0,
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
      if (section.subtitle.isNotEmpty) ...[
        pdfText(section.subtitle, style: labelStyle),
        pw.SizedBox(height: 4),
      ],
      if (section.supplierRows.isNotEmpty) ...[
        pdfText(section.supplierHeading, style: sectionHeadingStyle),
        pw.SizedBox(height: 2),
        for (final row in section.supplierRows)
          _labelValueLine(row.$1, row.$2, labelStyle, valueStyle),
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
      if (columns.isNotEmpty) ...[
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            for (var i = 0; i < columns.length; i++)
              i: pw.FlexColumnWidth(flex[columns[i].key] ?? 1.0),
          },
          children: [
            pw.TableRow(repeat: true, children: [
              for (final column in columns)
                cell(column.label.joined(inline: true), headerStyle),
            ]),
            for (final line in section.lines)
              pw.TableRow(children: [
                for (final column in columns)
                  cell(
                    line[column.key] ?? '',
                    valueStyle,
                    align: column.key == 'showReturnParticulars'
                        ? (params.isRtl
                            ? pw.Alignment.centerRight
                            : pw.Alignment.centerLeft)
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
              row.$1,
              row.$2 == null ? '' : _formatMoney(currency, row.$2!),
              labelStyle,
              valueStyle),
        ),
      ...buildReturnTaxSummaryPdf(
          params: params, style: valueStyle, headingStyle: labelStyle),
      if (wordsLines.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pdfText(section.wordsHeading, style: labelStyle),
        for (final line in wordsLines) pdfText(line, style: valueStyle),
      ],
      if (section.remarksRow != null) ...[
        pw.SizedBox(height: 4),
        _labelValueLine(section.remarksRow!.$1, section.remarksRow!.$2,
            labelStyle, valueStyle),
      ],
      if (section.signatory.isNotEmpty) ...[
        pw.SizedBox(height: 20),
        pdfText('____________________', style: labelStyle),
        pdfText(section.signatory, style: labelStyle),
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
    final words = params.finalSummaryWordsLines(currency);
    if (rows.isEmpty && words.isEmpty) return const [];
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
      if (rows.isNotEmpty)
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
                  child: pdfText(row.label.joined(inline: true),
                      style: labelStyle),
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
      for (final line in words) pdfText(line, style: wordsBold),
    ];
  }
}
