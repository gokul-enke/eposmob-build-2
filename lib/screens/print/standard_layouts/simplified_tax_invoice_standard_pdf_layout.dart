import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:pos_machine/resources/localization_service.dart';
import '../logo_loader.dart';
import 'standard_pdf_layout.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

/// Simplified Tax Invoice PDF layout — Saudi ZATCA "Simplified Tax Invoice"
/// design matching the Abyat Al Manarah reference template.
///
/// Visual structure (top → bottom):
///   • Header band: bilingual store name (centered) with logo top-right,
///     closed by a thick accent rule.
///   • Title band: `CR No.` (left) | `SIMPLIFIED TAX INVOICE` + Arabic
///     (center) | `VAT No.` (right).
///   • Info band: customer box (left) + invoice box (middle) + QR (right).
///   • Items table with Arabic-over-English bilingual column headers.
///   • Totals: amount-in-words (left) + bilingual totals box (right).
///   • Signature band (Signature / Salesman Signature) + accent rule.
///   • Footer band: account number / IBAN + store address line.
///
/// All field visibility, data extraction, B2B/B2C title resolution, ZATCA QR,
/// bilingual item names and A4/A5 scaling follow the same rules as the other
/// standard PDF layouts.
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
        currency.trim().toUpperCase() == 'INR' ? '₹' : currency.trim();
    if (currencyPrefix.isEmpty) return amount.toStringAsFixed(2);
    return '$currencyPrefix ${amount.toStringAsFixed(2)}';
  }

  // ── Public interface ────────────────────────────────────────────────
  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    final pdf = await buildPdfDocument(params);
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
    final appSettings =
        Provider.of<AppSettingsProvider>(params.context, listen: false)
            .appSettings;
    final currency = appSettings?.currency ?? '';
    final config = params.billDocumentConfig;
    final dc = config.displayConfiguration?.options;
    final isA5 = params.selectedPaperSize.toUpperCase() == 'A5';
    final pageFormat = isA5 ? PdfPageFormat.a5 : PdfPageFormat.a4;

    // Resolve B2B/B2C invoice title — params.displayConfig is B2B-aware
    final _resolvedTitleOpt = params.displayConfig?['showInvoiceTitle'];
    final _resolvedTitleVal = _resolvedTitleOpt?.value?.toString().trim();
    final _resolvedTitleDefault =
        _resolvedTitleOpt?.defaultValue?.toString().trim();
    final invoiceTitleText = (_resolvedTitleVal?.isNotEmpty == true)
        ? _resolvedTitleVal!
        : (_resolvedTitleDefault?.isNotEmpty == true
            ? _resolvedTitleDefault!
            : 'Simplified Tax Invoice');

    // ── Fonts & RTL ─────────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    final configLang = config.language;
    final isRtl = configLang != null
        ? configLang == 'ar'
        : LocalizationService.locale.languageCode == 'ar';
    // This template is laid out left-to-right by design (English primary with
    // Arabic sub-labels), so the page direction is always LTR regardless of the
    // configured language. Arabic runs carry their own per-widget RTL direction.
    // `isRtl` is still used below only to pick wording for optional extra lines.

    double fs(double value) => (isA5 ? value * 0.78 : value);

    // ── Text styles ─────────────────────────────────────────────────
    final storeNameArStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(18), fontWeight: pw.FontWeight.bold);
    final storeNameEnStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(16), fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: fontBold,
        fontSize: fs(12),
        fontWeight: pw.FontWeight.bold,
        decoration: pw.TextDecoration.underline);
    final titleArStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(11), fontWeight: pw.FontWeight.bold);
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
    if (config.showLogo == 1 && config.logo != null) {
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
    final totalAmount =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    final discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    final subTotal = totalExclTax - discountAmountValue;
    final double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;

    // ── ZATCA QR ────────────────────────────────────────────────────
    String qrData = '';
    final hasZatca = params.zatcaVatNumber?.isNotEmpty == true &&
        params.zatcaCompanyName?.isNotEmpty == true;
    if (hasZatca) {
      qrData = ZatcaQrHelper().generateQrForInvoice(
        sellerName: params.zatcaCompanyName!,
        vatNumber: params.zatcaVatNumber!,
        invoiceDate: params.orderDate,
        totalAmount: totalAmount,
        vatAmount: totalTax,
      );
    }

    // ── Config helpers ──────────────────────────────────────────────
    String _cfgVal(String key, String fallback) {
      final v = dc?[key]?.value as String?;
      return (v != null && v.isNotEmpty) ? v : fallback;
    }

    bool _cfgVisible(String key) => dc?[key]?.visible == true;

    String _displayOrBlank(String? value) {
      final trimmed = value?.trim();
      return (trimmed != null && trimmed.isNotEmpty) ? trimmed : '';
    }

    // ── Store info from config ──────────────────────────────────────
    final documentHeader = (config.header ?? '').trim();
    final documentSubheader = (config.subheader ?? '').trim();
    final _cfgStoreName = _cfgVal('showStoreName', '');
    final storeName = _cfgStoreName.isNotEmpty
        ? _cfgStoreName
        : (params.storeName?.isNotEmpty == true
            ? params.storeName!
            : 'STORE NAME');
    final addressLabel = _cfgVal('showStoreAddress', '');
    final addressVal = params.storeLocation ?? '';
    final storeAddress = addressVal.isNotEmpty
        ? (addressLabel.isNotEmpty ? '$addressLabel: $addressVal' : addressVal)
        : '';
    final telLabel = _cfgVal('showTel', '');
    final telVal = params.storePhone?.isNotEmpty == true
        ? params.storePhone!
        : params.customerCareNumber;
    final storeTel = telVal.isNotEmpty
        ? (telLabel.isNotEmpty ? '$telLabel: $telVal' : telVal)
        : '';
    final extraHeading2 = _cfgVal('showExtraHeading2', '');
    // Seller CR number (mirrors the convention used by standard_tax_invoice).
    final sellerCrNumber = extraHeading2;
    final ibanValue = params.primaryBankAccount?.iban ?? '';
    final accountNumberValue = params.primaryBankAccount?.accountNumber ?? '';

    // Two header lines — header acts as the primary (e.g. Arabic) name,
    // subheader as the secondary (e.g. English) name. Falls back to the
    // resolved store name when neither is configured.
    final headerPrimary =
        documentHeader.isNotEmpty ? documentHeader : storeName;
    final headerSecondary = documentSubheader;

    // Invoice number with prefix + stripping
    final prefix = config.numberPrefix ?? '';
    final invRegex = RegExp(r'[1-9]\d*');
    final invMatch = invRegex.firstMatch(params.orderNumber);
    final strippedOrderNumber =
        invMatch != null ? invMatch.group(0)! : params.orderNumber;
    final invoiceNumber = '$prefix$strippedOrderNumber';

    // ── Date parsing ────────────────────────────────────────────────
    String displayDate = params.orderDate;
    String displayTime = '';
    try {
      final dt = DateTime.parse(params.orderDate);
      displayDate = DateHelper.formatDate(dt);
      displayTime = DateFormat('hh:mm:ss a').format(dt);
    } catch (_) {}

    // ── Customer info ───────────────────────────────────────────────
    final bool isDefault = params.isDefaultCustomer;
    final bool hideDefaultPhone = params.hideDefaultCustomerPhone;
    final custName =
        params.customerName ?? (isRtl ? 'عميل' : 'GENERAL');
    final custPhone = (isDefault && hideDefaultPhone)
        ? null
        : (params.customerPhone != null
            ? (_cfgVisible('showCustomerPhoneMasked')
                ? StringHelper.maskStringShowLast4(params.customerPhone!)
                : params.customerPhone)
            : null);
    final custAddress = params.customerAddress;

    // English-primary template — keep the value in English.
    final cashCreditText = (params.paymentMethod == null ||
            params.paymentMethod!.isEmpty ||
            params.paymentMethod == 'CASH')
        ? 'Cash'
        : 'Credit';

    final deliveryNoteNo = (_cfgVisible('showTokenNumber') &&
            params.tokenNumber != null &&
            params.tokenNumber!.isNotEmpty)
        ? params.tokenNumber!
        : '';

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
            // SECTION 1: HEADER — bilingual store name + logo
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (headerPrimary.isNotEmpty)
                        pw.Text(headerPrimary,
                            style: storeNameArStyle,
                            textAlign: pw.TextAlign.center),
                      if (headerSecondary.isNotEmpty)
                        pw.Text(headerSecondary,
                            style: storeNameEnStyle,
                            textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),
                if (logoImage != null)
                  pw.Container(
                    height: isA5 ? 36 : 48,
                    width: isA5 ? 48 : 64,
                    alignment: pw.Alignment.centerRight,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Container(height: 3, color: _accent),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 2: TITLE BAND — CR No | Title | VAT No
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Left: CR No
                pw.Expanded(
                  child: pw.Text(
                    'CR No.${_displayOrBlank(sellerCrNumber)}',
                    style: crVatStyle,
                  ),
                ),
                // Center: title (bilingual)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(invoiceTitleText.toUpperCase(), style: titleStyle),
                    pw.Text('فاتورة ضريبية مبسطة',
                        style: titleArStyle,
                        textDirection: pw.TextDirection.rtl),
                  ],
                ),
                // Right: VAT No
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'VAT No. ${_displayOrBlank(params.zatcaVatNumber)}',
                      style: crVatStyle,
                    ),
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
                  // ── Customer box ──
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (_cfgVisible('showCustomerName'))
                          _kvRow('Customer', custName, infoLabel, infoValue),
                        if (_cfgVisible('showCustomerAddress'))
                          _kvRow('Address', _displayOrBlank(custAddress),
                              infoLabel, infoValue),
                        _kvRow('Customer VAT No.',
                            _displayOrBlank(params.customerVatNumber),
                            infoLabel, infoValue),
                        _kvRow('PO No.', '', infoLabel, infoValue),
                        if (custPhone != null)
                          _kvRow('Phone', custPhone, infoLabel, infoValue),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // ── Invoice box ──
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _kvRow('Invoice No.', invoiceNumber, infoLabel,
                            infoValue),
                        _kvRow('Date:', displayDate, infoLabel, infoValue),
                        _kvRow('Cash/Credit:', cashCreditText, infoLabel,
                            infoValue),
                        _kvRow('Delivery Note No:', deliveryNoteNo, infoLabel,
                            infoValue),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // ── QR ──
                  if (_cfgVisible('showQRCode') && qrData.isNotEmpty)
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
            // SECTION 4: ITEMS TABLE
            // ═══════════════════════════════════════════════════════
            _buildItemsTable(
                params, dc, currency, itemsHeaderEn, itemsHeaderAr,
                itemsBodyStyle),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 5: AMOUNT IN WORDS (left) + TOTALS BOX (right)
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_cfgVisible('showAmountInWords'))
                        pw.Text(
                          '${AmountHelper().convertNumberToWords(totalAmount, currency: currency)} only.',
                          style: wordsBold,
                        ),
                      pw.SizedBox(height: 4),
                      if (_cfgVisible('showDate'))
                        pw.Text(
                            'Delivery Time: $displayDate${displayTime.isNotEmpty ? ' $displayTime' : ''}',
                            style: smallStyle),
                      if (_cfgVisible('showPayment') &&
                          params.paymentMethod != null)
                        pw.Text(
                            isRtl
                                ? 'طريقة الدفع: ${params.paymentMethod}'
                                : 'Payment Method: ${params.paymentMethod}',
                            style: smallStyle),
                      if (params.orderComment != null &&
                          params.orderComment!.isNotEmpty)
                        pw.Text(
                            '${isRtl ? 'تعليق:' : 'Comment:'} ${params.orderComment}',
                            style: wordsStyle),
                      if (params.deliveryMethod != null &&
                          params.deliveryMethod!.isNotEmpty)
                        pw.Text(
                            '${isRtl ? 'التوصيل:' : 'Delivery:'} ${params.deliveryMethod}',
                            style: wordsStyle),
                      if (_cfgVisible('showCustomerPaidAmount') &&
                          params.paidAmount != null)
                        pw.Text(
                            '${_cfgVal('showCustomerPaidAmount', isRtl ? 'المبلغ المدفوع' : 'Paid Amt')}: ${_formatMoney(currency, params.paidAmount!)}',
                            style: wordsStyle),
                      if (_cfgVisible('showCustomerCurrentBalance') &&
                          params.customerCurrentBalance != null)
                        pw.Text(
                            '${_cfgVal('showCustomerCurrentBalance', isRtl ? 'الرصيد الحالي' : 'Cur Bal')}: ${_formatMoney(currency, params.customerCurrentBalance!)}',
                            style: wordsStyle),
                      if (_cfgVisible('showItemsCount'))
                        pw.Text(
                          '${_cfgVal('showItemsCount', isRtl ? 'العدد' : 'Items')}: ${params.cartItems.length}',
                          style: wordsStyle,
                        ),
                      if (_cfgVisible('showQuantityCount'))
                        pw.Text(
                          '${_cfgVal('showQuantityCount', isRtl ? 'إجمالي الكمية' : 'Total Qty')}: ${params.totalQuantity % 1 == 0 ? params.totalQuantity.toInt().toString() : params.totalQuantity.toStringAsFixed(2)}',
                          style: wordsStyle,
                        ),
                      if (_cfgVisible('showSaved') && saved > 0)
                        pw.Text(
                          '${_cfgVal('showSaved', isRtl ? 'لقد وفرت:' : 'You Saved:')} ${_formatMoney(currency, saved)}',
                          style: wordsBold,
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                // Totals box (bilingual)
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
                      if ((dc?['showSubTotal']?.visible ??
                              dc?['showMRPTotal']?.visible) !=
                          false)
                        _totalsRow('TOTAL', 'المجموع',
                            _formatMoney(currency, totalExclTax),
                            totalsLabelEn, totalsLabelAr, totalsValueStyle),
                      if (dc?['showDiscount']?.visible != false)
                        _totalsRow('DISCOUNT', 'خصم',
                            _formatMoney(currency, discountAmountValue),
                            totalsLabelEn, totalsLabelAr, totalsValueStyle),
                      if ((dc?['showSubTotal']?.visible ??
                              dc?['showMRPTotal']?.visible) !=
                          false)
                        _totalsRow('SUB TOTAL', 'المجموع الفرعي',
                            _formatMoney(currency, subTotal),
                            totalsLabelEn, totalsLabelAr, totalsValueStyle),
                      if (dc?['showTax']?.visible != false)
                        _totalsRow('TOTAL VAT 15%', 'ضريبة القيمة المضافة',
                            _formatMoney(currency, totalTax),
                            totalsLabelEn, totalsLabelAr, totalsValueStyle),
                      if (dc?['showNetAmount']?.visible != false)
                        _totalsRow('NET AMOUNT', 'المبلغ الصافي',
                            _formatMoney(currency, totalAmount),
                            totalsLabelEn, totalsLabelAr, totalsValueBold),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // TERMS & CONDITIONS
            // ═══════════════════════════════════════════════════════
            if (_cfgVisible('showTermsConditions')) ...[
              pw.Text(_cfgVal('showTermsConditions', ''), style: smallStyle),
              pw.SizedBox(height: 4),
            ],

            // ═══════════════════════════════════════════════════════
            // THANK YOU MESSAGE
            // ═══════════════════════════════════════════════════════
            if (_cfgVisible('showThankYouMessage'))
              pw.Center(
                child: pw.Text(
                  _cfgVal(
                      'showThankYouMessage',
                      isRtl
                          ? 'شكراً لتسوقكم معنا'
                          : 'Thank you for your business'),
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
            // SECTION 7: FOOTER BAND — account / IBAN + store line
            // ═══════════════════════════════════════════════════════
            if (accountNumberValue.isNotEmpty || ibanValue.isNotEmpty)
              pw.Text(
                'ACCOUNT NUMBER AT ${_displayOrBlank(accountNumberValue)}${ibanValue.isNotEmpty ? ' / IBAN ${_displayOrBlank(ibanValue)}' : ''}',
                style: footerBold,
              ),
            pw.Text(
              [
                storeName,
                if (storeAddress.isNotEmpty) storeAddress,
                if (storeTel.isNotEmpty) 'Mobile No.$storeTel',
              ].join(' . '),
              style: footerStyle,
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
            child: pw.Text(
              label,
              style: labelStyle,
              maxLines: 1,
              softWrap: false,
              overflow: pw.TextOverflow.clip,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: valueStyle,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
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
        child: pw.Text(en, style: enStyle),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(ar, style: arStyle, textDirection: pw.TextDirection.rtl),
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
  String _bilingualItemName(
      dynamic item, String englishName, ReceiptLayoutParams params) {
    final bool isAr =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';
    if (!isAr) return englishName;
    String? ar;
    try {
      if (item is Map) {
        final n = item['product_names'] ?? item['productNames'] ?? item['names'];
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
    String currency,
    pw.TextStyle headerEn,
    pw.TextStyle headerAr,
    pw.TextStyle bodyStyle,
  ) {
    bool _col(String key) => dc?[key]?.visible == true;

    final showSL = _col('showSLNumber');
    final showItems = _col('showParticulars');
    final showQty = _col('showQty');
    final showRate = _col('showRate');
    final showTax = _col('showTaxHeader');
    final showTotal = _col('showTotal');

    // Column widths matching the reference proportions.
    final Map<int, pw.TableColumnWidth> colWidths = {};
    int ci = 0;
    if (showSL) colWidths[ci++] = const pw.FlexColumnWidth(0.6);
    if (showItems) colWidths[ci++] = const pw.FlexColumnWidth(4.5);
    if (showQty) colWidths[ci++] = const pw.FlexColumnWidth(1.0);
    if (showRate) colWidths[ci++] = const pw.FlexColumnWidth(1.4);
    // AMOUNT (taxable / excl-VAT line total) always shown
    colWidths[ci++] = const pw.FlexColumnWidth(1.4);
    if (showTax) colWidths[ci++] = const pw.FlexColumnWidth(1.2);
    if (showTotal) colWidths[ci++] = const pw.FlexColumnWidth(1.5);

    // Bilingual header cell — Arabic on top, English below (reference order).
    pw.Widget hdr(String en, String ar, {pw.Alignment? align}) {
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
    if (showSL) hdrs.add(hdr('NO', ''));
    if (showItems) hdrs.add(hdr('DESCRIPTION', 'الوصف'));
    if (showQty) hdrs.add(hdr('QTY', 'كمية'));
    if (showRate) hdrs.add(hdr('UNIT PRICE', 'سعر الوحده'));
    hdrs.add(hdr('AMOUNT', 'مقدار'));
    if (showTax) hdrs.add(hdr('VAT 15%', 'الضريبة'));
    if (showTotal) hdrs.add(hdr('NET TOTAL', 'الإجمالي الصافي'));

    final rows = <pw.TableRow>[];
    for (int i = 0; i < params.cartItems.length; i++) {
      final item = params.cartItems[i];
      String name = '';
      double qty = 0, unitPrice = 0, iTax = 0, iTotal = 0;

      if (params.isFromLocalStorage) {
        name = item['productName']?.toString() ?? '';
        qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        unitPrice = double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0;
        iTax = double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0;
        iTotal = double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0;
      } else if (item is Map) {
        name = item['product_name']?.toString() ??
            item['productName']?.toString() ??
            '';
        qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        unitPrice = double.tryParse(item['unit_price']?.toString() ??
                item['unitPrice']?.toString() ??
                '0') ??
            0;
        iTax = double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0;
        iTotal = double.tryParse(item['total_price']?.toString() ??
                item['totalPrice']?.toString() ??
                '0') ??
            0;
      } else {
        try {
          name = item.productName ?? '';
          qty = double.tryParse(item.quantity?.toString() ?? '0') ?? 0;
          unitPrice = double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0;
          iTax = double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0;
          iTotal = double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0;
        } catch (_) {}
      }

      final double taxableAmt = iTotal - iTax;
      // Unit price excluding VAT (reference UNIT PRICE column is excl-VAT).
      final double rateExcTax = qty > 0 ? taxableAmt / qty : unitPrice;

      name = _bilingualItemName(item, name, params);
      final bool isArName =
          (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar' &&
              name.contains('\n');

      final cells = <pw.Widget>[];
      if (showSL) cells.add(_dataCell('${i + 1}', bodyStyle));
      if (showItems) {
        cells.add(_dataCell(name, bodyStyle,
            align:
                isArName ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            textDirection:
                isArName ? pw.TextDirection.rtl : pw.TextDirection.ltr));
      }
      if (showQty) {
        cells.add(_dataCell(qty.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      if (showRate) {
        cells.add(_dataCell(rateExcTax.toStringAsFixed(2), bodyStyle,
            align: pw.Alignment.centerRight));
      }
      // AMOUNT (excl VAT)
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
