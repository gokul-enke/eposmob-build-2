import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:pos_machine/resources/localization_service.dart';
import '../logo_loader.dart';
import 'standard_pdf_layout.dart';

/// Centered Simplified Tax Invoice PDF layout — Saudi ZATCA "Simplified Tax
/// Invoice" design with a three-column bilingual letterhead.
///
/// Visual structure (top → bottom):
///   • Header band: Arabic configuration values (left), centered logo, and
///     English configuration defaults (right), closed by a thick accent rule.
///   • Title band: `CR No.` (left) | `SIMPLIFIED TAX INVOICE` + Arabic
///     (center) | `VAT No.` (right).
///   • Info band: customer box (left) + invoice box (middle) + QR (right).
///   • Items table with Arabic-over-English bilingual column headers.
///   • Totals: amount-in-words / payment / balance (left) + bilingual totals
///     box (right).
///   • Signature band (Signature / Salesman Signature) + accent rule.
///   • Footer band: API-configured bank details + store address line.
///
/// All field visibility, data extraction, B2B/B2C title resolution, ZATCA QR
/// (with payment-gateway fallback), multi-payment breakdown, customer balance,
/// bilingual item names, bilingual amount-in-words and A4/A5 scaling follow the
/// same rules as the thermal `classic`/`premium2` layouts and the other
/// standard PDF layouts.
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

  // ── Bidi helpers ────────────────────────────────────────────────────
  // The `pdf` package only applies Arabic glyph shaping + bidi reordering
  // when a Text widget's resolved textDirection is RTL. On this LTR page any
  // Text carrying Arabic must therefore be flagged RTL, otherwise its letters
  // render isolated/unshaped and overlap adjacent Latin text. Detection is
  // conditional because forcing RTL on pure-Latin text reverses its word order.
  static final RegExp _arabicRegex = RegExp('[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');

  bool _hasArabic(String? s) => s != null && _arabicRegex.hasMatch(s);

  pw.TextDirection _dirOf(String? s) =>
      _hasArabic(s) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  /// Text widget that auto-selects its direction from its content so Arabic is
  /// shaped/reordered correctly while Latin/numeric content stays LTR.
  pw.Widget _autoText(String text, pw.TextStyle style,
      {pw.TextAlign? textAlign,
      int? maxLines,
      bool? softWrap,
      pw.TextDirection? textDirection}) {
    return pw.Text(text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        textDirection: textDirection ?? _dirOf(text));
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
    final appSettings =
        Provider.of<AppSettingsProvider>(params.context, listen: false)
            .appSettings;
    // Resolve providers up-front (before any await) to avoid using the
    // BuildContext across async gaps.
    final paymentGateways =
        Provider.of<PaymentGatewaysProvider>(params.context, listen: false)
            .paymentGateways;
    final currency = appSettings?.currency ?? '';
    final config = params.billDocumentConfig;
    final dc = config.displayConfiguration?.options;
    final resolvedLabels = config.resolvedLabels;
    final isA5 = params.selectedPaperSize.toUpperCase() == 'A5';
    final pageFormat = isA5 ? PdfPageFormat.a5 : PdfPageFormat.a4;

    // Resolve B2B/B2C invoice title — params.displayConfig is B2B-aware
    final resolvedTitleOpt = params.displayConfig?['showInvoiceTitle'];
    final resolvedTitleVal = resolvedTitleOpt?.value?.toString().trim();
    final resolvedTitleDefault =
        resolvedTitleOpt?.defaultValue?.toString().trim();
    final invoiceTitleText = (resolvedTitleVal?.isNotEmpty == true)
        ? resolvedTitleVal!
        : (resolvedTitleDefault?.isNotEmpty == true
            ? resolvedTitleDefault!
            : 'Simplified Tax Invoice');

    // ── Fonts & language ────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    final configLang = config.language;
    final isRtl = configLang != null
        ? configLang.toLowerCase() == 'ar'
        : LocalizationService.locale.languageCode == 'ar';
    final isEnglish = !isRtl;
    final isDualLanguage = (configLang ?? '').toLowerCase() == 'ar';
    // This template is laid out left-to-right by design (English primary with
    // Arabic sub-labels), so the page direction is always LTR. Arabic runs
    // carry their own per-widget RTL direction.

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

    // ── Config helpers ──────────────────────────────────────────────
    String cfgVal(String key, String fallback) {
      final v = dc?[key]?.value as String?;
      return (v != null && v.isNotEmpty) ? v : fallback;
    }

    bool cfgVisible(String key) => dc?[key]?.visible == true;
    bool cfgVisibleDefault(String key) => dc?[key]?.visible != false;

    String displayOrBlank(String? value) {
      final trimmed = value?.trim();
      return (trimmed != null && trimmed.isNotEmpty) ? trimmed : '';
    }

    // ── Logo ────────────────────────────────────────────────────────
    pw.MemoryImage? logoImage;
    if (config.showLogo == 1 &&
        config.logo != null &&
        config.logo.toString().isNotEmpty) {
      logoImage = await _fetchNetworkPdfImage(config.logo.toString());
    }

    // ── Tax totals (supports all 3 cart-item data formats) ──────────
    double totalTax = 0.0;
    double totalExclTax = 0.0;
    for (var item in params.cartItems) {
      double iTax = 0.0, iTotal = 0.0;
      if (params.isFromLocalStorage) {
        iTax = double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
        iTotal = double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0;
      } else if (item is Map) {
        iTax = double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
        iTotal = double.tryParse(item['total_price']?.toString() ??
                item['totalPrice']?.toString() ??
                '0') ??
            0.0;
      } else {
        try {
          iTax = double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
          iTotal = double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0;
        } catch (_) {}
      }
      totalTax += iTax;
      totalExclTax += (iTotal - iTax);
    }
    totalTax = params.totalTax;
    final totalAmount =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    final discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    final double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;

    // Authoritative net-excl-tax (after discount). Prefer params.netExcTax,
    // fall back to the item-summed excl-tax base.
    final double netExcTaxValue = params.netExcTax != null
        ? (double.tryParse(params.netExcTax!) ?? totalExclTax)
        : totalExclTax;

    // ── QR (ZATCA priority, payment-gateway fallback) ───────────────
    String qrData = '';
    if (params.hasZatcaCredentials) {
      qrData = ZatcaQrHelper().generateQrForInvoice(
        sellerName: params.zatcaCompanyName!,
        vatNumber: params.zatcaVatNumber!,
        invoiceDate: params.orderDate,
        totalAmount: totalAmount,
        vatAmount: totalTax,
      );
    }
    if (qrData.isEmpty) {
      try {
        final manualGateway = paymentGateways.firstWhere(
            (g) => g.code == 'MANUAL_PAYMENT_GATEWAY',
            orElse: () => PaymentGateway(
                  id: 0,
                  name: '',
                  code: '',
                  label: '',
                  link: '',
                  image: '',
                  status: '',
                  isWebActive: 0,
                  isAndroidActive: 0,
                  isIosActive: 0,
                  contactEmail: '',
                  contactPhone: '',
                  createdAt: '',
                  updatedAt: '',
                ));
        qrData = manualGateway.link;
        if (qrData.isNotEmpty) {
          if (qrData.contains('{formattedTotal}') ||
              qrData.contains('{orderNumber}')) {
            qrData = qrData
                .replaceAll('{formattedTotal}', params.formattedTotal)
                .replaceAll('{orderNumber}', params.orderNumber);
          } else if (qrData.contains('@')) {
            qrData =
                'upi://pay?pa=$qrData&am=${params.formattedTotal}&tn=${params.orderNumber}&cu=INR';
          }
        }
      } catch (e) {
        debugPrint(
            '[centered_simplified_tax_invoice] payment QR fallback error: $e');
      }
    }

    // ── Header / store info from config ─────────────────────────────
    // The centered template intentionally prints these values exactly as
    // configured. It does not append runtime store address/contact values.
    // FSSAI/VAT and Extra Heading 2 are excluded because they are rendered in
    // the title band below the accent divider.
    const headerConfigKeys = [
      'showStoreName',
      'showDescription',
      'showStoreAddress',
      'showTel',
      'showEmail',
      'showExtraHeading1',
    ];

    List<String> configuredHeaderLines({required bool arabic}) {
      final lines = <String>[];
      for (final key in headerConfigKeys) {
        final option = dc?[key];
        if (option?.visible != true) continue;

        // Prefer the API's normal language mapping (Arabic in `value`, English
        // in `default`), then fall back to the other slot only when its actual
        // script matches. This keeps English-only values out of the Arabic
        // column when a configuration has missing or swapped defaults.
        final candidates = arabic
            ? [option?.value, option?.defaultValue]
            : [option?.defaultValue, option?.value];
        for (final raw in candidates) {
          if (raw == null) continue;
          final text = raw.toString();
          if (text.trim().isEmpty || _hasArabic(text) != arabic) continue;
          lines.add(text);
          break;
        }
      }
      return lines;
    }

    final arabicHeaderLines = configuredHeaderLines(arabic: true);
    final englishHeaderLines = configuredHeaderLines(arabic: false);
    final storeFssai = cfgVal('showFssaiInfo', '');
    final extraHeading2 = cfgVal('showExtraHeading2', '');
    final bankLines = params.visibleBankAccountDetailLines(dc);

    // ── Invoice number (prefix + stripping) ─────────────────────────
    // Invoice prefix: config value > config default > numberPrefix > 'INV-'
    // (mirrors the thermal layout's showInvoicePrefix resolution).
    final prefix = _getOptionText(dc, 'showInvoicePrefix',
        fallback: config.numberPrefix, defaultValue: 'INV-');
    final invRegex = RegExp(r'[1-9]\d*');
    final invMatch = invRegex.firstMatch(params.orderNumber);
    final strippedOrderNumber =
        invMatch != null ? invMatch.group(0)! : params.orderNumber;
    final invoiceNumber = '$prefix$strippedOrderNumber';

    // ── Date (ISO/IST aware, matches thermal layouts) ───────────────
    String displayDate;
    String displayTime;
    try {
      displayDate = params.isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
          : DateHelper.formatISODate(params.orderDate);
      displayTime = params.isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
          : DateHelper.formatISOTimeOnlyToIST(params.orderDate);
    } catch (_) {
      displayDate = params.orderDate;
      displayTime = '';
    }

    // ── Customer info ───────────────────────────────────────────────
    final bool isDefault = params.isDefaultCustomer;
    final bool hideDefaultPhone = params.hideDefaultCustomerPhone;
    final custName = params.customerName ?? (isRtl ? 'عميل' : 'GENERAL');
    final bool maskPhone = dc?['showCustomerPhoneMasked']?.visible ??
        dc?['maskCustomerPhone']?.visible ??
        false;
    String? custPhone;
    if (params.customerPhone != null &&
        params.customerPhone!.isNotEmpty &&
        !(isDefault && hideDefaultPhone)) {
      custPhone = maskPhone
          ? StringHelper.maskStringShowLast4(params.customerPhone!)
          : params.customerPhone!;
      if (params.customerAlternatePhone != null &&
          params.customerAlternatePhone!.isNotEmpty) {
        custPhone = '$custPhone, ${params.customerAlternatePhone}';
      }
    }
    final custAddress = params.customerAddress;

    final bool isQuotation =
        (config.template ?? '').toLowerCase() == 'quotation' ||
            (config.type ?? '').toLowerCase().contains('quotation');

    // Customer / comment / payment / delivery config keys (with aliases).
    final String paymentConfigKey = dc?.containsKey('showPaymentMethod') == true
        ? 'showPaymentMethod'
        : 'showPayment';
    final String commentConfigKey = dc?.containsKey('showOrderComment') == true
        ? 'showOrderComment'
        : 'showComment';
    final bool showCustomerSection =
        dc?['showCustomerNameAndPhone']?.visible ?? true;
    final bool showCustomerName = cfgVisibleDefault('showCustomerName');
    final bool showCustomerAddress = cfgVisibleDefault('showCustomerAddress');
    final bool showCustomerVat = cfgVisible('showCustomerVatNumber');
    final bool showCustomerCr = cfgVisible('showCustomerCrNumber');
    final bool showPayment =
        !isQuotation && cfgVisibleDefault(paymentConfigKey);
    final bool showComment = cfgVisibleDefault(commentConfigKey);
    final bool showDeliveryMethod = cfgVisibleDefault('showDeliveryMethod');

    // Human-readable payment method summary (handles single + multi-payment),
    // reused by both the invoice info box and the left payment line.
    final paymentMethodSummary = _paymentMethodSummary(params);

    // ── Totals visibility ───────────────────────────────────────────
    final bool showSubTotalFlag =
        (dc?['showSubTotal']?.visible ?? dc?['showMRPTotal']?.visible) != false;
    final bool showDiscountFlag = dc?['showDiscount']?.visible != false;
    final bool showTaxTotalFlag = dc?['showTax']?.visible != false;
    final bool showNetFlag = dc?['showNetAmount']?.visible != false;

    // ── Customer box rows ───────────────────────────────────────────
    final customerRows = <pw.Widget>[];
    if (showCustomerSection) {
      if (showCustomerName) {
        customerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerName', null, 'Customer'),
            custName,
            infoLabel,
            infoValue));
      }
      if (showCustomerAddress) {
        customerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerAddress', null, 'Address'),
            displayOrBlank(custAddress),
            infoLabel,
            infoValue));
      }
      if (showCustomerVat) {
        customerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerVatNumber', null, 'Customer VAT No.'),
            displayOrBlank(params.customerVatNumber),
            infoLabel,
            infoValue));
      }
      if (showCustomerCr) {
        customerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerCrNumber', null, 'Customer CR No.'),
            displayOrBlank(params.customerCrNumber),
            infoLabel,
            infoValue));
      }
      if (custPhone != null) {
        customerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerPhone', null, 'Phone'),
            custPhone,
            infoLabel,
            infoValue));
      }
    }

    // ── Invoice box rows ────────────────────────────────────────────
    final String numberLabelDefault =
        isQuotation ? 'Quotation No.' : 'Invoice No.';
    final invoiceRows = <pw.Widget>[
      if (cfgVisibleDefault('showInvoiceNumber'))
        _kvRow(_getLabel(dc, 'showInvoiceNumber', null, numberLabelDefault),
            invoiceNumber, infoLabel, infoValue),
      if (cfgVisibleDefault('showDate'))
        _kvRow('Date:', displayDate, infoLabel, infoValue),
      if (showPayment && paymentMethodSummary.isNotEmpty)
        _kvRow(_getLabel(dc, paymentConfigKey, null, 'Payment Method'),
            paymentMethodSummary, infoLabel, infoValue),
    ];

    // ── Payment breakdown lines (left column) ───────────────────────
    final paymentLines = isQuotation
        ? <pw.Widget>[]
        : _buildPaymentBreakdownLines(params, currency, wordsStyle, dc);

    // ══════════════════════════════════════════════════════════════════
    // BUILD PDF
    // ══════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: pw.EdgeInsets.only(
            left: isA5 ? 14 : 22,
            right: isA5 ? 14 : 22,
            top: isA5 ? 12 : 18,
            bottom: isA5 ? 12 : 18),
        footer: (ctx) => pw.Center(
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
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
                    textDirection: pw.TextDirection.rtl,
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
                    textDirection: pw.TextDirection.ltr,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 3, color: _accent),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 2: TITLE BAND — CR No | Title | VAT No
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: (cfgVisible('showExtraHeading2') &&
                            extraHeading2.isNotEmpty)
                        ? _autoText(extraHeading2, crVatStyle)
                        : (cfgVisible('showFssaiInfo') && storeFssai.isNotEmpty)
                            ? _autoText(storeFssai, crVatStyle)
                            : pw.SizedBox(),
                  ),
                ),
                _autoText(invoiceTitleText.toUpperCase(), titleStyle),
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child:
                        (cfgVisible('showFssaiInfo') && storeFssai.isNotEmpty)
                            ? _autoText(storeFssai, crVatStyle)
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
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children:
                          customerRows.isEmpty ? [pw.SizedBox()] : customerRows,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: invoiceRows,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  if (cfgVisible('showQRCode') && qrData.isNotEmpty)
                    pw.Container(
                      width: isA5 ? 56 : 72,
                      height: isA5 ? 56 : 72,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: isA5 ? 56 : 72,
                        height: isA5 ? 56 : 72,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 4: ITEMS TABLE (fully config-driven columns)
            // ═══════════════════════════════════════════════════════
            if (!params.isReturnOnly) ...[
              _buildItemsTable(params, dc, resolvedLabels, isEnglish,
                  itemsHeaderEn, itemsHeaderAr, itemsBodyStyle),
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
                        if (cfgVisible('showAmountInWords'))
                          ..._amountInWords(totalAmount, currency,
                              isDualLanguage, configLang, wordsBold),
                        pw.SizedBox(height: 4),
                        if (cfgVisibleDefault('showDate'))
                          pw.Text(
                              'Time: $displayDate${displayTime.isNotEmpty ? ' $displayTime' : ''}',
                              style: wordsStyle),
                        if (showPayment && paymentMethodSummary.isNotEmpty)
                          _autoText(
                              '${_getLabel(dc, paymentConfigKey, null, 'Payment Method')}: $paymentMethodSummary',
                              wordsStyle),
                        if (showComment &&
                            params.orderComment != null &&
                            params.orderComment!.isNotEmpty)
                          _autoText(
                              '${_getLabel(dc, commentConfigKey, null, 'Comment')}: ${params.orderComment}',
                              wordsStyle),
                        if (showDeliveryMethod &&
                            params.deliveryMethod != null &&
                            params.deliveryMethod!.isNotEmpty)
                          _autoText(
                              '${_getLabel(dc, 'showDeliveryMethod', null, 'Delivery')}: ${params.deliveryMethod}',
                              wordsStyle),
                        ...paymentLines,
                        ..._customerBalanceLines(
                            params, dc, currency, wordsStyle, wordsBold),
                        if (!params.isReturnOnly &&
                            cfgVisible('showItemsCount'))
                          _autoText(
                            '${_withColon(_getLabel(dc, 'showItemsCount', null, 'Items'))} ${params.cartItems.length}',
                            wordsStyle,
                          ),
                        if (!params.isReturnOnly &&
                            cfgVisible('showQuantityCount'))
                          _autoText(
                            '${_withColon(_getLabel(dc, 'showQuantityCount', null, 'Total Qty'))} ${params.totalQuantity % 1 == 0 ? params.totalQuantity.toInt().toString() : params.totalQuantity.toStringAsFixed(2)}',
                            wordsStyle,
                          ),
                        if (cfgVisible('showSaved') && saved > 0)
                          pw.Text(
                            '${_getLabel(dc, 'showSaved', null, 'You Saved:')} ${_formatMoney(currency, saved)}',
                            style: wordsBold,
                          ),
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
                        if (showSubTotalFlag)
                          _totalsRow(
                              _labelEn(dc, 'showSubTotal', null, 'SUB TOTAL',
                                  isDualLanguage),
                              _labelAr(dc, 'showSubTotal', null,
                                  'المجموع الفرعي', isDualLanguage),
                              _formatMoney(currency, netExcTaxValue),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showDiscountFlag && discountAmountValue != 0)
                          _totalsRow(
                              _labelEn(dc, 'showDiscount', null, 'DISCOUNT',
                                  isDualLanguage),
                              _labelAr(dc, 'showDiscount', null, 'خصم',
                                  isDualLanguage),
                              _formatMoney(currency, discountAmountValue),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showTaxTotalFlag)
                          _totalsRow(
                              _labelEn(
                                  dc,
                                  'showTax',
                                  resolvedLabels?.taxDefault,
                                  'TOTAL VAT 15%',
                                  isDualLanguage),
                              _labelAr(dc, 'showTax', resolvedLabels?.tax,
                                  'ضريبة القيمة المضافة', isDualLanguage),
                              _formatMoney(currency, totalTax),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showNetFlag)
                          _totalsRow(
                              _labelEn(dc, 'showNetAmount', null, 'NET AMOUNT',
                                  isDualLanguage),
                              _labelAr(dc, 'showNetAmount', null,
                                  'المبلغ الصافي', isDualLanguage),
                              _formatMoney(currency, totalAmount),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueBold),
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
            if (params.orderReturns != null &&
                params.orderReturns!.returnItems != null &&
                params.orderReturns!.returnItems!.isNotEmpty) ...[
              ..._buildReturnsPdfSection(
                  params, dc, currency, font, fontBold, isA5),
              if (!params.isReturnOnly)
                ..._buildFinalSummaryPdfSection(params, dc, currency, font,
                    fontBold, isA5, isDualLanguage, configLang),
            ],

            // ═══════════════════════════════════════════════════════
            // TERMS & CONDITIONS (config value → billDocumentConfig.terms)
            // ═══════════════════════════════════════════════════════
            if (cfgVisible('showTermsConditions')) ...[
              _autoText(_termsText(dc, config), smallStyle),
              pw.SizedBox(height: 4),
            ],

            // ═══════════════════════════════════════════════════════
            // THANK YOU (config value → footer → default)
            // ═══════════════════════════════════════════════════════
            if (cfgVisible('showThankYouMessage'))
              pw.Center(
                child: _autoText(
                  _thankYouText(dc, config, isEnglish),
                  footerBold,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            pw.SizedBox(height: 10),

            // ═══════════════════════════════════════════════════════
            // SECTION 6: SIGNATURES
            // ═══════════════════════════════════════════════════════
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Signature: ____________________',
                        style: signatureStyle),
                    pw.SizedBox(width: 6),
                    pw.Text('التوقيع',
                        style: signatureArStyle,
                        textDirection: pw.TextDirection.rtl),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Text('Salesman Signature: ____________________',
                        style: signatureStyle),
                    pw.SizedBox(width: 6),
                    pw.Text('توقيع البائع',
                        style: signatureArStyle,
                        textDirection: pw.TextDirection.rtl),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 3, color: _accent),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 7: FOOTER BAND — bank details (opt-in) + VAT
            // Store name / address / tax info / extra headings are rendered
            // in the top header band instead of here.
            // ═══════════════════════════════════════════════════════
            // Bank fields follow the API's showBankInfo and per-field flags.
            if (bankLines.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _autoText('BANK DETAILS', footerBold,
                      textAlign: pw.TextAlign.center),
                  ...bankLines.map((line) => _autoText(line, footerStyle,
                      textAlign: pw.TextAlign.center)),
                ],
              ),
            if (cfgVisible('showVATFooter') &&
                params.zatcaVatNumber?.isNotEmpty == true)
              pw.Text(
                  '${cfgVal('showVATFooter', '').trim().isNotEmpty ? '${cfgVal('showVATFooter', '').trim()} ' : ''}${params.zatcaVatNumber}',
                  style: footerStyle),
          ];
        },
      ),
    );

    return pdf;
  }

  // ══════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════

  /// Renders one side of the three-column header. The first configured line is
  /// treated as the company name; remaining lines use compact detail styling.
  pw.Widget _configuredHeaderBlock(
    List<String> lines, {
    required pw.TextStyle headingStyle,
    required pw.TextStyle detailStyle,
    required pw.CrossAxisAlignment alignment,
    required pw.TextAlign textAlign,
    required pw.TextDirection textDirection,
  }) {
    return pw.Column(
      crossAxisAlignment: alignment,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          pw.Container(
            width: double.infinity,
            child: _autoText(
              lines[i],
              i == 0 ? headingStyle : detailStyle,
              textAlign: textAlign,
              maxLines: 2,
              textDirection: textDirection,
            ),
          ),
          if (i < lines.length - 1) pw.SizedBox(height: 2),
        ],
      ],
    );
  }

  /// Appends a single trailing colon, avoiding a double `::` when the
  /// configured label already ends with one (e.g. value `"AR Qty:"`).
  String _withColon(String label) {
    final t = label.trimRight();
    return t.endsWith(':') ? t : '$t:';
  }

  /// Get a label with priority: displayConfig value > resolvedLabel > default.
  String _getLabel(Map<String, DisplayOption>? dc, String key,
      String? resolvedLabel, String defaultLabel) {
    final configValue = dc?[key]?.value as String?;
    if (configValue != null && configValue.isNotEmpty) return configValue;
    if (resolvedLabel != null && resolvedLabel.isNotEmpty) return resolvedLabel;
    return defaultLabel;
  }

  /// Text from a config option: value > defaultValue > fallback > default.
  /// Mirrors the thermal layout's `_getOptionText`.
  String _getOptionText(Map<String, DisplayOption>? dc, String key,
      {String? fallback, String defaultValue = ''}) {
    final opt = dc?[key];
    final v = opt?.value;
    if (v is String && v.isNotEmpty) return v;
    final d = opt?.defaultValue;
    if (d != null && d.isNotEmpty) return d;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return defaultValue;
  }

  /// English label slot, dual-language aware.
  ///
  /// In dual/Arabic configs the localized custom label lives in `value`
  /// (Arabic) and the English text in `defaultValue`, so the English slot must
  /// prefer `defaultValue`. In English configs `value` *is* the English label.
  /// Falls back to the English-default resolved label, then the hardcoded
  /// default. Mirrors the English half of the thermal `_getBilingualLabel`.
  String _labelEn(Map<String, DisplayOption>? dc, String key,
      String? resolvedEnglish, String defaultEn, bool isDual) {
    if (isDual) {
      final cfgEn = dc?[key]?.defaultValue;
      if (cfgEn != null && cfgEn.isNotEmpty) return cfgEn;
    } else {
      final cfgVal = dc?[key]?.value as String?;
      if (cfgVal != null && cfgVal.isNotEmpty) return cfgVal;
    }
    if (resolvedEnglish != null && resolvedEnglish.isNotEmpty) {
      return resolvedEnglish;
    }
    return defaultEn;
  }

  /// Arabic sub-label slot. In dual configs prefer the localized custom label
  /// (`value`) / localized resolved label; otherwise fall back to the fixed
  /// template translation. Mirrors the Arabic half of `_getBilingualLabel`.
  String _labelAr(Map<String, DisplayOption>? dc, String key,
      String? resolvedArabic, String defaultAr, bool isDual) {
    if (isDual) {
      final cfgAr = dc?[key]?.value as String?;
      if (cfgAr != null && cfgAr.isNotEmpty) return cfgAr;
      if (resolvedArabic != null && resolvedArabic.isNotEmpty) {
        return resolvedArabic;
      }
    }
    return defaultAr;
  }

  /// Bilingual amount-in-words (Arabic + English when the template is Arabic).
  List<pw.Widget> _amountInWords(double total, String currency,
      bool isDualLanguage, String? configLang, pw.TextStyle style) {
    if (isDualLanguage) {
      final ar = AmountHelper()
          .convertNumberToWords(total, currency: currency, language: 'ar');
      final en = AmountHelper()
          .convertNumberToWords(total, currency: currency, language: 'en');
      return [
        pw.Text('$ar فقط.', style: style, textDirection: pw.TextDirection.rtl),
        pw.Text('$en Only.', style: style),
      ];
    }
    final language = (configLang ?? 'en').toLowerCase();
    final words = AmountHelper()
        .convertNumberToWords(total, currency: currency, language: language);
    final suffix = language == 'ar' ? ' فقط.' : ' only.';
    return [pw.Text('$words$suffix', style: style)];
  }

  /// Friendly label for a raw payment-method code.
  String _paymentMethodLabel(String method) {
    switch (method.trim().toUpperCase()) {
      case 'CASH':
        return 'Cash';
      case 'CARD':
        return 'Card';
      case 'UPI':
        return 'UPI';
      default:
        return method;
    }
  }

  /// Returns a payment breakdown keyed by human-readable method names. Prefers
  /// the structured map already on [params]; otherwise resolves the raw
  /// multi-payment JSON in `paymentMethod` (whose keys are numeric ids) into
  /// names so dynamic/extra methods (BANK, Cheque, ...) don't print as ids.
  Map<String, dynamic>? _resolvedBreakdown(ReceiptLayoutParams params) {
    if (params.paymentBreakdown != null &&
        params.paymentBreakdown!.isNotEmpty) {
      return params.paymentBreakdown;
    }
    final parsed = PaymentHelper.parseLocalMultiPayment(
        params.context, params.paymentMethod);
    if (parsed != null && parsed.paymentBreakdown.isNotEmpty) {
      return parsed.paymentBreakdown;
    }
    return null;
  }

  /// Human-readable payment method(s). Handles a structured `paymentBreakdown`
  /// map, a JSON multi-payment payload in `paymentMethod`, or a single method.
  /// For multiple payments the method names are joined with ', '.
  String _paymentMethodSummary(ReceiptLayoutParams params) {
    // Structured breakdown map (name-keyed; resolves numeric ids when needed).
    final breakdown = _resolvedBreakdown(params);
    if (breakdown != null && breakdown.isNotEmpty) {
      final methods = <String>[];
      breakdown.forEach((method, amount) {
        final amt = double.tryParse(amount.toString()) ?? 0.0;
        if (amt > 0) methods.add(_paymentMethodLabel(method));
      });
      if (methods.isNotEmpty) return methods.join(', ');
    }

    // JSON multi-payment payload embedded in paymentMethod.
    final pm = params.paymentMethod;
    if (pm != null && pm.startsWith('{')) {
      try {
        final data = json.decode(pm);
        if (data['isMultiPayment'] == true && data['amounts'] is Map) {
          final methods = <String>[];
          (data['amounts'] as Map).forEach((method, amount) {
            final amt = double.tryParse(amount.toString()) ?? 0.0;
            if (amt > 0) methods.add(_paymentMethodLabel(method.toString()));
          });
          if (methods.isNotEmpty) return methods.join(', ');
        }
      } catch (e) {
        debugPrint('[simplified_tax_invoice] payment summary parse error: $e');
      }
    }

    if (pm == null || pm.isEmpty) return '';
    return _paymentMethodLabel(pm);
  }

  /// Multi-payment breakdown lines (structured map → JSON payload → single).
  List<pw.Widget> _buildPaymentBreakdownLines(
    ReceiptLayoutParams params,
    String currency,
    pw.TextStyle style,
    Map<String, DisplayOption>? dc,
  ) {
    final bool showPaymentBreaked = dc?['showPaymentBreaked']?.visible ?? true;
    if (params.paidAmount == null || !showPaymentBreaked) return [];

    String labelFor(String method) {
      if (method == 'CASH') return 'Cash';
      if (method == 'CARD') return 'Card';
      if (method == 'UPI') return 'UPI';
      return method;
    }

    final lines = <pw.Widget>[];
    bool isMulti = false;

    final breakdown = _resolvedBreakdown(params);
    if (breakdown != null && breakdown.isNotEmpty) {
      isMulti = true;
      breakdown.forEach((method, amount) {
        final amt = double.tryParse(amount.toString()) ?? 0.0;
        if (amt > 0) {
          lines.add(pw.Text(
              '${labelFor(method)}: ${_formatMoney(currency, amt)}',
              style: style));
        }
      });
    } else if (params.paymentMethod != null &&
        params.paymentMethod!.startsWith('{')) {
      try {
        final data = json.decode(params.paymentMethod!);
        if (data['isMultiPayment'] == true) {
          isMulti = true;
          final Map<String, dynamic> amounts = data['amounts'];
          amounts.forEach((method, amount) {
            final amt = double.tryParse(amount.toString()) ?? 0.0;
            if (amt > 0) {
              lines.add(pw.Text(
                  '${labelFor(method)}: ${_formatMoney(currency, amt)}',
                  style: style));
            }
          });
        }
      } catch (e) {
        debugPrint('[simplified_tax_invoice] payment parse error: $e');
      }
    }

    if (!isMulti) {
      final pm = params.paymentMethod;
      if (pm != null && pm.isNotEmpty && !pm.startsWith('{')) {
        lines.add(pw.Text(
            '${_paymentMethodLabel(pm)}: ${_formatMoney(currency, params.paidAmount!)}',
            style: style));
      }
    }
    return lines;
  }

  /// Customer balance lines (master gate + default-customer guard + per field).
  List<pw.Widget> _customerBalanceLines(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    String currency,
    pw.TextStyle style,
    pw.TextStyle boldStyle,
  ) {
    final bool showCustomerBalance =
        dc?['showCustomerBalance']?.visible ?? true;
    if (!showCustomerBalance) return [];
    if (params.isDefaultCustomer) return [];
    if (params.customerOldBalance == null &&
        params.customerCurrentBalance == null &&
        params.paidAmount == null) {
      return [];
    }

    final bool showPrev = dc?['showCustomerPrevBalance']?.visible ?? true;
    final bool showPaid = dc?['showCustomerPaidAmount']?.visible ?? true;
    final bool showCurrent = dc?['showCustomerCurrentBalance']?.visible ?? true;

    final lines = <pw.Widget>[];
    if (showPrev && params.customerOldBalance != null) {
      lines.add(pw.Text(
          '${_getLabel(dc, 'showCustomerPrevBalance', null, 'Previous Balance')}: ${_formatMoney(currency, params.customerOldBalance!)}',
          style: style));
    }
    if (showPaid && params.paidAmount != null) {
      lines.add(pw.Text(
          '${_getLabel(dc, 'showCustomerPaidAmount', null, 'Paid Amount')}: ${_formatMoney(currency, params.paidAmount!)}',
          style: style));
    }
    if (showCurrent && params.customerCurrentBalance != null) {
      lines.add(pw.Text(
          '${_getLabel(dc, 'showCustomerCurrentBalance', null, 'Current Balance')}: ${_formatMoney(currency, params.customerCurrentBalance!)}',
          style: boldStyle));
    }
    return lines;
  }

  /// Terms text: config value, falling back to billDocumentConfig.terms.
  String _termsText(Map<String, DisplayOption>? dc, DocumentConfig config) {
    String? terms = dc?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      terms = config.terms;
    }
    return terms?.trim() ?? '';
  }

  /// Thank-you text: config value → billDocumentConfig.footer → default.
  String _thankYouText(
      Map<String, DisplayOption>? dc, DocumentConfig config, bool isEnglish) {
    final value = dc?['showThankYouMessage']?.value as String?;
    if (value != null && value.isNotEmpty) return value;
    if (config.footer?.isNotEmpty == true) return config.footer!;
    return isEnglish ? 'Thank you for your business' : 'شكراً لتسوقكم معنا';
  }

  /// Key/value row used in the customer & invoice info boxes.
  pw.Widget _kvRow(String label, String value, pw.TextStyle labelStyle,
      pw.TextStyle valueStyle,
      {double labelWidth = 96}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Text(label,
                style: labelStyle,
                maxLines: 1,
                softWrap: false,
                overflow: pw.TextOverflow.clip,
                textDirection: _dirOf(label)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: valueStyle,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textDirection: _dirOf(value)),
          ),
        ],
      ),
    );
  }

  /// Totals box row: EN label | AR label | value.
  pw.TableRow _totalsRow(String en, String ar, String value,
      pw.TextStyle enStyle, pw.TextStyle arStyle, pw.TextStyle valueStyle) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Text(en, style: enStyle, textDirection: _dirOf(en)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child:
              pw.Text(ar, style: arStyle, textDirection: pw.TextDirection.rtl),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(value, style: valueStyle),
        ),
      ),
    ]);
  }

  /// When the template language is Arabic and the item carries an Arabic name,
  /// show Arabic on line 1 and English on line 2 (mirrors the thermal layout).
  String _bilingualItemName(dynamic item, String englishName, bool isAr) {
    if (!isAr) return englishName;
    String? ar;
    try {
      if (item is Map) {
        final n =
            item['product_names'] ?? item['productNames'] ?? item['names'];
        if (n is Map) ar = (n['ar'] ?? n['arabic'])?.toString();
      } else {
        ar = item.names?.ar?.toString();
      }
    } catch (_) {}
    if (ar != null && ar.trim().isNotEmpty) {
      return englishName.trim().isNotEmpty ? '$ar\n$englishName' : ar;
    }
    return englishName;
  }

  String _variantAttributeLabel(dynamic rawAttributes) {
    dynamic attrs = rawAttributes;
    if (attrs is String) {
      final trimmed = attrs.trim();
      if (trimmed.isEmpty) return '';
      try {
        attrs = json.decode(trimmed);
      } catch (_) {
        return trimmed;
      }
    }
    if (attrs is Map) {
      return attrs.values
          .map((value) => value?.toString() ?? '')
          .where((value) => value.trim().isNotEmpty)
          .join(' | ');
    }
    return '';
  }

  String _itemDisplayName(dynamic item, String fallbackName) {
    try {
      final displayName = item.displayName?.toString();
      if (displayName != null && displayName.trim().isNotEmpty) {
        return displayName;
      }
    } catch (_) {}

    dynamic rawAttributes;
    if (item is Map) {
      rawAttributes = item['variant_attributes'] ?? item['variantAttributes'];
    } else {
      try {
        rawAttributes = item.variantAttributes;
      } catch (_) {}
    }

    final attrs = _variantAttributeLabel(rawAttributes);
    if (attrs.isEmpty || fallbackName.contains('($attrs)')) {
      return fallbackName;
    }
    return fallbackName.trim().isEmpty ? attrs : '$fallbackName ($attrs)';
  }

  pw.Widget _buildItemsTable(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    ResolvedLabels? resolvedLabels,
    bool isEnglish,
    pw.TextStyle headerEn,
    pw.TextStyle headerAr,
    pw.TextStyle bodyStyle,
  ) {
    bool col(String key) => dc?[key]?.visible == true;

    final showSL = col('showSLNumber');
    final showItems = col('showParticulars');
    final showMRP = col('showMRP');
    final showQty = col('showQty');
    final showRate = col('showRate');
    final showRateExcTax = col('showRateExcTax');
    final showUnit = col('showUnit');
    final showDiscountColumn = col('showDiscountColumn');
    final showTax = col('showTaxHeader');
    final showTotal = col('showTotal');

    final bool isAr =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    // Column widths matching the reference proportions.
    final Map<int, pw.TableColumnWidth> colWidths = {};
    int ci = 0;
    if (showSL) colWidths[ci++] = const pw.FlexColumnWidth(0.6);
    if (showItems) colWidths[ci++] = const pw.FlexColumnWidth(4.2);
    if (showMRP) colWidths[ci++] = const pw.FlexColumnWidth(1.1);
    if (showQty) colWidths[ci++] = const pw.FlexColumnWidth(0.9);
    if (showRate) colWidths[ci++] = const pw.FlexColumnWidth(1.3);
    if (showRateExcTax) colWidths[ci++] = const pw.FlexColumnWidth(1.2);
    if (showUnit) colWidths[ci++] = const pw.FlexColumnWidth(0.8);
    if (showDiscountColumn) colWidths[ci++] = const pw.FlexColumnWidth(1.0);
    if (showTax) colWidths[ci++] = const pw.FlexColumnWidth(1.1);
    if (showTotal) colWidths[ci++] = const pw.FlexColumnWidth(1.5);

    // Bilingual header cell — Arabic on top, English below (reference order).
    pw.Widget hdr(String en, String ar) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (ar.isNotEmpty)
              pw.Text(ar,
                  style: headerAr,
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.center),
            pw.Text(en, style: headerEn, textAlign: pw.TextAlign.center),
          ],
        ),
      );
    }

    final hdrs = <pw.Widget>[];
    if (showSL) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showSLNumber', resolvedLabels?.slNumberDefault, 'NO', isAr),
          _labelAr(dc, 'showSLNumber', resolvedLabels?.slNumber, '', isAr)));
    }
    if (showItems) {
      hdrs.add(hdr(
          _labelEn(dc, 'showParticulars', resolvedLabels?.particularsDefault,
              'DESCRIPTION', isAr),
          _labelAr(dc, 'showParticulars', resolvedLabels?.particulars, 'الوصف',
              isAr)));
    }
    if (showMRP) {
      hdrs.add(hdr(_labelEn(dc, 'showMRP', null, 'MRP', isAr),
          _labelAr(dc, 'showMRP', resolvedLabels?.mrp, 'القيمة', isAr)));
    }
    if (showQty) {
      hdrs.add(hdr(
          _labelEn(dc, 'showQty', resolvedLabels?.qtyDefault, 'QTY', isAr),
          _labelAr(dc, 'showQty', resolvedLabels?.qty, 'كمية', isAr)));
    }
    if (showRate) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showRate', resolvedLabels?.rateDefault, 'UNIT PRICE', isAr),
          _labelAr(dc, 'showRate', resolvedLabels?.rate, 'سعر الوحده', isAr)));
    }
    if (showRateExcTax) {
      hdrs.add(hdr(_labelEn(dc, 'showRateExcTax', null, 'RATE EX TAX', isAr),
          _labelAr(dc, 'showRateExcTax', null, 'السعر بدون ضريبة', isAr)));
    }
    if (showUnit) {
      hdrs.add(hdr(_labelEn(dc, 'showUnit', null, 'UNIT', isAr),
          _labelAr(dc, 'showUnit', resolvedLabels?.unitName, 'الوحدة', isAr)));
    }
    if (showDiscountColumn) {
      hdrs.add(hdr(_labelEn(dc, 'showDiscountColumn', null, 'DISCOUNT', isAr),
          _labelAr(dc, 'showDiscountColumn', null, 'خصم', isAr)));
    }
    if (showTax) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showTaxHeader', resolvedLabels?.taxDefault, 'VAT 15%', isAr),
          _labelAr(dc, 'showTaxHeader', resolvedLabels?.tax, 'الضريبة', isAr)));
    }
    if (showTotal) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showTotal', resolvedLabels?.totalDefault, 'NET TOTAL', isAr),
          _labelAr(dc, 'showTotal', resolvedLabels?.total, 'الإجمالي الصافي',
              isAr)));
    }

    final rows = <pw.TableRow>[];
    for (int i = 0; i < params.cartItems.length; i++) {
      final item = params.cartItems[i];
      String name = '';
      double mrp = 0,
          qty = 0,
          unitPrice = 0,
          iDiscount = 0,
          iTax = 0,
          iTotal = 0;
      String unitName = '';

      if (params.isFromLocalStorage) {
        name = item['productName']?.toString() ??
            item['product_name']?.toString() ??
            '';
        mrp = double.tryParse(item['mrp']?.toString() ?? '0') ?? 0;
        qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        unitPrice = double.tryParse(
                (item['unitPrice'] ?? item['unit_price'])?.toString() ?? '0') ??
            0;
        unitName = getPrintUnit(item);
        iDiscount = double.tryParse(item['discount']?.toString() ?? '0') ?? 0;
        iTax = double.tryParse(
                (item['tax_amount'] ?? item['taxAmount'])?.toString() ?? '0') ??
            0;
        iTotal = double.tryParse(
                (item['totalPrice'] ?? item['total_price'])?.toString() ??
                    '0') ??
            0;
      } else if (item is Map) {
        name = item['product_name']?.toString() ??
            item['productName']?.toString() ??
            '';
        mrp = double.tryParse(item['mrp']?.toString() ?? '0') ?? 0;
        qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        unitPrice = double.tryParse(
                (item['unit_price'] ?? item['unitPrice'])?.toString() ?? '0') ??
            0;
        unitName = getPrintUnit(item);
        iDiscount = double.tryParse(item['discount']?.toString() ?? '0') ?? 0;
        iTax = double.tryParse(
                (item['tax_amount'] ?? item['taxAmount'])?.toString() ?? '0') ??
            0;
        iTotal = double.tryParse(
                (item['total_price'] ?? item['totalPrice'])?.toString() ??
                    '0') ??
            0;
      } else {
        try {
          name = item.productName ?? '';
          mrp = double.tryParse(item.mrp?.toString() ?? '0') ?? 0;
          qty = double.tryParse(item.quantity?.toString() ?? '0') ?? 0;
          unitPrice = double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0;
          unitName = getPrintUnit(item);
          iTax = double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0;
          iTotal = double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0;
        } catch (_) {}
        try {
          iDiscount =
              double.tryParse(item.discountAmount?.toString() ?? '0') ?? 0;
        } catch (_) {}
      }

      final double taxPerUnit = qty > 0 ? (iTax / qty) : 0;
      final double rateExcTax = unitPrice - taxPerUnit;

      name = _itemDisplayName(item, name);
      name = _bilingualItemName(item, name, isAr);
      // Right-align + RTL-shape whenever the name carries any Arabic (covers
      // bilingual names and English names with embedded Arabic).
      final bool isArName = _hasArabic(name);

      final cells = <pw.Widget>[];
      if (showSL) cells.add(_dataCell('${i + 1}', bodyStyle));
      if (showItems) {
        cells.add(_dataCell(name, bodyStyle,
            align:
                isArName ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            textDirection:
                isArName ? pw.TextDirection.rtl : pw.TextDirection.ltr));
      }
      if (showMRP) {
        cells.add(_dataCell(mrp.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showQty) {
        cells.add(_dataCell(qty.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showRate) {
        cells.add(_dataCell(unitPrice.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showRateExcTax) {
        cells.add(_dataCell(rateExcTax.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showUnit) {
        cells.add(_dataCell(unitName, bodyStyle));
      }
      if (showDiscountColumn) {
        cells.add(_dataCell(iDiscount.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showTax) {
        cells.add(_dataCell(iTax.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showTotal) {
        cells.add(_dataCell(iTotal.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }

      rows.add(pw.TableRow(children: cells));
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: colWidths,
      children: [
        pw.TableRow(children: hdrs),
        ...rows,
      ],
    );
  }

  /// Data cell for items table.
  pw.Widget _dataCell(String text, pw.TextStyle style,
      {pw.Alignment align = pw.Alignment.center,
      pw.TextDirection? textDirection}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: style,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          textDirection: textDirection,
        ),
      ),
    );
  }

  // ── Return section helpers ──────────────────────────────────────────

  List<pw.Widget> _buildReturnsPdfSection(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    String currency,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return [];
    }
    double fs(double v) => isA5 ? v * 0.78 : v;
    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    final labelStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final valueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final headerStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8), fontWeight: pw.FontWeight.bold);
    final bodyStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final titleStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);

    bool col(String key) => dc?[key]?.visible == true;
    String lbl(String key, String? resolved, String def) {
      final v = dc?[key]?.value as String?;
      if (v != null && v.isNotEmpty) return v;
      if (resolved != null && resolved.isNotEmpty) return resolved;
      return def;
    }

    final showSl = col('showReturnSLNumber');
    final showParticulars = col('showReturnParticulars');
    final showMrp = col('showReturnMRP');
    final showQty = col('showReturnQty');
    final showRate = col('showReturnRate');
    final showTotal = col('showReturnTotal');

    final Map<int, pw.TableColumnWidth> colWidths = {};
    int ci = 0;
    if (showSl) colWidths[ci++] = const pw.FlexColumnWidth(0.6);
    if (showParticulars) colWidths[ci++] = const pw.FlexColumnWidth(4.2);
    if (showMrp) colWidths[ci++] = const pw.FlexColumnWidth(1.1);
    if (showQty) colWidths[ci++] = const pw.FlexColumnWidth(0.9);
    if (showRate) colWidths[ci++] = const pw.FlexColumnWidth(1.3);
    if (showTotal) colWidths[ci++] = const pw.FlexColumnWidth(1.5);

    pw.Widget hdrCell(String text) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child:
              pw.Text(text, style: headerStyle, textAlign: pw.TextAlign.center),
        );

    final headerCells = <pw.Widget>[];
    if (showSl) {
      headerCells.add(hdrCell(
          lbl('showReturnSLNumber', resolvedLabels?.returnSlNumber, 'SL#')));
    }
    if (showParticulars) {
      headerCells.add(hdrCell(lbl('showReturnParticulars',
          resolvedLabels?.returnParticulars, 'PARTICULARS')));
    }
    if (showMrp) {
      headerCells
          .add(hdrCell(lbl('showReturnMRP', resolvedLabels?.returnMrp, 'MRP')));
    }
    if (showQty) {
      headerCells
          .add(hdrCell(lbl('showReturnQty', resolvedLabels?.returnQty, 'QTY')));
    }
    if (showRate) {
      headerCells.add(
          hdrCell(lbl('showReturnRate', resolvedLabels?.returnRate, 'RATE')));
    }
    if (showTotal) {
      headerCells.add(hdrCell(
          lbl('showReturnTotal', resolvedLabels?.returnTotal, 'TOTAL')));
    }

    pw.Widget cell(String text, {pw.Alignment align = pw.Alignment.center}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Align(
            alignment: align,
            child: pw.Text(text, style: bodyStyle),
          ),
        );

    final tableRows = <pw.TableRow>[];
    if (headerCells.isNotEmpty) {
      tableRows.add(pw.TableRow(children: headerCells));
    }

    for (int i = 0; i < orderReturns.returnItems!.length; i++) {
      final ri = orderReturns.returnItems![i];
      final int qty = ri.quantity ?? 0;
      final String name = ri.productName ?? '';

      double itemRate = 0.0;
      double itemMrp = 0.0;
      for (var cartItem in params.cartItems) {
        String cartName = '';
        double cartRate = 0.0;
        double cartMrp = 0.0;
        if (params.isFromLocalStorage || cartItem is Map) {
          cartName = (cartItem['product_name'] ?? cartItem['productName'] ?? '')
              .toString();
          cartRate = double.tryParse(
                  (cartItem['unit_price'] ?? cartItem['unitPrice'])
                          ?.toString() ??
                      '0') ??
              0.0;
          cartMrp = double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
        } else {
          try {
            cartName = cartItem.productName?.toString() ?? '';
            cartRate =
                double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
            cartMrp = double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0;
          } catch (_) {}
        }
        if (cartName == name) {
          itemRate = cartRate;
          itemMrp = cartMrp;
          break;
        }
      }
      if (itemRate == 0.0) {
        final totalRet =
            double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
        int totalQty = 0;
        for (var ri2 in orderReturns.returnItems!) {
          totalQty += ri2.quantity ?? 0;
        }
        itemRate = totalQty > 0 ? totalRet / totalQty : 0.0;
        itemMrp = itemRate;
      }
      final double itemTotal = qty * itemRate;

      final cells = <pw.Widget>[];
      if (showSl) cells.add(cell('${i + 1}'));
      if (showParticulars) {
        cells.add(cell(name, align: pw.Alignment.centerLeft));
      }
      if (showMrp) {
        cells.add(
            cell(itemMrp.toStringAsFixed(2), align: pw.Alignment.centerRight));
      }
      if (showQty) {
        cells.add(cell(qty.toString(), align: pw.Alignment.centerRight));
      }
      if (showRate) {
        cells.add(
            cell(itemRate.toStringAsFixed(2), align: pw.Alignment.centerRight));
      }
      if (showTotal) {
        cells.add(cell(itemTotal.toStringAsFixed(2),
            align: pw.Alignment.centerRight));
      }
      tableRows.add(pw.TableRow(children: cells));
    }

    final double returnRateTotal =
        double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;

    final retDc = params.returnBillDisplayConfig;
    final retLabels = params.returnBillResolvedLabels;
    bool retVis(String key) => retDc?[key]?.visible == true;
    String retLbl(String key, String? resolved, String def) {
      final v = retDc?[key]?.value as String?;
      if (v != null && v.isNotEmpty) return v;
      if (resolved != null && resolved.isNotEmpty) return resolved;
      return def;
    }

    final sectionHeadingStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);

    final hasCreditNoteConfig = retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null;

    final widgets = <pw.Widget>[
      pw.SizedBox(height: 6),
      pw.Divider(height: 0, thickness: 0.8),
      pw.SizedBox(height: 4),
      if (!hasCreditNoteConfig) ...[
        pw.Text(params.returnsSectionHeading, style: titleStyle),
        pw.SizedBox(height: 4),
      ],
    ];

    // — Credit Note Details section —
    final cnDetailsRows = <pw.Widget>[];
    if ((retLabels?.creditNoteNumber != null)) {
      cnDetailsRows.add(_kvRow(
        retLbl('showCreditNoteNumber', retLabels?.creditNoteNumber,
            'Credit Note No:'),
        params.orderNumber,
        labelStyle,
        valueStyle,
      ));
    }
    if ((retLabels?.creditNoteDate != null)) {
      cnDetailsRows.add(_kvRow(
        retLbl('showCreditNoteDate', retLabels?.creditNoteDate,
            'Credit Note Date:'),
        params.orderDate,
        labelStyle,
        valueStyle,
      ));
    }
    if ((retLabels?.creditNoteReason != null)) {
      cnDetailsRows.add(_kvRow(
        retLbl('showCreditNoteReason', retLabels?.creditNoteReason, 'Reason:'),
        '',
        labelStyle,
        valueStyle,
      ));
    }
    if (cnDetailsRows.isNotEmpty) {
      widgets.add(pw.Text(
        retLbl('showCreditNoteOrder', retLabels?.detailsHeading,
            'CREDIT NOTE DETAILS'),
        style: sectionHeadingStyle,
      ));
      widgets.add(pw.SizedBox(height: 2));
      widgets.addAll(cnDetailsRows);
      widgets.add(pw.SizedBox(height: 4));
    }

    // — Customer Details section —
    final custRows = <pw.Widget>[];
    if (params.customerName != null && params.customerName!.trim().isNotEmpty) {
      custRows.add(_kvRow(
        'Customer Name:',
        params.customerName!,
        labelStyle,
        valueStyle,
      ));
    }
    if (params.customerPhone != null &&
        params.customerPhone!.trim().isNotEmpty) {
      custRows.add(
          _kvRow('Phone:', params.customerPhone!, labelStyle, valueStyle));
    }
    if (params.customerAddress != null &&
        params.customerAddress!.trim().isNotEmpty) {
      custRows.add(_kvRow(
          'Billing Address:', params.customerAddress!, labelStyle, valueStyle));
    }
    if (custRows.isNotEmpty) {
      widgets.add(pw.Text(retLabels?.customerHeading ?? 'CUSTOMER DETAILS', style: sectionHeadingStyle));
      widgets.add(pw.SizedBox(height: 2));
      widgets.addAll(custRows);
      widgets.add(pw.SizedBox(height: 4));
    }

if (retLabels?.itemsHeading != null) {
      widgets.add(pw.Text(retLabels!.itemsHeading!, style: sectionHeadingStyle));
      widgets.add(pw.SizedBox(height: 2));
    }

    if (tableRows.isNotEmpty) {
      widgets.add(pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: colWidths,
        children: tableRows,
      ));
      widgets.add(pw.SizedBox(height: 4));
    }

    if (col('showReturnItemsCount') || (retLabels?.creditNoteItemsCount != null)) {
      final countLabel = (retLabels?.creditNoteItemsCount != null)
          ? retLbl('showCreditNoteItemsCount', retLabels?.creditNoteItemsCount,
              'Total Items:')
          : lbl('showReturnItemsCount', null, 'Return Items:');
      widgets.add(pw.Text('$countLabel ${orderReturns.returnItems!.length}',
          style: labelStyle));
      widgets.add(pw.SizedBox(height: 2));
    }

    if (col('showReturnTotalAmount') || (retLabels?.creditNoteTotalAmount != null)) {
      final label = (retLabels?.creditNoteTotalAmount != null)
          ? retLbl('showCreditNoteTotalAmount',
              retLabels?.creditNoteTotalAmount, 'Total Amount:')
          : lbl('showReturnTotalAmount', null, 'Return Total:');
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label ', style: labelStyle),
          pw.Text(_formatMoney(currency, returnRateTotal), style: valueStyle),
        ],
      ));
    }

    if (col('showReturnNetAmount') || (retLabels?.creditNoteRefund != null)) {
      final label = (retLabels?.creditNoteRefund != null)
          ? retLbl('showCreditNoteRefund', retLabels?.creditNoteRefund,
              'Credit Note Total:')
          : lbl('showReturnNetAmount', null, 'Return Net Amount:');
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label ', style: labelStyle),
          pw.Text(_formatMoney(currency, returnRateTotal), style: valueStyle),
        ],
      ));
    }

    if (hasCreditNoteConfig) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.addAll(_amountInWords(
          returnRateTotal, currency, false, null, labelStyle));
    }

    return widgets;
  }

  List<pw.Widget> _buildFinalSummaryPdfSection(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    String currency,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
    bool isDualLanguage,
    String? configLang,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return [];
    }
    double fs(double v) => isA5 ? v * 0.78 : v;

    bool vis(String key) => dc?[key]?.visible != false;
    bool visExplicit(String key) => dc?[key]?.visible == true;
    String lbl(String key, String def) {
      final v = dc?[key]?.value as String?;
      if (v != null && v.isNotEmpty) return v;
      return def;
    }

    final showFinalPurchase = vis('showFinalPurchase');
    final showFinalReturn = vis('showFinalReturn');
    final showFinalNetAmount = vis('showFinalNetAmount');
    final showFinalAmountInWords = visExplicit('showFinalAmountInWords');

    if (!showFinalPurchase && !showFinalReturn && !showFinalNetAmount) {
      return [];
    }

    final labelStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);
    final valueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(9));
    final valueBold = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final wordsBold = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);

    double returnTotal = 0.0;
    for (final ri in orderReturns.returnItems!) {
      final int qty = ri.quantity ?? 0;
      double itemRate = 0.0;
      for (var cartItem in params.cartItems) {
        String cartName = '';
        double cartRate = 0.0;
        if (params.isFromLocalStorage || cartItem is Map) {
          cartName = (cartItem['product_name'] ?? cartItem['productName'] ?? '')
              .toString();
          cartRate = double.tryParse(
                  (cartItem['unit_price'] ?? cartItem['unitPrice'])
                          ?.toString() ??
                      '0') ??
              0.0;
        } else {
          try {
            cartName = cartItem.productName?.toString() ?? '';
            cartRate =
                double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
          } catch (_) {}
        }
        if (cartName == ri.productName) {
          itemRate = cartRate;
          break;
        }
      }
      if (itemRate == 0.0) {
        final totalRet =
            double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
        int totalQty = 0;
        for (var ri2 in orderReturns.returnItems!) {
          totalQty += ri2.quantity ?? 0;
        }
        itemRate = totalQty > 0 ? totalRet / totalQty : 0.0;
      }
      returnTotal += qty * itemRate;
    }

    final orderTotal =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    final finalTotal = orderTotal - returnTotal;

    pw.TableRow summaryRow(String label, String value, pw.TextStyle valStyle) =>
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Text(label, style: labelStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(value, style: valStyle),
            ),
          ),
        ]);

    final tableRows = <pw.TableRow>[];
    if (showFinalPurchase) {
      tableRows.add(summaryRow(lbl('showFinalPurchase', 'Order Total:'),
          _formatMoney(currency, orderTotal), valueStyle));
    }
    if (showFinalReturn) {
      tableRows.add(summaryRow(lbl('showFinalReturn', 'Return Total:'),
          _formatMoney(currency, returnTotal), valueStyle));
    }
    if (showFinalNetAmount) {
      tableRows.add(summaryRow(lbl('showFinalNetAmount', 'Final Total:'),
          _formatMoney(currency, finalTotal), valueBold));
    }

    final widgets = <pw.Widget>[
      pw.SizedBox(height: 6),
      pw.Divider(height: 0, thickness: 0.8),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: tableRows,
      ),
    ];

    if (showFinalAmountInWords) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.addAll(_amountInWords(
          finalTotal, currency, isDualLanguage, configLang, wordsBold));
    }

    return widgets;
  }
}
