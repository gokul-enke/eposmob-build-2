import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:pos_machine/resources/localization_service.dart';
import '../logo_loader.dart';
import 'standard_pdf_layout.dart';
import 'tax_invoice_returns_pdf_section.dart';

/// Letterhead Tax Invoice PDF layout — bilingual ZATCA tax invoice with a
/// tri-column letterhead, matching the Architectural Power Trading reference.
///
/// Visual structure (top → bottom):
///   • Letterhead: English company block (left) · logo + C.R + email (center)
///     · Arabic company block (right).
///   • Boxed title: `TAX INVOICE  فاتورة ضريبية`.
///   • Info band: customer box (left) + invoice box (middle, incl. Page x/y)
///     + QR (right).
///   • Items table with Arabic-over-English bilingual column headers.
///   • Totals: amount-in-words / payment / balance (left) + bilingual totals
///     box (right).
///   • Footer: tagline (thank-you) + account / IBAN line.
///
/// All field visibility, data extraction, B2B/B2C title resolution, ZATCA QR
/// (with payment-gateway fallback), multi-payment breakdown, customer balance,
/// bilingual item names / amount-in-words and A4/A5 scaling follow the same
/// rules as the thermal `classic`/`premium2` layouts and the other standard
/// PDF layouts.
class LetterheadTaxInvoiceStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'letterhead_tax_invoice';

  @override
  String get displayName => 'Letterhead Tax Invoice';

  /// Maroon accent used for the company name, title box and footer rule.
  static const PdfColor _maroon = PdfColor.fromInt(0xFF7A1F2B);

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
        tag: '[letterhead_tax_invoice_standard_pdf_layout]');
  }

  String _formatMoney(String currency, num amount) {
    final currencyPrefix =
        currency.trim().toUpperCase() == 'INR' ? '₹' : currency.trim();
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
      {pw.TextAlign? textAlign, int? maxLines, bool? softWrap}) {
    return pw.Text(text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: softWrap,
        textDirection: _dirOf(text));
  }

  // ── Public interface ────────────────────────────────────────────────
  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    final pdf = await buildPdfDocument(params);
    final sanitized = params.orderNumber.replaceAll('/', '_');
    final output = await _getEposDirectory();
    final file = File('${output.path}/LetterheadTaxInvoice_$sanitized.pdf');
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
            : 'Tax Invoice');
    final invoiceTitleArabic = _arabicTitleFor(invoiceTitleText);

    // ── Fonts & language ────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    final configLang = config.language;
    final isRtl = configLang != null
        ? configLang.toLowerCase() == 'ar'
        : LocalizationService.locale.languageCode == 'ar';
    final isEnglish = !isRtl;
    final isDualLanguage = (configLang ?? '').toLowerCase() == 'ar';

    double fs(double value) => (isA5 ? value * 0.78 : value);

    // ── Text styles ─────────────────────────────────────────────────
    final companyNameStyle = pw.TextStyle(
        font: fontBold,
        fontSize: fs(13),
        fontWeight: pw.FontWeight.bold,
        color: _maroon);
    final companyNameArStyle = pw.TextStyle(
        font: fontBold,
        fontSize: fs(12),
        fontWeight: pw.FontWeight.bold,
        color: _maroon);
    final letterheadStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8));
    final centerInfoStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7.5));
    final titleStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(13), fontWeight: pw.FontWeight.bold);
    final titleArStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(12), fontWeight: pw.FontWeight.bold);
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
    final taglineStyle = pw.TextStyle(
        font: fontBold,
        fontSize: fs(9),
        fontWeight: pw.FontWeight.bold,
        fontStyle: pw.FontStyle.italic,
        color: _maroon);
    final wordsStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final wordsBold = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
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
    final double netExcTaxValue = params.netExcTax != null
        ? (double.tryParse(params.netExcTax!) ?? totalExclTax)
        : totalExclTax;
    final double grossExclTax = netExcTaxValue + discountAmountValue;

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
        debugPrint('[letterhead_tax_invoice] payment QR fallback error: $e');
      }
    }

    // ── Store / seller info from config ─────────────────────────────
    final documentHeader = (config.header ?? '').trim();
    final documentSubheader = (config.subheader ?? '').trim();
    final cfgStoreName = cfgVal('showStoreName', '');
    final storeName = cfgStoreName.isNotEmpty
        ? cfgStoreName
        : (params.storeName?.isNotEmpty == true
            ? params.storeName!
            : 'STORE NAME');
    final storeDesc = cfgVal('showDescription', '');
    final addressLabel = cfgVal('showStoreAddress', '');
    final addressVal = params.storeLocation ?? '';
    final storeAddress = addressVal.isNotEmpty
        ? (addressLabel.isNotEmpty ? '$addressLabel: $addressVal' : addressVal)
        : '';
    final storeFssai = cfgVal('showFssaiInfo', '');
    final extraHeading1 = cfgVal('showExtraHeading1', '');
    final telLabel = cfgVal('showTel', '');
    final telVal = params.storePhone?.isNotEmpty == true
        ? params.storePhone!
        : params.customerCareNumber;
    final storeTel = telVal.isNotEmpty
        ? (telLabel.isNotEmpty ? '$telLabel: $telVal' : telVal)
        : '';
    final emailLabel = cfgVal('showEmail', '');
    final emailVal = params.storeEmail?.isNotEmpty == true
        ? params.storeEmail!
        : params.customerCareEmail;
    final storeEmail = emailVal.isNotEmpty
        ? (emailLabel.isNotEmpty ? '$emailLabel: $emailVal' : emailVal)
        : '';
    final sellerCrNumber = cfgVal('showExtraHeading2', '');
    final ibanValue = params.primaryBankAccount?.iban ?? '';
    final accountNumberValue = params.primaryBankAccount?.accountNumber ?? '';

    final sellerNameEn = documentHeader.isNotEmpty ? documentHeader : storeName;

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

    // ── Date (ISO/IST aware) ────────────────────────────────────────
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
    final bool showPayment = cfgVisibleDefault(paymentConfigKey);
    final bool showComment = cfgVisibleDefault(commentConfigKey);
    final bool showDeliveryMethod = cfgVisibleDefault('showDeliveryMethod');

    final cashCreditText = (params.paymentMethod == null ||
            params.paymentMethod!.isEmpty ||
            params.paymentMethod == 'CASH')
        ? 'Cash'
        : 'Credit';
    final deliveryNoteNo = (cfgVisible('showTokenNumber') &&
            params.tokenNumber != null &&
            params.tokenNumber!.isNotEmpty)
        ? '${cfgVal('showTokenNumber', '')}${params.tokenNumber}'
        : '';

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
      customerRows.add(_kvRow('PO No.', '', infoLabel, infoValue));
      if (custPhone != null) {
        customerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerPhone', null, 'Phone'),
            custPhone,
            infoLabel,
            infoValue));
      }
    }

    // ── Payment breakdown / balance lines ───────────────────────────
    final paymentLines =
        _buildPaymentBreakdownLines(params, currency, wordsStyle, dc);
    final balanceLines =
        _customerBalanceLines(params, dc, currency, wordsStyle, wordsBold);

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
          // Invoice box rows. The live page count isn't known during the body
          // build phase (ctx.pageNumber is null here — only valid in the
          // footer), so the box shows a static "1 of 1"; the footer renders the
          // authoritative running page numbers.
          final invoiceRows = <pw.Widget>[
            _kvRow('Invoice No.', invoiceNumber, infoLabel, infoValue),
            _kvRow('Date:', displayDate, infoLabel, infoValue),
            if (showPayment)
              _kvRow('Cash/Credit:', cashCreditText, infoLabel, infoValue),
            _kvRow('Delivery Note No:', deliveryNoteNo, infoLabel, infoValue),
            _kvRow('Page', '1 of 1', infoLabel, infoValue),
          ];

          return [
            // ═══════════════════════════════════════════════════════
            // SECTION 1: LETTERHEAD — EN block | logo/CR/email | AR block
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // English company block
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _autoText(sellerNameEn, companyNameStyle),
                      if (cfgVisible('showStoreAddress') &&
                          storeAddress.isNotEmpty)
                        _autoText(storeAddress, letterheadStyle),
                      if (cfgVisible('showFssaiInfo') && storeFssai.isNotEmpty)
                        _autoText(storeFssai, letterheadStyle),
                      if (cfgVisible('showExtraHeading1') &&
                          extraHeading1.isNotEmpty)
                        _autoText(extraHeading1, letterheadStyle),
                      if (params.zatcaVatNumber?.isNotEmpty == true)
                        pw.Text('VAT NO . ${params.zatcaVatNumber}',
                            style: letterheadStyle),
                    ],
                  ),
                ),
                // Center: logo + C.R + email
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                            height: isA5 ? 34 : 46,
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
                      if (sellerCrNumber.isNotEmpty)
                        _autoText('C.R.$sellerCrNumber', centerInfoStyle),
                      if (cfgVisible('showEmail') && storeEmail.isNotEmpty)
                        _autoText(storeEmail, centerInfoStyle),
                    ],
                  ),
                ),
                // Arabic company block
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (documentSubheader.isNotEmpty)
                        pw.Text(documentSubheader,
                            style: companyNameArStyle,
                            textDirection: pw.TextDirection.rtl),
                      if (cfgVisible('showDescription') && storeDesc.isNotEmpty)
                        pw.Text(storeDesc,
                            style: letterheadStyle,
                            textDirection: pw.TextDirection.rtl),
                      if (params.zatcaVatNumber?.isNotEmpty == true)
                        pw.Text('رقم الضريبية ${params.zatcaVatNumber}',
                            style: letterheadStyle,
                            textDirection: pw.TextDirection.rtl),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 2: BOXED TITLE
            // ═══════════════════════════════════════════════════════
            pw.Center(
              child: pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _autoText(invoiceTitleText.toUpperCase(), titleStyle),
                    pw.SizedBox(width: 10),
                    pw.Text(invoiceTitleArabic,
                        style: titleArStyle,
                        textDirection: pw.TextDirection.rtl),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 3: INFO BAND — customer | invoice | QR
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    height: isA5 ? 64 : 80,
                    decoration:
                        pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children:
                          customerRows.isEmpty ? [pw.SizedBox()] : customerRows,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    height: isA5 ? 64 : 80,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(width: 0.5),
                        bottom: pw.BorderSide(width: 0.5),
                        right: pw.BorderSide(width: 0.5),
                      ),
                    ),
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: invoiceRows,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                if (cfgVisible('showQRCode') && qrData.isNotEmpty)
                  pw.Container(
                    width: isA5 ? 60 : 76,
                    height: isA5 ? 60 : 76,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: isA5 ? 60 : 76,
                      height: isA5 ? 60 : 76,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 4: ITEMS TABLE (fully config-driven columns)
            // ═══════════════════════════════════════════════════════
            if (!params.isReturnOnly) ...[
              _buildItemsTable(params, dc, resolvedLabels, itemsHeaderEn,
                  itemsHeaderAr, itemsBodyStyle),
              pw.SizedBox(height: 6),

              // ═══════════════════════════════════════════════════════
              // SECTION 5: LEFT INFO + TOTALS BOX
              // ═══════════════════════════════════════════════════════
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
                              'Delivery Time: $displayDate${displayTime.isNotEmpty ? ' $displayTime' : ''}',
                              style: smallStyle),
                        if (showPayment && params.paymentMethod != null)
                          _autoText(
                              '${_getLabel(dc, paymentConfigKey, null, 'Payment Method')}: ${params.paymentMethod}',
                              smallStyle),
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
                        ...balanceLines,
                        if (cfgVisible('showItemsCount'))
                          pw.Text(
                              '${_getLabel(dc, 'showItemsCount', null, 'Items')}: ${params.cartItems.length}',
                              style: wordsStyle),
                        if (cfgVisible('showQuantityCount'))
                          pw.Text(
                              '${_getLabel(dc, 'showQuantityCount', null, 'Total Qty')}: ${params.totalQuantity % 1 == 0 ? params.totalQuantity.toInt().toString() : params.totalQuantity.toStringAsFixed(2)}',
                              style: wordsStyle),
                        if (cfgVisible('showSaved') && saved > 0)
                          pw.Text(
                              '${_getLabel(dc, 'showSaved', null, 'You Saved:')} ${_formatMoney(currency, saved)}',
                              style: wordsBold),
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
                              'TOTAL',
                              'المجموع',
                              _formatMoney(currency, grossExclTax),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showDiscountFlag && discountAmountValue != 0)
                          _totalsRow(
                              _labelEn(dc, 'showDiscount', null, 'DISCOUNT',
                                  isDualLanguage),
                              'خصم',
                              _formatMoney(currency, discountAmountValue),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showSubTotalFlag)
                          _totalsRow(
                              _labelEn(dc, 'showSubTotal', null, 'SUB TOTAL',
                                  isDualLanguage),
                              'المجموع الفرعي',
                              _formatMoney(currency, netExcTaxValue),
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
                              'ضريبة القيمة المضافة',
                              _formatMoney(currency, totalTax),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showNetFlag)
                          _totalsRow(
                              _labelEn(dc, 'showNetAmount', null, 'NET AMOUNT',
                                  isDualLanguage),
                              'المبلغ الصافي',
                              _formatMoney(currency, totalAmount),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueBold),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],

            if (params.orderReturns != null &&
                params.orderReturns!.returnItems != null &&
                params.orderReturns!.returnItems!.isNotEmpty) ...[
              ...TaxInvoiceReturnsPdfSection.buildReturnsSection(
                  params, dc, currency, font, fontBold, isA5),
              if (!params.isReturnOnly)
                ...TaxInvoiceReturnsPdfSection.buildFinalSummarySection(
                    params, dc, currency, font, fontBold, isA5,
                    isDualLanguage: isDualLanguage, configLang: configLang),
            ],

            // ═══════════════════════════════════════════════════════
            // TERMS
            // ═══════════════════════════════════════════════════════
            if (cfgVisible('showTermsConditions')) ...[
              _autoText(_termsText(dc, config), smallStyle),
              pw.SizedBox(height: 4),
            ],

            // ═══════════════════════════════════════════════════════
            // SECTION 6: FOOTER — tagline + account/IBAN
            // ═══════════════════════════════════════════════════════
            pw.Container(height: 1.5, color: _maroon),
            pw.SizedBox(height: 4),
            if (cfgVisible('showThankYouMessage'))
              pw.Center(
                child: _autoText(
                    _thankYouText(dc, config, isEnglish), taglineStyle,
                    textAlign: pw.TextAlign.center),
              ),
            if (accountNumberValue.isNotEmpty || ibanValue.isNotEmpty)
              pw.Center(
                child: _autoText(
                  'ACCOUNT NUMBER AT ${displayOrBlank(accountNumberValue)}${ibanValue.isNotEmpty ? ' / IBAN ${displayOrBlank(ibanValue)}' : ''}',
                  footerStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            if (cfgVisible('showTel') && storeTel.isNotEmpty)
              pw.Center(
                child: _autoText(storeTel, footerStyle,
                    textAlign: pw.TextAlign.center),
              ),
          ];
        },
      ),
    );

    return pdf;
  }

  // ══════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════

  /// Maps a (freeform, English) invoice title to its Arabic equivalent.
  String _arabicTitleFor(String englishTitle) {
    final t = englishTitle.toLowerCase().trim();
    if (t.contains('simplified')) return 'فاتورة ضريبية مبسطة';
    if (t.contains('quotation') || t.contains('quote')) return 'عرض سعر';
    if (t.contains('credit note')) return 'إشعار دائن';
    if (t.contains('debit note')) return 'إشعار مدين';
    if (t.contains('return')) return 'فاتورة مرتجع';
    if (t.contains('tax')) return 'فاتورة ضريبية';
    if (t.contains('invoice')) return 'فاتورة';
    return 'فاتورة ضريبية';
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
  /// Mirrors the English half of the thermal `_getBilingualLabel`.
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

    if (params.paymentBreakdown != null &&
        params.paymentBreakdown!.isNotEmpty) {
      isMulti = true;
      params.paymentBreakdown!.forEach((method, amount) {
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
        debugPrint('[letterhead_tax_invoice] payment parse error: $e');
      }
    }

    if (!isMulti) {
      String label = 'Cash';
      if (params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty &&
          params.paymentMethod != 'CASH' &&
          !params.paymentMethod!.startsWith('{')) {
        label = params.paymentMethod!;
      }
      lines.add(pw.Text('$label: ${_formatMoney(currency, params.paidAmount!)}',
          style: style));
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

  /// Thank-you / tagline text: config value → billDocumentConfig.footer →
  /// default.
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

  pw.Widget _buildItemsTable(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    ResolvedLabels? resolvedLabels,
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
    // AMOUNT (taxable / excl-VAT line total) — always shown.
    colWidths[ci++] = const pw.FlexColumnWidth(1.3);
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
          _labelAr(dc, 'showSLNumber', resolvedLabels?.slNumber, 'م', isAr)));
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
          _labelAr(dc, 'showRate', resolvedLabels?.rate, 'سعر الوحدة', isAr)));
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
    // AMOUNT (taxable) — always shown.
    hdrs.add(hdr('AMOUNT', 'مقدار'));
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

      final double taxableAmt = iTotal - iTax;

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
        final double taxPerUnit = qty > 0 ? (iTax / qty) : 0;
        cells.add(_dataCell(
            (unitPrice - taxPerUnit).toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showUnit) {
        cells.add(_dataCell(unitName, bodyStyle));
      }
      if (showDiscountColumn) {
        cells.add(_dataCell(iDiscount.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      // AMOUNT (excl VAT) — always shown.
      cells.add(_dataCell(taxableAmt.toStringAsFixed(2), bodyStyle,
          align: pw.Alignment.centerRight));
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
}
