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

/// Simplified Tax Invoice PDF layout — Saudi ZATCA "Simplified Tax Invoice"
/// design matching the Abyat Al Manarah reference template.
///
/// Visual structure (top → bottom):
///   • Header band: store name (centred, one line per language) + store
///     contact lines, logo top-right, closed by a thick accent rule.
///   • Title band: store CR + extra heading 2 (left) | invoice title
///     (centre) | store VAT + FSSAI (right).
///   • Info band: customer box (left) + invoice box (middle) + QR (right).
///   • Items table with Arabic-over-English column headers.
///   • Totals: amount in words / comment / payment / balance (left) +
///     bilingual totals box (right).
///   • Signature band + accent rule.
///   • Footer band: bank details, VAT and order-number footers.
///
/// Every text comes from the shared [ReceiptLayoutParams] / [ReceiptSections]
/// helpers, so a configuration prints the same labels, values and language
/// lines here as on the thermal receipt and every other A4/A5 template. This
/// file only decides where each row is drawn (and the A4/A5 scaling).
class SimplifiedTaxInvoiceStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'simplified_tax_invoice';

  @override
  String get displayName => 'Simplified Tax Invoice';

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
        tag: '[simplified_tax_invoice_standard_pdf_layout]');
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
    final file = File('${output.path}/SimplifiedTaxInvoice_$sanitized.pdf');
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
    // Resolve providers (and the title, whose fallback reads the app
    // settings) before any await so the BuildContext is not used across
    // async gaps.
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
    // B2B/B2C title resolved by the shared helper; one line per language.
    final invoiceTitle = params.invoiceTitleText.toUpperCase();

    // ── Fonts ───────────────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    // This template is laid out left-to-right by design, so the page
    // direction is always LTR. Arabic runs carry their own RTL direction
    // through pdfText.

    double fs(double value) => (isA5 ? value * 0.78 : value);

    // ── Text styles ─────────────────────────────────────────────────
    final storeNameArStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(18), fontWeight: pw.FontWeight.bold);
    final storeNameEnStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(16), fontWeight: pw.FontWeight.bold);
    final storeDescStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(15), fontWeight: pw.FontWeight.bold);
    final storeInfoStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(11), fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: fontBold,
        fontSize: fs(12),
        fontWeight: pw.FontWeight.bold,
        decoration: pw.TextDecoration.underline);
    final crVatStyle = pw.TextStyle(
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
    final smallStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));

    // ── Logo ────────────────────────────────────────────────────────
    pw.MemoryImage? logoImage;
    if (config.showLogo == 1 &&
        config.logo != null &&
        config.logo.toString().isNotEmpty) {
      logoImage = await _fetchNetworkPdfImage(config.logo.toString());
    }

    // ── QR (ZATCA priority, payment-gateway fallback) ───────────────
    final qrData = _qrData(params, paymentGateways);
    final showQr = params.isVisible('showQRCode') && qrData.isNotEmpty;
    final qrCaption = params.qrCaption;
    final qrSize = isA5 ? 56.0 : 72.0;

    // ── Shared section data ─────────────────────────────────────────
    final documentHeader = params.documentText(config.header);
    final documentSubheader = params.documentText(config.subheader);
    final storeName = params.headerTextParts('showStoreName').joined();
    final storeDescription =
        params.headerTextParts('showDescription').joined();
    // Store sub-details, one centred line per language. Address and
    // telephone share a line, as the design has always had them.
    final storeAddress = params.storeLineParts('showStoreAddress');
    final storeTel = params.storeLineParts('showTel');
    String sameLine(List<String> parts) =>
        parts.where((part) => part.trim().isNotEmpty).join(' . ');
    final headerInfoLines = <String>[
      for (final text in [
        sameLine([storeAddress.arabic, storeTel.arabic]),
        sameLine([storeAddress.english, storeTel.english]),
        params.storeLineParts('showEmail').joined(),
        params.headerTextParts('showExtraHeading1').joined(),
      ])
        for (final line in text.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
    ];
    // Title band: the store CR / VAT slots, with extra heading 2 and FSSAI
    // printed once each beside them (never in the header as well).
    final storeCr = params.storeLineParts('showCRNumber').joined();
    final storeVat = params.storeLineParts('showVatNumber').joined();
    final extraHeading2 =
        params.headerTextParts('showExtraHeading2').joined(inline: true);
    final storeFssai =
        params.headerTextParts('showFssaiInfo').joined(inline: true);
    final customerRows = params.customerInfoRows;
    final orderRows = params.orderInfoRows;
    final commentText = params.commentText;
    final savedLabel = params.savedLabel;
    final totalsRows = params.totalsRows;
    final paymentRows = params.paymentBreakdownRows;
    final balanceRows = params.customerBalanceRows;
    final bankRows = params.bankDetailRows;
    final wordsLines = params.isVisible('showAmountInWords')
        ? params.amountInWordsLines(params.netAmountValue, currency: currency)
        : const <String>[];
    // Non-English documents print the caption right of the signature line.
    final captionRight = !params.receiptLanguageMode.isEnglish;

    // One info box. Only the label columns its rows use are reserved, so a
    // single-language document keeps its label | value look.
    pw.Widget infoBox(List<ReceiptInfoRow> rows) {
      if (rows.isEmpty) return pw.SizedBox();
      final english = rows.any((row) => row.label.english.isNotEmpty);
      final arabic = rows.any((row) => row.label.arabic.isNotEmpty);
      final labelWidth = english && arabic ? (isA5 ? 48.0 : 64.0) : 96.0;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            _infoRow(row, infoLabel, infoValue,
                englishColumn: english,
                arabicColumn: arabic,
                labelWidth: labelWidth),
        ],
      );
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
        build: (pw.Context ctx) {
          return [
            // ═══════════════════════════════════════════════════════
            // SECTION 1: HEADER — store name block + logo
            // ═══════════════════════════════════════════════════════
            pw.Stack(
              children: [
                // Store identity, centered across the full page width so the
                // name stays visually centered regardless of the logo. The
                // horizontal padding reserves room for the logo on the right.
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.symmetric(
                      horizontal: logoImage != null ? (isA5 ? 60 : 84) : 0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(
                        width: isA5 ? 260 : 360,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            // The document header, when configured, leads
                            // and the store name follows the subheader;
                            // otherwise the store name leads.
                            if (documentHeader.isNotEmpty) ...[
                              ..._textLines(documentHeader, storeNameArStyle,
                                  textAlign: pw.TextAlign.center),
                              ..._textLines(documentSubheader, storeNameEnStyle,
                                  textAlign: pw.TextAlign.center),
                              ..._textLines(storeName, storeNameEnStyle,
                                  textAlign: pw.TextAlign.center),
                            ] else ...[
                              ..._textLines(storeName, storeNameEnStyle,
                                  firstStyle: storeNameArStyle,
                                  textAlign: pw.TextAlign.center),
                              ..._textLines(documentSubheader, storeNameEnStyle,
                                  textAlign: pw.TextAlign.center),
                            ],
                            ..._textLines(storeDescription, storeDescStyle,
                                textAlign: pw.TextAlign.center),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      // Store sub-details, each with an even vertical rhythm.
                      ..._headerInfoLines(headerInfoLines, storeInfoStyle),
                    ],
                  ),
                ),
                // Logo pinned to the right edge, vertically centered against
                // the whole header block.
                if (logoImage != null)
                  pw.Positioned.fill(
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Container(
                        height: isA5 ? 64 : 86,
                        width: isA5 ? 92 : 124,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 3, color: _accent),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 2: TITLE BAND — CR + heading 2 | Title | VAT + FSSAI
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      ..._textLines(storeCr, crVatStyle,
                          textAlign: pw.TextAlign.left),
                      ..._textLines(extraHeading2, crVatStyle,
                          textAlign: pw.TextAlign.left),
                    ],
                  ),
                ),
                if (invoiceTitle.isNotEmpty)
                  pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: _textLines(invoiceTitle, titleStyle,
                        textAlign: pw.TextAlign.center),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      ..._textLines(storeVat, crVatStyle,
                          textAlign: pw.TextAlign.right),
                      ..._textLines(storeFssai, crVatStyle,
                          textAlign: pw.TextAlign.right),
                    ],
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
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 5, child: infoBox(customerRows)),
                  pw.SizedBox(width: 8),
                  pw.Expanded(flex: 5, child: infoBox(orderRows)),
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
                    child: pw.Table(
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
                            row.emphasised ? totalsValueBold : totalsValueStyle,
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
            // TERMS & CONDITIONS / THANK YOU
            // ═══════════════════════════════════════════════════════
            if (params.termsText.isNotEmpty) ...[
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _textLines(params.termsText, smallStyle),
              ),
              pw.SizedBox(height: 4),
            ],
            if (params.thankYouText.isNotEmpty)
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: _textLines(params.thankYouText, footerBold,
                      textAlign: pw.TextAlign.center),
                ),
              ),
            pw.SizedBox(height: 10),

            // ═══════════════════════════════════════════════════════
            // SECTION 6: SIGNATURES
            // ═══════════════════════════════════════════════════════
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signature(params.customerSignatureLabel, signatureStyle,
                    signatureArStyle,
                    captionRight: captionRight),
                _signature(params.salesmanSignatureLabel, signatureStyle,
                    signatureArStyle,
                    captionRight: captionRight),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 3, color: _accent),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 7: FOOTER BAND — bank details + VAT / order number
            // Store name / address / tax info / extra headings are rendered
            // in the header and title bands instead of here.
            // ═══════════════════════════════════════════════════════
            if (bankRows.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pdfText(params.bankDetailsHeading,
                      style: footerBold, textAlign: pw.TextAlign.center),
                  for (final row in bankRows)
                    _labelValueLine(row.$1, row.$2, footerStyle, footerStyle),
                ],
              ),
            if (params.vatFooterText.isNotEmpty)
              pdfText(params.vatFooterText, style: footerStyle),
            if (params.orderNumberFooterText.isNotEmpty)
              pdfText(params.orderNumberFooterText, style: footerStyle),
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

  /// One pdfText per non-empty line of [text], so a bilingual
  /// 'Arabic\nEnglish' value keeps each script in its own run on this LTR
  /// page. [firstStyle] styles the first line only.
  List<pw.Widget> _textLines(
    String text,
    pw.TextStyle style, {
    pw.TextStyle? firstStyle,
    pw.TextAlign? textAlign,
  }) {
    final lines = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    return [
      for (var i = 0; i < lines.length; i++)
        pdfText(lines[i],
            style: i == 0 ? (firstStyle ?? style) : style,
            textAlign: textAlign),
    ];
  }

  /// Renders header sub-detail lines centered with an even vertical rhythm
  /// (a small gap between each, none before the first).
  List<pw.Widget> _headerInfoLines(List<String> lines, pw.TextStyle style) {
    final widgets = <pw.Widget>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) widgets.add(pw.SizedBox(height: 2.5));
      widgets.add(
          pdfText(lines[i], style: style, textAlign: pw.TextAlign.center));
    }
    return widgets;
  }

  /// Info-box row: English label | value | Arabic label. Only the label
  /// columns the box uses are drawn ([englishColumn] / [arabicColumn]); a
  /// language with no label for this row leaves its cell empty. The value is
  /// its own LTR run so dates, numbers and names keep their own direction.
  pw.Widget _infoRow(
    ReceiptInfoRow row,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle, {
    required bool englishColumn,
    required bool arabicColumn,
    required double labelWidth,
  }) {
    final english =
        ReceiptConfigurationContract.withoutTrailingColon(row.label.english);
    final arabic =
        ReceiptConfigurationContract.withoutTrailingColon(row.label.arabic);
    // Centred between two labels, otherwise beside the single label.
    final (valueAlignment, valueTextAlign) = englishColumn && arabicColumn
        ? (pw.Alignment.topCenter, pw.TextAlign.center)
        : arabicColumn
            ? (pw.Alignment.topRight, pw.TextAlign.right)
            : (pw.Alignment.topLeft, pw.TextAlign.left);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (englishColumn) ...[
            pw.SizedBox(
              width: labelWidth,
              child: pdfText(english,
                  style: labelStyle,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  textDirection: pw.TextDirection.ltr),
            ),
            pw.SizedBox(width: 6),
          ],
          pw.Expanded(
            child: pw.Align(
              alignment: valueAlignment,
              child: pdfText(row.value,
                  style: valueStyle,
                  maxLines: 2,
                  textAlign: valueTextAlign,
                  overflow: pw.TextOverflow.clip,
                  textDirection: pw.TextDirection.ltr),
            ),
          ),
          if (arabicColumn) ...[
            pw.SizedBox(width: 6),
            pw.SizedBox(
              width: labelWidth,
              child: pdfText(arabic,
                  style: labelStyle,
                  maxLines: 2,
                  textAlign: pw.TextAlign.right,
                  overflow: pw.TextOverflow.clip,
                  textDirection: pw.TextDirection.rtl),
            ),
          ],
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
              style: arStyle, textDirection: pw.TextDirection.rtl),
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

  /// A signature caption beside its underline: `Caption: ____` on English
  /// documents; otherwise the caption (in [captionStyle]) sits on the right
  /// of the line.
  pw.Widget _signature(
      String caption, pw.TextStyle style, pw.TextStyle captionStyle,
      {required bool captionRight}) {
    const line = '____________________';
    return pw.Row(
      children: captionRight
          ? [
              pdfText(line, style: style),
              pw.SizedBox(width: 6),
              pdfText(caption, style: captionStyle),
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

    // Header cell: Arabic line on top, the typed English line below.
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

    // Name cell: one text per name line (Arabic above English). A name that
    // carries Arabic hugs the right edge of the cell, a Latin name the left.
    pw.Widget nameCell(ReceiptItemLine line) {
      final align = line.nameLines.any(pdfHasArabic)
          ? pw.TextAlign.right
          : pw.TextAlign.left;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final name in line.nameLines)
              pw.Container(
                width: double.infinity,
                child: pdfText(name,
                    style: bodyStyle,
                    softWrap: true,
                    textAlign: align,
                    textDirection: pdfTextDirectionOf(name)),
              ),
            if (line.hasWarranty && warranty.isNotEmpty)
              pw.Container(
                width: double.infinity,
                child: pdfText(warranty, style: bodyStyle, textAlign: align),
              ),
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
