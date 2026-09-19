import 'dart:io';
import 'dart:convert';
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
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/services/common_print_settings.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
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

  /// Language mode of the document being built; read by the label helpers.
  ReceiptLanguageMode _mode = ReceiptLanguageMode.english;

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
    final dc = params.displayConfig;
    final resolvedLabels = config.resolvedLabels;
    final isA5 = params.selectedPaperSize.toUpperCase() == 'A5';
    final pageFormat = isA5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
    // The QR column is narrower after the summary row becomes a
    // bank-details | QR | totals layout. Keep the A5 QR inside that column.
    final summaryQrSize = isA5 ? 68.0 : 100.0;
    // Minimum room needed for the summary, optional words/balance content,
    // and the signature/footer tail when it is anchored to a page bottom.
    final bottomFooterReserve = isA5 ? 190.0 : 250.0;

    // Resolve B2B/B2C invoice title — params.displayConfig is B2B-aware
    final invoiceTitleText = params.isVisible('showInvoiceTitle')
        ? params.labelFor('showInvoiceTitle',
            englishFallback: 'Simplified Tax Invoice',
            arabicFallback: 'فاتورة ضريبية مبسطة')
        : '';

    // ── Fonts & language ────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    final configLang = params.amountInWordsLanguage;
    final mode = params.receiptLanguageMode;
    _mode = mode;
    final isDualLanguage = mode == ReceiptLanguageMode.bilingual;
    final isRtl = mode == ReceiptLanguageMode.arabic;
    final isEnglish = mode == ReceiptLanguageMode.english;
    final isAr = mode == ReceiptLanguageMode.bilingual ||
        mode == ReceiptLanguageMode.arabic;
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
    bool cfgVisible(String key) => dc?[key]?.visible == true;
    bool cfgVisibleDefault(String key) => params.isVisible(key);

    // Configured text that may be 'Arabic\nEnglish': one Text per line so each
    // language keeps its own direction on this LTR page.
    pw.Widget modeText(String text, pw.TextStyle style,
            [pw.CrossAxisAlignment align = pw.CrossAxisAlignment.center]) =>
        pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: align,
          children: [
            for (final line in text.split('\n'))
              pdfText(line, style: style,
                  textAlign: align == pw.CrossAxisAlignment.center
                      ? pw.TextAlign.center
                      : null),
          ],
        );

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
    // Configuration supplies header labels and visibility. The active store
    // supplies the address value.
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

    // Label for one header column; a bilingual column never carries the other
    // column's script.
    String headerLabel(String key, bool arabic, String en, String ar) {
      final label = ReceiptConfigurationContract.label(
        options: dc,
        key: key,
        mode: arabic ? ReceiptLanguageMode.arabic : ReceiptLanguageMode.english,
        englishFallback: en,
        arabicFallback: ar,
      );
      return _withColon(isDualLanguage && pdfHasArabic(label) != arabic
          ? (arabic ? ar : en)
          : label);
    }

    List<String> configuredHeaderLines({required bool arabic}) {
      final lines = <String>[];
      for (final key in headerConfigKeys) {
        final option = dc?[key];
        if (option?.visible != true) continue;

        if (key == 'showStoreAddress') {
          final address = params.storeAddressText(
            mode: arabic
                ? ReceiptLanguageMode.arabic
                : ReceiptLanguageMode.english,
          );
          if (address.isNotEmpty) lines.add(address);
          continue;
        }

        if (key == 'showTel' || key == 'showEmail') {
          // The shared helper owns visibility + value (store, then customer
          // care); this column owns the label.
          final value = params.storeContactText(key).split(': ').last;
          final isTel = key == 'showTel';
          if (value.isNotEmpty) {
            lines.add(
                '${headerLabel(key, arabic, isTel ? 'Telephone' : 'Email', isTel ? 'الهاتف' : 'البريد الإلكتروني')} $value');
          }
          continue;
        }

        if (!isDualLanguage) {
          // One language, one column: configured text is never dropped.
          final text =
              params.labelFor(key, englishFallback: '', arabicFallback: '');
          if (text.isNotEmpty) lines.add(text);
          continue;
        }

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
          if (text.trim().isEmpty || pdfHasArabic(text) != arabic) continue;
          lines.add(text);
          break;
        }
      }
      return lines;
    }

    final arabicHeaderLines =
        isEnglish ? <String>[] : configuredHeaderLines(arabic: true);
    final englishHeaderLines =
        isRtl ? <String>[] : configuredHeaderLines(arabic: false);
    final storeFssai =
        params.labelFor('showFssaiInfo', englishFallback: '', arabicFallback: '');
    final extraHeading2 = params.labelFor('showExtraHeading2',
        englishFallback: '', arabicFallback: '');
    // The store owns the CR / VAT numbers; the option text is only the label.
    void addSellerNumber(String key, String? number, String en, String ar) {
      final value = number?.trim() ?? '';
      if (!params.isVisible(key) || value.isEmpty) return;
      if (!isRtl) {
        englishHeaderLines.add('${headerLabel(key, false, en, ar)} $value');
      }
      if (!isEnglish) {
        arabicHeaderLines.add('${headerLabel(key, true, en, ar)} $value');
      }
    }

    addSellerNumber(
        'showCRNumber', params.zatcaCrNumber, 'CR No', 'السجل التجاري');
    addSellerNumber(
        'showVatNumber', params.zatcaVatNumber, 'VAT No', 'الرقم الضريبي');
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

    // ── Invoice number (shared: number_prefix + printable component) ─
    final invoiceNumber = params.invoiceNumberText;

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
    final custName = params.customerName ?? (isRtl ? 'عميل' : 'GENERAL');
    // Shared rule: toggle, walk-in default customer and masking.
    String custPhone = params.customerPhoneText;
    if (custPhone.isNotEmpty &&
        params.customerAlternatePhone != null &&
        params.customerAlternatePhone!.isNotEmpty) {
      custPhone = '$custPhone, ${params.customerAlternatePhone}';
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
    // Master switch of the whole customer section (payment, comment and
    // delivery included).
    final bool showCustomerSection =
        params.isVisible('showCustomerNameAndPhone');
    final bool showCustomerName = cfgVisibleDefault('showCustomerName');
    final bool showCustomerAddress = cfgVisibleDefault('showCustomerAddress');
    final bool showCustomerVat = cfgVisible('showCustomerVatNumber');
    final bool showCustomerCr = cfgVisible('showCustomerCrNumber');
    final bool showPayment = showCustomerSection &&
        !isQuotation &&
        cfgVisibleDefault(paymentConfigKey);
    final bool showComment =
        showCustomerSection && cfgVisibleDefault(commentConfigKey);
    final bool showDeliveryMethod =
        showCustomerSection && cfgVisibleDefault('showDeliveryMethod');
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
    final paymentBreakdownLines =
        _buildPaymentBreakdownLines(params, currency, wordsStyle, dc);

    // ── Totals visibility ───────────────────────────────────────────
    final bool showSubTotalFlag =
        params.isVisible('showSubTotal') || params.isVisible('showMRPTotal');
    final bool showDiscountFlag = params.isVisible('showDiscount');
    final bool showTaxTotalFlag = params.isVisible('showTax');
    final bool showNetFlag = params.isVisible('showNetAmount');

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
                isDualLanguage,
                isAr: isAr),
            custName,
            infoLabel,
            infoValue));
      }
      if (showCustomerAddress && displayOrBlank(custAddress).isNotEmpty) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(
                    dc, 'showCustomerAddress', null, 'Address', isDualLanguage),
                _labelAr(
                    dc, 'showCustomerAddress', null, 'العنوان', isDualLanguage),
                isDualLanguage,
                isAr: isAr),
            displayOrBlank(custAddress),
            infoLabel,
            infoValue));
      }
      if (showCustomerVat &&
          displayOrBlank(params.customerVatNumber).isNotEmpty) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(dc, 'showCustomerVatNumber', null, 'Customer VAT No.',
                    isDualLanguage),
                _labelAr(dc, 'showCustomerVatNumber', null,
                    'الرقم الضريبي للعميل', isDualLanguage),
                isDualLanguage,
                isAr: isAr),
            displayOrBlank(params.customerVatNumber),
            infoLabel,
            infoValue));
      }
      if (showCustomerCr &&
          displayOrBlank(params.customerCrNumber).isNotEmpty) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(dc, 'showCustomerCrNumber', null, 'Customer CR No.',
                    isDualLanguage),
                _labelAr(dc, 'showCustomerCrNumber', null,
                    'رقم السجل التجاري للعميل', isDualLanguage),
                isDualLanguage,
                isAr: isAr),
            displayOrBlank(params.customerCrNumber),
            infoLabel,
            infoValue));
      }
      if (custPhone.isNotEmpty) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(
                    dc, 'showCustomerPhone', null, 'Phone', isDualLanguage),
                _labelAr(
                    dc, 'showCustomerPhone', null, 'الهاتف', isDualLanguage),
                isDualLanguage,
                isAr: isAr),
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
                isDualLanguage,
                isAr: isAr),
            invoiceNumber,
            infoLabel,
            infoValue),
      if (cfgVisibleDefault('showDate'))
        _kvRow(
            _infoLabel(
                _labelEn(dc, 'showDate', null, 'Date', isDualLanguage),
                _labelAr(dc, 'showDate', null, 'التاريخ', isDualLanguage),
                isDualLanguage,
                isAr: isAr),
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
                isDualLanguage,
                isAr: isAr),
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
                isDualLanguage,
                isAr: isAr),
            params.deliveryMethod!,
            infoLabel,
            infoValue),
      if (showCustomerSection &&
          params.isVisible('showDeliveryPhone') &&
          (params.deliveryPhone ?? '').trim().isNotEmpty)
        _kvRow(
            _infoLabel(_labelEn(dc, 'showDeliveryPhone', null, 'Delivery Phone', isDualLanguage), _labelAr(dc, 'showDeliveryPhone', null, 'هاتف التوصيل', isDualLanguage), isDualLanguage, isAr: isAr),
            params.deliveryPhone!.trim(), infoLabel, infoValue),
      if (params.isVisible('showTokenNumber') &&
          (params.tokenNumber ?? '').trim().isNotEmpty)
        _kvRow(
            _infoLabel(_labelEn(dc, 'showTokenNumber', null, 'Token No', isDualLanguage), _labelAr(dc, 'showTokenNumber', null, 'رقم الرمز', isDualLanguage), isDualLanguage, isAr: isAr),
            params.tokenNumber!.trim(), infoLabel, infoValue),
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
    final referenceSellerAddress = params.storeAddressValue;
    const String? referenceSellerAddressSecondary = null;
    final referenceBuyerAddress = params.customerAddress?.trim() ?? '';
    final referenceDueDate = displayDate;
    final referenceGross = netExcTaxValue + discountAmountValue;

    // ── Payment breakdown lines (left column) ───────────────────────
    // ══════════════════════════════════════════════════════════════════
    // BUILD PDF
    // ══════════════════════════════════════════════════════════════════
    final pdfMargins = await CommonPrintSettings.resolvePdfMargins(
      pw.EdgeInsets.all(isA5 ? 8 : 10),
    );

    List<pw.Widget> buildContent(
      pw.Context ctx, {
      required bool fillSinglePageItemsBox,
    }) {
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
              child: pdfText(value, style: referenceValueStyle,
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
        final showReferenceTitle = params.isVisible('showInvoiceTitle');

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
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.75)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pdfText(referenceTitleEnglish, style: referenceTitleStyle),
                  if (isDualLanguage &&
                      referenceTitleArabic.trim().isNotEmpty) ...[
                    pdfText(' / ', style: referenceTitleStyle),
                    pdfText(
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
                    showAddress: cfgVisible('showStoreAddress'),
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
                  .map((text) => pdfText(text, style: smallStyle))
                  .toList(),
            ),
            pw.SizedBox(height: 2),
          ],
          if (cfgVisible('showThankYouMessage') && referenceThankYou.isNotEmpty)
            pw.Center(
              child: pw.Wrap(
                alignment: pw.WrapAlignment.center,
                spacing: 4,
                runSpacing: 1,
                children: referenceThankYou
                    .map(
                      (text) => pdfText(
                        text,
                        style: referenceFooterBold,
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
                  pdfText(
                    'Customer Signature: ____________________',
                    style: referenceSignatureStyle,
                  ),
                  pw.SizedBox(width: 4),
                  pdfText(
                    'التوقيع',
                    style: referenceSignatureArStyle,
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pdfText(
                    'Salesman Signature: ____________________',
                    style: referenceSignatureStyle,
                  ),
                  pw.SizedBox(width: 4),
                  pdfText(
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
        // Document-level header / subheader (shared language rules).
        for (final text in [
          params.documentText(config.header),
          params.documentText(config.subheader)
        ])
          if (text.isNotEmpty) pw.Center(child: modeText(text, headerDetailStyle)),
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
                    ? modeText(
                        extraHeading2, crVatStyle, pw.CrossAxisAlignment.start)
                    : pw.SizedBox(),
              ),
            ),
            modeText(invoiceTitleText.toUpperCase(), titleStyle),
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: (cfgVisible('showFssaiInfo') && storeFssai.isNotEmpty)
                    ? modeText(
                        storeFssai, crVatStyle, pw.CrossAxisAlignment.end)
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
          if (fillSinglePageItemsBox)
            pw.Expanded(
              child: pw.Container(
                width: double.infinity,
                alignment: pw.Alignment.topLeft,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.75),
                ),
                child: _buildItemsTable(
                  params,
                  dc,
                  resolvedLabels,
                  isEnglish,
                  itemsHeaderEn,
                  itemsHeaderAr,
                  itemsBodyStyle,
                ),
              ),
            )
          else
            _buildItemsTable(params, dc, resolvedLabels, isEnglish,
                itemsHeaderEn, itemsHeaderAr, itemsBodyStyle),
          pw.SizedBox(height: 6),
          // Keep the summary and invoice footer together near the bottom
          // of the final page. If the remaining space is too small for
          // the footer block, start a fresh page before the flexible
          // spacer so it cannot be left behind after the item table.
          if (!fillSinglePageItemsBox) ...[
            pw.NewPage(freeSpace: bottomFooterReserve),
            pw.Spacer(),
          ],
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
                      pdfText(
                          '${_getLabel(dc, commentConfigKey, null, 'Comment')}: ${params.orderComment}',
                          style: wordsStyle),
                    ..._customerBalanceLines(
                        params, dc, currency, wordsStyle, wordsBold),
                    if (cfgVisible('showSaved') && saved > 0)
                      pdfText(
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
                              _withColon(_getLabel(
                                  dc, 'showQuantityCount', null, 'Total Qty')),
                              '',
                              params.totalQuantity % 1 == 0
                                  ? params.totalQuantity.toInt().toString()
                                  : params.totalQuantity.toStringAsFixed(2),
                              totalsLabelEn,
                              totalsLabelAr,
                              totalsValueStyle),
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
                    if (cfgVisible('showAmountInWords')) ...[
                      pw.SizedBox(height: 4),
                      ..._amountInWords(totalAmount, currency, isDualLanguage,
                          configLang, wordsBold),
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
                              child: pdfText('BANK DETAILS', style: footerBold,
                                  textAlign: pw.TextAlign.center),
                            ),
                            pw.SizedBox(height: 3),
                            ...bankLines
                                .map((line) => pdfText(line, style: footerStyle)),
                          ],
                          if (hasSummaryComment) ...[
                            if (bankLines.isNotEmpty) pw.SizedBox(height: 4),
                            pdfText(
                                '${params.labelFor(commentConfigKey, englishFallback: 'Comment', arabicFallback: 'تعليق', inlineBilingual: true)}: ${params.orderComment}',
                                style: wordsStyle),
                          ],
                          if (showSavedSummary)
                            pdfText(
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
                                  _withColon(_labelEn(dc, 'showItemsCount',
                                      null, 'Items', isDualLanguage)),
                                  _labelAr(dc, 'showItemsCount', null, 'العدد',
                                      isDualLanguage),
                                  params.cartItems.length.toString(),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueStyle),
                            if (cfgVisible('showQuantityCount'))
                              _totalsRow(
                                  _withColon(_labelEn(dc, 'showQuantityCount',
                                      null, 'Total Qty', isDualLanguage)),
                                  _labelAr(dc, 'showQuantityCount', null,
                                      'إجمالي الكمية', isDualLanguage),
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
                                  _labelAr(dc, 'showDiscount', null, 'الخصم',
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
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (paymentBreakdownLines.isNotEmpty ||
              customerBalanceSummaryLines.isNotEmpty ||
              cfgVisible('showAmountInWords')) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      ...paymentBreakdownLines,
                      ...customerBalanceSummaryLines,
                    ],
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
        if (params.termsText.isNotEmpty) ...[
          modeText(
              params.termsText, smallStyle, pw.CrossAxisAlignment.start),
          pw.SizedBox(height: 4),
        ],

        // ═══════════════════════════════════════════════════════
        // THANK YOU (config value → footer → default)
        // ═══════════════════════════════════════════════════════
        if (params.thankYouText.isNotEmpty)
          pw.Center(child: modeText(params.thankYouText, footerBold)),
        if (params.isVisible('showVATFooter') &&
            (params.zatcaVatNumber ?? '').trim().isNotEmpty)
          pw.Center(
              child: pdfText(
                  '${params.labelFor('showVATFooter', englishFallback: 'VAT No', arabicFallback: 'الرقم الضريبي', inlineBilingual: true)}: ${params.zatcaVatNumber!.trim()}',
                  style: footerStyle)),
        if (params.isVisible('showOrderNumberInFooter'))
          pw.Center(
              child: pdfText(
                  '${params.labelFor('showOrderNumberInFooter', englishFallback: 'Invoice No', arabicFallback: 'رقم الفاتورة', inlineBilingual: true)}: ${params.printableOrderNumberComponent}',
                  style: footerStyle)),
        pw.SizedBox(height: 10),

        // ═══════════════════════════════════════════════════════
        // SECTION 6: SIGNATURES
        // ═══════════════════════════════════════════════════════
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                pdfText(
                    '${isRtl ? '' : 'Customer Signature: '}____________________',
                    style: signatureStyle),
                pw.SizedBox(width: 6),
                if (!isEnglish)
                  pdfText('التوقيع',
                      style: signatureArStyle,
                      textDirection: pw.TextDirection.rtl),
              ],
            ),
            pw.Row(
              children: [
                pdfText(
                    '${isRtl ? '' : 'Salesman Signature: '}____________________',
                    style: signatureStyle),
                pw.SizedBox(width: 6),
                if (!isEnglish)
                  pdfText('توقيع البائع',
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
    }

    final multiPagePdf = pdf;
    multiPagePdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: pdfMargins,
        build: (ctx) => buildContent(
          ctx,
          fillSinglePageItemsBox: false,
        ),
      ),
    );

    // The normal MultiPage pass determines whether every section fits on one
    // page. Only then can the item table safely receive a full-height box;
    // applying that constraint during pagination would interfere with row
    // splitting on multi-page invoices.
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
          children: buildContent(
            ctx,
            fillSinglePageItemsBox: true,
          ),
        ),
      ),
    );

    return singlePagePdf;
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
        parts.where((part) => !pdfHasArabic(part)).toList(growable: false);
    final arabicParts =
        parts.where((part) => pdfHasArabic(part)).toList(growable: false);

    if (englishParts.isEmpty || arabicParts.isEmpty) {
      return pdfText(text, style: style);
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Wrap(
        crossAxisAlignment: pw.WrapCrossAlignment.center,
        children: [
          pdfText(
            englishParts.join(' / '),
            style: style,
            textDirection: pw.TextDirection.ltr,
          ),
          pdfText(
            ' / ',
            style: style,
            textDirection: pw.TextDirection.ltr,
          ),
          pdfText(
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
          pdfText(arabic,
              style: arabicStyle,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right),
          pdfText(english, style: englishStyle, textAlign: pw.TextAlign.right),
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
                pdfText(titleEnglish, style: titleStyle),
                if (isDualLanguage && titleArabic.trim().isNotEmpty) ...[
                  pdfText(' | ', style: titleStyle),
                  pdfText(
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
                        pdfText(row.english, style: labelStyle),
                        if (isDualLanguage && row.arabic.trim().isNotEmpty) ...[
                          pw.SizedBox(width: 3),
                          pdfText(
                            row.arabic,
                            style: valueStyle,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ],
                      ],
                    ),
                  ),
                  pdfText(': ', style: valueStyle),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (row.isName)
                          _referencePartyNameText(row.value, valueStyle)
                        else
                          pdfText(row.value, style: valueStyle),
                        if (row.secondaryValue.trim().isNotEmpty &&
                            row.secondaryValue.trim() != row.value.trim())
                          pdfText(row.secondaryValue, style: valueStyle),
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
              pdfText(english, style: headerEn, textAlign: pw.TextAlign.center),
              if (arabic.isNotEmpty)
                pdfText(arabic,
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
            child: pdfText(
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
                pdfText(
                  englishName,
                  style: bodyStyle,
                  textDirection: pw.TextDirection.ltr,
                  textAlign: pw.TextAlign.left,
                  // Let the table cell grow for long names instead of
                  // clipping the product text at the right edge.
                  softWrap: true,
                ),
              if (arabicName.trim().isNotEmpty)
                pdfText(
                  arabicName,
                  style: bodyStyle,
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.right,
                  softWrap: true,
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
              pdfText(headingEnglish, style: headingStyle),
              if (isDualLanguage && headingArabic.trim().isNotEmpty) ...[
                pdfText(' | ', style: headingStyle),
                pdfText(
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
                  pdfText(row.english, style: labelStyle),
                  if (isDualLanguage && row.arabic.trim().isNotEmpty) ...[
                    pw.SizedBox(width: 3),
                    pdfText(row.arabic,
                        style: valueStyle, textDirection: pw.TextDirection.rtl),
                  ],
                  pdfText(': ${row.value}', style: valueStyle),
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
              pdfText(english, style: bold ? labelBold : labelStyle),
              if (isDualLanguage && arabic.trim().isNotEmpty) ...[
                pw.SizedBox(width: 3),
                pdfText(arabic,
                    style: labelStyle, textDirection: pw.TextDirection.rtl),
              ],
              pw.Spacer(),
              pdfText(money(amount), style: bold ? valueBold : valueStyle),
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
                  pdfText(wordsEnglish, style: labelBold),
                  if (isDualLanguage && wordsArabic.trim().isNotEmpty) ...[
                    pw.SizedBox(width: 3),
                    pdfText(
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
    bool singleLineHeading = false,
  }) {
    pw.Widget line(int i) => pdfText(
          singleLineHeading && i == 0
              ? lines[i].replaceAll(RegExp(r'\s+'), ' ').trim()
              : lines[i],
          style: i == 0 ? headingStyle : detailStyle,
          textAlign: textAlign,
          maxLines: singleLineHeading && i == 0 ? 1 : 2,
          softWrap: !(singleLineHeading && i == 0),
        );

    return pw.Column(
      crossAxisAlignment: alignment,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          pw.Container(
            width: double.infinity,
            child: singleLineHeading && i == 0
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

  /// Appends a single trailing colon, avoiding a double `::` when the
  /// configured label already ends with one (e.g. value `"AR Qty:"`).
  String _withColon(String label) {
    final t = label.trimRight();
    return t.isEmpty || t.endsWith(':') ? t : '$t:';
  }

  /// Bilingual label used in the compact customer/invoice information boxes.
  /// The Arabic fallback remains available even when the API only supplies an
  /// English configuration value.
  String _infoLabel(String en, String ar, bool isDual, {bool isAr = false}) {
    if (ar.trim().isEmpty) return en;
    if (isDual) return '$en\n$ar';
    if (isAr) return ar;
    return en;
  }

  /// One-line label resolved by the shared contract for the active language
  /// mode (the Arabic fallback is the contract's translation of [defaultLabel]).
  String _getLabel(Map<String, DisplayOption>? dc, String key,
      String? resolvedLabel, String defaultLabel) {
    return ReceiptConfigurationContract.label(
      options: dc,
      key: key,
      mode: _mode,
      englishFallback: defaultLabel,
      arabicFallback: '',
      resolvedEnglish: resolvedLabel,
      inlineBilingual: true,
    );
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
    // Arabic-only invoices leave the English slot empty.
    if (_mode.isArabic) return '';
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
    // English-only invoices leave the Arabic slot empty; Arabic-only invoices
    // use the configured Arabic label like bilingual ones.
    if (_mode.isEnglish) return '';
    if (isDual || _mode.isArabic) {
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
        pdfText('$ar فقط.', style: style, textDirection: pw.TextDirection.rtl),
        pdfText('$en Only.', style: style),
      ];
    }
    final language = (configLang ?? 'en').toLowerCase();
    final words = AmountHelper()
        .convertNumberToWords(total, currency: currency, language: language);
    final mode = ReceiptConfigurationContract.languageMode(configLang);
    final suffix = mode == ReceiptLanguageMode.arabic ? ' فقط.' : ' only.';
    final needsRtl = mode == ReceiptLanguageMode.arabic ||
        mode == ReceiptLanguageMode.bilingual;
    return [
      pdfText(
        '$words$suffix',
        style: style,
        textDirection: needsRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    ];
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
    final bool showPaymentBreaked =
        ReceiptConfigurationContract.isVisible(dc, 'showPaymentBreaked');
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
          lines.add(pdfText(
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
              lines.add(pdfText(
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
        lines.add(pdfText(
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
    if (!params.isVisible('showCustomerBalance')) return [];
    if (params.isDefaultCustomer) return [];
    if (params.customerOldBalance == null &&
        params.customerCurrentBalance == null &&
        params.paidAmount == null) {
      return [];
    }

    final bool showPrev = params.isVisible('showCustomerPrevBalance');
    final bool showPaid = params.isVisible('showCustomerPaidAmount');
    final bool showCurrent = params.isVisible('showCustomerCurrentBalance');

    final lines = <pw.Widget>[];
    if (showPrev && params.customerOldBalance != null) {
      lines.add(pdfText(
        '${_getLabel(dc, 'showCustomerPrevBalance', null, 'Previous Balance')}: ${_formatMoney(currency, params.customerOldBalance!)}',
        style: style,
        textAlign: pw.TextAlign.left,
      ));
    }
    if (showPaid && params.paidAmount != null) {
      lines.add(pdfText(
        '${_getLabel(dc, 'showCustomerPaidAmount', null, 'Paid Amount')}: ${_formatMoney(currency, params.paidAmount!)}',
        style: style,
        textAlign: pw.TextAlign.left,
      ));
    }
    if (showCurrent && params.customerCurrentBalance != null) {
      lines.add(pdfText(
        '${_getLabel(dc, 'showCustomerCurrentBalance', null, 'Current Balance')}: ${_formatMoney(currency, params.customerCurrentBalance!)}',
        style: boldStyle,
        textAlign: pw.TextAlign.left,
      ));
    }
    return lines;
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
              child: pdfText(
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
                child: pdfText(
                  value,
                  style: valueStyle,
                  maxLines: 2,
                  textAlign: pw.TextAlign.center,
                  overflow: pw.TextOverflow.clip,
                  textDirection: pdfTextDirectionOf(value),
                ),
              ),
            ),
            pw.SizedBox(
              width: labelWidth,
              child: pdfText(
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
            child: pdfText(label,
                style: labelStyle,
                maxLines: 2,
                softWrap: true,
                overflow: pw.TextOverflow.clip,
                textDirection: pdfTextDirectionOf(label)),
          ),
          // Keep a gap: an RTL label hugs the right edge of its box.
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pdfText(value,
                style: valueStyle,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textDirection: pdfTextDirectionOf(value)),
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
        child: pdfText(en, style: enStyle, textDirection: pdfTextDirectionOf(en)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child:
              pdfText(ar, style: arStyle, textDirection: pw.TextDirection.rtl),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pdfText(value, style: valueStyle),
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

    final mode = params.receiptLanguageMode;
    final bool isAr = mode == ReceiptLanguageMode.bilingual ||
        mode == ReceiptLanguageMode.arabic;

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
              pdfText(ar,
                  style: headerAr,
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.center),
            if (en.isNotEmpty)
              pdfText(en, style: headerEn, textAlign: pw.TextAlign.center),
          ],
        ),
      );
    }

    pw.Widget itemNameCell(String englishName, String arabicName) {
      pw.Widget nameLine(String text, pw.TextDirection direction) =>
          pw.Container(
            width: double.infinity,
            child: pdfText(
              text,
              style: bodyStyle,
              // Product names must wrap instead of being clipped when they
              // exceed the particulars column width.
              softWrap: true,
              textAlign: pw.TextAlign.left,
              textDirection: direction,
            ),
          );

      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (arabicName.isNotEmpty)
              nameLine(arabicName, pw.TextDirection.rtl),
            if (arabicName.isNotEmpty && englishName.isNotEmpty)
              pw.SizedBox(height: 1),
            if (englishName.isNotEmpty)
              nameLine(englishName, pdfTextDirectionOf(englishName)),
          ],
        ),
      );
    }

    final hdrs = <pw.Widget>[];
    if (showSL) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showSLNumber', resolvedLabels?.slNumberDefault, 'NO', isAr),
          _labelAr(dc, 'showSLNumber', resolvedLabels?.slNumber,
              mode == ReceiptLanguageMode.arabic ? 'م' : '', isAr)));
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
      child: pw.Align(
        alignment: align,
        child: pdfText(
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
              pdfText(text, style: headerStyle, textAlign: pw.TextAlign.center),
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
            child: pdfText(text, style: bodyStyle),
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
        pdfText(params.returnsSectionHeading, style: titleStyle),
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
      widgets.add(pdfText(
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
    if (params.isVisible('showCustomerName') &&
        params.customerName != null &&
        params.customerName!.trim().isNotEmpty) {
      custRows.add(_kvRow(
        'Customer Name:',
        params.customerName!,
        labelStyle,
        valueStyle,
      ));
    }
    if (params.customerPhoneText.isNotEmpty) {
      custRows.add(
          _kvRow('Phone:', params.customerPhoneText, labelStyle, valueStyle));
    }
    if (params.isVisible('showCustomerAddress') &&
        params.customerAddress != null &&
        params.customerAddress!.trim().isNotEmpty) {
      custRows.add(_kvRow(
          'Billing Address:', params.customerAddress!, labelStyle, valueStyle));
    }
    if (custRows.isNotEmpty) {
      widgets.add(pdfText(retLabels?.customerHeading ?? 'CUSTOMER DETAILS',
          style: sectionHeadingStyle));
      widgets.add(pw.SizedBox(height: 2));
      widgets.addAll(custRows);
      widgets.add(pw.SizedBox(height: 4));
    }

    if (retLabels?.itemsHeading != null) {
      widgets
          .add(pdfText(retLabels!.itemsHeading!, style: sectionHeadingStyle));
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

    if (col('showReturnItemsCount')) {
      final countLabel = (retLabels?.creditNoteItemsCount != null)
          ? retLbl('showCreditNoteItemsCount', retLabels?.creditNoteItemsCount,
              'Total Items:')
          : lbl('showReturnItemsCount', null, 'Return Items:');
      widgets.add(pdfText('$countLabel ${orderReturns.returnItems!.length}',
          style: labelStyle));
      widgets.add(pw.SizedBox(height: 2));
    }

    if (col('showReturnTotalAmount')) {
      final label = (retLabels?.creditNoteTotalAmount != null)
          ? retLbl('showCreditNoteTotalAmount',
              retLabels?.creditNoteTotalAmount, 'Total Amount:')
          : lbl('showReturnTotalAmount', null, 'Return Total:');
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pdfText('$label ', style: labelStyle),
          pdfText(_formatMoney(currency, returnRateTotal), style: valueStyle),
        ],
      ));
    }

    if (col('showReturnNetAmount')) {
      final label = (retLabels?.creditNoteRefund != null)
          ? retLbl('showCreditNoteRefund', retLabels?.creditNoteRefund,
              'Credit Note Total:')
          : lbl('showReturnNetAmount', null, 'Return Net Amount:');
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pdfText('$label ', style: labelStyle),
          pdfText(_formatMoney(currency, returnRateTotal), style: valueStyle),
        ],
      ));
    }

    if (hasCreditNoteConfig &&
        (col('showReturnTotalAmount') || col('showReturnNetAmount'))) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.addAll(_amountInWords(returnRateTotal, currency, false,
          params.amountInWordsLanguage, labelStyle));
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

    bool vis(String key) => ReceiptConfigurationContract.isVisible(dc, key);
    String lbl(String key, String def) {
      final v = dc?[key]?.value as String?;
      if (v != null && v.isNotEmpty) return v;
      return def;
    }

    final showFinalPurchase = vis('showFinalPurchase');
    final showFinalReturn = vis('showFinalReturn');
    final showFinalNetAmount = vis('showFinalNetAmount');
    final showFinalAmountInWords = vis('showFinalAmountInWords');

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
            child: pdfText(label, style: labelStyle),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pdfText(value, style: valStyle),
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
