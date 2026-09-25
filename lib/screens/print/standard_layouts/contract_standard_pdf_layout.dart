import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_bidi_text.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_sections.dart';
import 'package:pos_machine/screens/print/logo_loader.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/services/common_print_settings.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:provider/provider.dart';

import 'standard_pdf_layout.dart';

/// The one production renderer used by every standard (A4/A5) theme.
///
/// Theme identifiers are intentionally kept at the adapter boundary.  The
/// document contract is not a property of a visual skin: it is a property of
/// the data passed to a PDF renderer.  Keeping this renderer shared means that
/// a newly added theme cannot accidentally re-introduce raw language checks,
/// permissive `visible != false` checks, or a different section order.
class ContractStandardPdfLayout implements StandardPdfLayout {
  final String _layoutId;
  final String _displayName;

  const ContractStandardPdfLayout({
    required String layoutId,
    required String displayName,
  })  : _layoutId = layoutId,
        _displayName = displayName;

  @override
  String get layoutId => _layoutId;

  @override
  String get displayName => _displayName;

  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    try {
      final document = await buildPdfDocument(params);
      final bytes = await document.save();

      // Keep the same development-printer contract as the historical PDF
      // layouts.  Development output is saved and never sent to a system
      // printer.
      if (params.selectedPrinter.isDevelopment) {
        final file = await DevelopmentPrinterService.savePdf(
          bytes: bytes,
          orderNumber: params.orderNumber,
          layoutId: layoutId,
        );
        if (params.context.mounted) {
          showScaffold(
            context: params.context,
            message: 'print.pdf_saved'.trParams({'path': file.path}),
          );
        }
        return;
      }

      // A4/A5 is carried both by the PDF page format and by the direct print
      // call.  The direct service uses the selected paper size when creating
      // the OS printing job.
      if (await StandardPdfDirectPrintService.printBytes(
        pdfBytes: bytes,
        selectedPrinter: params.selectedPrinter,
        paperSize: params.selectedPaperSize,
        jobName: 'Receipt ${params.orderNumber}',
      )) {
        return;
      }

      final directory = await _getEposDirectory();
      final safeOrderNumber = params.orderNumber.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final file = File(
        '${directory.path}/Receipt_${safeOrderNumber}_$layoutId.pdf',
      );
      await file.writeAsBytes(bytes);

      if (Platform.isWindows) {
        try {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } catch (error) {
          debugPrint('[ContractStandardPdfLayout] Could not open PDF: $error');
        }
      } else {
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done && params.context.mounted) {
            showScaffold(
              context: params.context,
              message: 'print.pdf_saved'.trParams({'path': file.path}),
            );
          }
        } catch (error) {
          debugPrint('[ContractStandardPdfLayout] Could not open PDF: $error');
          if (params.context.mounted) {
            showScaffold(
              context: params.context,
            message: 'print.pdf_saved'.trParams({'path': file.path}),
            );
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[ContractStandardPdfLayout] PDF generation failed: $error');
      debugPrint('$stackTrace');
      if (params.context.mounted) {
        showScaffoldError(
          context: params.context,
          message: 'print.pdf_generation_failed'.trParams(
              {'error': error.toString()}),
        );
      }
      if (params.selectedPrinter.isDevelopment) rethrow;
    }
  }

  @override
  Future<pw.Document> buildPdfDocument(ReceiptLayoutParams params) {
    return ContractStandardPdfRenderer().build(params);
  }

  Future<Directory> _getEposDirectory() async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final epos = Directory('${documents.path}/epos');
      if (!await epos.exists()) await epos.create(recursive: true);
      return epos;
    } catch (_) {
      return getTemporaryDirectory();
    }
  }
}

/// Contract implementation for the standard PDF surface.
///
/// Every text comes from the shared [ReceiptLayoutParams] / [ReceiptSections]
/// helpers (which delegate to [ReceiptConfigurationContract]), so this
/// renderer prints the same labels, values and language lines as the thermal
/// receipt and every other A4/A5 template. It never reads `DisplayOption`
/// fields or the raw language string itself.
class ContractStandardPdfRenderer {
  Future<pw.Document> build(ReceiptLayoutParams params) async {
    final pageFormat = _pageFormat(params.selectedPaperSize);
    final mode = params.receiptLanguageMode;
    _pageRtl = mode.isArabic;
    final fonts = await _loadFonts();
    final currency = _currency(params);
    final accent = _accentColor(params.billDocumentConfig.accentColor);
    final logo = await _loadLogo(params);

    final document = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final scale = pageFormat == PdfPageFormat.a5 ? 0.78 : 1.0;
    final body = <pw.Widget>[];

    // Canonical section order: header -> customer -> items -> totals ->
    // returns -> footer.  Keep these calls explicit for reviewability.
    body.addAll(_buildHeaderSection(params, fonts, accent, logo, scale));
    body.addAll(_buildCustomerSection(params, fonts, accent, scale));
    if (!params.isReturnOnly) {
      body.addAll(_buildCartItemsSection(params, fonts, accent, currency, scale));
      body.addAll(_buildTotalsSection(params, fonts, accent, currency, scale));
    }
    body.addAll(_buildReturnSection(params, fonts, accent, currency, scale));
    body.addAll(_buildFooterSection(params, fonts, accent, scale));

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection:
            mode.isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: await CommonPrintSettings.resolvePdfMargins(
          pw.EdgeInsets.all(22 * scale),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pdfText(
            params.pageNumberText(context.pageNumber, context.pagesCount),
            style: fonts.small,
          ),
        ),
        build: (_) => body,
      ),
    );
    return document;
  }

  List<pw.Widget> _buildHeaderSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    pw.MemoryImage? logo,
    double scale,
  ) {
    final config = params.billDocumentConfig;
    final children = <pw.Widget>[];
    if (logo != null) {
      children.add(
        pw.Center(
          child: pw.Container(
            height: 48 * scale,
            constraints: pw.BoxConstraints(maxWidth: 170 * scale),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final header = params.documentText(config.header);
    final subheader = params.documentText(config.subheader);
    if (header.isNotEmpty) children.add(_centerLines(header, fonts.section));
    if (subheader.isNotEmpty) children.add(_centerLines(subheader, fonts.small));

    final store = params.headerTextParts('showStoreName').joined();
    if (store.isNotEmpty) children.add(_centerLines(store, fonts.title));
    final description = params.headerTextParts('showDescription').joined();
    if (description.isNotEmpty) {
      children.add(_centerLines(description, fonts.bodyBold));
    }
    for (final key in const [
      'showStoreAddress',
      'showFssaiInfo',
      'showVatNumber',
      'showCRNumber',
      'showExtraHeading1',
      'showExtraHeading2',
      'showTel',
      'showEmail',
    ]) {
      final parts = key == 'showFssaiInfo' ||
              key == 'showExtraHeading1' ||
              key == 'showExtraHeading2'
          ? params.headerTextParts(key)
          : params.storeLineParts(key);
      final text = parts.joined();
      if (text.isNotEmpty) {
        children.add(_centerLines(
            text, key == 'showStoreAddress' ? fonts.body : fonts.small));
      }
    }

    final title = params.invoiceTitleText;
    if (title.isNotEmpty) {
      children.add(pw.SizedBox(height: 5 * scale));
      children.add(
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 6 * scale),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: _centerLines(
              title, fonts.section.copyWith(color: PdfColors.white)),
        ),
      );
    }

    // Invoice number, token and date. The invoice number carries no label,
    // exactly like the thermal receipt.
    final meta = <pw.Widget>[
      for (final row in params.orderInfoRows)
        if (_metaKeys.contains(row.key)) _infoRow(row, fonts.body),
    ];
    if (meta.isNotEmpty) {
      children.add(pw.SizedBox(height: 6 * scale));
      children.add(pw.Column(children: meta));
    }
    if (children.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.only(bottom: 8 * scale),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: accent, width: 1.2)),
        ),
        child: pw.Column(children: children),
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  static const _metaKeys = {
    'showInvoiceNumber',
    'showTokenNumber',
    'showDate',
  };

  List<pw.Widget> _buildCustomerSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    double scale,
  ) {
    // `showCustomerNameAndPhone` is the customer-section master switch; the
    // shared rows already apply it.
    final rows = <pw.Widget>[
      for (final row in params.customerInfoRows) _infoRow(row, fonts.body),
      for (final row in params.orderInfoRows)
        if (!_metaKeys.contains(row.key)) _infoRow(row, fonts.body),
    ];
    final comment = params.commentText;
    if (comment.isNotEmpty) rows.add(_textLine(comment, fonts.body));
    if (rows.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      _sectionBox(
        rows,
        accent,
        scale,
        heading: params.rendererText(
          english: 'Customer Details',
          arabic: 'بيانات العميل',
        ),
        fonts: fonts,
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildCartItemsSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    String currency,
    double scale,
  ) {
    final columns = params.itemColumns;
    if (columns.isEmpty || params.cartItems.isEmpty) {
      return const <pw.Widget>[];
    }
    final lines = params.itemLines;
    final warranty = params.warrantyLabel;
    const moneyKeys = {
      'showMRP',
      'showRate',
      'showRateExcTax',
      'showTaxHeader',
      'showTotal',
    };

    pw.Widget valueCell(ReceiptItemLine line, String key) {
      if (key == 'showParticulars') {
        return _cellLines(
          [
            ...line.nameLines,
            if (line.hasWarranty && warranty.isNotEmpty) warranty,
          ],
          fonts.small,
          align: pw.TextAlign.left,
        );
      }
      final value = line.valueFor(key);
      return _cellLines(
        [moneyKeys.contains(key) ? _money(value, currency) : value],
        fonts.small,
        align: pw.TextAlign.center,
      );
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: accent),
        children: [
          for (final column in columns)
            _cellLines(
              [column.label.arabic, column.label.english],
              fonts.tableHeader,
              align: pw.TextAlign.center,
            ),
        ],
      ),
      for (var index = 0; index < lines.length; index++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven
                ? PdfColors.white
                : const PdfColor.fromInt(0xFFF5F7FA),
          ),
          children: [
            for (final column in columns) valueCell(lines[index], column.key),
          ],
        ),
    ];

    return <pw.Widget>[
      _sectionTitle(
        params.rendererText(english: 'Items', arabic: 'الأصناف'),
        fonts.section,
        accent,
        scale,
      ),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          for (var i = 0; i < columns.length; i++)
            i: pw.FlexColumnWidth(
                columns[i].key == 'showParticulars' ? 3 : 1),
        },
        children: tableRows,
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildTotalsSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    String currency,
    double scale,
  ) {
    final rows = <pw.Widget>[];
    for (final row in params.totalsRows) {
      final value = row.text ?? _money(row.amount, currency);
      if (row.key == 'showNetAmount') {
        rows.add(
          pw.Container(
            margin: pw.EdgeInsets.only(top: 3 * scale),
            padding: pw.EdgeInsets.symmetric(
                vertical: 5 * scale, horizontal: 7 * scale),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: _labelValue(row.label.joined(inline: true), value,
                fonts.bodyBold.copyWith(color: PdfColors.white)),
          ),
        );
      } else {
        rows.add(_labelValue(row.label.joined(inline: true), value, fonts.body));
      }
    }
    final saved = params.savedLabel;
    if (saved.isNotEmpty) {
      rows.add(_labelValue(
          saved, _money(params.savedAmountValue, currency), fonts.body));
    }
    if (params.isVisible('showAmountInWords')) {
      for (final line in params.amountInWordsLines(params.netAmountValue,
          currency: currency)) {
        rows.add(_textLine(line, fonts.small));
      }
    }
    final payments = params.paymentBreakdownRows;
    if (payments.isNotEmpty) {
      rows.add(pw.Divider(color: PdfColors.grey300, height: 6 * scale));
      for (final row in payments) {
        rows.add(_labelValue(row.$1, _money(row.$2, currency), fonts.small));
      }
    }
    for (final row in params.customerBalanceRows) {
      rows.add(_labelValue(row.$1, _money(row.$2, currency),
          row.$3 ? fonts.bodyBold : fonts.body));
    }
    if (rows.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      _sectionBox(
        rows,
        accent,
        scale,
        heading: params.rendererText(english: 'Summary', arabic: 'الملخص'),
        fonts: fonts,
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildReturnSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    String currency,
    double scale,
  ) {
    final section = params.returnsSection;
    if (section == null) return const <pw.Widget>[];
    final widgets = <pw.Widget>[];
    if (section.heading.isNotEmpty) {
      widgets.add(_sectionTitle(section.heading, fonts.section, accent, scale));
    }
    if (section.creditNoteRows.isNotEmpty) {
      widgets.add(_sectionTitle(
          section.creditNoteHeading, fonts.bodyBold, accent, scale));
      for (final row in section.creditNoteRows) {
        widgets.add(_labelValue(row.$1, row.$2, fonts.body));
      }
    }
    if (section.customerRows.isNotEmpty) {
      widgets.add(
          _sectionTitle(section.customerHeading, fonts.bodyBold, accent, scale));
      for (final row in section.customerRows) {
        widgets.add(_labelValue(row.$1, row.$2, fonts.body));
      }
    }
    if (section.itemsHeading.isNotEmpty) {
      widgets
          .add(_sectionTitle(section.itemsHeading, fonts.bodyBold, accent, scale));
    }
    if (section.columns.isNotEmpty) {
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          for (var i = 0; i < section.columns.length; i++)
            i: pw.FlexColumnWidth(
                section.columns[i].key == 'showReturnParticulars' ? 3 : 1),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: pw.BoxDecoration(color: accent),
            children: [
              for (final column in section.columns)
                _cellLines([column.label.joined(inline: true)],
                    fonts.tableHeader,
                    align: pw.TextAlign.center),
            ],
          ),
          for (final line in section.lines)
            pw.TableRow(children: [
              for (final column in section.columns)
                _cellLines([line[column.key] ?? ''], fonts.small,
                    align: column.key == 'showReturnParticulars'
                        ? pw.TextAlign.left
                        : pw.TextAlign.center),
            ]),
        ],
      ));
    }
    if (section.countRow != null) {
      widgets.add(_labelValue(
          section.countRow!.$1, section.countRow!.$2, fonts.bodyBold));
    }
    for (final row in section.totalRows) {
      widgets.add(_labelValue(row.$1, _money(row.$2, currency), fonts.bodyBold));
    }
    final words = params.returnsWordsLines(currency);
    if (words.isNotEmpty) {
      widgets.add(_textLine(section.wordsHeading, fonts.bodyBold));
      for (final line in words) {
        widgets.add(_textLine(line, fonts.small));
      }
    }

    final finalRows = params.isReturnOnly
        ? const <ReceiptAmountRow>[]
        : params.finalSummaryRows;
    if (finalRows.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 6 * scale));
      for (final row in finalRows) {
        widgets.add(_labelValue(row.label.joined(inline: true),
            _money(row.amount, currency),
            row.emphasised ? fonts.bodyBold : fonts.body));
      }
      for (final line in params.finalSummaryWordsLines(currency)) {
        widgets.add(_textLine(line, fonts.small));
      }
    }
    widgets.add(pw.SizedBox(height: 8 * scale));
    return widgets;
  }

  List<pw.Widget> _buildFooterSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    double scale,
  ) {
    final children = <pw.Widget>[];
    final bankRows = params.bankDetailRows;
    if (bankRows.isNotEmpty) {
      children.add(_sectionTitle(
          params.bankDetailsHeading, fonts.bodyBold, accent, scale));
      for (final row in bankRows) {
        children.add(_labelValue(row.$1, row.$2, fonts.small));
      }
    }

    if (params.isVisible('showQRCode')) {
      final qr = _qrData(params);
      if (qr.isNotEmpty) {
        children.add(pw.SizedBox(height: 5 * scale));
        if (params.qrCaption.isNotEmpty) {
          children.add(_centerLines(params.qrCaption, fonts.small));
          children.add(pw.SizedBox(height: 2 * scale));
        }
        children.add(
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qr,
            width: 82 * scale,
            height: 82 * scale,
          ),
        );
      }
    }
    if (params.vatFooterText.isNotEmpty) {
      children.add(_centerLines(params.vatFooterText, fonts.small));
    }
    final terms = params.termsText;
    if (terms.isNotEmpty) children.add(_centerLines(terms, fonts.small));
    final thankYou = params.thankYouText;
    if (thankYou.isNotEmpty) {
      children.add(_centerLines(thankYou, fonts.bodyBold));
    }
    if (params.orderNumberFooterText.isNotEmpty) {
      children.add(_centerLines(params.orderNumberFooterText, fonts.small));
    }
    if (children.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      pw.SizedBox(height: 4 * scale),
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.only(top: 7 * scale),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: accent, width: 1)),
        ),
        child: pw.Column(children: children),
      ),
    ];
  }

  pw.Widget _sectionBox(
    List<pw.Widget> children,
    PdfColor accent,
    double scale, {
    required String heading,
    required _PdfFonts fonts,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(7 * scale),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (heading.isNotEmpty)
            _sectionTitle(heading, fonts.bodyBold, accent, scale),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(
      String title, pw.TextStyle style, PdfColor accent, double scale) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 4 * scale),
      child: pdfText(
        title,
        style: style.copyWith(color: accent),
        textAlign: pw.TextAlign.left,
        textDirection: _dir(title),
      ),
    );
  }

  // The pdf package shapes Arabic glyphs only inside an rtl Text, so Arabic
  // content on an LTR (English / bilingual) page needs its own direction.
  bool _pageRtl = false;
  pw.TextDirection? _dir(String text) =>
      pdfHasArabic(text) ? pw.TextDirection.rtl : null;

  /// Shared label/value row: a label with no text leaves its cell empty.
  pw.Widget _infoRow(ReceiptInfoRow row, pw.TextStyle style) =>
      _labelValue(row.label.joined(inline: true), row.value, style);

  pw.Widget _labelValue(String label, String value, pw.TextStyle style) {
    final cleanLabel = ReceiptConfigurationContract.withoutTrailingColon(label);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.7),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pdfText(cleanLabel,
                style: style,
                textDirection: _dir(cleanLabel),
                textAlign: _pageRtl ? null : pw.TextAlign.left),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pdfText(value,
                style: style,
                textAlign: pw.TextAlign.right,
                textDirection: _dir(value) ?? pw.TextDirection.ltr),
          ),
        ],
      ),
    );
  }

  /// A standalone line (comment, amount in words).
  pw.Widget _textLine(String text, pw.TextStyle style) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pdfText(text,
            style: style,
            textDirection: _dir(text),
            textAlign: _pageRtl ? null : pw.TextAlign.left),
      );

  /// Centred text; a bilingual `Arabic\nEnglish` string becomes one Text per
  /// line so each script keeps its own direction.
  pw.Widget _centerLines(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Column(
        children: [
          for (final line in text.split('\n'))
            if (line.trim().isNotEmpty)
              pdfText(line,
                  style: style,
                  textAlign: pw.TextAlign.center,
                  textDirection: _dir(line)),
        ],
      ),
    );
  }

  /// Table cell with one Text per line (item names, two-line headers).
  pw.Widget _cellLines(List<String> lines, pw.TextStyle style,
      {pw.TextAlign? align}) {
    final visible = lines.where((line) => line.trim().isNotEmpty).toList();
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        crossAxisAlignment: align == pw.TextAlign.left
            ? pw.CrossAxisAlignment.start
            : pw.CrossAxisAlignment.center,
        children: [
          for (final line in visible)
            pdfText(line,
                style: style,
                textAlign: align ?? pw.TextAlign.left,
                textDirection: _dir(line) ?? pw.TextDirection.ltr),
        ],
      ),
    );
  }

  PdfPageFormat _pageFormat(String paperSize) {
    return paperSize.trim().toUpperCase() == 'A5'
        ? PdfPageFormat.a5
        : PdfPageFormat.a4;
  }

  Future<_PdfFonts> _loadFonts() async {
    try {
      final regular =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      final bold =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      final font = pw.Font.ttf(regular);
      final fontBold = pw.Font.ttf(bold);
      return _PdfFonts.from(font, fontBold);
    } catch (error) {
      debugPrint(
          '[ContractStandardPdfRenderer] Arabic font unavailable: $error');
      return _PdfFonts.from(pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  Future<pw.MemoryImage?> _loadLogo(ReceiptLayoutParams params) async {
    if (params.billDocumentConfig.showLogo != 1) return null;
    final source = _clean(params.billDocumentConfig.logo);
    if (source.isEmpty) return null;
    try {
      return PrintLogoLoader.loadPdfLogo(
        source,
        tag: '[ContractStandardPdfRenderer]',
      );
    } catch (error) {
      debugPrint('[ContractStandardPdfRenderer] Logo unavailable: $error');
      return null;
    }
  }

  String _currency(ReceiptLayoutParams params) {
    try {
      return Provider.of<AppSettingsProvider>(params.context, listen: false)
              .appSettings
              ?.currency ??
          '';
    } catch (_) {
      return '';
    }
  }

  PdfColor _accentColor(String? raw) {
    final value = _clean(raw).replaceFirst('#', '');
    if (value.isEmpty) return const PdfColor.fromInt(0xFF2563EB);
    final normalized = value.length == 6 ? 'FF$value' : value;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null
        ? const PdfColor.fromInt(0xFF2563EB)
        : PdfColor.fromInt(parsed);
  }

  String _qrData(ReceiptLayoutParams params) {
    if (params.hasZatcaCredentials) {
      final zatca = ZatcaQrHelper().generateQrForInvoice(
        sellerName: params.zatcaCompanyName,
        vatNumber: params.zatcaVatNumber,
        invoiceDate: params.orderDate,
        totalAmount: params.netAmountValue,
        vatAmount: params.totalTax,
      );
      if (zatca.isNotEmpty) return zatca;
    }

    // Non-ZATCA documents can still use the configured manual/payment QR.
    // Provider lookup is optional so offline PDF generation remains safe.
    try {
      final gateways = Provider.of<PaymentGatewaysProvider>(
        params.context,
        listen: false,
      ).paymentGateways;
      for (final gateway in gateways) {
        if (gateway.code != 'MANUAL_PAYMENT_GATEWAY') continue;
        var link = gateway.link.trim();
        if (link.isEmpty) return '';
        if (link.contains('{formattedTotal}') ||
            link.contains('{orderNumber}')) {
          return link
              .replaceAll('{formattedTotal}', params.formattedTotal)
              .replaceAll('{orderNumber}', params.orderNumber);
        }
        if (link.contains('@')) {
          link =
              'upi://pay?pa=$link&am=${params.formattedTotal}&tn=${params.orderNumber}&cu=INR';
        }
        return link;
      }
    } catch (_) {}
    return '';
  }

  String _money(dynamic value, String currency) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(_clean(value).replaceAll(',', '')) ?? 0;
    final formatted = amount.toStringAsFixed(2);
    return currency.trim().isEmpty ? formatted : '$currency $formatted';
  }

  String _clean(dynamic value) => value?.toString().trim() ?? '';
}

class _PdfFonts {
  final pw.TextStyle title;
  final pw.TextStyle section;
  final pw.TextStyle body;
  final pw.TextStyle bodyBold;
  final pw.TextStyle tableHeader;
  final pw.TextStyle small;

  _PdfFonts.from(pw.Font font, pw.Font bold)
      : title = pw.TextStyle(
            font: bold, fontSize: 16, fontWeight: pw.FontWeight.bold),
        section = pw.TextStyle(
            font: bold, fontSize: 11, fontWeight: pw.FontWeight.bold),
        body = pw.TextStyle(font: font, fontBold: bold, fontSize: 8.5),
        bodyBold = pw.TextStyle(
            font: bold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        tableHeader = pw.TextStyle(
            font: bold,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white),
        small = pw.TextStyle(font: font, fontBold: bold, fontSize: 7);
}
