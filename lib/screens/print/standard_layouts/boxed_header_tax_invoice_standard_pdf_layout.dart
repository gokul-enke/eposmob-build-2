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

/// Boxed-header tax invoice: English | logo | Arabic header band, title band,
/// customer / order info band, config-driven items table and a bank | QR |
/// totals summary row.
///
/// Every text comes from the shared [ReceiptLayoutParams] / [ReceiptSections]
/// helpers, so a configuration prints the same labels, values and language
/// lines here as on the thermal receipt and every other A4/A5 template. This
/// file only decides where each row is drawn.
class BoxedHeaderTaxInvoiceStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'boxed_header_tax_invoice';

  @override
  String get displayName => 'Boxed Header Tax Invoice';

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
      jobName: 'Tax Invoice ${params.orderNumber}',
    )) {
      return;
    }

    final sanitized = params.orderNumber.replaceAll('/', '_');
    final output = await _getEposDirectory();
    final file = File('${output.path}/BoxedHeaderTaxInvoice_$sanitized.pdf');
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

    // Resolve providers before any await so the BuildContext is not used
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
    final summaryQrSize = isA5 ? 68.0 : 100.0;
    // Room the summary / words / signature tail needs at a page bottom.
    final bottomFooterReserve = isA5 ? 190.0 : 250.0;

    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();

    double fs(double value) => (isA5 ? value * 0.78 : value);

    // ── Text styles ─────────────────────────────────────────────────
    final headerCompanyStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final englishHeaderCompanyStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9.5), fontWeight: pw.FontWeight.bold);
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

    // A configured text may hold 'Arabic\nEnglish': one Text per line so each
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
      logoImage = await PrintLogoLoader.loadPdfLogo(config.logo.toString(),
          tag: '[boxed_header_tax_invoice_standard_pdf_layout]');
    }

    // ── QR (ZATCA priority, payment-gateway fallback) ───────────────
    final qrData = _qrData(params, paymentGateways);

    // ── Shared section data ─────────────────────────────────────────
    final englishHeaderLines = params.headerColumnLines(arabic: false);
    final arabicHeaderLines = params.headerColumnLines(arabic: true);
    final extraHeading2 =
        params.headerTextParts('showExtraHeading2').joined(inline: true);
    final storeFssai =
        params.headerTextParts('showFssaiInfo').joined(inline: true);
    final customerRows = params.customerInfoRows;
    final orderRows = params.orderInfoRows;
    final bankRows = params.bankDetailRows;
    final commentText = params.commentText;
    final savedLabel = params.savedLabel;
    final totalsRows = params.totalsRows;
    final paymentRows = params.paymentBreakdownRows;
    final balanceRows = params.customerBalanceRows;
    final showQr = params.isVisible('showQRCode') && qrData.isNotEmpty;
    final wordsLines = params.isVisible('showAmountInWords')
        ? params.amountInWordsLines(params.netAmountValue, currency: currency)
        : const <String>[];
    final hasLeftSummaryContent =
        bankRows.isNotEmpty || commentText.isNotEmpty || savedLabel.isNotEmpty;

    final pdfMargins = await CommonPrintSettings.resolvePdfMargins(
      pw.EdgeInsets.all(isA5 ? 8 : 10),
    );

    List<pw.Widget> buildContent({required bool fillSinglePageItemsBox}) {
      return [
        // Document-level header / subheader (shared language rules).
        for (final text in [
          params.documentText(config.header),
          params.documentText(config.subheader)
        ])
          if (text.isNotEmpty) pw.Center(child: modeText(text, headerDetailStyle)),

        // SECTION 1: HEADER — English | centered logo | Arabic
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              flex: 4,
              child: _configuredHeaderBlock(
                englishHeaderLines,
                headingStyle: englishHeaderCompanyStyle,
                detailStyle: headerDetailStyle,
                alignment: pw.CrossAxisAlignment.start,
                textAlign: pw.TextAlign.left,
              ),
            ),
            pw.Expanded(
              flex: 2,
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
              flex: 4,
              child: _configuredHeaderBlock(
                arabicHeaderLines,
                headingStyle: headerCompanyStyle,
                detailStyle: headerDetailStyle,
                alignment: pw.CrossAxisAlignment.end,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 3, color: _accent),
        pw.SizedBox(height: 4),

        // SECTION 2: TITLE BAND — extra heading 2 | title | FSSAI
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: extraHeading2.isNotEmpty
                    ? modeText(
                        extraHeading2, bandStyle, pw.CrossAxisAlignment.start)
                    : pw.SizedBox(),
              ),
            ),
            if (params.invoiceTitleText.isNotEmpty)
              modeText(params.invoiceTitleText.toUpperCase(), titleStyle),
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: storeFssai.isNotEmpty
                    ? modeText(storeFssai, bandStyle, pw.CrossAxisAlignment.end)
                    : pw.SizedBox(),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(height: 0, thickness: 0.8),
        pw.SizedBox(height: 6),

        // SECTION 3: INFO BAND — customer | order
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

        // SECTION 4: ITEMS TABLE (config-driven columns)
        if (!params.isReturnOnly) ...[
          if (fillSinglePageItemsBox)
            pw.Expanded(
              child: pw.Container(
                width: double.infinity,
                alignment: pw.Alignment.topLeft,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.75),
                ),
                child: _buildItemsTable(
                    params, itemsHeaderEn, itemsHeaderAr, itemsBodyStyle),
              ),
            )
          else
            _buildItemsTable(
                params, itemsHeaderEn, itemsHeaderAr, itemsBodyStyle),
          pw.SizedBox(height: 6),
          // Keep the summary and footer together near the bottom of the last
          // page: start a fresh page when too little room remains.
          if (!fillSinglePageItemsBox) ...[
            pw.NewPage(freeSpace: bottomFooterReserve),
            pw.Spacer(),
          ],
        ],

        // SECTION 5: BANK DETAILS | QR CODE | TOTALS
        if (!params.isReturnOnly) ...[
          pw.Table(
            columnWidths: hasLeftSummaryContent
                ? const {
                    0: pw.FlexColumnWidth(5),
                    1: pw.FixedColumnWidth(8),
                    2: pw.FlexColumnWidth(3),
                    3: pw.FixedColumnWidth(8),
                    4: pw.FlexColumnWidth(6),
                  }
                : const {
                    0: pw.FlexColumnWidth(3),
                    1: pw.FixedColumnWidth(8),
                    2: pw.FlexColumnWidth(6),
                  },
            children: [
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.full,
                children: [
                  if (hasLeftSummaryContent) ...[
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
                              child: pdfText(params.bankDetailsHeading,
                                  style: footerBold,
                                  textAlign: pw.TextAlign.center),
                            ),
                            pw.SizedBox(height: 3),
                            for (final row in bankRows)
                              _labelValueLine(row.$1, row.$2, footerStyle,
                                  footerStyle),
                          ],
                          if (commentText.isNotEmpty) ...[
                            if (bankRows.isNotEmpty) pw.SizedBox(height: 4),
                            pdfText(commentText, style: wordsStyle),
                          ],
                          if (savedLabel.isNotEmpty)
                            _labelValueLine(
                                savedLabel,
                                _formatMoney(currency, params.savedAmountValue),
                                wordsBold,
                                wordsBold),
                        ],
                      ),
                    ),
                    pw.SizedBox(),
                  ],
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.5),
                    ),
                    padding: const pw.EdgeInsets.all(4),
                    alignment: pw.Alignment.center,
                    child: showQr
                        ? pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              if (params.qrCaption.isNotEmpty) ...[
                                pdfText(params.qrCaption,
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
                          )
                        : pw.SizedBox(),
                  ),
                  pw.SizedBox(),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.5),
                    ),
                    child: pw.Table(
                      border: const pw.TableBorder(
                        horizontalInside: pw.BorderSide(width: 0.5),
                        verticalInside: pw.BorderSide(width: 0.5),
                      ),
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
            ],
          ),
          if (paymentRows.isNotEmpty ||
              balanceRows.isNotEmpty ||
              wordsLines.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (final row in paymentRows)
                        _labelValueLine(row.$1,
                            _formatMoney(currency, row.$2), wordsStyle, wordsStyle),
                      for (final row in balanceRows)
                        _labelValueLine(
                            row.$1,
                            _formatMoney(currency, row.$2),
                            row.$3 ? wordsBold : wordsStyle,
                            row.$3 ? wordsBold : wordsStyle),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
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
            ),
          ],
          pw.SizedBox(height: 6),
        ],

        // SECTION 5b: RETURNS TABLE + FINAL SUMMARY
        ..._buildReturnsPdfSection(params, currency, font, fontBold, isA5),
        if (!params.isReturnOnly)
          ..._buildFinalSummaryPdfSection(
              params, currency, font, fontBold, isA5),

        // TERMS & CONDITIONS / THANK YOU / VAT + ORDER-NUMBER FOOTERS
        if (params.termsText.isNotEmpty) ...[
          modeText(params.termsText, smallStyle, pw.CrossAxisAlignment.start),
          pw.SizedBox(height: 4),
        ],
        if (params.thankYouText.isNotEmpty)
          pw.Center(child: modeText(params.thankYouText, footerBold)),
        if (params.vatFooterText.isNotEmpty)
          pw.Center(child: pdfText(params.vatFooterText, style: footerStyle)),
        if (params.orderNumberFooterText.isNotEmpty)
          pw.Center(
              child: pdfText(params.orderNumberFooterText, style: footerStyle)),
        pw.SizedBox(height: 10),

        // SECTION 6: SIGNATURES — one block with the closing rule, so the rule
        // never spills alone onto an otherwise empty page.
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: _accent, width: 3)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signature(params.customerSignatureLabel, signatureStyle,
                  captionRight: !params.receiptLanguageMode.isEnglish),
              _signature(params.salesmanSignatureLabel, signatureStyle,
                  captionRight: !params.receiptLanguageMode.isEnglish),
            ],
          ),
        ),
      ];
    }

    final multiPagePdf = pdf;
    multiPagePdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: pdfMargins,
        build: (ctx) => buildContent(fillSinglePageItemsBox: false),
      ),
    );

    // The MultiPage pass tells whether everything fits on one page. Only then
    // may the items table receive a full-height box: applying that during
    // pagination would interfere with row splitting on longer invoices.
    if (params.isReturnOnly ||
        multiPagePdf.document.pdfPageList.pages.length != 1) {
      return multiPagePdf;
    }

    final singlePagePdf =
        pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    singlePagePdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: pdfMargins,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.max,
          children: buildContent(fillSinglePageItemsBox: true),
        ),
      ),
    );

    return singlePagePdf;
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

  /// One side of the three-column header. The first line is the company name
  /// (one line, shrunk to fit); the rest use compact detail styling.
  pw.Widget _configuredHeaderBlock(
    List<String> lines, {
    required pw.TextStyle headingStyle,
    required pw.TextStyle detailStyle,
    required pw.CrossAxisAlignment alignment,
    required pw.TextAlign textAlign,
  }) {
    pw.Widget line(int i) => pdfText(
          i == 0 ? lines[i].replaceAll(RegExp(r'\s+'), ' ').trim() : lines[i],
          style: i == 0 ? headingStyle : detailStyle,
          textAlign: textAlign,
          maxLines: i == 0 ? 1 : 2,
          softWrap: i != 0,
        );

    return pw.Column(
      crossAxisAlignment: alignment,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          pw.Container(
            width: double.infinity,
            child: i == 0
                // Shrink an over-long heading rather than run off the page.
                ? pw.Align(
                    alignment: textAlign == pw.TextAlign.right
                        ? pw.Alignment.centerRight
                        : pw.Alignment.centerLeft,
                    child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown, child: line(i)),
                  )
                : line(i),
          ),
          if (i < lines.length - 1) pw.SizedBox(height: 2),
        ],
      ],
    );
  }

  /// One info-band column (customer or order rows). The column picks its
  /// layout once so its rows line up: English labels sit left of the value,
  /// Arabic labels right of it, and only a column whose rows carry both
  /// languages reserves a label cell on each side (English | value | Arabic).
  /// A single-language column gives the value the remaining width, so short
  /// A5 columns do not break values mid-word. Each value is its own text run
  /// so dates, numbers and names keep their own direction.
  pw.Widget _infoColumn(List<ReceiptInfoRow> rows, pw.TextStyle labelStyle,
      pw.TextStyle valueStyle,
      {required bool isA5}) {
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
              maxLines: 2,
              textAlign: arabic ? pw.TextAlign.right : pw.TextAlign.left,
              overflow: pw.TextOverflow.clip,
              textDirection:
                  arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr),
        );

    pw.Widget valueCell(String value, pw.TextAlign align) => pw.Expanded(
          child: pdfText(value,
              style: valueStyle,
              maxLines: 2,
              textAlign: align,
              overflow: pw.TextOverflow.clip,
              textDirection: pw.TextDirection.ltr),
        );

    pw.Widget row(ReceiptInfoRow row) {
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
        children = [valueCell(row.value, pw.TextAlign.center)];
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
      children: [for (final r in rows) row(r)],
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

    pw.Widget nameCell(ReceiptItemLine line) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final name in line.nameLines)
                pw.Container(
                  width: double.infinity,
                  child: pdfText(name,
                      style: bodyStyle,
                      softWrap: true,
                      textAlign: pw.TextAlign.left,
                      textDirection: pdfTextDirectionOf(name)),
                ),
              if (line.hasWarranty && warranty.isNotEmpty)
                pdfText(warranty, style: bodyStyle),
            ],
          ),
        );

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
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
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
