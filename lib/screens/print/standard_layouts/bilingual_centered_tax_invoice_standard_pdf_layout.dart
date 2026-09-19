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
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/services/common_print_settings.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
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
    final dc = params.displayConfig;
    final resolvedLabels = config.resolvedLabels;
    final isA5 = params.selectedPaperSize.toUpperCase() == 'A5';
    final pageFormat = isA5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
    // The QR column is narrower after the summary row becomes a
    // bank-details | QR | totals layout. Keep the A5 QR inside that column.
    final summaryQrSize = isA5 ? 68.0 : 100.0;

    // Resolve B2B/B2C invoice title — params.displayConfig is B2B-aware
    final invoiceTitleText = params.isVisible('showInvoiceTitle')
        ? params.labelFor('showInvoiceTitle',
            englishFallback: 'Simplified Tax Invoice',
            arabicFallback: 'فاتورة ضريبية مبسطة',
            inlineBilingual: true)
        : '';

    // ── Fonts & language ────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    final mode = params.receiptLanguageMode;
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
    bool cfgVisible(String key) => params.isVisible(key);

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
            '[bilingual_centered_tax_invoice] payment QR fallback error: $e');
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

    List<String> configuredHeaderLines({required bool arabic}) {
      final lines = <String>[];
      for (final key in headerConfigKeys) {
        final option = dc?[key];
        if (option?.visible != true) continue;
        final columnMode =
            arabic ? ReceiptLanguageMode.arabic : ReceiptLanguageMode.english;

        if (key == 'showStoreAddress') {
          final address = params.storeAddressText(mode: columnMode);
          if (address.isNotEmpty) lines.add(address);
          continue;
        }

        if (key == 'showTel' || key == 'showEmail') {
          // Shared helper owns visibility + value ('' = hidden or no value);
          // only the label is re-resolved in this column's language.
          final contact = params.storeContactText(key);
          if (contact.isEmpty) continue;
          final label = ReceiptConfigurationContract.label(
              options: dc,
              key: key,
              mode: columnMode,
              englishFallback: key == 'showTel' ? 'Telephone' : 'Email',
              arabicFallback:
                  key == 'showTel' ? 'الهاتف' : 'البريد الإلكتروني');
          lines.add('$label: ${contact.split(': ').last}');
          continue;
        }

        // A single-language document has one header column: print the
        // configured text through the shared contract so nothing is lost.
        if (!isDualLanguage) {
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

    // English-only documents have no Arabic column and vice versa.
    final arabicHeaderLines =
        isEnglish ? <String>[] : configuredHeaderLines(arabic: true);
    // Store name and description stay on separate lines, mirroring the Arabic
    // side; merging them overflowed the single-line heading.
    final englishHeaderLines =
        isRtl ? <String>[] : configuredHeaderLines(arabic: false);
    final storeFssai = params.labelFor('showFssaiInfo',
        englishFallback: '', arabicFallback: '', inlineBilingual: true);
    final extraHeading2 = params.labelFor('showExtraHeading2',
        englishFallback: '', arabicFallback: '', inlineBilingual: true);
    // Store CR / VAT: '<label>: <number>' only when toggled on and known.
    String storeTaxLine(String key, String? number, String en, String ar) =>
        (cfgVisible(key) && (number ?? '').trim().isNotEmpty)
            ? '${params.labelFor(key, englishFallback: en, arabicFallback: ar, inlineBilingual: true)}: ${number!.trim()}'
            : '';
    final storeCrLine = storeTaxLine(
        'showCRNumber', params.zatcaCrNumber, 'CR No', 'السجل التجاري');
    final storeVatLine = storeTaxLine(
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

    debugPrint(
        '[BilingualCenteredTaxInvoice][Bank] order=${params.orderNumber} '
        'bankDetailsCount=${params.bankDetails.length} '
        'primaryBank=${primaryBank?.bankName ?? '<none>'} '
        'accountCount=${primaryBank?.bankAccounts.length ?? 0}');
    debugPrint('[BilingualCenteredTaxInvoice][Bank] '
        'accountNumber=${maskBankValue(accountNumberValue)} '
        'iban=${maskBankValue(ibanValue)} '
        'accountHolderPresent=${primaryBankAccount?.accountHolderName?.trim().isNotEmpty == true} '
        'ifscPresent=${primaryBankAccount?.ifsc?.trim().isNotEmpty == true} '
        'swiftPresent=${primaryBankAccount?.swiftCode?.trim().isNotEmpty == true}');
    debugPrint('[BilingualCenteredTaxInvoice][Bank] flags '
        'showBankInfo=$showBankInfo '
        'showBankName=$showBankName '
        'showAccountName=$showAccountName '
        'showAccountNumber=$showAccountNumber '
        'showIBAN=$showIban '
        'showSwiftCode=$showSwiftCode '
        'configuredLineCount=${bankLines.length} '
        'willRender=${bankLines.isNotEmpty}');

    // ── Invoice number (shared: number_prefix + order number) ───────
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
    // Shared rule: '' when showCustomerPhone is off / no phone / hidden
    // walk-in customer; masked when showCustomerPhoneMasked is on.
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
    // Master switch of the whole customer section (incl. payment, comment,
    // delivery), same as the thermal layouts.
    final bool showCustomerSection = cfgVisible('showCustomerNameAndPhone');
    final bool showCustomerName = cfgVisible('showCustomerName');
    final bool showCustomerAddress = cfgVisible('showCustomerAddress');
    final bool showCustomerVat = cfgVisible('showCustomerVatNumber');
    final bool showCustomerCr = cfgVisible('showCustomerCrNumber');
    final bool showPayment =
        showCustomerSection && !isQuotation && cfgVisible(paymentConfigKey);
    final bool showComment =
        showCustomerSection && cfgVisible(commentConfigKey);
    final bool showDeliveryMethod =
        showCustomerSection && cfgVisible('showDeliveryMethod');

    // Human-readable payment method summary (handles single + multi-payment),
    // reused by both the invoice info box and the left payment line.
    final paymentMethodSummary = _paymentMethodSummary(params);

    // ── Totals visibility ───────────────────────────────────────────
    final bool showSubTotalFlag =
        cfgVisible('showSubTotal') || cfgVisible('showMRPTotal');
    final bool showDiscountFlag = cfgVisible('showDiscount');
    final bool showTaxTotalFlag = cfgVisible('showTax');
    final bool showNetFlag = cfgVisible('showNetAmount');

    // ── Customer box rows ───────────────────────────────────────────
    final customerRows = <pw.Widget>[];
    if (showCustomerSection) {
      if (showCustomerName) {
        customerRows.add(_kvRow(
            _infoLabel(
                _labelEn(
                    dc, 'showCustomerName', null, 'Customer', mode),
                _labelAr(
                    dc, 'showCustomerName', null, 'العميل', mode),
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
                    dc, 'showCustomerAddress', null, 'Address', mode),
                _labelAr(
                    dc, 'showCustomerAddress', null, 'العنوان', mode),
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
                    mode),
                _labelAr(dc, 'showCustomerVatNumber', null,
                    'الرقم الضريبي للعميل', mode),
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
                    mode),
                _labelAr(dc, 'showCustomerCrNumber', null,
                    'رقم السجل التجاري للعميل', mode),
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
                    dc, 'showCustomerPhone', null, 'Phone', mode),
                _labelAr(
                    dc, 'showCustomerPhone', null, 'الهاتف', mode),
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
      if (cfgVisible('showInvoiceNumber'))
        _kvRow(
            _infoLabel(
                _labelEn(dc, 'showInvoiceNumber', null, numberLabelDefault,
                    mode),
                _labelAr(
                    dc,
                    'showInvoiceNumber',
                    null,
                    isQuotation ? 'رقم عرض السعر' : 'رقم الفاتورة',
                    mode),
                isDualLanguage,
                isAr: isAr),
            invoiceNumber,
            infoLabel,
            infoValue),
      if (cfgVisible('showDate'))
        _kvRow(
            _infoLabel(
                _labelEn(dc, 'showDate', null, 'Date', mode),
                _labelAr(dc, 'showDate', null, 'التاريخ', mode),
                isDualLanguage,
                isAr: isAr),
            '$displayDate${displayTime.isNotEmpty ? ' $displayTime' : ''}',
            infoLabel,
            infoValue),
      if (showPayment && paymentMethodSummary.isNotEmpty)
        _kvRow(
            _infoLabel(
                _labelEn(dc, paymentConfigKey, null, 'Payment Method',
                    mode),
                _labelAr(
                    dc, paymentConfigKey, null, 'طريقة الدفع', mode),
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
                    dc, 'showDeliveryMethod', null, 'Delivery', mode),
                _labelAr(dc, 'showDeliveryMethod', null, 'طريقة التسليم',
                    mode),
                isDualLanguage,
                isAr: isAr),
            params.deliveryMethod!,
            infoLabel,
            infoValue),
    ];

    // ── Payment breakdown lines (left column) ───────────────────────
    // ══════════════════════════════════════════════════════════════════
    // BUILD PDF
    // ══════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.ltr,
        margin: await CommonPrintSettings.resolvePdfMargins(
          pw.EdgeInsets.only(
            left: isA5 ? 14 : 22,
            right: isA5 ? 14 : 22,
            top: isA5 ? 12 : 18,
            bottom: isA5 ? 12 : 18,
          ),
        ),
        footer: (ctx) => pw.Center(
          child: pdfText('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: fs(6))),
        ),
        build: (pw.Context ctx) {
          return [
            // Document-level header / subheader (shared documentText rule).
            for (final t in [config.header, config.subheader])
              if (params.documentText(t).isNotEmpty)
                pw.Center(
                    child: pdfText(params.documentText(t), style: headerDetailStyle,
                        textAlign: pw.TextAlign.center)),
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
                    headingStyle: englishHeaderCompanyStyle,
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
                    child: storeCrLine.isNotEmpty
                        ? pdfText(storeCrLine, style: crVatStyle)
                        : (cfgVisible('showExtraHeading2') &&
                            extraHeading2.isNotEmpty)
                        ? pdfText(extraHeading2, style: crVatStyle)
                        : (cfgVisible('showFssaiInfo') && storeFssai.isNotEmpty)
                            ? pdfText(storeFssai, style: crVatStyle)
                            : pw.SizedBox(),
                  ),
                ),
                pdfText(invoiceTitleText.toUpperCase(), style: titleStyle),
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: storeVatLine.isNotEmpty
                        ? pdfText(storeVatLine, style: crVatStyle)
                        : (cfgVisible('showFssaiInfo') && storeFssai.isNotEmpty)
                            ? pdfText(storeFssai, style: crVatStyle)
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
                          pdfText(
                              '${_getLabel(params, commentConfigKey, null, 'Comment')}: ${params.orderComment}',
                              style: wordsStyle),
                        ..._customerBalanceLines(
                            params, currency, wordsStyle, wordsBold),
                        if (cfgVisible('showSaved') && saved > 0)
                          pdfText(
                            '${_getLabel(params, 'showSaved', null, 'You Saved:')} ${_formatMoney(currency, saved)}',
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
                                      params, 'showItemsCount', null, 'Items')),
                                  '',
                                  params.cartItems.length.toString(),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueStyle),
                            if (!params.isReturnOnly &&
                                cfgVisible('showQuantityCount'))
                              _totalsRow(
                                  _withColon(_getLabel(params, 'showQuantityCount',
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
                                      'SUB TOTAL', mode),
                                  _labelAr(dc, 'showSubTotal', null,
                                      'المجموع الفرعي', mode),
                                  _formatMoney(currency, netExcTaxValue),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueStyle),
                            if (showDiscountFlag && discountAmountValue != 0)
                              _totalsRow(
                                  _labelEn(dc, 'showDiscount', null, 'DISCOUNT',
                                      mode),
                                  _labelAr(dc, 'showDiscount', null, 'الخصم',
                                      mode),
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
                                      mode),
                                  _labelAr(dc, 'showTax', resolvedLabels?.tax,
                                      'ضريبة القيمة المضافة', mode),
                                  _formatMoney(currency, totalTax),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueStyle),
                            if (showNetFlag)
                              _totalsRow(
                                  _labelEn(dc, 'showNetAmount', null,
                                      'NET AMOUNT', mode),
                                  _labelAr(dc, 'showNetAmount', null,
                                      'المبلغ الصافي', mode),
                                  _formatMoney(currency, totalAmount),
                                  totalsLabelEn,
                                  totalsLabelAr,
                                  totalsValueBold),
                          ],
                        ),
                        if (cfgVisible('showAmountInWords')) ...[
                          pw.SizedBox(height: 4),
                          ..._amountInWords(
                              totalAmount, currency, params, wordsBold),
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
                columnWidths: const {
                  0: pw.FlexColumnWidth(5),
                  1: pw.FixedColumnWidth(8),
                  2: pw.FlexColumnWidth(3),
                  3: pw.FixedColumnWidth(8),
                  4: pw.FlexColumnWidth(6),
                },
                children: [
                  pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.full,
                    children: [
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
                                child: pdfText(
                                    _getLabel(params, 'showBankInfo', null,
                                        'BANK DETAILS'),
                                    style: footerBold,
                                    textAlign: pw.TextAlign.center),
                              ),
                              pw.SizedBox(height: 3),
                              ...bankLines
                                  .map((line) => pdfText(line, style: footerStyle)),
                            ],
                            if (showComment &&
                                params.orderComment != null &&
                                params.orderComment!.isNotEmpty) ...[
                              if (bankLines.isNotEmpty) pw.SizedBox(height: 4),
                              pdfText(
                                  '${_withColon(_getLabel(params, commentConfigKey, null, 'Comment:'))} ${params.orderComment}',
                                  style: wordsStyle),
                            ],
                            ..._buildPaymentBreakdownLines(
                                params, currency, wordsStyle),
                            ..._customerBalanceLines(
                                params, currency, wordsStyle, wordsBold),
                            if (cfgVisible('showSaved') && saved > 0)
                              pdfText(
                                '${_getLabel(params, 'showSaved', null, 'You Saved:')} ${_formatMoney(currency, saved)}',
                                style: wordsBold,
                              ),
                          ],
                        ),
                      ),
                      pw.SizedBox(),
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
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Table(
                            // Keep the original complete payment-summary
                            // grid inside its own payment-summary table.
                            border: pw.TableBorder.all(width: 0.5),
                            columnWidths: const {
                              0: pw.FlexColumnWidth(2.2),
                              1: pw.FlexColumnWidth(2.0),
                              2: pw.FlexColumnWidth(1.8),
                            },
                            children: [
                              if (cfgVisible('showItemsCount'))
                                _totalsRow(
                                    _withColon(_labelEn(dc, 'showItemsCount',
                                        null, 'Items', mode)),
                                    _labelAr(dc, 'showItemsCount', null,
                                        'العدد', mode),
                                    params.cartItems.length.toString(),
                                    totalsLabelEn,
                                    totalsLabelAr,
                                    totalsValueStyle),
                              if (cfgVisible('showQuantityCount'))
                                _totalsRow(
                                    _withColon(_labelEn(dc, 'showQuantityCount',
                                        null, 'Total Qty', mode)),
                                    _labelAr(dc, 'showQuantityCount', null,
                                        'إجمالي الكمية', mode),
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
                                        'SUB TOTAL', mode),
                                    _labelAr(dc, 'showSubTotal', null,
                                        'المجموع الفرعي', mode),
                                    _formatMoney(currency, netExcTaxValue),
                                    totalsLabelEn,
                                    totalsLabelAr,
                                    totalsValueStyle),
                              if (showDiscountFlag && discountAmountValue != 0)
                                _totalsRow(
                                    _labelEn(dc, 'showDiscount', null,
                                        'DISCOUNT', mode),
                                    _labelAr(dc, 'showDiscount', null, 'الخصم',
                                        mode),
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
                                        mode),
                                    _labelAr(dc, 'showTax', resolvedLabels?.tax,
                                        'ضريبة القيمة المضافة', mode),
                                    _formatMoney(currency, totalTax),
                                    totalsLabelEn,
                                    totalsLabelAr,
                                    totalsValueStyle),
                              if (showNetFlag)
                                _totalsRow(
                                    _labelEn(dc, 'showNetAmount', null,
                                        'NET AMOUNT', mode),
                                    _labelAr(dc, 'showNetAmount', null,
                                        'المبلغ الصافي', mode),
                                    _formatMoney(currency, totalAmount),
                                    totalsLabelEn,
                                    totalsLabelAr,
                                    totalsValueBold),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (cfgVisible('showAmountInWords')) ...[
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      ..._amountInWords(
                          totalAmount, currency, params, wordsBold),
                    ],
                  ),
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
                ..._buildFinalSummaryPdfSection(
                    params, currency, font, fontBold, isA5),
            ],

            // ═══════════════════════════════════════════════════════
            // TERMS & CONDITIONS (config value → billDocumentConfig.terms)
            // ═══════════════════════════════════════════════════════
            if (params.termsText.isNotEmpty) ...[
              pdfText(params.termsText, style: smallStyle),
              pw.SizedBox(height: 4),
            ],

            // ═══════════════════════════════════════════════════════
            // THANK YOU (config value → footer → default)
            // ═══════════════════════════════════════════════════════
            if (params.thankYouText.isNotEmpty)
              pw.Center(
                child: pdfText(
                  params.thankYouText,
                  style: footerBold,
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
                    pdfText('Customer Signature: ____________________',
                        style: signatureStyle),
                    pw.SizedBox(width: 6),
                    pdfText('التوقيع',
                        style: signatureArStyle,
                        textDirection: pw.TextDirection.rtl),
                  ],
                ),
                pw.Row(
                  children: [
                    pdfText('Salesman Signature: ____________________',
                        style: signatureStyle),
                    pw.SizedBox(width: 6),
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
    bool singleLineHeading = false,
  }) {
    pw.Widget line(int i) => pdfText(
          lines[i],
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
    if (t.isEmpty) return t; // empty language slot: no orphan colon
    return t.endsWith(':') ? t : '$t:';
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

  /// One-line label through the shared contract (en: English, ar: Arabic,
  /// en_ar: 'Arabic / English'). The Arabic default is derived by the contract.
  String _getLabel(ReceiptLayoutParams params, String key,
          String? resolvedLabel, String defaultLabel) =>
      params.labelFor(key,
          englishFallback: defaultLabel,
          arabicFallback: '',
          resolvedEnglish: resolvedLabel,
          inlineBilingual: true);

  /// English label slot, dual-language aware.
  ///
  /// In dual/Arabic configs the localized custom label lives in `value`
  /// (Arabic) and the English text in `defaultValue`, so the English slot must
  /// prefer `defaultValue`.
  /// Falls back to the English-default resolved label, then the hardcoded
  /// default. Mirrors the English half of the thermal `_getBilingualLabel`.
  String _labelEn(Map<String, DisplayOption>? dc, String key,
      String? resolvedEnglish, String defaultEn, ReceiptLanguageMode mode) {
    // Arabic-only documents have no English slot; English-only documents use
    // the shared contract. Bilingual keeps `default` as the English slot.
    if (mode.isArabic) return '';
    if (mode.isEnglish) {
      return ReceiptConfigurationContract.label(
          options: dc,
          key: key,
          mode: mode,
          englishFallback: defaultEn,
          arabicFallback: '',
          resolvedEnglish: resolvedEnglish);
    }
    final cfgEn = dc?[key]?.defaultValue;
    if (cfgEn != null && cfgEn.isNotEmpty) return cfgEn;
    if (resolvedEnglish != null && resolvedEnglish.isNotEmpty) {
      return resolvedEnglish;
    }
    return defaultEn;
  }

  /// Arabic sub-label slot. In dual configs prefer the localized custom label
  /// (`value`) / localized resolved label; otherwise fall back to the fixed
  /// template translation. Mirrors the Arabic half of `_getBilingualLabel`.
  String _labelAr(Map<String, DisplayOption>? dc, String key,
      String? resolvedArabic, String defaultAr, ReceiptLanguageMode mode) {
    // English-only documents have no Arabic slot; Arabic-only documents use
    // the configured label through the shared contract.
    if (mode.isEnglish) return '';
    if (mode.isArabic) {
      return ReceiptConfigurationContract.label(
          options: dc,
          key: key,
          mode: mode,
          englishFallback: '',
          arabicFallback: defaultAr,
          resolvedArabic: resolvedArabic);
    }
    final cfgAr = dc?[key]?.value as String?;
    if (cfgAr != null && cfgAr.isNotEmpty) return cfgAr;
    if (resolvedArabic != null && resolvedArabic.isNotEmpty) {
      return resolvedArabic;
    }
    return defaultAr;
  }

  /// Bilingual amount-in-words (Arabic + English when the template is Arabic).
  List<pw.Widget> _amountInWords(double total, String currency,
      ReceiptLayoutParams params, pw.TextStyle style) {
    if (params.isBilingual) {
      final ar = AmountHelper()
          .convertNumberToWords(total, currency: currency, language: 'ar');
      final en = AmountHelper()
          .convertNumberToWords(total, currency: currency, language: 'en');
      return [
        pdfText('$ar فقط.', style: style, textDirection: pw.TextDirection.rtl),
        pdfText('$en Only.', style: style),
      ];
    }
    final words = AmountHelper().convertNumberToWords(total,
        currency: currency, language: params.amountInWordsLanguage);
    final suffix = params.isRtl ? ' فقط.' : ' only.';
    return [
      pdfText(
        '$words$suffix',
        style: style,
        textDirection:
            params.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
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
  ) {
    if (params.paidAmount == null || !params.isVisible('showPaymentBreaked')) {
      return [];
    }

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
          '${_getLabel(params, 'showCustomerPrevBalance', null, 'Previous Balance')}: ${_formatMoney(currency, params.customerOldBalance!)}',
          style: style));
    }
    if (showPaid && params.paidAmount != null) {
      lines.add(pdfText(
          '${_getLabel(params, 'showCustomerPaidAmount', null, 'Paid Amount')}: ${_formatMoney(currency, params.paidAmount!)}',
          style: style));
    }
    if (showCurrent && params.customerCurrentBalance != null) {
      lines.add(pdfText(
          '${_getLabel(params, 'showCustomerCurrentBalance', null, 'Current Balance')}: ${_formatMoney(currency, params.customerCurrentBalance!)}',
          style: boldStyle));
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
            pdfText(en, style: headerEn, textAlign: pw.TextAlign.center),
          ],
        ),
      );
    }

    final hdrs = <pw.Widget>[];
    if (showSL) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showSLNumber', resolvedLabels?.slNumberDefault, 'NO', mode),
          _labelAr(dc, 'showSLNumber', resolvedLabels?.slNumber, '', mode)));
    }
    if (showItems) {
      hdrs.add(hdr(
          _labelEn(dc, 'showParticulars', resolvedLabels?.particularsDefault,
              'DESCRIPTION', mode),
          _labelAr(dc, 'showParticulars', resolvedLabels?.particulars, 'الوصف',
              mode)));
    }
    if (showMRP) {
      hdrs.add(hdr(_labelEn(dc, 'showMRP', null, 'MRP', mode),
          _labelAr(dc, 'showMRP', resolvedLabels?.mrp, 'القيمة', mode)));
    }
    if (showQty) {
      hdrs.add(hdr(
          _labelEn(dc, 'showQty', resolvedLabels?.qtyDefault, 'QTY', mode),
          _labelAr(dc, 'showQty', resolvedLabels?.qty, 'كمية', mode)));
    }
    if (showRate) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showRate', resolvedLabels?.rateDefault, 'UNIT PRICE', mode),
          _labelAr(dc, 'showRate', resolvedLabels?.rate, 'سعر الوحده', mode)));
    }
    if (showRateExcTax) {
      hdrs.add(hdr(_labelEn(dc, 'showRateExcTax', null, 'RATE EX TAX', mode),
          _labelAr(dc, 'showRateExcTax', null, 'السعر بدون ضريبة', mode)));
    }
    if (showUnit) {
      hdrs.add(hdr(_labelEn(dc, 'showUnit', null, 'UNIT', mode),
          _labelAr(dc, 'showUnit', resolvedLabels?.unitName, 'الوحدة', mode)));
    }
    if (showDiscountColumn) {
      hdrs.add(hdr(_labelEn(dc, 'showDiscountColumn', null, 'DISCOUNT', mode),
          _labelAr(dc, 'showDiscountColumn', null, 'خصم', mode)));
    }
    if (showTax) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showTaxHeader', resolvedLabels?.taxDefault, 'VAT 15%', mode),
          _labelAr(dc, 'showTaxHeader', resolvedLabels?.tax, 'الضريبة', mode)));
    }
    if (showTotal) {
      hdrs.add(hdr(
          _labelEn(
              dc, 'showTotal', resolvedLabels?.totalDefault, 'NET TOTAL', mode),
          _labelAr(dc, 'showTotal', resolvedLabels?.total, 'الإجمالي الصافي',
              mode)));
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
      final bool isArName = pdfHasArabic(name);

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
    // Labels resolve through the shared contract for the document language.
    String cfgLbl(Map<String, DisplayOption>? options, String key,
        String? resolved, String def) {
      final text = ReceiptConfigurationContract.label(
          options: options,
          key: key,
          mode: params.receiptLanguageMode,
          englishFallback: def,
          arabicFallback: '',
          resolvedEnglish: resolved,
          resolvedArabic: resolved,
          inlineBilingual: true);
      return text.isNotEmpty ? text : def;
    }

    String lbl(String key, String? resolved, String def) =>
        cfgLbl(dc, key, resolved, def);

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
          child: pdfText(text, style: headerStyle, textAlign: pw.TextAlign.center),
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
    String retLbl(String key, String? resolved, String def) =>
        cfgLbl(retDc, key, resolved, def);

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
    String modeText(String english, String arabic) => params.textForMode(
        english: english, arabic: arabic, inlineBilingual: true);
    if (params.isVisible('showCustomerName') &&
        params.customerName != null &&
        params.customerName!.trim().isNotEmpty) {
      custRows.add(_kvRow(
        modeText('Customer Name:', 'اسم العميل:'),
        params.customerName!,
        labelStyle,
        valueStyle,
      ));
    }
    if (params.customerPhoneText.isNotEmpty) {
      custRows.add(_kvRow(modeText('Phone:', 'الهاتف:'),
          params.customerPhoneText, labelStyle, valueStyle));
    }
    if (params.isVisible('showCustomerAddress') &&
        params.customerAddress != null &&
        params.customerAddress!.trim().isNotEmpty) {
      custRows.add(_kvRow(modeText('Billing Address:', 'عنوان الفاتورة:'),
          params.customerAddress!, labelStyle, valueStyle));
    }
    if (custRows.isNotEmpty) {
      widgets.add(pdfText(
          retLabels?.customerHeading ??
              modeText('CUSTOMER DETAILS', 'بيانات العميل'),
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
      widgets.add(pdfText(
          '$countLabel ${orderReturns.returnItems!.length}', style: labelStyle));
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

    if (hasCreditNoteConfig) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.addAll(
          _amountInWords(returnRateTotal, currency, params, labelStyle));
    }

    return widgets;
  }

  List<pw.Widget> _buildFinalSummaryPdfSection(
    ReceiptLayoutParams params,
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

    bool vis(String key) => params.isVisible(key);
    String lbl(String key, String en, String ar) => params.labelFor(key,
        englishFallback: en, arabicFallback: ar, inlineBilingual: true);

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
      tableRows.add(summaryRow(
          lbl('showFinalPurchase', 'Order Total:', 'إجمالي الطلب:'),
          _formatMoney(currency, orderTotal),
          valueStyle));
    }
    if (showFinalReturn) {
      tableRows.add(summaryRow(
          lbl('showFinalReturn', 'Return Total:', 'إجمالي المرتجع:'),
          _formatMoney(currency, returnTotal),
          valueStyle));
    }
    if (showFinalNetAmount) {
      tableRows.add(summaryRow(
          lbl('showFinalNetAmount', 'Final Total:', 'المبلغ النهائي:'),
          _formatMoney(currency, finalTotal),
          valueBold));
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
      widgets
          .addAll(_amountInWords(finalTotal, currency, params, wordsBold));
    }

    return widgets;
  }
}
