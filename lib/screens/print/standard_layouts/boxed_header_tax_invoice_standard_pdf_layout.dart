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

/// Boxed bilingual tax-invoice PDF with a reference-style full-width logo,
/// metadata strip, seller/buyer boxes, fixed six-column items table, and a
/// bank-details / QR / totals footer row.
///
/// All field visibility, data extraction, B2B/B2C title resolution, ZATCA QR
/// (with payment-gateway fallback), multi-payment breakdown, customer balance,
/// bilingual item names, bilingual amount-in-words and A4/A5 scaling follow the
/// same rules as the thermal `classic`/`premium2` layouts and the other
/// standard PDF layouts.
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

  Future<pw.MemoryImage?> _fetchNetworkPdfImage(String? url) async {
    return PrintLogoLoader.loadPdfLogo(url,
        tag: '[boxed_bilingual_tax_invoice_standard_pdf_layout]');
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
    // `params.displayConfig` preserves every API option and overlays the
    // B2B/B2C-resolved invoice-title option when required.
    final dc = params.displayConfig ?? config.displayConfiguration?.options;
    final resolvedLabels = config.resolvedLabels;
    final isA5 = params.selectedPaperSize.toUpperCase() == 'A5';
    final pageFormat = isA5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
    // The QR column is narrower after the summary row becomes a
    // bank-details | QR | totals layout. Keep the A5 QR inside that column.
    final summaryQrSize = isA5 ? 68.0 : 100.0;

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

    String maskBankValue(String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty) return '<empty>';
      if (trimmed.length <= 4) return '****';
      return '****${trimmed.substring(trimmed.length - 4)}';
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
            '[boxed_bilingual_tax_invoice] payment QR fallback error: $e');
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
    final savedSellerCrNumber = params.zatcaCrNumber?.trim() ?? '';
    final configuredSellerCrNumber = cfgVal('showCRNumber', '').trim();
    final sellerCrNumber = savedSellerCrNumber.isNotEmpty
        ? savedSellerCrNumber
        : configuredSellerCrNumber;
    final savedSellerVatNumber = params.zatcaVatNumber?.trim() ?? '';
    final configuredSellerVatNumber = cfgVal('showVatNumber', '').trim();
    final sellerVatNumber = savedSellerVatNumber.isNotEmpty
        ? savedSellerVatNumber
        : configuredSellerVatNumber;
    if (sellerCrNumber.isNotEmpty) {
      englishHeaderLines.add('CR No: $sellerCrNumber');
      arabicHeaderLines.add('رقم السجل التجاري: $sellerCrNumber');
    }
    if (sellerVatNumber.isNotEmpty) {
      englishHeaderLines.add('VAT No: $sellerVatNumber');
      arabicHeaderLines.add('الرقم الضريبي: $sellerVatNumber');
    }
    final primaryBank = params.primaryBank;
    final primaryBankAccount = params.primaryBankAccount;
    final ibanValue = primaryBankAccount?.iban ?? '';
    final accountNumberValue = primaryBankAccount?.accountNumber ?? '';

    // These keys match the API's display_configuration schema.
    final showBankInfo = cfgVisible('showBankInfo');
    final showBankName = cfgVisible('showBankName');
    final showAccountName = cfgVisible('showAccountName');
    final showAccountNumber = cfgVisible('showAccountNumber');
    final showIban = cfgVisible('showIBAN');
    final showSwiftCode = cfgVisible('showSwiftCode');
    final bankLines = params.visibleBankAccountDetailLines(dc);

    debugPrint('[BoxedBilingualTaxInvoice][Bank] order=${params.orderNumber} '
        'bankDetailsCount=${params.bankDetails.length} '
        'primaryBank=${primaryBank?.bankName ?? '<none>'} '
        'accountCount=${primaryBank?.bankAccounts.length ?? 0}');
    debugPrint('[BoxedBilingualTaxInvoice][Bank] '
        'accountNumber=${maskBankValue(accountNumberValue)} '
        'iban=${maskBankValue(ibanValue)} '
        'accountHolderPresent=${primaryBankAccount?.accountHolderName?.trim().isNotEmpty == true} '
        'ifscPresent=${primaryBankAccount?.ifsc?.trim().isNotEmpty == true} '
        'swiftPresent=${primaryBankAccount?.swiftCode?.trim().isNotEmpty == true}');
    debugPrint('[BoxedBilingualTaxInvoice][Bank] flags '
        'showBankInfo=$showBankInfo '
        'showBankName=$showBankName '
        'showAccountName=$showAccountName '
        'showAccountNumber=$showAccountNumber '
        'showIBAN=$showIban '
        'showSwiftCode=$showSwiftCode '
        'configuredLineCount=${bankLines.length} '
        'willRender=${bankLines.isNotEmpty}');

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
    final bool hasSummaryComment = showComment &&
        params.orderComment != null &&
        params.orderComment!.isNotEmpty;
    final customerBalanceSummaryLines =
        _customerBalanceLines(params, dc, currency, wordsStyle, wordsBold);
    final bool showSavedSummary = cfgVisible('showSaved') && saved > 0;
    final bool hasLeftSummaryContent =
        bankLines.isNotEmpty || hasSummaryComment || showSavedSummary;

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
            _infoLabel(
                _labelEn(
                    dc, 'showCustomerName', null, 'Customer', isDualLanguage),
                _labelAr(
                    dc, 'showCustomerName', null, 'العميل', isDualLanguage),
                isDualLanguage),
            custName,
            infoLabel,
            infoValue));
      }
      if (showCustomerAddress) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(
                    dc, 'showCustomerAddress', null, 'Address', isDualLanguage),
                _labelAr(
                    dc, 'showCustomerAddress', null, 'العنوان', isDualLanguage),
                isDualLanguage),
            displayOrBlank(custAddress),
            infoLabel,
            infoValue));
      }
      if (showCustomerVat) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(dc, 'showCustomerVatNumber', null, 'Customer VAT No.',
                    isDualLanguage),
                _labelAr(dc, 'showCustomerVatNumber', null,
                    'الرقم الضريبي للعميل', isDualLanguage),
                isDualLanguage),
            displayOrBlank(params.customerVatNumber),
            infoLabel,
            infoValue));
      }
      if (showCustomerCr) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(dc, 'showCustomerCrNumber', null, 'Customer CR No.',
                    isDualLanguage),
                _labelAr(dc, 'showCustomerCrNumber', null,
                    'رقم السجل التجاري للعميل', isDualLanguage),
                isDualLanguage),
            displayOrBlank(params.customerCrNumber),
            infoLabel,
            infoValue));
      }
      if (custPhone != null) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(
                    dc, 'showCustomerPhone', null, 'Phone', isDualLanguage),
                _labelAr(
                    dc, 'showCustomerPhone', null, 'الهاتف', isDualLanguage),
                isDualLanguage),
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
        _kvRow(
            _infoLabel(
                _labelEn(dc, 'showInvoiceNumber', null, numberLabelDefault,
                    isDualLanguage),
                _labelAr(
                    dc,
                    'showInvoiceNumber',
                    null,
                    isQuotation ? 'رقم عرض السعر' : 'رقم الفاتورة',
                    isDualLanguage),
                isDualLanguage),
            invoiceNumber,
            infoLabel,
            infoValue),
      if (cfgVisibleDefault('showDate'))
        _kvRow(
            _infoLabel(
                _labelEn(dc, 'showDate', null, 'Date', isDualLanguage),
                _labelAr(dc, 'showDate', null, 'التاريخ', isDualLanguage),
                isDualLanguage),
            '$displayDate${displayTime.isNotEmpty ? ' $displayTime' : ''}',
            infoLabel,
            infoValue),
      if (showPayment && paymentMethodSummary.isNotEmpty)
        _kvRow(
            _infoLabel(
                _labelEn(dc, paymentConfigKey, null, 'Payment Method',
                    isDualLanguage),
                _labelAr(
                    dc, paymentConfigKey, null, 'طريقة الدفع', isDualLanguage),
                isDualLanguage),
            paymentMethodSummary,
            infoLabel,
            infoValue),
      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty)
        _kvRow(
            _infoLabel(
                _labelEn(
                    dc, 'showDeliveryMethod', null, 'Delivery', isDualLanguage),
                _labelAr(dc, 'showDeliveryMethod', null, 'طريقة التسليم',
                    isDualLanguage),
                isDualLanguage),
            params.deliveryMethod!,
            infoLabel,
            infoValue),
    ];

    final runtimeSellerName = params.storeName?.trim().isNotEmpty == true
        ? params.storeName!.trim()
        : params.zatcaCompanyName?.trim();
    final referenceSellerName = _referenceConfiguredTextLines(
      dc,
      'showStoreName',
      runtimeSellerName ?? 'Seller',
      isDualLanguage,
    ).join(' / ');
    final sellerAddressOption = dc?['showStoreAddress'];
    final localizedSellerAddress =
        sellerAddressOption?.value?.toString().trim() ?? '';
    final englishSellerAddress =
        sellerAddressOption?.defaultValue?.trim() ?? '';
    final runtimeSellerAddress = params.storeLocation?.trim() ?? '';
    final referenceSellerAddress =
        isDualLanguage && englishSellerAddress.isNotEmpty
            ? englishSellerAddress
            : (localizedSellerAddress.isNotEmpty
                ? localizedSellerAddress
                : (englishSellerAddress.isNotEmpty
                    ? englishSellerAddress
                    : runtimeSellerAddress));
    final referenceSellerAddressSecondary = isDualLanguage &&
            localizedSellerAddress.isNotEmpty &&
            localizedSellerAddress != referenceSellerAddress
        ? localizedSellerAddress
        : null;
    final referenceBuyerAddress = params.customerAddress?.trim() ?? '';
    final referenceDueDate = displayDate;
    final referenceGross = netExcTaxValue + discountAmountValue;

    // ── Payment breakdown lines (left column) ───────────────────────
    // ══════════════════════════════════════════════════════════════════
    // BUILD PDF
    // ══════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: pw.EdgeInsets.all(isA5 ? 8 : 10),
        build: (pw.Context ctx) {
          if (layoutId == 'boxed_bilingual_tax_invoice') {
            final referenceValueStyle = pw.TextStyle(
              font: font,
              fontBold: fontBold,
              fontSize: fs(8),
            );
            final referenceTitleStyle = pw.TextStyle(
              font: fontBold,
              fontSize: fs(9),
              fontWeight: pw.FontWeight.bold,
            );
            final referenceFooterBold = pw.TextStyle(
              font: fontBold,
              fontSize: fs(7.5),
              fontWeight: pw.FontWeight.bold,
            );
            final referenceSignatureStyle = pw.TextStyle(
              font: fontBold,
              fontSize: fs(8),
              fontWeight: pw.FontWeight.bold,
            );
            final referenceSignatureArStyle = pw.TextStyle(
              font: font,
              fontBold: fontBold,
              fontSize: fs(8),
            );

            pw.Widget metadataValue(String value) => pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  child: _autoText(value, referenceValueStyle,
                      textAlign: pw.TextAlign.left),
                );

            final referenceMetadata =
                <({String english, String arabic, String value})>[
              if (cfgVisibleDefault('showDate'))
                (
                  english: _labelEn(
                    dc,
                    'showDate',
                    isDualLanguage ? null : resolvedLabels?.date,
                    'Invoice Date',
                    isDualLanguage,
                  ),
                  arabic: _labelAr(
                    dc,
                    'showDate',
                    resolvedLabels?.date,
                    'تاريخ الفاتورة',
                    isDualLanguage,
                  ),
                  value: displayDate,
                ),
              // The current print contract has no due-date key or value. Keep
              // the reference field with its documented invoice-date fallback.
              (
                english: 'Invoice Due Date',
                arabic: 'تاريخ استحقاق الفاتورة',
                value: referenceDueDate,
              ),
              if (cfgVisibleDefault('showInvoiceNumber'))
                (
                  english: _labelEn(
                    dc,
                    'showInvoiceNumber',
                    isDualLanguage ? null : resolvedLabels?.orderNumber,
                    'Invoice No',
                    isDualLanguage,
                  ),
                  arabic: _labelAr(
                    dc,
                    'showInvoiceNumber',
                    resolvedLabels?.orderNumber,
                    'رقم الفاتورة',
                    isDualLanguage,
                  ),
                  value: invoiceNumber,
                ),
            ];

            pw.Widget referenceMetadataTable() {
              final widths = <int, pw.TableColumnWidth>{};
              final cells = <pw.Widget>[];
              for (final entry in referenceMetadata) {
                widths[cells.length] = const pw.FlexColumnWidth(1.5);
                cells.add(_referenceMetadataLabel(
                  entry.english,
                  entry.arabic,
                  font,
                  fontBold,
                  isA5,
                ));
                widths[cells.length] = const pw.FlexColumnWidth(1.1);
                cells.add(metadataValue(entry.value));
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

            final referenceTitleEnglish = _labelEn(
              dc,
              'showInvoiceTitle',
              null,
              'Tax Invoice',
              isDualLanguage,
            );
            final referenceTitleArabic = _labelAr(
              dc,
              'showInvoiceTitle',
              null,
              'فاتورة ضريبية',
              isDualLanguage,
            );
            final showReferenceTitle = resolvedTitleOpt?.visible != false;

            final showReferenceGross =
                dc?['showMRPTotal']?.visible ?? showSubTotalFlag;
            final showReferenceGrossBeforeVat =
                dc?['showSubTotal']?.visible ?? showSubTotalFlag;
            final showReferenceAmountWords = cfgVisible('showAmountInWords');

            pw.Widget referenceSummaryRow() {
              final cells = <pw.Widget>[];
              final widths = <int, pw.TableColumnWidth>{};

              void addSection(pw.Widget widget, double flex) {
                if (cells.isNotEmpty) {
                  widths[cells.length] = const pw.FixedColumnWidth(10);
                  cells.add(pw.SizedBox());
                }
                widths[cells.length] = pw.FlexColumnWidth(flex);
                cells.add(widget);
              }

              if (cfgVisible('showBankInfo')) {
                addSection(
                  _referenceBankBox(
                    params,
                    dc,
                    font,
                    fontBold,
                    isA5,
                    isDualLanguage,
                  ),
                  4.2,
                );
              }
              if (cfgVisible('showQRCode') && qrData.isNotEmpty) {
                addSection(
                  pw.Container(
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.75),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: isA5 ? 54 : 76,
                      height: isA5 ? 54 : 76,
                    ),
                  ),
                  1.9,
                );
              }

              final hasTotals = showReferenceGross ||
                  showDiscountFlag ||
                  showReferenceGrossBeforeVat ||
                  showTaxTotalFlag ||
                  showNetFlag ||
                  showReferenceAmountWords;
              if (hasTotals) {
                addSection(
                  _referenceTotalsBox(
                    gross: referenceGross,
                    discount: discountAmountValue,
                    grossBeforeVat: netExcTaxValue,
                    vat: totalTax,
                    net: totalAmount,
                    currency: currency,
                    dc: dc,
                    resolvedLabels: resolvedLabels,
                    isDualLanguage: isDualLanguage,
                    configLanguage: configLang,
                    showGross: showReferenceGross,
                    showDiscount: showDiscountFlag,
                    showGrossBeforeVat: showReferenceGrossBeforeVat,
                    showVat: showTaxTotalFlag,
                    showNet: showNetFlag,
                    showAmountInWords: showReferenceAmountWords,
                    font: font,
                    fontBold: fontBold,
                    isA5: isA5,
                  ),
                  5.1,
                );
              }

              if (cells.isEmpty) return pw.SizedBox();
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

            final referenceTerms = _referenceConfiguredTextLines(
              dc,
              'showTermsConditions',
              config.terms,
              isDualLanguage,
            );
            final referenceThankYou = _referenceConfiguredTextLines(
              dc,
              'showThankYouMessage',
              config.footer ??
                  (isEnglish
                      ? 'Thank you for your business'
                      : 'شكراً لتسوقكم معنا'),
              isDualLanguage,
            );

            return [
              pw.Container(
                height: isA5 ? 58 : 90,
                width: double.infinity,
                alignment: pw.Alignment.center,
                child: logoImage != null
                    ? pw.Container(
                        width: double.infinity,
                        height: isA5 ? 52 : 82,
                        alignment: pw.Alignment.center,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      )
                    : pw.SizedBox(),
              ),
              referenceMetadataTable(),
              if (showReferenceTitle) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  decoration:
                      pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(referenceTitleEnglish,
                          style: referenceTitleStyle),
                      if (isDualLanguage &&
                          referenceTitleArabic.trim().isNotEmpty) ...[
                        pw.Text(' / ', style: referenceTitleStyle),
                        pw.Text(
                          referenceTitleArabic,
                          style: referenceTitleStyle,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Table(
                columnWidths: showCustomerSection
                    ? const {
                        0: pw.FlexColumnWidth(1),
                        1: pw.FixedColumnWidth(10),
                        2: pw.FlexColumnWidth(1),
                      }
                    : const {0: pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.full,
                    children: [
                      _referencePartyBox(
                        titleEnglish: 'Seller Details',
                        titleArabic: 'تفاصيل البائع',
                        nameLabelEnglish: 'Name',
                        nameLabelArabic: 'الاسم',
                        vatLabelEnglish: 'VAT No',
                        vatLabelArabic: 'الرقم الضريبي',
                        addressLabelEnglish: 'Street',
                        addressLabelArabic: 'الشارع',
                        name: referenceSellerName,
                        vatNumber: params.zatcaVatNumber?.trim() ?? '',
                        address: referenceSellerAddress,
                        secondaryAddress: referenceSellerAddressSecondary,
                        showName: cfgVisibleDefault('showStoreName'),
                        showVat: true,
                        showAddress: cfgVisibleDefault('showStoreAddress'),
                        font: font,
                        fontBold: fontBold,
                        isA5: isA5,
                        isDualLanguage: isDualLanguage,
                      ),
                      if (showCustomerSection) ...[
                        pw.SizedBox(),
                        _referencePartyBox(
                          titleEnglish: _labelEn(
                            dc,
                            'showCustomerNameAndPhone',
                            null,
                            'Buyer Details',
                            isDualLanguage,
                          ),
                          titleArabic: _labelAr(
                            dc,
                            'showCustomerNameAndPhone',
                            null,
                            'تفاصيل المشتري',
                            isDualLanguage,
                          ),
                          nameLabelEnglish: _labelEn(
                            dc,
                            'showCustomerName',
                            null,
                            'Customer Name',
                            isDualLanguage,
                          ),
                          nameLabelArabic: _labelAr(
                            dc,
                            'showCustomerName',
                            null,
                            'اسم العميل',
                            isDualLanguage,
                          ),
                          vatLabelEnglish: _labelEn(
                            dc,
                            'showCustomerVatNumber',
                            null,
                            'VAT No',
                            isDualLanguage,
                          ),
                          vatLabelArabic: _labelAr(
                            dc,
                            'showCustomerVatNumber',
                            null,
                            'الرقم الضريبي',
                            isDualLanguage,
                          ),
                          addressLabelEnglish: _labelEn(
                            dc,
                            'showCustomerAddress',
                            null,
                            'Street',
                            isDualLanguage,
                          ),
                          addressLabelArabic: _labelAr(
                            dc,
                            'showCustomerAddress',
                            null,
                            'الشارع',
                            isDualLanguage,
                          ),
                          name: custName,
                          vatNumber: params.customerVatNumber?.trim() ?? '',
                          address: referenceBuyerAddress,
                          secondaryAddress: null,
                          showName: cfgVisibleDefault('showCustomerName'),
                          showVat: cfgVisible('showCustomerVatNumber'),
                          showAddress: cfgVisibleDefault('showCustomerAddress'),
                          font: font,
                          fontBold: fontBold,
                          isA5: isA5,
                          isDualLanguage: isDualLanguage,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              if (!params.isReturnOnly)
                _buildReferenceItemsTable(
                  params,
                  dc,
                  resolvedLabels,
                  font,
                  fontBold,
                  isA5,
                  isDualLanguage,
                ),
              pw.SizedBox(height: 5),
              referenceSummaryRow(),
              if (params.orderReturns != null &&
                  params.orderReturns!.returnItems != null &&
                  params.orderReturns!.returnItems!.isNotEmpty) ...[
                ..._buildReturnsPdfSection(
                    params, dc, currency, font, fontBold, isA5),
                if (!params.isReturnOnly)
                  ..._buildFinalSummaryPdfSection(params, dc, currency, font,
                      fontBold, isA5, isDualLanguage, configLang),
              ],
              pw.SizedBox(height: 4),
              if (cfgVisible('showTermsConditions') &&
                  referenceTerms.isNotEmpty) ...[
                pw.Wrap(
                  spacing: 4,
                  runSpacing: 1,
                  children: referenceTerms
                      .map((text) => _autoText(text, smallStyle))
                      .toList(),
                ),
                pw.SizedBox(height: 2),
              ],
              if (cfgVisible('showThankYouMessage') &&
                  referenceThankYou.isNotEmpty)
                pw.Center(
                  child: pw.Wrap(
                    alignment: pw.WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 1,
                    children: referenceThankYou
                        .map(
                          (text) => _autoText(
                            text,
                            referenceFooterBold,
                            textAlign: pw.TextAlign.center,
                          ),
                        )
                        .toList(),
                  ),
                ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        'Customer Signature: ____________________',
                        style: referenceSignatureStyle,
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'التوقيع',
                        style: referenceSignatureArStyle,
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Text(
                        'Salesman Signature: ____________________',
                        style: referenceSignatureStyle,
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        'توقيع البائع',
                        style: referenceSignatureArStyle,
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Container(height: 2, color: _accent),
              pw.SizedBox(height: 2),
            ];
          }

          return [
            // ═══════════════════════════════════════════════════════
            // SECTION 1: HEADER — English | centered logo | Arabic
            // ═══════════════════════════════════════════════════════
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
                    textDirection: pw.TextDirection.ltr,
                    singleLineHeading: true,
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
                    textDirection: pw.TextDirection.rtl,
                    singleLineHeading: true,
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
              padding: const pw.EdgeInsets.all(2.5),
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
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(
                            width: 0.5,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                      padding: const pw.EdgeInsets.only(left: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: invoiceRows,
                      ),
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
            // SECTION 5: BANK DETAILS | QR CODE | TOTALS
            // ═══════════════════════════════════════════════════════
            // Retained only as unreachable legacy markup while the new
            // three-column summary is used below.
            if (params.isReturnOnly &&
                params.cartItems.isEmpty &&
                params.cartItems.isNotEmpty) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (cfgVisible('showQRCode') && qrData.isNotEmpty)
                          pw.Align(
                            alignment: pw.Alignment.center,
                            child: pw.Container(
                              height: isA5 ? 92 : 116,
                              alignment: pw.Alignment.center,
                              padding: const pw.EdgeInsets.only(top: 4),
                              child: pw.Container(
                                width: summaryQrSize,
                                height: summaryQrSize,
                                child: pw.BarcodeWidget(
                                  barcode: pw.Barcode.qrCode(),
                                  data: qrData,
                                  width: summaryQrSize,
                                  height: summaryQrSize,
                                ),
                              ),
                            ),
                          ),
                        pw.SizedBox(height: 4),
                        if (showComment &&
                            params.orderComment != null &&
                            params.orderComment!.isNotEmpty)
                          _autoText(
                              '${_getLabel(dc, commentConfigKey, null, 'Comment')}: ${params.orderComment}',
                              wordsStyle),
                        ..._customerBalanceLines(
                            params, dc, currency, wordsStyle, wordsBold),
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
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Table(
                          border: pw.TableBorder.all(width: 0.5),
                          columnWidths: const {
                            0: pw.FlexColumnWidth(2.2),
                            1: pw.FlexColumnWidth(2.0),
                            2: pw.FlexColumnWidth(1.8),
                          },
                          children: [
                            if (!params.isReturnOnly &&
                                cfgVisible('showItemsCount'))
                              _totalsRow(
                                  _withColon(_getLabel(
                                      dc, 'showItemsCount', null, 'Items')),
                                  '',
                                  params.cartItems.length.toString(),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueStyle),
                            if (!params.isReturnOnly &&
                                cfgVisible('showQuantityCount'))
                              _totalsRow(
                                  _withColon(_getLabel(dc, 'showQuantityCount',
                                      null, 'Total Qty')),
                                  '',
                                  params.totalQuantity % 1 == 0
                                      ? params.totalQuantity.toInt().toString()
                                      : params.totalQuantity.toStringAsFixed(2),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueStyle),
                            if (showSubTotalFlag)
                              _totalsRow(
                                  _labelEn(dc, 'showSubTotal', null,
                                      'SUB TOTAL', isDualLanguage),
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
                                  _labelEn(dc, 'showNetAmount', null,
                                      'NET AMOUNT', isDualLanguage),
                                  _labelAr(dc, 'showNetAmount', null,
                                      'المبلغ الصافي', isDualLanguage),
                                  _formatMoney(currency, totalAmount),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueBold),
                          ],
                        ),
                        if (cfgVisible('showAmountInWords')) ...[
                          pw.SizedBox(height: 4),
                          ..._amountInWords(totalAmount, currency,
                              isDualLanguage, configLang, wordsBold),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
            ],

            // ═══════════════════════════════════════════════════════
            // Replacement summary row: bank details | QR code | totals.
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
                              if (bankLines.isNotEmpty) ...[
                                pw.Center(
                                  child: _autoText('BANK DETAILS', footerBold,
                                      textAlign: pw.TextAlign.center),
                                ),
                                pw.SizedBox(height: 3),
                                ...bankLines.map(
                                    (line) => _autoText(line, footerStyle)),
                              ],
                              if (hasSummaryComment) ...[
                                if (bankLines.isNotEmpty)
                                  pw.SizedBox(height: 4),
                                _autoText(
                                    '${_getLabel(dc, commentConfigKey, null, 'Comment')}: ${params.orderComment}',
                                    wordsStyle),
                              ],
                              if (showSavedSummary)
                                pw.Text(
                                  '${_getLabel(dc, 'showSaved', null, 'You Saved:')} ${_formatMoney(currency, saved)}',
                                  style: wordsBold,
                                ),
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
                        child: (cfgVisible('showQRCode') && qrData.isNotEmpty)
                            ? pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: qrData,
                                width: summaryQrSize,
                                height: summaryQrSize,
                              )
                            : pw.SizedBox(),
                      ),
                      pw.SizedBox(),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Table(
                              // Keep the original complete payment-summary
                              // grid inside its own payment-summary table. The
                              // outer container owns the full-height border so
                              // all visible summary boxes remain equal height.
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
                                if (cfgVisible('showItemsCount'))
                                  _totalsRow(
                                      _withColon(_getLabel(
                                          dc, 'showItemsCount', null, 'Items')),
                                      '',
                                      params.cartItems.length.toString(),
                                      totalsLabelEn,
                                      totalsLabelAr,
                                      totalsValueStyle),
                                if (cfgVisible('showQuantityCount'))
                                  _totalsRow(
                                      _withColon(_getLabel(
                                          dc,
                                          'showQuantityCount',
                                          null,
                                          'Total Qty')),
                                      '',
                                      params.totalQuantity % 1 == 0
                                          ? params.totalQuantity
                                              .toInt()
                                              .toString()
                                          : params.totalQuantity
                                              .toStringAsFixed(2),
                                      totalsLabelEn,
                                      totalsLabelAr,
                                      totalsValueStyle),
                                if (showSubTotalFlag)
                                  _totalsRow(
                                      _labelEn(dc, 'showSubTotal', null,
                                          'SUB TOTAL', isDualLanguage),
                                      _labelAr(dc, 'showSubTotal', null,
                                          'SUB TOTAL', isDualLanguage),
                                      _formatMoney(currency, netExcTaxValue),
                                      totalsLabelEn,
                                      totalsLabelAr,
                                      totalsValueStyle),
                                if (showDiscountFlag &&
                                    discountAmountValue != 0)
                                  _totalsRow(
                                      _labelEn(dc, 'showDiscount', null,
                                          'DISCOUNT', isDualLanguage),
                                      _labelAr(dc, 'showDiscount', null,
                                          'DISCOUNT', isDualLanguage),
                                      _formatMoney(
                                          currency, discountAmountValue),
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
                                      _labelAr(
                                          dc,
                                          'showTax',
                                          resolvedLabels?.tax,
                                          'TOTAL VAT 15%',
                                          isDualLanguage),
                                      _formatMoney(currency, totalTax),
                                      totalsLabelEn,
                                      totalsLabelAr,
                                      totalsValueStyle),
                                if (showNetFlag)
                                  _totalsRow(
                                      _labelEn(dc, 'showNetAmount', null,
                                          'NET AMOUNT', isDualLanguage),
                                      _labelAr(dc, 'showNetAmount', null,
                                          'NET AMOUNT', isDualLanguage),
                                      _formatMoney(currency, totalAmount),
                                      totalsLabelEn,
                                      totalsLabelAr,
                                      totalsValueBold),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (customerBalanceSummaryLines.isNotEmpty ||
                  cfgVisible('showAmountInWords')) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: customerBalanceSummaryLines,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: cfgVisible('showAmountInWords')
                            ? _amountInWords(
                                totalAmount,
                                currency,
                                isDualLanguage,
                                configLang,
                                wordsBold,
                              )
                            : const <pw.Widget>[],
                      ),
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 6),
            ],

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
                    pw.Text('Customer Signature: ____________________',
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
            // SECTION 7: FOOTER BAND
            // Store name / address / tax info / extra headings are rendered
            // in the top header band instead of here.
            // ═══════════════════════════════════════════════════════
          ];
        },
      ),
    );

    return pdf;
  }

  List<String> _referenceConfiguredTextLines(
    Map<String, DisplayOption>? dc,
    String key,
    String? fallback,
    bool isDualLanguage,
  ) {
    final option = dc?[key];
    final localized = option?.value?.toString().trim() ?? '';
    final english = option?.defaultValue?.trim() ?? '';
    final fallbackText = fallback?.trim() ?? '';
    final lines = <String>[];

    void add(String value) {
      if (value.isNotEmpty && !lines.contains(value)) lines.add(value);
    }

    if (isDualLanguage) {
      add(localized);
      add(english);
    } else {
      add(localized);
      if (lines.isEmpty) add(english);
    }
    if (lines.isEmpty) add(fallbackText);
    return lines;
  }

  List<String> _referenceAddressParts(String? rawAddress) {
    if (rawAddress == null || rawAddress.trim().isEmpty) return const [];
    return rawAddress
        .split(',')
        .map((part) => part.trim())
        .where((part) =>
            part.isNotEmpty &&
            part.toLowerCase() != 'null' &&
            part.toLowerCase() != 'n/a')
        .toList();
  }

  String _referenceAddressPart(List<String> parts, int index) {
    if (index < 0 || index >= parts.length) return '';
    return parts[index];
  }

  /// Keeps bilingual party names visually stable on this LTR template.
  ///
  /// The `pdf` package applies one direction to an entire Text/RichText
  /// widget, so a value such as `English / العربية` cannot give both scripts
  /// their natural direction inside a single widget. Render the two language
  /// runs separately: English on the left in LTR and Arabic on the right in
  /// RTL. Single-language values continue to use their detected direction.
  pw.Widget _referencePartyNameText(
    String text,
    pw.TextStyle style,
  ) {
    final parts = text
        .split(RegExp(r'\s*/\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final englishParts =
        parts.where((part) => !_hasArabic(part)).toList(growable: false);
    final arabicParts =
        parts.where((part) => _hasArabic(part)).toList(growable: false);

    if (englishParts.isEmpty || arabicParts.isEmpty) {
      return _autoText(text, style);
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Wrap(
        crossAxisAlignment: pw.WrapCrossAlignment.center,
        children: [
          pw.Text(
            englishParts.join(' / '),
            style: style,
            textDirection: pw.TextDirection.ltr,
          ),
          pw.Text(
            ' / ',
            style: style,
            textDirection: pw.TextDirection.ltr,
          ),
          pw.Text(
            arabicParts.join(' / '),
            style: style,
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  pw.Widget _referenceMetadataLabel(
    String english,
    String arabic,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
  ) {
    double fs(double value) => isA5 ? value * 0.78 : value;
    final englishStyle = pw.TextStyle(
      font: fontBold,
      fontSize: fs(8),
      fontWeight: pw.FontWeight.bold,
    );
    final arabicStyle = pw.TextStyle(
      font: font,
      fontBold: fontBold,
      fontSize: fs(7),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(arabic,
              style: arabicStyle,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right),
          pw.Text(english, style: englishStyle, textAlign: pw.TextAlign.right),
        ],
      ),
    );
  }

  pw.Widget _referencePartyBox({
    required String titleEnglish,
    required String titleArabic,
    required String nameLabelEnglish,
    required String nameLabelArabic,
    required String vatLabelEnglish,
    required String vatLabelArabic,
    required String addressLabelEnglish,
    required String addressLabelArabic,
    required String name,
    required String vatNumber,
    required String? address,
    required String? secondaryAddress,
    required bool showName,
    required bool showVat,
    required bool showAddress,
    required pw.Font font,
    required pw.Font fontBold,
    required bool isA5,
    required bool isDualLanguage,
  }) {
    double fs(double value) => isA5 ? value * 0.78 : value;
    final titleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: fs(9),
      fontWeight: pw.FontWeight.bold,
    );
    final labelStyle = pw.TextStyle(
      font: fontBold,
      fontSize: fs(7.5),
      fontWeight: pw.FontWeight.bold,
    );
    final valueStyle = pw.TextStyle(
      font: font,
      fontBold: fontBold,
      fontSize: fs(7.5),
    );
    final addressParts = _referenceAddressParts(address);
    final secondaryAddressParts = _referenceAddressParts(secondaryAddress);
    final rows = <({
      String english,
      String arabic,
      String value,
      String secondaryValue,
      bool isName,
    })>[
      if (showName)
        (
          english: nameLabelEnglish,
          arabic: nameLabelArabic,
          value: name,
          secondaryValue: '',
          isName: true,
        ),
      if (showVat)
        (
          english: vatLabelEnglish,
          arabic: vatLabelArabic,
          value: vatNumber,
          secondaryValue: '',
          isName: false,
        ),
      if (showAddress) ...[
        (
          english: addressLabelEnglish,
          arabic: addressLabelArabic,
          value: _referenceAddressPart(addressParts, 0),
          secondaryValue: _referenceAddressPart(secondaryAddressParts, 0),
          isName: false,
        ),
        (
          english: 'Building No',
          arabic: 'رقم المبنى',
          value: _referenceAddressPart(addressParts, 1),
          secondaryValue: _referenceAddressPart(secondaryAddressParts, 1),
          isName: false,
        ),
        (
          english: 'Postal Code',
          arabic: 'الرمز البريدي',
          value: _referenceAddressPart(addressParts, 2),
          secondaryValue: _referenceAddressPart(secondaryAddressParts, 2),
          isName: false,
        ),
        (
          english: 'District',
          arabic: 'الحي',
          value: _referenceAddressPart(addressParts, 3),
          secondaryValue: _referenceAddressPart(secondaryAddressParts, 3),
          isName: false,
        ),
        (
          english: 'City',
          arabic: 'المدينة',
          value: _referenceAddressPart(addressParts, 4),
          secondaryValue: _referenceAddressPart(secondaryAddressParts, 4),
          isName: false,
        ),
        (
          english: 'Country',
          arabic: 'الدولة',
          value:
              addressParts.length > 5 ? addressParts.sublist(5).join(', ') : '',
          secondaryValue: secondaryAddressParts.length > 5
              ? secondaryAddressParts.sublist(5).join(', ')
              : '',
          isName: false,
        ),
      ],
    ];

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
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(titleEnglish, style: titleStyle),
                if (isDualLanguage && titleArabic.trim().isNotEmpty) ...[
                  pw.Text(' | ', style: titleStyle),
                  pw.Text(
                    titleArabic,
                    style: titleStyle,
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ],
            ),
          ),
          ...rows.map(
            (row) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 0.75,
              ),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 0.25, color: PdfColors.grey400),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: isA5 ? 74 : 104,
                    child: pw.Wrap(
                      children: [
                        pw.Text(row.english, style: labelStyle),
                        if (isDualLanguage && row.arabic.trim().isNotEmpty)
                          pw.Text(
                            ' ${row.arabic}',
                            style: valueStyle,
                            textDirection: pw.TextDirection.rtl,
                          ),
                      ],
                    ),
                  ),
                  pw.Text(': ', style: valueStyle),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (row.isName)
                          _referencePartyNameText(row.value, valueStyle)
                        else
                          _autoText(row.value, valueStyle),
                        if (row.secondaryValue.trim().isNotEmpty &&
                            row.secondaryValue.trim() != row.value.trim())
                          _autoText(row.secondaryValue, valueStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReferenceItemsTable(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    ResolvedLabels? resolvedLabels,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
    bool isDualLanguage,
  ) {
    double fs(double value) => isA5 ? value * 0.78 : value;
    final headerEn = pw.TextStyle(
      font: fontBold,
      fontSize: fs(7.5),
      fontWeight: pw.FontWeight.bold,
    );
    final headerAr = pw.TextStyle(
      font: font,
      fontBold: fontBold,
      fontSize: fs(6.5),
    );
    final bodyStyle = pw.TextStyle(
      font: font,
      fontBold: fontBold,
      fontSize: fs(7.5),
    );

    pw.Widget headerCell(String english, String arabic) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(english, style: headerEn, textAlign: pw.TextAlign.center),
              if (arabic.isNotEmpty)
                pw.Text(arabic,
                    style: headerAr,
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center),
            ],
          ),
        );

    const columnKeys = [
      'showSLNumber',
      'showParticulars',
      'showMRP',
      'showUnit',
      'showQty',
      'showRate',
      'showRateExcTax',
      'showDiscountColumn',
      'showTaxHeader',
      'showTotal',
    ];
    final hasColumnConfiguration =
        dc != null && columnKeys.any((key) => dc.containsKey(key));
    bool show(String key, {required bool fallback}) {
      if (!hasColumnConfiguration) return fallback;
      return dc[key]?.visible == true;
    }

    final showSl = show('showSLNumber', fallback: true);
    final showParticulars = show('showParticulars', fallback: true);
    final showMrp = show('showMRP', fallback: false);
    final showUnit = show('showUnit', fallback: true);
    final showQty = show('showQty', fallback: true);
    final showRate = show('showRate', fallback: true);
    final showRateExcTax = show('showRateExcTax', fallback: false);
    final showDiscount = show('showDiscountColumn', fallback: false);
    final showTax = show('showTaxHeader', fallback: false);
    final showTotal = show('showTotal', fallback: true);

    final columnWidths = <int, pw.TableColumnWidth>{};
    final headers = <pw.Widget>[];
    void addHeader(
      double flex,
      String english,
      String arabic,
    ) {
      columnWidths[headers.length] = pw.FlexColumnWidth(flex);
      headers.add(headerCell(english, arabic));
    }

    if (showSl) {
      addHeader(
        0.7,
        _labelEn(
          dc,
          'showSLNumber',
          resolvedLabels?.slNumberDefault ??
              (isDualLanguage ? null : resolvedLabels?.slNumber),
          'No',
          isDualLanguage,
        ),
        _labelAr(
          dc,
          'showSLNumber',
          resolvedLabels?.slNumber,
          'م',
          isDualLanguage,
        ),
      );
    }
    if (showParticulars) {
      addHeader(
        3.8,
        _labelEn(
          dc,
          'showParticulars',
          resolvedLabels?.particularsDefault ??
              (isDualLanguage
                  ? null
                  : resolvedLabels?.particulars ?? resolvedLabels?.itemName),
          'Fare Name',
          isDualLanguage,
        ),
        _labelAr(
          dc,
          'showParticulars',
          resolvedLabels?.particulars ?? resolvedLabels?.itemName,
          'اسم الصنف',
          isDualLanguage,
        ),
      );
    }
    if (showMrp) {
      addHeader(
        1.2,
        _labelEn(
            dc,
            'showMRP',
            resolvedLabels?.mrpDefault ??
                (isDualLanguage ? null : resolvedLabels?.mrp),
            'MRP',
            isDualLanguage),
        _labelAr(dc, 'showMRP', resolvedLabels?.mrp, 'القيمة', isDualLanguage),
      );
    }
    if (showUnit) {
      addHeader(
        1.0,
        _labelEn(
            dc,
            'showUnit',
            resolvedLabels?.unitNameDefault ??
                (isDualLanguage ? null : resolvedLabels?.unitName),
            'Units',
            isDualLanguage),
        _labelAr(
            dc, 'showUnit', resolvedLabels?.unitName, 'الوحدة', isDualLanguage),
      );
    }
    if (showQty) {
      addHeader(
        1.1,
        _labelEn(
            dc,
            'showQty',
            resolvedLabels?.qtyDefault ??
                (isDualLanguage ? null : resolvedLabels?.qty),
            'Qty',
            isDualLanguage),
        _labelAr(dc, 'showQty', resolvedLabels?.qty, 'الكمية', isDualLanguage),
      );
    }
    if (showRate) {
      addHeader(
        1.5,
        _labelEn(
            dc,
            'showRate',
            resolvedLabels?.rateDefault ??
                (isDualLanguage
                    ? null
                    : resolvedLabels?.rate ?? resolvedLabels?.priceName),
            'Unit Price',
            isDualLanguage),
        _labelAr(
          dc,
          'showRate',
          resolvedLabels?.rate ?? resolvedLabels?.priceName,
          'سعر الوحدة',
          isDualLanguage,
        ),
      );
    }
    if (showRateExcTax) {
      addHeader(
        1.4,
        _labelEn(
            dc,
            'showRateExcTax',
            resolvedLabels?.rateExcTaxDefault ??
                (isDualLanguage ? null : resolvedLabels?.rateExcTax),
            'Rate Ex Tax',
            isDualLanguage),
        _labelAr(dc, 'showRateExcTax', resolvedLabels?.rateExcTax,
            'السعر بدون ضريبة', isDualLanguage),
      );
    }
    if (showDiscount) {
      addHeader(
        1.3,
        _labelEn(dc, 'showDiscountColumn', null, 'Discount', isDualLanguage),
        _labelAr(dc, 'showDiscountColumn', null, 'خصم', isDualLanguage),
      );
    }
    if (showTax) {
      addHeader(
        1.3,
        _labelEn(
            dc,
            'showTaxHeader',
            resolvedLabels?.taxDefault ??
                (isDualLanguage
                    ? null
                    : resolvedLabels?.tax ?? resolvedLabels?.taxName),
            'Tax',
            isDualLanguage),
        _labelAr(
          dc,
          'showTaxHeader',
          resolvedLabels?.tax ?? resolvedLabels?.taxName,
          'الضريبة',
          isDualLanguage,
        ),
      );
    }
    if (showTotal) {
      addHeader(
        1.6,
        _labelEn(
            dc,
            'showTotal',
            resolvedLabels?.totalDefault ??
                (isDualLanguage
                    ? null
                    : resolvedLabels?.total ?? resolvedLabels?.amountName),
            'Amount',
            isDualLanguage),
        _labelAr(
          dc,
          'showTotal',
          resolvedLabels?.total ?? resolvedLabels?.amountName,
          'إجمالي',
          isDualLanguage,
        ),
      );
    }

    if (headers.isEmpty) return pw.SizedBox();

    pw.Widget dataCell(
      String text, {
      pw.Alignment alignment = pw.Alignment.topCenter,
      pw.TextDirection? direction,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
          child: pw.Align(
            alignment: alignment,
            child: pw.Text(
              text,
              style: bodyStyle,
              textDirection: direction,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        );

    pw.Widget itemNameCell(String englishName, String arabicName) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (englishName.trim().isNotEmpty)
                pw.Text(
                  englishName,
                  style: bodyStyle,
                  textDirection: pw.TextDirection.ltr,
                  textAlign: pw.TextAlign.left,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              if (arabicName.trim().isNotEmpty)
                pw.Text(
                  arabicName,
                  style: bodyStyle,
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
            ],
          ),
        );

    final rows = <pw.TableRow>[];
    for (var index = 0; index < params.cartItems.length; index++) {
      final item = params.cartItems[index];
      String name = '';
      String unit = '';
      double quantity = 0;
      double mrp = 0;
      double unitPrice = 0;
      double discount = 0;
      double tax = 0;
      double total = 0;

      if (params.isFromLocalStorage || item is Map) {
        name = (item['productName'] ?? item['product_name'] ?? '').toString();
        unit = getPrintUnit(item);
        quantity = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        mrp = double.tryParse(item['mrp']?.toString() ?? '0') ?? 0;
        unitPrice = double.tryParse(
                (item['unitPrice'] ?? item['unit_price'])?.toString() ?? '0') ??
            0;
        discount = double.tryParse(
                (item['discount'] ?? item['discount_amount'])?.toString() ??
                    '0') ??
            0;
        tax = double.tryParse(
                (item['taxAmount'] ?? item['tax_amount'])?.toString() ?? '0') ??
            0;
        total = double.tryParse(
                (item['totalPrice'] ?? item['total_price'])?.toString() ??
                    '0') ??
            0;
      } else {
        try {
          name = item.productName?.toString() ?? '';
          unit = getPrintUnit(item);
          quantity = double.tryParse(item.quantity?.toString() ?? '0') ?? 0;
          mrp = double.tryParse(item.mrp?.toString() ?? '0') ?? 0;
          unitPrice = double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0;
          tax = double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0;
          total = double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0;
        } catch (_) {}
        try {
          discount =
              double.tryParse(item.discountAmount?.toString() ?? '0') ?? 0;
        } catch (_) {}
      }

      name = _itemDisplayName(item, name);
      final arabicName = isDualLanguage ? _arabicItemName(item) : '';
      final taxPerUnit = quantity > 0 ? tax / quantity : 0.0;
      final rateExcTax = unitPrice - taxPerUnit;
      final cells = <pw.Widget>[];
      if (showSl) cells.add(dataCell('${index + 1}'));
      if (showParticulars) {
        cells.add(itemNameCell(name, arabicName));
      }
      if (showMrp) {
        cells.add(dataCell(AmountHelper.formatAmount(mrp),
            alignment: pw.Alignment.topRight));
      }
      if (showUnit) cells.add(dataCell(unit));
      if (showQty) {
        cells.add(dataCell(quantity.toStringAsFixed(2),
            alignment: pw.Alignment.topRight));
      }
      if (showRate) {
        cells.add(dataCell(AmountHelper.formatAmount(unitPrice),
            alignment: pw.Alignment.topRight));
      }
      if (showRateExcTax) {
        cells.add(dataCell(AmountHelper.formatAmount(rateExcTax),
            alignment: pw.Alignment.topRight));
      }
      if (showDiscount) {
        cells.add(dataCell(AmountHelper.formatAmount(discount),
            alignment: pw.Alignment.topRight));
      }
      if (showTax) {
        cells.add(dataCell(AmountHelper.formatAmount(tax),
            alignment: pw.Alignment.topRight));
      }
      if (showTotal) {
        cells.add(dataCell(AmountHelper.formatAmount(total),
            alignment: pw.Alignment.topRight));
      }
      rows.add(
        pw.TableRow(children: cells),
      );
    }

    if (rows.isEmpty) {
      rows.add(
        pw.TableRow(
          children: List.generate(headers.length, (_) => dataCell('')),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.75),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(children: headers),
        ...rows,
      ],
    );
  }

  pw.Widget _referenceBankBox(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
    bool isDualLanguage,
  ) {
    double fs(double value) => isA5 ? value * 0.78 : value;
    final headingStyle = pw.TextStyle(
      font: fontBold,
      fontSize: fs(8),
      fontWeight: pw.FontWeight.bold,
    );
    final labelStyle = pw.TextStyle(
      font: fontBold,
      fontSize: fs(7.25),
      fontWeight: pw.FontWeight.bold,
    );
    final valueStyle = pw.TextStyle(
      font: font,
      fontBold: fontBold,
      fontSize: fs(7.25),
    );
    final bank = params.primaryBank;
    final account = params.primaryBankAccount;
    bool visible(String key) => dc?[key]?.visible == true;
    final rows = <({String english, String arabic, String value})>[
      if (visible('showBankName'))
        (
          english:
              _labelEn(dc, 'showBankName', null, 'Bank Name', isDualLanguage),
          arabic:
              _labelAr(dc, 'showBankName', null, 'اسم البنك', isDualLanguage),
          value: bank?.bankName ?? ''
        ),
      if (visible('showAccountName'))
        (
          english: _labelEn(
              dc, 'showAccountName', null, 'Account Name', isDualLanguage),
          arabic: _labelAr(
              dc, 'showAccountName', null, 'اسم الحساب', isDualLanguage),
          value: account?.accountHolderName ?? ''
        ),
      if (visible('showAccountNumber'))
        (
          english: _labelEn(
              dc, 'showAccountNumber', null, 'Account Number', isDualLanguage),
          arabic: _labelAr(
              dc, 'showAccountNumber', null, 'رقم الحساب', isDualLanguage),
          value: account?.accountNumber ?? ''
        ),
      if (visible('showIBAN'))
        (
          english: _labelEn(dc, 'showIBAN', null, 'IBAN', isDualLanguage),
          arabic: _labelAr(
              dc, 'showIBAN', null, 'رقم الحساب المصرفي', isDualLanguage),
          value: account?.iban ?? ''
        ),
      if (visible('showSwiftCode'))
        (
          english:
              _labelEn(dc, 'showSwiftCode', null, 'SWIFT Code', isDualLanguage),
          arabic:
              _labelAr(dc, 'showSwiftCode', null, 'رمز سويفت', isDualLanguage),
          value: account?.swiftCode?.trim().isNotEmpty == true
              ? account!.swiftCode!.trim()
              : account?.ifsc ?? ''
        ),
    ];

    final headingEnglish =
        _labelEn(dc, 'showBankInfo', null, 'Bank Details', isDualLanguage);
    final headingArabic =
        _labelAr(dc, 'showBankInfo', null, 'تفاصيل البنك', isDualLanguage);

    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(headingEnglish, style: headingStyle),
              if (isDualLanguage && headingArabic.trim().isNotEmpty) ...[
                pw.Text(' | ', style: headingStyle),
                pw.Text(
                  headingArabic,
                  style: headingStyle,
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ],
          ),
          pw.Divider(height: 3, thickness: 0.4),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Wrap(
                crossAxisAlignment: pw.WrapCrossAlignment.center,
                children: [
                  pw.Text(row.english, style: labelStyle),
                  if (isDualLanguage && row.arabic.trim().isNotEmpty)
                    pw.Text(' ${row.arabic}',
                        style: valueStyle, textDirection: pw.TextDirection.rtl),
                  pw.Text(': ${row.value}', style: valueStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _referenceTotalsBox({
    required double gross,
    required double discount,
    required double grossBeforeVat,
    required double vat,
    required double net,
    required String currency,
    required Map<String, DisplayOption>? dc,
    required ResolvedLabels? resolvedLabels,
    required bool isDualLanguage,
    required String? configLanguage,
    required bool showGross,
    required bool showDiscount,
    required bool showGrossBeforeVat,
    required bool showVat,
    required bool showNet,
    required bool showAmountInWords,
    required pw.Font font,
    required pw.Font fontBold,
    required bool isA5,
  }) {
    double fs(double value) => isA5 ? value * 0.78 : value;
    final labelStyle = pw.TextStyle(
      font: font,
      fontBold: fontBold,
      fontSize: fs(7.25),
    );
    final labelBold = pw.TextStyle(
      font: fontBold,
      fontSize: fs(7.75),
      fontWeight: pw.FontWeight.bold,
    );
    final valueStyle = pw.TextStyle(
      font: font,
      fontBold: fontBold,
      fontSize: fs(7.5),
    );
    final valueBold = pw.TextStyle(
      font: fontBold,
      fontSize: fs(8),
      fontWeight: pw.FontWeight.bold,
    );

    String money(double amount) {
      final value = AmountHelper.formatAmount(amount);
      return currency.trim().isEmpty ? value : '$value ${currency.trim()}';
    }

    pw.Widget row(
      String english,
      String arabic,
      double amount, {
      bool bold = false,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 0.75),
          child: pw.Row(
            children: [
              pw.Text(english, style: bold ? labelBold : labelStyle),
              if (isDualLanguage && arabic.trim().isNotEmpty) ...[
                pw.SizedBox(width: 3),
                pw.Text(arabic,
                    style: labelStyle, textDirection: pw.TextDirection.rtl),
              ],
              pw.Spacer(),
              pw.Text(money(amount), style: bold ? valueBold : valueStyle),
            ],
          ),
        );

    final grossEnglish =
        _labelEn(dc, 'showMRPTotal', null, 'Gross', isDualLanguage);
    final grossArabic =
        _labelAr(dc, 'showMRPTotal', null, 'إجمالي', isDualLanguage);
    final discountEnglish =
        _labelEn(dc, 'showDiscount', null, 'Discount', isDualLanguage);
    final discountArabic =
        _labelAr(dc, 'showDiscount', null, 'خصم', isDualLanguage);
    final grossBeforeVatEnglish =
        _labelEn(dc, 'showSubTotal', null, 'Gross Before VAT', isDualLanguage);
    final grossBeforeVatArabic = _labelAr(
        dc, 'showSubTotal', null, 'إجمالي قبل الضريبة', isDualLanguage);
    final vatEnglish = _labelEn(
      dc,
      'showTax',
      resolvedLabels?.taxDefault ??
          (isDualLanguage
              ? null
              : resolvedLabels?.tax ?? resolvedLabels?.taxName),
      'VAT 15%',
      isDualLanguage,
    );
    final vatArabic = _labelAr(
      dc,
      'showTax',
      resolvedLabels?.tax ?? resolvedLabels?.taxName,
      'ضريبة القيمة المضافة',
      isDualLanguage,
    );
    final netEnglish =
        _labelEn(dc, 'showNetAmount', null, 'Net Amount', isDualLanguage);
    final netArabic =
        _labelAr(dc, 'showNetAmount', null, 'المبلغ الإجمالي', isDualLanguage);
    final wordsEnglish = _labelEn(
        dc, 'showAmountInWords', null, 'Amount In Words :', isDualLanguage);
    final wordsArabic = _labelAr(
        dc, 'showAmountInWords', null, 'المبلغ بالكلمات :', isDualLanguage);
    final hasRows =
        showGross || showDiscount || showGrossBeforeVat || showVat || showNet;
    final hasRowsBeforeNet =
        showGross || showDiscount || showGrossBeforeVat || showVat;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (showGross) row(grossEnglish, grossArabic, gross),
          if (showDiscount) row(discountEnglish, discountArabic, discount),
          if (showGrossBeforeVat)
            row(grossBeforeVatEnglish, grossBeforeVatArabic, grossBeforeVat),
          if (showVat) row(vatEnglish, vatArabic, vat),
          if (showNet) ...[
            if (hasRowsBeforeNet)
              pw.Divider(height: 4, thickness: 0.6, indent: 5, endIndent: 5),
            row(netEnglish, netArabic, net, bold: true),
          ],
          if (showAmountInWords) ...[
            if (hasRows)
              pw.Divider(height: 4, thickness: 0.4, indent: 5, endIndent: 5),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5),
              child: pw.Row(
                children: [
                  pw.Text(wordsEnglish, style: labelBold),
                  if (isDualLanguage && wordsArabic.trim().isNotEmpty) ...[
                    pw.SizedBox(width: 3),
                    pw.Text(
                      wordsArabic,
                      style: labelStyle,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(5, 1, 5, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _amountInWords(
                  net,
                  currency,
                  isDualLanguage,
                  configLanguage,
                  pw.TextStyle(
                    font: font,
                    fontBold: fontBold,
                    fontSize: fs(7.25),
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
    bool singleLineHeading = false,
  }) {
    return pw.Column(
      crossAxisAlignment: alignment,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          pw.Container(
            width: double.infinity,
            child: _autoText(
              singleLineHeading && i == 0
                  ? lines[i].replaceAll(RegExp(r'\s+'), ' ').trim()
                  : lines[i],
              i == 0 ? headingStyle : detailStyle,
              textAlign: textAlign,
              maxLines: singleLineHeading && i == 0 ? 1 : 2,
              softWrap: !(singleLineHeading && i == 0),
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

  /// Bilingual label used in the compact customer/invoice information boxes.
  /// The Arabic fallback remains available even when the API only supplies an
  /// English configuration value.
  String _infoLabel(String en, String ar, bool isDual) {
    if (!isDual || ar.trim().isEmpty) return en;
    return '$en\n$ar';
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
      lines.add(_autoText(
        '${_getLabel(dc, 'showCustomerPrevBalance', null, 'Previous Balance')}: ${_formatMoney(currency, params.customerOldBalance!)}',
        style,
        textAlign: pw.TextAlign.left,
      ));
    }
    if (showPaid && params.paidAmount != null) {
      lines.add(_autoText(
        '${_getLabel(dc, 'showCustomerPaidAmount', null, 'Paid Amount')}: ${_formatMoney(currency, params.paidAmount!)}',
        style,
        textAlign: pw.TextAlign.left,
      ));
    }
    if (showCurrent && params.customerCurrentBalance != null) {
      lines.add(_autoText(
        '${_getLabel(dc, 'showCustomerCurrentBalance', null, 'Current Balance')}: ${_formatMoney(currency, params.customerCurrentBalance!)}',
        boldStyle,
        textAlign: pw.TextAlign.left,
      ));
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
      {double labelWidth = 80}) {
    final bilingualParts = label.split('\n');
    if (bilingualParts.length > 1 && bilingualParts[1].trim().isNotEmpty) {
      final englishLabel = bilingualParts.first.trim();
      final arabicLabel = bilingualParts.sublist(1).join(' ').trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: labelWidth,
              child: pw.Text(
                englishLabel,
                style: labelStyle,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textDirection: pw.TextDirection.ltr,
              ),
            ),
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  value,
                  style: valueStyle,
                  maxLines: 2,
                  textAlign: pw.TextAlign.center,
                  overflow: pw.TextOverflow.clip,
                  textDirection: _dirOf(value),
                ),
              ),
            ),
            pw.SizedBox(
              width: labelWidth,
              child: pw.Text(
                arabicLabel,
                style: labelStyle,
                maxLines: 2,
                textAlign: pw.TextAlign.right,
                overflow: pw.TextOverflow.clip,
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Text(label,
                style: labelStyle,
                maxLines: 2,
                softWrap: true,
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

  /// Returns the product's Arabic name for the second, RTL-aligned item line.
  String _arabicItemName(dynamic item) {
    String? arabicName;
    try {
      if (item is Map) {
        final names =
            item['product_names'] ?? item['productNames'] ?? item['names'];
        if (names is Map) {
          arabicName = (names['ar'] ?? names['arabic'])?.toString();
        }
      } else {
        arabicName = item.names?.ar?.toString();
      }
    } catch (_) {}
    return arabicName?.trim() ?? '';
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

    pw.Widget itemNameCell(String englishName, String arabicName) {
      pw.Widget nameLine(String text, pw.TextDirection direction) =>
          pw.Container(
            width: double.infinity,
            child: pw.Text(
              text,
              style: bodyStyle,
              maxLines: 1,
              softWrap: false,
              overflow: pw.TextOverflow.clip,
              textAlign: pw.TextAlign.left,
              textDirection: direction,
            ),
          );

      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (arabicName.isNotEmpty)
              nameLine(arabicName, pw.TextDirection.rtl),
            if (arabicName.isNotEmpty && englishName.isNotEmpty)
              pw.SizedBox(height: 2),
            if (englishName.isNotEmpty)
              nameLine(englishName, _dirOf(englishName)),
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
      final englishName = name;
      final arabicName = isAr ? _arabicItemName(item) : '';

      final cells = <pw.Widget>[];
      if (showSL) cells.add(_dataCell('${i + 1}', bodyStyle));
      if (showItems) {
        cells.add(itemNameCell(englishName, arabicName));
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
      final num qty = ri.quantity ?? 0;
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
        num totalQty = 0;
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
      custRows
          .add(_kvRow('Phone:', params.customerPhone!, labelStyle, valueStyle));
    }
    if (params.customerAddress != null &&
        params.customerAddress!.trim().isNotEmpty) {
      custRows.add(_kvRow(
          'Billing Address:', params.customerAddress!, labelStyle, valueStyle));
    }
    if (custRows.isNotEmpty) {
      widgets.add(pw.Text(retLabels?.customerHeading ?? 'CUSTOMER DETAILS',
          style: sectionHeadingStyle));
      widgets.add(pw.SizedBox(height: 2));
      widgets.addAll(custRows);
      widgets.add(pw.SizedBox(height: 4));
    }

    if (retLabels?.itemsHeading != null) {
      widgets
          .add(pw.Text(retLabels!.itemsHeading!, style: sectionHeadingStyle));
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

    if (col('showReturnItemsCount') ||
        (retLabels?.creditNoteItemsCount != null)) {
      final countLabel = (retLabels?.creditNoteItemsCount != null)
          ? retLbl('showCreditNoteItemsCount', retLabels?.creditNoteItemsCount,
              'Total Items:')
          : lbl('showReturnItemsCount', null, 'Return Items:');
      widgets.add(pw.Text('$countLabel ${orderReturns.returnItems!.length}',
          style: labelStyle));
      widgets.add(pw.SizedBox(height: 2));
    }

    if (col('showReturnTotalAmount') ||
        (retLabels?.creditNoteTotalAmount != null)) {
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
      widgets.addAll(
          _amountInWords(returnRateTotal, currency, false, null, labelStyle));
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
      final num qty = ri.quantity ?? 0;
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
        num totalQty = 0;
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
