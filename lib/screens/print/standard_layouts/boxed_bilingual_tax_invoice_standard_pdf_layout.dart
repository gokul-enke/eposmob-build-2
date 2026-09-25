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
import 'package:pos_machine/helpers/amount_helper.dart';
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

/// Boxed bilingual tax invoice: full-width logo band, date / invoice-number
/// metadata strip, title box, seller / buyer boxes, config-driven items table
/// and a bank-details | QR | totals summary row.
///
/// Every text comes from the shared [ReceiptLayoutParams] / [ReceiptSections]
/// helpers, so a configuration prints the same labels, values and language
/// lines here as on the thermal receipt and every other A4/A5 template. This
/// file only decides where each row is drawn.
class BoxedBilingualTaxInvoiceStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'boxed_bilingual_tax_invoice';

  @override
  String get displayName => 'Boxed Bilingual Tax Invoice';

  /// Dark teal accent used for the closing rule.
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

  /// Totals-box amount: thousands-separated with the currency after it
  /// (`1,234.00 SAR`), as this template's totals box has always printed it.
  String _totalsMoney(String currency, num amount) {
    final value = AmountHelper.formatAmount(amount);
    return currency.trim().isEmpty ? value : '$value ${currency.trim()}';
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
      jobName: 'Boxed Tax Invoice ${params.orderNumber}',
    )) {
      return;
    }

    final sanitized = params.orderNumber.replaceAll('/', '_');
    final output = await _getEposDirectory();
    final file = File('${output.path}/BoxedBilingualTaxInvoice_$sanitized.pdf');
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
    final qrSize = isA5 ? 54.0 : 76.0;

    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();

    // ── Text styles (A5 scales every size by 0.78) ──────────────────
    double fs(double value) => isA5 ? value * 0.78 : value;
    pw.TextStyle regular(double size) =>
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(size));
    pw.TextStyle bold(double size) => pw.TextStyle(
        font: fontBold, fontSize: fs(size), fontWeight: pw.FontWeight.bold);

    final captionStyle = regular(7);
    final itemsHeaderAr = regular(6.5);
    final detailStyle = regular(7.25);
    final detailBold = bold(7.25);
    final bodyStyle = regular(7.5);
    final bodyBold = bold(7.5);
    final totalsLabelBold = bold(7.75);
    final valueStyle = regular(8);
    final valueBold = bold(8);
    final infoStyle = regular(8.5);
    final infoBold = bold(8.5);
    final headingStyle = bold(9);
    final wordsItalic = detailStyle.copyWith(fontStyle: pw.FontStyle.italic);

    // ── Logo ────────────────────────────────────────────────────────
    final logoImage = config.showLogo == 1 &&
            config.logo != null &&
            config.logo.toString().isNotEmpty
        ? await PrintLogoLoader.loadPdfLogo(config.logo.toString(),
            tag: '[boxed_bilingual_tax_invoice_standard_pdf_layout]')
        : null;

    // ── QR (ZATCA priority, payment-gateway fallback) ───────────────
    final qrData = _qrData(params, paymentGateways);
    final showQr = params.isVisible('showQRCode') && qrData.isNotEmpty;
    final qrCaption = params.qrCaption;

    // ── Shared section data ─────────────────────────────────────────
    // The metadata strip shows the date and the invoice number; every other
    // order row (token, payment, delivery) prints once, under the boxes.
    final metadataRows = <ReceiptInfoRow>[
      if (params.isVisible('showDate'))
        ReceiptInfoRow('showDate', params.fieldLabelParts('showDate'),
            params.orderDateTimeText),
      if (params.isVisible('showInvoiceNumber'))
        ReceiptInfoRow('showInvoiceNumber', const ReceiptLabelParts(),
            params.invoiceNumberText),
    ];
    final orderRows = [
      for (final row in params.orderInfoRows)
        if (row.key != 'showDate' && row.key != 'showInvoiceNumber') row,
    ];
    final titleLines = _lines(params.invoiceTitleText);
    final storeName =
        params.headerTextParts('showStoreName').joined(inline: true);
    // One seller line per key: description, registration numbers, address,
    // contact details, then the extra headings.
    final sellerLines = [
      params.headerTextParts('showDescription'),
      for (final key in const [
        'showVatNumber',
        'showCRNumber',
        'showStoreAddress',
        'showTel',
        'showEmail',
      ])
        params.storeLineParts(key),
      for (final key in const [
        'showExtraHeading1',
        'showExtraHeading2',
        'showFssaiInfo',
      ])
        params.headerTextParts(key),
    ]
        .map((parts) => parts.joined(inline: true))
        .where((line) => line.isNotEmpty)
        .toList();
    final customerRows = params.customerInfoRows;
    final commentText = params.commentText;
    final bankRows = params.bankDetailRows;
    final totalsRows = params.totalsRows;
    final wordsLines = params.isVisible('showAmountInWords')
        ? params.amountInWordsLines(params.netAmountValue, currency: currency)
        : const <String>[];
    final paymentRows = params.paymentBreakdownRows;
    final balanceRows = params.customerBalanceRows;
    final savedLabel = params.savedLabel;
    final termsLines = _lines(params.termsText);
    final thankYouLines = _lines(params.thankYouText);
    final footerLines = [params.vatFooterText, params.orderNumberFooterText]
        .where((line) => line.isNotEmpty)
        .toList();
    final captionRight = !params.receiptLanguageMode.isEnglish;

    final pdfMargins = await CommonPrintSettings.resolvePdfMargins(
      pw.EdgeInsets.all(isA5 ? 8 : 10),
    );

    List<pw.Widget> buildContent() {
      final partyBoxes = <(pw.Widget, double)>[
        if (storeName.isNotEmpty || sellerLines.isNotEmpty)
          (
            _partyBox(
              params.rendererText(
                  english: 'Seller Details', arabic: 'تفاصيل البائع'),
              headingStyle,
              [
                if (storeName.isNotEmpty)
                  _partyLine(pdfText(storeName, style: bodyBold)),
                for (final line in sellerLines)
                  _partyLine(pdfText(line, style: bodyStyle)),
              ],
            ),
            1.0,
          ),
        if (customerRows.isNotEmpty)
          (
            _partyBox(
              params.rendererText(
                  english: 'Buyer Details', arabic: 'تفاصيل المشتري'),
              headingStyle,
              [
                for (final row in customerRows)
                  _partyRow(row, bodyBold, bodyStyle,
                      labelWidth: isA5 ? 74 : 104),
                if (commentText.isNotEmpty)
                  _partyLine(pdfText(commentText, style: bodyStyle)),
              ],
            ),
            1.0,
          ),
      ];

      final summaryBoxes = <(pw.Widget, double)>[
        if (bankRows.isNotEmpty)
          (
            _bankBox(params.bankDetailsHeading, bankRows, valueBold,
                detailBold, detailStyle),
            4.2,
          ),
        if (showQr)
          (
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(3),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (qrCaption.isNotEmpty) ...[
                    pdfText(qrCaption,
                        style: captionStyle, textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 2),
                  ],
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: qrSize,
                    height: qrSize,
                  ),
                ],
              ),
            ),
            1.9,
          ),
        if (totalsRows.isNotEmpty || wordsLines.isNotEmpty)
          (
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < totalsRows.length; i++) ...[
                    // A rule sets the emphasised grand total off the rows
                    // above it.
                    if (totalsRows[i].emphasised && i > 0)
                      pw.Divider(
                          height: 4, thickness: 0.6, indent: 5, endIndent: 5),
                    _totalsRow(
                      totalsRows[i].label,
                      totalsRows[i].text ??
                          _totalsMoney(currency, totalsRows[i].amount),
                      totalsRows[i].emphasised ? totalsLabelBold : detailStyle,
                      detailStyle,
                      totalsRows[i].emphasised ? valueBold : bodyStyle,
                    ),
                  ],
                  if (wordsLines.isNotEmpty) ...[
                    if (totalsRows.isNotEmpty)
                      pw.Divider(
                          height: 4, thickness: 0.4, indent: 5, endIndent: 5),
                    pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(5, 1, 5, 0),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          for (final line in wordsLines)
                            pdfText(line, style: wordsItalic),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            5.1,
          ),
      ];

      return [
        // Full-width logo band — only when the document shows a logo, so a
        // logo-less invoice does not start with an empty band.
        if (logoImage != null)
          pw.Container(
            height: isA5 ? 58 : 90,
            width: double.infinity,
            alignment: pw.Alignment.center,
            child: pw.Container(
              width: double.infinity,
              height: isA5 ? 52 : 82,
              alignment: pw.Alignment.center,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ),

        // Metadata strip: invoice date | invoice number.
        if (metadataRows.isNotEmpty)
          _metadataStrip(metadataRows, valueBold, captionStyle, valueStyle),

        // Title box: one centred line per language.
        if (titleLines.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
            child: pw.Column(
              children: [
                for (final line in titleLines)
                  pdfText(line,
                      style: headingStyle, textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 10),

        // Seller / buyer boxes, then the remaining order rows.
        if (partyBoxes.isNotEmpty) _boxRow(partyBoxes),
        for (final row in orderRows) _infoRow(row, infoBold, infoStyle),
        // Without a buyer box the order comment still prints, once.
        if (customerRows.isEmpty && commentText.isNotEmpty)
          pdfText(commentText, style: infoStyle),
        pw.SizedBox(height: 5),

        // Items table and the bank | QR | totals summary (sales only).
        if (!params.isReturnOnly) ...[
          _buildItemsTable(params, bodyBold, itemsHeaderAr, bodyStyle),
          pw.SizedBox(height: 5),
          if (summaryBoxes.isNotEmpty) _boxRow(summaryBoxes),
          if (paymentRows.isNotEmpty ||
              balanceRows.isNotEmpty ||
              savedLabel.isNotEmpty)
            pw.SizedBox(height: 4),
          for (final row in paymentRows)
            _labelValueLine(row.$1, _formatMoney(currency, row.$2), infoStyle,
                infoStyle),
          for (final row in balanceRows)
            _labelValueLine(row.$1, _formatMoney(currency, row.$2),
                row.$3 ? infoBold : infoStyle, row.$3 ? infoBold : infoStyle),
          if (savedLabel.isNotEmpty)
            _labelValueLine(savedLabel,
                _formatMoney(currency, params.savedAmountValue), infoBold,
                infoBold),
        ],

        // Returns table and final summary.
        ..._buildReturnsPdfSection(params, currency, font, fontBold, isA5),
        if (!params.isReturnOnly)
          ..._buildFinalSummaryPdfSection(
              params, currency, font, fontBold, isA5),
        pw.SizedBox(height: 4),

        // Terms, thank-you message, VAT and order-number footers.
        if (termsLines.isNotEmpty) ...[
          pw.Wrap(
            spacing: 4,
            runSpacing: 1,
            children: [
              for (final line in termsLines)
                pdfText(line, style: captionStyle),
            ],
          ),
          pw.SizedBox(height: 2),
        ],
        if (thankYouLines.isNotEmpty)
          pw.Center(
            child: pw.Wrap(
              alignment: pw.WrapAlignment.center,
              spacing: 4,
              runSpacing: 1,
              children: [
                for (final line in thankYouLines)
                  pdfText(line,
                      style: bodyBold, textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        for (final line in footerLines)
          pw.Center(
            child: pdfText(line,
                style: valueStyle, textAlign: pw.TextAlign.center),
          ),
        pw.SizedBox(height: 5),

        // Signatures and the closing accent rule.
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signature(params.customerSignatureLabel, valueBold,
                captionRight: captionRight, captionStyle: valueStyle),
            _signature(params.salesmanSignatureLabel, valueBold,
                captionRight: captionRight, captionStyle: valueStyle),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 2, color: _accent),
        pw.SizedBox(height: 2),
      ];
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: pdfMargins,
        build: (ctx) => buildContent(),
      ),
    );

    return pdf;
  }

  // ══════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS (drawing only — text comes from the shared helpers)
  // ══════════════════════════════════════════════════════════════════

  /// The non-blank lines of a shared text. A bilingual text arrives as
  /// 'Arabic\nEnglish'; each line is drawn as its own run so the two scripts
  /// keep their own direction.
  static List<String> _lines(String text) => [
        for (final line in text.split('\n'))
          if (line.trim().isNotEmpty) line,
      ];

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

  /// Boxes side by side in one table row, each as tall as the tallest, with a
  /// 10pt gap between neighbours.
  pw.Widget _boxRow(List<(pw.Widget, double)> boxes) {
    final widths = <int, pw.TableColumnWidth>{};
    final cells = <pw.Widget>[];
    for (final (box, flex) in boxes) {
      if (cells.isNotEmpty) {
        widths[cells.length] = const pw.FixedColumnWidth(10);
        cells.add(pw.SizedBox());
      }
      widths[cells.length] = pw.FlexColumnWidth(flex);
      cells.add(box);
    }
    return pw.Table(
      columnWidths: widths,
      children: [
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: cells,
        ),
      ],
    );
  }

  /// Metadata strip: one bordered row of label | value cells, the Arabic label
  /// line above the English one. An entry without a label (the invoice number)
  /// also takes the label's width, centred.
  pw.Widget _metadataStrip(List<ReceiptInfoRow> rows, pw.TextStyle englishStyle,
      pw.TextStyle arabicStyle, pw.TextStyle valueStyle) {
    final widths = <int, pw.TableColumnWidth>{};
    final cells = <pw.Widget>[];
    for (final row in rows) {
      final english =
          ReceiptConfigurationContract.withoutTrailingColon(row.label.english);
      final arabic =
          ReceiptConfigurationContract.withoutTrailingColon(row.label.arabic);
      final hasLabel = english.isNotEmpty || arabic.isNotEmpty;
      if (hasLabel) {
        widths[cells.length] = const pw.FlexColumnWidth(1.5);
        cells.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (arabic.isNotEmpty)
                pdfText(arabic,
                    style: arabicStyle,
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.right),
              if (english.isNotEmpty)
                pdfText(english,
                    style: englishStyle, textAlign: pw.TextAlign.right),
            ],
          ),
        ));
      }
      widths[cells.length] = pw.FlexColumnWidth(hasLabel ? 1.1 : 2.6);
      cells.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pdfText(row.value,
            style: valueStyle,
            textAlign: hasLabel ? pw.TextAlign.left : pw.TextAlign.center,
            textDirection: pw.TextDirection.ltr),
      ));
    }
    return pw.Table(
      border: pw.TableBorder.all(width: 0.75),
      columnWidths: widths,
      children: [
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: cells,
        ),
      ],
    );
  }

  /// Seller / buyer box: a centred heading band over its ruled lines.
  pw.Widget _partyBox(
      String heading, pw.TextStyle headingStyle, List<pw.Widget> lines) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 0.75)),
            ),
            child: pdfText(heading,
                style: headingStyle, textAlign: pw.TextAlign.center),
          ),
          ...lines,
        ],
      ),
    );
  }

  /// One ruled line of a seller / buyer box.
  pw.Widget _partyLine(pw.Widget child) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 0.75),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 0.25, color: PdfColors.grey400),
          ),
        ),
        child: child,
      );

  /// Buyer-box line: the English and Arabic labels in a fixed-width cell, then
  /// the value as its own run so names and numbers keep their direction.
  pw.Widget _partyRow(
      ReceiptInfoRow row, pw.TextStyle labelStyle, pw.TextStyle valueStyle,
      {required double labelWidth}) {
    final english =
        ReceiptConfigurationContract.withoutTrailingColon(row.label.english);
    final arabic =
        ReceiptConfigurationContract.withoutTrailingColon(row.label.arabic);
    final value = pdfText(row.value,
        style: valueStyle, textDirection: pw.TextDirection.ltr);
    if (english.isEmpty && arabic.isEmpty) return _partyLine(value);
    return _partyLine(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Wrap(
              children: [
                if (english.isNotEmpty) pdfText(english, style: labelStyle),
                if (english.isNotEmpty && arabic.isNotEmpty)
                  pw.SizedBox(width: 3),
                if (arabic.isNotEmpty)
                  pdfText(arabic,
                      style: valueStyle, textDirection: pw.TextDirection.rtl),
              ],
            ),
          ),
          pdfText(': ', style: valueStyle),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [value],
            ),
          ),
        ],
      ),
    );
  }

  /// Order row: English label | value | Arabic label. A language with no
  /// label (e.g. English on a bilingual document with no typed default)
  /// leaves its cell empty; the value is its own text run so dates, numbers
  /// and names keep their own direction.
  pw.Widget _infoRow(
      ReceiptInfoRow row, pw.TextStyle labelStyle, pw.TextStyle valueStyle,
      {double labelWidth = 80}) {
    final english =
        ReceiptConfigurationContract.withoutTrailingColon(row.label.english);
    final arabic =
        ReceiptConfigurationContract.withoutTrailingColon(row.label.arabic);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pdfText(english,
                style: labelStyle,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textDirection: pw.TextDirection.ltr),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.center,
              child: pdfText(row.value,
                  style: valueStyle,
                  maxLines: 2,
                  textAlign: pw.TextAlign.center,
                  overflow: pw.TextOverflow.clip,
                  textDirection: pw.TextDirection.ltr),
            ),
          ),
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
      ),
    );
  }

  /// `label: value` drawn as two runs so an Arabic label never reorders the
  /// value next to it; an Arabic label sits right of its value. A long value
  /// wraps instead of running past the edge.
  pw.Widget _labelValueLine(String label, String value, pw.TextStyle labelStyle,
      pw.TextStyle valueStyle) {
    final clean = ReceiptConfigurationContract.withoutTrailingColon(label);
    if (clean.isEmpty) return pdfText(value, style: valueStyle);
    final labelText = pdfText('$clean:', style: labelStyle);
    final valueText = pw.Flexible(
      child: pdfText(value,
          style: valueStyle, textDirection: pw.TextDirection.ltr),
    );
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: pdfHasArabic(clean)
          ? [valueText, pw.SizedBox(width: 4), labelText]
          : [labelText, pw.SizedBox(width: 4), valueText],
    );
  }

  /// Bank block: the configured heading over one `label: value` line per
  /// enabled bank field.
  pw.Widget _bankBox(
      String heading,
      List<(String, String)> rows,
      pw.TextStyle headingStyle,
      pw.TextStyle labelStyle,
      pw.TextStyle valueStyle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pdfText(heading,
                style: headingStyle, textAlign: pw.TextAlign.center),
          ),
          pw.Divider(height: 3, thickness: 0.4),
          for (final row in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: _labelValueLine(row.$1, row.$2, labelStyle, valueStyle),
            ),
        ],
      ),
    );
  }

  /// Totals-box row: English label, Arabic label, then the value flush right.
  pw.Widget _totalsRow(ReceiptLabelParts label, String value,
      pw.TextStyle enStyle, pw.TextStyle arStyle, pw.TextStyle valueStyle) {
    final english =
        ReceiptConfigurationContract.withoutTrailingColon(label.english);
    final arabic =
        ReceiptConfigurationContract.withoutTrailingColon(label.arabic);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 0.75),
      child: pw.Row(
        children: [
          if (english.isNotEmpty) pdfText(english, style: enStyle),
          if (english.isNotEmpty && arabic.isNotEmpty) pw.SizedBox(width: 3),
          if (arabic.isNotEmpty)
            pdfText(arabic, style: arStyle, textDirection: pw.TextDirection.rtl),
          pw.Spacer(),
          pdfText(value, style: valueStyle, textDirection: pw.TextDirection.ltr),
        ],
      ),
    );
  }

  /// A signature caption beside its underline: `Caption: ____` on English
  /// documents, otherwise the caption on the right of the line.
  pw.Widget _signature(String caption, pw.TextStyle style,
      {required bool captionRight, pw.TextStyle? captionStyle}) {
    const line = '____________________';
    return pw.Row(
      children: captionRight
          ? [
              pdfText(line, style: style),
              pw.SizedBox(width: 4),
              pdfText(caption, style: captionStyle ?? style),
            ]
          : [
              pdfText('$caption: ', style: style),
              pdfText(line, style: style),
            ],
    );
  }

  /// Items table driven by the shared columns and lines: each header cell
  /// holds the Arabic line above the English one, and the header row repeats
  /// on every page.
  pw.Widget _buildItemsTable(
    ReceiptLayoutParams params,
    pw.TextStyle headerEn,
    pw.TextStyle headerAr,
    pw.TextStyle bodyStyle,
  ) {
    final columns = params.itemColumns;
    if (columns.isEmpty) return pw.SizedBox();
    const flex = <String, double>{
      'showSLNumber': 0.7,
      'showParticulars': 3.8,
      'showMRP': 1.2,
      'showQty': 1.1,
      'showRate': 1.5,
      'showRateExcTax': 1.4,
      'showUnit': 1.0,
      'showTaxHeader': 1.3,
      'showTotal': 1.6,
    };
    final lines = params.itemLines;
    final warranty = params.warrantyLabel;

    pw.Widget header(ReceiptItemColumn column) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          child: pw.Column(
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

    pw.Widget cell(String text, pw.Alignment alignment) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
          child: pw.Align(
            alignment: alignment,
            child: pdfText(text,
                style: bodyStyle,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                textDirection: pw.TextDirection.ltr),
          ),
        );

    // Name lines in the shared order (Arabic above English on a bilingual
    // document), each aligned to its own script, then the warranty label.
    pw.Widget nameCell(ReceiptItemLine line) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              for (final name in line.nameLines)
                pdfText(name,
                    style: bodyStyle,
                    softWrap: true,
                    textAlign: pdfHasArabic(name)
                        ? pw.TextAlign.right
                        : pw.TextAlign.left),
              if (line.hasWarranty && warranty.isNotEmpty)
                pdfText(warranty, style: bodyStyle),
            ],
          ),
        );

    pw.Widget bodyCell(ReceiptItemColumn column, ReceiptItemLine line) =>
        switch (column.key) {
          'showParticulars' => nameCell(line),
          'showSLNumber' || 'showUnit' =>
            cell(line.valueFor(column.key), pw.Alignment.topCenter),
          _ => cell(line.valueFor(column.key), pw.Alignment.topRight),
        };

    return pw.Table(
      border: pw.TableBorder.all(width: 0.75),
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: pw.FlexColumnWidth(flex[columns[i].key] ?? 1.0),
      },
      children: [
        pw.TableRow(repeat: true, children: [
          for (final column in columns) header(column),
        ]),
        for (final line in lines)
          pw.TableRow(children: [
            for (final column in columns) bodyCell(column, line),
          ]),
        // An order without lines still shows one empty row under the header.
        if (lines.isEmpty)
          pw.TableRow(
            children: List.generate(
                columns.length, (_) => cell('', pw.Alignment.topCenter)),
          ),
      ],
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
