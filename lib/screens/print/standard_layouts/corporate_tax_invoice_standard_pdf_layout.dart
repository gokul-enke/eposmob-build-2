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
import 'standard_pdf_contract_delegate.dart';
import 'tax_invoice_returns_pdf_section.dart';

/// Corporate Tax Invoice PDF layout — formal bilingual A4/A5 tax invoice
/// matching the Makhdoom/Expert reference template.
///
/// Visual structure (top → bottom):
///   • Header band: logo (left) + bilingual company name (right), navy rule.
///   • Seller info block: name, Arabic name, address, country, CR No.
///   • Title (centered): Arabic + `TAX INVOICE` + `VAT NO:`.
///   • Bordered Invoice No. / Invoice Date row (bilingual).
///   • Buyer block (Name / VAT No. / Address) + QR (right).
///   • Method of Payment row.
///   • Items table — excl-VAT columns, English-over-Arabic item names.
///   • Totals: Taxable (excl VAT) / VAT 15% / Amount Due (SAR, bold).
///   • Bank details (left) + bilingual amount-in-words (right).
///   • Footer band: CR + contact (address / email / web).
///
/// All field visibility, data extraction, B2B/B2C title resolution, ZATCA QR
/// (with payment-gateway fallback), multi-payment breakdown, customer balance,
/// bilingual item names / amount-in-words and A4/A5 scaling follow the same
/// rules as the thermal `classic`/`premium2` layouts and the other standard
/// PDF layouts.
class CorporateTaxInvoiceStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'corporate_tax_invoice';

  @override
  String get displayName => 'Corporate Tax Invoice';

  /// Navy accent used for the company name, title and rules.
  static const PdfColor _navy = PdfColor.fromInt(0xFF1B3F73);

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
        tag: '[corporate_tax_invoice_standard_pdf_layout]');
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
    if (StandardPdfContractDelegate.enabled) {
      return StandardPdfContractDelegate.generateAndPrintPdf(
        params,
        layoutId: layoutId,
        displayName: displayName,
      );
    }
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
      jobName: 'Corporate Tax Invoice ${params.orderNumber}',
    )) {
      return;
    }

    final sanitized = params.orderNumber.replaceAll('/', '_');
    final output = await _getEposDirectory();
    final file = File('${output.path}/CorporateTaxInvoice_$sanitized.pdf');
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
    if (StandardPdfContractDelegate.enabled) {
      return StandardPdfContractDelegate.buildPdfDocument(
        params,
        layoutId: layoutId,
        displayName: displayName,
      );
    }
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
    // Laid out left-to-right by design (English primary with Arabic sub-labels);
    // Arabic runs carry their own per-widget RTL direction.

    double fs(double value) => (isA5 ? value * 0.78 : value);

    // ── Text styles ─────────────────────────────────────────────────
    final sellerNameStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(11), fontWeight: pw.FontWeight.bold);
    final sellerInfoStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final titleStyle = pw.TextStyle(
        font: fontBold,
        fontSize: fs(13),
        fontWeight: pw.FontWeight.bold,
        color: _navy);
    final titleArStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(11), fontWeight: pw.FontWeight.bold);
    final vatNoStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final infoLabel = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final infoValue =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final infoArStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8));
    final buyerHeading = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final itemsHeaderEn = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final itemsHeaderAr =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7.5));
    final itemsBodyStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final itemsBodyAr =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7.5));
    final totalsLabelEn =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(9));
    final totalsLabelAr =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final totalsValueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(9));
    final totalsDueEn = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final totalsDueValue = pw.TextStyle(
        font: fontBold, fontSize: fs(11), fontWeight: pw.FontWeight.bold);
    final bankHeading = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);
    final bankStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final wordsStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final wordsBold = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final footerStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8));
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
        debugPrint('[corporate_tax_invoice] payment QR fallback error: $e');
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

    // ── Bank details (API visibility flags) ─────────────────────────
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

    // ── Buyer (customer) info ───────────────────────────────────────
    final bool isDefault = params.isDefaultCustomer;
    final bool hideDefaultPhone = params.hideDefaultCustomerPhone;
    final custName =
        params.customerName ?? (isRtl ? 'عميل' : 'Walk-in Customer');
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

    final paymentMethodText =
        (params.paymentMethod == null || params.paymentMethod!.isEmpty)
            ? 'Cash'
            : (params.paymentMethod == 'CASH' ? 'Cash' : params.paymentMethod!);

    // ── Totals visibility ───────────────────────────────────────────
    final bool showTaxableFlag =
        (dc?['showSubTotal']?.visible ?? dc?['showMRPTotal']?.visible) != false;
    final bool showDiscountFlag = dc?['showDiscount']?.visible != false;
    final bool showTaxTotalFlag = dc?['showTax']?.visible != false;
    final bool showNetFlag = dc?['showNetAmount']?.visible != false;

    // ── Buyer rows ──────────────────────────────────────────────────
    final buyerRows = <pw.Widget>[];
    if (showCustomerSection) {
      if (showCustomerName) {
        buyerRows.add(_kvRow(_getLabel(dc, 'showCustomerName', null, 'Name:'),
            custName, infoLabel, infoValue));
      }
      if (showCustomerVat) {
        buyerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerVatNumber', null, 'VAT No.'),
            displayOrBlank(params.customerVatNumber),
            infoLabel,
            infoValue));
      }
      if (showCustomerCr) {
        buyerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerCrNumber', null, 'CR No.'),
            displayOrBlank(params.customerCrNumber),
            infoLabel,
            infoValue));
      }
      if (showCustomerAddress) {
        buyerRows.add(_kvRow(
            _getLabel(dc, 'showCustomerAddress', null, 'Address:'),
            displayOrBlank(custAddress),
            infoLabel,
            infoValue));
      }
      if (custPhone != null) {
        buyerRows.add(_kvRow(_getLabel(dc, 'showCustomerPhone', null, 'Phone:'),
            custPhone, infoLabel, infoValue));
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
            left: isA5 ? 16 : 26,
            right: isA5 ? 16 : 26,
            top: isA5 ? 14 : 20,
            bottom: isA5 ? 14 : 20),
        footer: (ctx) => pw.Center(
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: fs(6))),
        ),
        build: (pw.Context ctx) {
          return [
            // ═══════════════════════════════════════════════════════
            // SECTION 1: HEADER — logo only (above the rule)
            // ═══════════════════════════════════════════════════════
            if (logoImage != null)
              pw.Container(
                height: isA5 ? 42 : 56,
                alignment: pw.Alignment.centerLeft,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            if (logoImage != null) pw.SizedBox(height: 4),
            pw.Container(height: 2, color: _navy),
            pw.SizedBox(height: 8),

            // ═══════════════════════════════════════════════════════
            // SECTION 2: SELLER INFO BLOCK
            // ═══════════════════════════════════════════════════════
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _autoText(
                    documentHeader.isNotEmpty ? documentHeader : storeName,
                    sellerNameStyle),
                if (documentSubheader.isNotEmpty)
                  pw.Text(documentSubheader,
                      style: sellerInfoStyle,
                      textDirection: pw.TextDirection.rtl),
                if (cfgVisible('showDescription') && storeDesc.isNotEmpty)
                  _autoText(storeDesc, sellerInfoStyle),
                if (cfgVisible('showStoreAddress') && storeAddress.isNotEmpty)
                  _autoText(storeAddress, sellerInfoStyle),
                if (cfgVisible('showFssaiInfo') && storeFssai.isNotEmpty)
                  _autoText(storeFssai, sellerInfoStyle),
                if (cfgVisible('showExtraHeading1') && extraHeading1.isNotEmpty)
                  _autoText(extraHeading1, sellerInfoStyle),
                if (sellerCrNumber.isNotEmpty)
                  _autoText('CR No. $sellerCrNumber', sellerInfoStyle),
              ],
            ),
            pw.SizedBox(height: 8),

            // ═══════════════════════════════════════════════════════
            // SECTION 3: TITLE (centered)
            // ═══════════════════════════════════════════════════════
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(invoiceTitleArabic,
                      style: titleArStyle, textDirection: pw.TextDirection.rtl),
                  _autoText(invoiceTitleText.toUpperCase(), titleStyle),
                  if (params.zatcaVatNumber?.isNotEmpty == true)
                    pw.Text('VAT NO: ${params.zatcaVatNumber}',
                        style: vatNoStyle),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 4: INVOICE NO. / DATE ROW (bordered, bilingual)
            // ═══════════════════════════════════════════════════════
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(width: 0.5),
                  bottom: pw.BorderSide(width: 0.5),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        pw.Text('Invoice No. ', style: infoLabel),
                        pw.Text(invoiceNumber, style: infoValue),
                        pw.SizedBox(width: 6),
                        pw.Text('رقم الفاتورة',
                            style: infoArStyle,
                            textDirection: pw.TextDirection.rtl),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text('Invoice Date: ', style: infoLabel),
                        pw.Text(displayDate, style: infoValue),
                        pw.SizedBox(width: 6),
                        pw.Text('تاريخ إصدار الفاتورة',
                            style: infoArStyle,
                            textDirection: pw.TextDirection.rtl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // ═══════════════════════════════════════════════════════
            // SECTION 5: BUYER BLOCK + QR
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Buyer:', style: buyerHeading),
                      pw.SizedBox(height: 3),
                      ...buyerRows,
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                if (cfgVisible('showQRCode') && qrData.isNotEmpty)
                  pw.Container(
                    width: isA5 ? 64 : 84,
                    height: isA5 ? 64 : 84,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: isA5 ? 64 : 84,
                      height: isA5 ? 64 : 84,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ═══════════════════════════════════════════════════════
            // SECTION 6: METHOD OF PAYMENT ROW
            // ═══════════════════════════════════════════════════════
            if (showPayment) ...[
              pw.Divider(height: 0, thickness: 0.5),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Method of Payment ', style: infoLabel),
                    pw.Text(paymentMethodText, style: infoValue),
                    pw.SizedBox(width: 6),
                    pw.Text('طريقة الدفع',
                        style: infoArStyle,
                        textDirection: pw.TextDirection.rtl),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 7: ITEMS TABLE
            // ═══════════════════════════════════════════════════════
            if (!params.isReturnOnly) ...[
              _buildItemsTable(params, dc, resolvedLabels, itemsHeaderEn,
                  itemsHeaderAr, itemsBodyStyle, itemsBodyAr),
              pw.SizedBox(height: 8),

              // ═══════════════════════════════════════════════════════
              // SECTION 8: TOTALS (right-aligned, bilingual)
              // ═══════════════════════════════════════════════════════
              pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.SizedBox()),
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      children: [
                        pw.Divider(height: 0, thickness: 0.5),
                        pw.SizedBox(height: 3),
                        if (showTaxableFlag)
                          _totalsRow(
                              'Total Taxable Amount Excluding VAT',
                              'المبلغ الإجمالي الخاضع للضريبة بإستثناء',
                              _formatMoney(currency, netExcTaxValue),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showDiscountFlag && discountAmountValue != 0)
                          _totalsRow(
                              _labelEn(dc, 'showDiscount', null, 'Discount',
                                  isDualLanguage),
                              'الخصم',
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
                                  'Total VAT 15%',
                                  isDualLanguage),
                              'مجموع ضريبة القيمة المضافة ال 15%',
                              _formatMoney(currency, totalTax),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
                        if (showNetFlag) ...[
                          pw.SizedBox(height: 2),
                          pw.Divider(height: 0, thickness: 0.5),
                          _totalsRow(
                              _labelEn(dc, 'showNetAmount', null,
                                  'Total Amount Due', isDualLanguage),
                              'إجمالي المبلغ المستحق',
                              _formatMoney(currency, totalAmount),
                              totalsDueEn,
                              totalsLabelAr,
                              totalsDueValue),
                          pw.Divider(height: 0, thickness: 0.5),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // ═══════════════════════════════════════════════════════
              // SECTION 9: BANK DETAILS (left) + AMOUNT IN WORDS (right)
              // ═══════════════════════════════════════════════════════
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (bankLines.isNotEmpty) ...[
                          pw.Text('OUR BANK DETAILS | لتفاصيل المصرفية',
                              style: bankHeading),
                          pw.SizedBox(height: 2),
                          ...bankLines
                              .map((line) => _autoText(line, bankStyle)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (cfgVisible('showAmountInWords'))
                          ..._amountInWords(totalAmount, currency, wordsBold),
                        ...paymentLines,
                        ...balanceLines,
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
                        if (cfgVisibleDefault('showDate'))
                          pw.Text(
                              'Delivery Time: $displayDate${displayTime.isNotEmpty ? ' $displayTime' : ''}',
                              style: smallStyle),
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
            // TERMS & THANK YOU
            // ═══════════════════════════════════════════════════════
            if (cfgVisible('showTermsConditions')) ...[
              _autoText(_termsText(dc, config), smallStyle),
              pw.SizedBox(height: 4),
            ],
            if (cfgVisible('showThankYouMessage'))
              pw.Center(
                child: _autoText(
                    _thankYouText(dc, config, isEnglish), wordsBold,
                    textAlign: pw.TextAlign.center),
              ),
            pw.SizedBox(height: 8),

            // ═══════════════════════════════════════════════════════
            // SECTION 10: FOOTER BAND — CR + contact
            // ═══════════════════════════════════════════════════════
            pw.Container(height: 2, color: _navy),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (sellerCrNumber.isNotEmpty)
                  _autoText('CR $sellerCrNumber', footerStyle),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (cfgVisible('showStoreAddress') &&
                          storeAddress.isNotEmpty)
                        _autoText(storeAddress, footerStyle),
                      if (cfgVisible('showEmail') && storeEmail.isNotEmpty)
                        _autoText(storeEmail, footerStyle),
                      if (cfgVisible('showTel') && storeTel.isNotEmpty)
                        _autoText(storeTel, footerStyle),
                      if (cfgVisible('showVATFooter') &&
                          params.zatcaVatNumber?.isNotEmpty == true)
                        pw.Text(
                            '${cfgVal('showVATFooter', '').trim().isNotEmpty ? '${cfgVal('showVATFooter', '').trim()} ' : ''}${params.zatcaVatNumber}',
                            style: footerStyle),
                    ],
                  ),
                ),
              ],
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
    if (t.contains('tax')) return 'فاتورة ضريبة';
    if (t.contains('invoice')) return 'فاتورة';
    return 'فاتورة ضريبة';
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

  /// Bilingual amount-in-words (English then Arabic), as in the reference.
  List<pw.Widget> _amountInWords(
      double total, String currency, pw.TextStyle style) {
    final en = AmountHelper()
        .convertNumberToWords(total, currency: currency, language: 'en');
    final ar = AmountHelper()
        .convertNumberToWords(total, currency: currency, language: 'ar');
    return [
      pw.Text('$en Only.', style: style, textAlign: pw.TextAlign.right),
      pw.Text('$ar لا غير.',
          style: style,
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right),
    ];
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
        debugPrint('[corporate_tax_invoice] payment parse error: $e');
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

  /// Thank-you text: config value → billDocumentConfig.footer → default.
  String _thankYouText(
      Map<String, DisplayOption>? dc, DocumentConfig config, bool isEnglish) {
    final value = dc?['showThankYouMessage']?.value as String?;
    if (value != null && value.isNotEmpty) return value;
    if (config.footer?.isNotEmpty == true) return config.footer!;
    return isEnglish ? 'Thank you for your business' : 'شكراً لتسوقكم معنا';
  }

  /// Key/value row used in the buyer block.
  pw.Widget _kvRow(String label, String value, pw.TextStyle labelStyle,
      pw.TextStyle valueStyle,
      {double labelWidth = 64}) {
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

  /// Totals row: EN label (left) | AR label (right) | value (right).
  pw.Widget _totalsRow(String en, String ar, String value, pw.TextStyle enStyle,
      pw.TextStyle arStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
              flex: 4,
              child: pw.Text(en, style: enStyle, textDirection: _dirOf(en))),
          pw.Expanded(
            flex: 4,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(ar,
                  style: arStyle, textDirection: pw.TextDirection.rtl),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(value, style: valueStyle),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolve English + Arabic product names (English on line 1, Arabic line 2).
  List<String> _itemNames(dynamic item, ReceiptLayoutParams params) {
    String en = '';
    String ar = '';
    if (params.isFromLocalStorage || item is Map) {
      en = (item['product_name'] ?? item['productName'] ?? '').toString();
      final n = item['product_names'] ?? item['productNames'] ?? item['names'];
      if (n is Map) ar = (n['ar'] ?? n['arabic'] ?? '').toString();
    } else {
      try {
        en = item.names?.en ?? item.productName ?? '';
        ar = item.names?.ar ?? '';
      } catch (_) {
        try {
          en = item.productName ?? '';
        } catch (_) {}
      }
    }
    return [en.trim(), ar.trim()];
  }

  pw.Widget _buildItemsTable(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    ResolvedLabels? resolvedLabels,
    pw.TextStyle headerEn,
    pw.TextStyle headerAr,
    pw.TextStyle bodyStyle,
    pw.TextStyle bodyAr,
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
    if (showSL) colWidths[ci++] = const pw.FlexColumnWidth(0.7);
    if (showItems) colWidths[ci++] = const pw.FlexColumnWidth(4.5);
    if (showMRP) colWidths[ci++] = const pw.FlexColumnWidth(1.1);
    if (showQty) colWidths[ci++] = const pw.FlexColumnWidth(1.1);
    if (showRate) colWidths[ci++] = const pw.FlexColumnWidth(1.3);
    if (showRateExcTax) colWidths[ci++] = const pw.FlexColumnWidth(1.3);
    if (showUnit) colWidths[ci++] = const pw.FlexColumnWidth(0.9);
    if (showDiscountColumn) colWidths[ci++] = const pw.FlexColumnWidth(1.0);
    // Total Amount (taxable / excl-VAT line total) — always shown.
    colWidths[ci++] = const pw.FlexColumnWidth(1.4);
    if (showTax) colWidths[ci++] = const pw.FlexColumnWidth(1.1);
    if (showTotal) colWidths[ci++] = const pw.FlexColumnWidth(1.4);

    // Bilingual header cell — Arabic on top, English below (reference order).
    pw.Widget hdr(String en, String ar, {pw.Alignment? align}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: align == pw.Alignment.centerLeft
              ? pw.CrossAxisAlignment.start
              : pw.CrossAxisAlignment.center,
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
              dc, 'showSLNumber', resolvedLabels?.slNumberDefault, 'S/N', isAr),
          _labelAr(
              dc, 'showSLNumber', resolvedLabels?.slNumber, 'التسلسل', isAr)));
    }
    if (showItems) {
      hdrs.add(hdr(
          _labelEn(dc, 'showParticulars', resolvedLabels?.particularsDefault,
              'Description', isAr),
          _labelAr(dc, 'showParticulars', resolvedLabels?.particulars, 'البيان',
              isAr),
          align: pw.Alignment.centerLeft));
    }
    if (showMRP) {
      hdrs.add(hdr(_labelEn(dc, 'showMRP', null, 'MRP', isAr),
          _labelAr(dc, 'showMRP', resolvedLabels?.mrp, 'القيمة', isAr)));
    }
    if (showQty) {
      hdrs.add(hdr(
          _labelEn(dc, 'showQty', resolvedLabels?.qtyDefault, 'Quantity', isAr),
          _labelAr(dc, 'showQty', resolvedLabels?.qty, 'الكمية', isAr)));
    }
    if (showRate) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showRate', resolvedLabels?.rateDefault, 'Unit Price', isAr),
          _labelAr(dc, 'showRate', resolvedLabels?.rate, 'سعر الوحدة', isAr)));
    }
    if (showRateExcTax) {
      hdrs.add(hdr(
          _labelEn(dc, 'showRateExcTax', null, 'Unit Price (Ex Tax)', isAr),
          _labelAr(dc, 'showRateExcTax', null, 'السعر بدون ضريبة', isAr)));
    }
    if (showUnit) {
      hdrs.add(hdr(_labelEn(dc, 'showUnit', null, 'Unit', isAr),
          _labelAr(dc, 'showUnit', resolvedLabels?.unitName, 'الوحدة', isAr)));
    }
    if (showDiscountColumn) {
      hdrs.add(hdr(_labelEn(dc, 'showDiscountColumn', null, 'Discount', isAr),
          _labelAr(dc, 'showDiscountColumn', null, 'الخصم', isAr)));
    }
    // Total Amount (taxable) — always shown.
    hdrs.add(hdr('Total Amount', 'مبلغ الإجمالي'));
    if (showTax) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showTaxHeader', resolvedLabels?.taxDefault, 'VAT 15%', isAr),
          _labelAr(dc, 'showTaxHeader', resolvedLabels?.tax, 'الضريبة', isAr)));
    }
    if (showTotal) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showTotal', resolvedLabels?.totalDefault, 'Net Total', isAr),
          _labelAr(dc, 'showTotal', resolvedLabels?.total, 'الإجمالي', isAr)));
    }

    final rows = <pw.TableRow>[];
    for (int i = 0; i < params.cartItems.length; i++) {
      final item = params.cartItems[i];
      double mrp = 0,
          qty = 0,
          unitPrice = 0,
          iDiscount = 0,
          iTax = 0,
          iTotal = 0;
      String unitName = '';

      if (params.isFromLocalStorage) {
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
      final double taxPerUnit = qty > 0 ? (iTax / qty) : 0;
      final double rateExcTax = unitPrice - taxPerUnit;

      final names = _itemNames(item, params);
      final enName = names[0];
      final arName = names[1];

      final cells = <pw.Widget>[];
      if (showSL) cells.add(_dataCell('${i + 1}', bodyStyle));
      if (showItems)
        cells.add(_itemNameCell(enName, arName, bodyStyle, bodyAr));
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
      // Total Amount (excl VAT) — always shown.
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
      border: const pw.TableBorder(
        top: pw.BorderSide(width: 0.5),
        bottom: pw.BorderSide(width: 0.5),
        horizontalInside: pw.BorderSide(width: 0.3),
      ),
      columnWidths: colWidths,
      children: [
        pw.TableRow(children: hdrs),
        ...rows,
      ],
    );
  }

  /// Item-name cell: English on line 1, Arabic on line 2.
  pw.Widget _itemNameCell(
      String en, String ar, pw.TextStyle enStyle, pw.TextStyle arStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (en.isNotEmpty)
            pw.Text(en, style: enStyle, textDirection: _dirOf(en)),
          if (ar.isNotEmpty)
            pw.Text(ar, style: arStyle, textDirection: pw.TextDirection.rtl),
        ],
      ),
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
