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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'standard_pdf_layout.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

/// Standard Tax Invoice PDF layout — enhanced ZATCA-compliant bilingual template.
///
/// Features an enriched Invoice From/To section with Building No, City,
/// Account No, IBAN, C.R No, Customer No fields. QR code is placed
/// beside the "Tax Invoice" title in the top-right header area.
class StandardTaxInvoiceStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'standard_tax_invoice';

  @override
  String get displayName => 'Standard Tax Invoice';

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
    if (url == null || url.isEmpty) return null;
    String fullUrl;
    if (url.startsWith('http')) {
      fullUrl = url;
    } else if (url.startsWith('logos/')) {
      fullUrl = '${APPUrl.baseURL}/storage/$url';
    } else {
      fullUrl = url.startsWith('/')
          ? '${APPUrl.baseURL}$url'
          : '${APPUrl.baseURL}/$url';
    }
    try {
      final uri = Uri.parse(fullUrl);
      final prefs = await SharedPreferences.getInstance();
      final int? activeStoreId = prefs.getInt('active_store_id');

      final Map<String, String> queryParams =
          Map<String, String>.from(uri.queryParameters);
      if (activeStoreId != null) {
        queryParams['store_id'] = activeStoreId.toString();
      }
      final urlWithStore = uri.replace(queryParameters: queryParams);

      final response = await http.get(urlWithStore);
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('[DetailedTaxInvoice] Error fetching logo: $e');
    }
    return null;
  }

  // ── Public interface ────────────────────────────────────────────────
  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    final pdf = await buildPdfDocument(params);
    final sanitized = params.orderNumber.replaceAll('/', '_');
    final output = await _getEposDirectory();
    final file = File('${output.path}/DetailedTaxInvoice_$sanitized.pdf');
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

    // ── Fonts & RTL ─────────────────────────────────────────────────
    final font = await _loadArabicFont();
    final fontBold = await _loadArabicFontBold();
    final configLang = config.language;
    final isRtl = configLang != null
        ? configLang == 'ar'
        : LocalizationService.locale.languageCode == 'ar';
    final textDir = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    double fs(double value) => (isA5 ? value * 0.72 : value * 0.82);

    // ══════════════════════════════════════════════════════════════════
    // EXACT FONT SIZES from reference image
    // ══════════════════════════════════════════════════════════════════
    // Store name: 14pt bold
    final storeNameStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(12), fontWeight: pw.FontWeight.bold);
    // Store address/contact lines: 9pt regular
    final storeInfoStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8));
    // "Tax Invoice" title: 22pt bold
    final taxInvoiceTitleStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(16), fontWeight: pw.FontWeight.bold);
    // "فاتورة ضريبية" Arabic subtitle: 18pt bold
    final taxInvoiceArabicStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(13), fontWeight: pw.FontWeight.bold);
    // VAT No line: 10pt bold
    final vatNoStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8), fontWeight: pw.FontWeight.bold);
    // "الرقم الضريبي" under VAT: 9pt regular
    final vatNoArabicStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));
    // Invoice details table text: 9pt
    final tableInfoStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));
    final tableInfoBold = pw.TextStyle(
        font: fontBold, fontSize: fs(7), fontWeight: pw.FontWeight.bold);
    // Invoice From/To labels: 8pt
    final fromToLabel =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(6.5));
    final fromToValue = pw.TextStyle(
        font: fontBold, fontSize: fs(6.5), fontWeight: pw.FontWeight.bold);
    final fromToHeader = pw.TextStyle(
        font: fontBold, fontSize: fs(7), fontWeight: pw.FontWeight.bold);
    // Items table header: 8pt bold
    final itemsHeaderStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(6.5), fontWeight: pw.FontWeight.bold);
    // Items table body: 9pt
    final itemsBodyStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));
    // Footer text: 9pt
    final footerStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(7));
    final footerBold = pw.TextStyle(
        font: fontBold, fontSize: fs(7), fontWeight: pw.FontWeight.bold);
    // Signature text: 10pt bold
    final signatureStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8), fontWeight: pw.FontWeight.bold);

    // ── Logo ────────────────────────────────────────────────────────
    pw.MemoryImage? logoImage;
    if (config.showLogo == 1 && config.logo != null) {
      logoImage = await _fetchNetworkPdfImage(config.logo.toString());
    }

    // ── Tax totals ──────────────────────────────────────────────────
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
    final totalAmount = double.tryParse(params.formattedTotal) ?? 0.0;
    final discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
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

    // ── Store info from config ──────────────────────────────────────
    final documentHeader = (config.header ?? '').trim();
    final documentSubheader = (config.subheader ?? '').trim();
    final storeName = _cfgVal('showStoreName', 'STORE NAME');
    final storeDesc = _cfgVal('showDescription', '');
    final storeAddress = _cfgVal('showStoreAddress', '');
    final storeFssai = _cfgVal('showFssaiInfo', '');
    final storeTel = _cfgVal('showTel', params.customerCareNumber);
    final storeEmail = _cfgVal('showEmail', params.customerCareEmail);
    final extraHeading1 = _cfgVal('showExtraHeading1', '');
    final extraHeading2 = _cfgVal('showExtraHeading2', '');
    final ibanValue = params.primaryBankAccount?.iban ?? extraHeading2;
    final accountNumberValue =
        params.primaryBankAccount?.accountNumber ?? 'N/A';
    final accountHolderNameValue =
        params.primaryBankAccount?.accountHolderName ?? 'N/A';

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
        params.customerName ?? (isRtl ? 'عميل' : 'Walk-in Customer');
    final custPhone = (isDefault && hideDefaultPhone)
        ? null
        : (params.customerPhone != null
            ? (_cfgVisible('showCustomerPhoneMasked')
                ? StringHelper.maskStringShowLast4(params.customerPhone!)
                : params.customerPhone)
            : null);
    final custAddress = params.customerAddress;
    final custAltPhone = params.customerAlternatePhone;

    String _displayOrNA(String? value) {
      final trimmed = value?.trim();
      return (trimmed != null && trimmed.isNotEmpty) ? trimmed : 'N/A';
    }

    // ══════════════════════════════════════════════════════════════════
    // BUILD PDF — exact reference layout (screenshot match)
    // ══════════════════════════════════════════════════════════════════
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: textDir,
        margin: pw.EdgeInsets.only(
            left: isA5 ? 8 : 14,
            right: isA5 ? 8 : 14,
            top: isA5 ? 8 : 12,
            bottom: isA5 ? 8 : 12),
        footer: (ctx) => pw.Center(
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: fs(5.8))),
        ),
        build: (pw.Context ctx) {
          final fromFieldRows = <pw.Widget>[
            _fromToRow('Name :', _displayOrNA(storeName), 'إسم :', fromToLabel,
                fromToValue),
            _fromToRow('Building No :', _displayOrNA(storeAddress),
                'رقم المبنى :', fromToLabel, fromToValue),
            _fromToRow('Street name :', _displayOrNA(extraHeading1),
                'اسم الشارع :', fromToLabel, fromToValue),
            // _fromToRow('City :', _displayOrNA(extraHeading2), 'مدينة :',
            //     fromToLabel, fromToValue),
            _fromToRow('C.R No :', _displayOrNA(extraHeading2), 'رقم التجارة :',
                fromToLabel, fromToValue),
            _fromToRow('VAT No :', _displayOrNA(params.zatcaVatNumber),
                'رقم الضريبة :', fromToLabel, fromToValue),
            _fromToRow('Account Name :', _displayOrNA(accountHolderNameValue),
                'رقم الحساب :', fromToLabel, fromToValue),
            _fromToRow('Account No :', _displayOrNA(accountNumberValue),
                'رقم الحساب :', fromToLabel, fromToValue),
            _fromToRow('IBAN :', _displayOrNA(ibanValue), 'رقم الآيبان :',
                fromToLabel, fromToValue),
          ];

          final toFieldRows = <pw.Widget>[
            _fromToRow('Name :', _displayOrNA(custName), 'إسم :', fromToLabel,
                fromToValue),
            _fromToRow('Building No :', 'N/A', 'رقم المبنى :', fromToLabel,
                fromToValue),
            _fromToRow('Address :', _displayOrNA(custAddress), 'عنوان :',
                fromToLabel, fromToValue),
            _fromToRow('City :', 'N/A', 'مدينة :', fromToLabel, fromToValue),
            _fromToRow('C.R No :', _displayOrNA(params.customerCrNumber),
                'رقم التجارة :', fromToLabel, fromToValue),
            _fromToRow('VAT No :', _displayOrNA(params.customerVatNumber),
                'رقم الضريبة :', fromToLabel, fromToValue),
            _fromToRow('Phone :', _displayOrNA(custPhone), 'هاتف :',
                fromToLabel, fromToValue),
            _fromToRow('Alt Phone :', _displayOrNA(custAltPhone), 'هاتف بديل :',
                fromToLabel, fromToValue),
          ];

          return [
            // ═══════════════════════════════════════════════════════
            // SECTION 1: TOP HEADER
            // Left: Company info | Right: Tax Invoice + QR + VAT
            // QR code is placed beside the title (screenshot design)
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Left: Company information ──
                pw.Expanded(
                  flex: 1,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (logoImage != null) ...[
                              pw.Container(
                                  height: isA5 ? 16 : 22,
                                  child: pw.Image(logoImage)),
                              pw.SizedBox(height: 2),
                            ],
                            if (documentHeader.isNotEmpty)
                              pw.Text(documentHeader, style: storeNameStyle),
                            if (documentSubheader.isNotEmpty)
                              pw.Text(documentSubheader, style: storeInfoStyle),
                            if (_cfgVisible('showStoreName'))
                              pw.Text(storeName, style: storeNameStyle),
                            if (_cfgVisible('showDescription') &&
                                storeDesc.isNotEmpty)
                              pw.Text(storeDesc, style: storeInfoStyle),
                            if (_cfgVisible('showStoreAddress') &&
                                storeAddress.isNotEmpty)
                              pw.Text(storeAddress, style: storeInfoStyle),
                            if (_cfgVisible('showFssaiInfo') &&
                                storeFssai.isNotEmpty)
                              pw.Text(storeFssai, style: storeInfoStyle),
                            if (_cfgVisible('showExtraHeading1') &&
                                extraHeading1.isNotEmpty)
                              pw.Text(extraHeading1, style: storeInfoStyle),
                            if (_cfgVisible('showEmail') &&
                                storeEmail.isNotEmpty)
                              pw.Text('Email: $storeEmail',
                                  style: storeInfoStyle),
                            if (_cfgVisible('showTel') && storeTel.isNotEmpty)
                              pw.Text('Mob: $storeTel', style: storeInfoStyle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Right: Tax Invoice title + QR Code ──
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Title row with QR beside it
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        // Title text column
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Tax Invoice', style: taxInvoiceTitleStyle),
                            pw.Text('فاتورة ضريبية',
                                style: taxInvoiceArabicStyle,
                                textDirection: pw.TextDirection.rtl),
                          ],
                        ),
                        // QR Code next to the title
                        if (_cfgVisible('showQRCode') && qrData.isNotEmpty) ...[
                          pw.SizedBox(width: 4),
                          pw.Container(
                            width: isA5 ? 40 : 48,
                            height: isA5 ? 40 : 48,
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              width: isA5 ? 40 : 48,
                              height: isA5 ? 40 : 48,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_cfgVisible('showVATFooter') &&
                        params.zatcaVatNumber?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                          '${(_cfgVal('showVATFooter', '')).trim().isNotEmpty ? '${_cfgVal('showVATFooter', '').trim()} ' : ''}${params.zatcaVatNumber}',
                          style: vatNoStyle),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 2: INVOICE DETAILS TABLE (full-width)
            // No QR beside it — QR is in the header above
            // ═══════════════════════════════════════════════════════
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              children: [
                // Header row (bilingual)
                pw.TableRow(children: [
                  _paddedCell(
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Invoice Number', style: tableInfoBold),
                          pw.Text('رقم الفاتورة',
                              style: tableInfoStyle,
                              textDirection: pw.TextDirection.rtl),
                        ],
                      ),
                      4),
                  _paddedCell(
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Invoice Date', style: tableInfoBold),
                          pw.Text('تاريخ الفاتورة',
                              style: tableInfoStyle,
                              textDirection: pw.TextDirection.rtl),
                        ],
                      ),
                      4),
                  _paddedCell(
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Invoice Type', style: tableInfoBold),
                          pw.Text('نوع الفاتورة',
                              style: tableInfoStyle,
                              textDirection: pw.TextDirection.rtl),
                        ],
                      ),
                      4),
                ]),
                // Values row
                pw.TableRow(children: [
                  _paddedCell(
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(invoiceNumber, style: tableInfoStyle),
                          if (_cfgVisible('showTokenNumber') &&
                              params.tokenNumber != null &&
                              params.tokenNumber!.isNotEmpty)
                            pw.Text(
                                '${_cfgVal('showTokenNumber', 'Token - ')}${params.tokenNumber}',
                                style: tableInfoStyle),
                        ],
                      ),
                      4),
                  _paddedCell(pw.Text(displayDate, style: tableInfoStyle), 4),
                  _paddedCell(
                      pw.Text(
                          params.paymentMethod == 'CASH' ? 'Cash' : 'Credit',
                          style: tableInfoStyle),
                      4),
                ]),
              ],
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 3: INVOICE FROM / INVOICE TO
            // Two bordered boxes side by side — extended fields
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── INVOICE FROM ──
                pw.Expanded(
                  child: pw.Container(
                    decoration:
                        pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Header row
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Invoice From', style: fromToHeader),
                              pw.Text('فاتورة من',
                                  style: fromToHeader,
                                  textDirection: pw.TextDirection.rtl),
                            ],
                          ),
                        ),
                        pw.Divider(height: 0, thickness: 0.5),
                        // Field rows — extended with Building No, City, etc.
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: pw.Column(children: fromFieldRows),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── INVOICE TO ──
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: const pw.BorderSide(width: 0.5),
                        bottom: const pw.BorderSide(width: 0.5),
                        right: const pw.BorderSide(width: 0.5),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Header row
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Invoice To', style: fromToHeader),
                              pw.Text('فاتورة إلى',
                                  style: fromToHeader,
                                  textDirection: pw.TextDirection.rtl),
                            ],
                          ),
                        ),
                        pw.Divider(height: 0, thickness: 0.5),
                        // Field rows — extended with Building No, City, etc.
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: pw.Column(children: toFieldRows),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 4: ITEMS TABLE
            // Bilingual headers, bordered, exact column widths
            // ═══════════════════════════════════════════════════════
            _buildItemsTable(
                params, dc, config, itemsHeaderStyle, itemsBodyStyle),
            pw.SizedBox(height: 4),

            // ═══════════════════════════════════════════════════════
            // SECTION 5: FOOTER  (Amount in Words + Totals)
            // ═══════════════════════════════════════════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left side: Amount in Words, Delivery, Payment, etc.
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_cfgVisible('showAmountInWords'))
                        pw.RichText(
                          text: pw.TextSpan(children: [
                            pw.TextSpan(
                                text: 'Amount in Words: ', style: footerBold),
                            pw.TextSpan(
                                text:
                                    '${AmountHelper().convertNumberToWords(totalAmount, currency: currency)} Only',
                                style: footerStyle),
                          ]),
                        ),
                      if (_cfgVisible('showDate'))
                        pw.Text(
                            'Delivery Time: $displayDate${displayTime.isNotEmpty ? ' $displayTime' : ''}',
                            style: pw.TextStyle(
                                font: font,
                                fontBold: fontBold,
                                fontSize: fs(6))),
                      if (_cfgVisible('showPayment') &&
                          params.paymentMethod != null)
                        pw.Text('Payment Method: ${params.paymentMethod}',
                            style: pw.TextStyle(
                                font: font,
                                fontBold: fontBold,
                                fontSize: fs(6))),
                      if (params.orderComment != null &&
                          params.orderComment!.isNotEmpty)
                        pw.Text(
                            '${isRtl ? 'تعليق:' : 'Comment:'} ${params.orderComment}',
                            style: footerStyle),
                      if (params.deliveryMethod != null &&
                          params.deliveryMethod!.isNotEmpty)
                        pw.Text(
                            '${isRtl ? 'التوصيل:' : 'Delivery:'} ${params.deliveryMethod}',
                            style: footerStyle),
                      // Customer Paid Amount
                      if (_cfgVisible('showCustomerPaidAmount') &&
                          params.paidAmount != null)
                        pw.Text(
                            '${_cfgVal('showCustomerPaidAmount', isRtl ? 'المبلغ المدفوع' : 'Paid Amt')}: ${params.paidAmount!.toStringAsFixed(2)}',
                            style: footerStyle),
                      // Customer Current Balance
                      if (_cfgVisible('showCustomerCurrentBalance') &&
                          params.customerCurrentBalance != null)
                        pw.Text(
                            '${_cfgVal('showCustomerCurrentBalance', isRtl ? 'الرصيد الحالي' : 'Cur Bal')}: ${params.customerCurrentBalance!.toStringAsFixed(2)}',
                            style: footerStyle),
                    ],
                  ),
                ),
                // Right side: Totals table
                pw.Expanded(
                  flex: 3,
                  child: pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    children: [
                      if (dc?['showMRPTotal']?.visible != false)
                        _totalsRow('Total (Exc VAT)',
                            totalExclTax.toStringAsFixed(2), footerStyle),
                      if (dc?['showDiscount']?.visible != false &&
                          discountAmountValue > 0)
                        _totalsRow(
                            'Discount',
                            discountAmountValue.toStringAsFixed(2),
                            footerStyle),
                      if (dc?['showTax']?.visible != false)
                        _totalsRow('Total VAT', totalTax.toStringAsFixed(2),
                            footerStyle),
                      if (dc?['showNetAmount']?.visible != false)
                        _totalsRow('Total (Inc VAT)',
                            totalAmount.toStringAsFixed(2), footerBold),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),

            // ═══════════════════════════════════════════════════════
            // ITEMS COUNT
            // ═══════════════════════════════════════════════════════
            if (_cfgVisible('showItemsCount'))
              pw.Text(
                '${_cfgVal('showItemsCount', isRtl ? 'العدد' : 'Items')}: ${params.cartItems.length}',
                style: footerStyle,
              ),
            if (_cfgVisible('showQuantityCount'))
              pw.Text(
                '${_cfgVal('showQuantityCount', isRtl ? 'إجمالي الكمية' : 'Total Qty')}: ${params.totalQuantity % 1 == 0 ? params.totalQuantity.toInt().toString() : params.totalQuantity.toStringAsFixed(2)}',
                style: footerStyle,
              ),

            // ═══════════════════════════════════════════════════════
            // YOU SAVED
            // ═══════════════════════════════════════════════════════
            if (_cfgVisible('showSaved') && saved > 0)
              pw.Text(
                '${_cfgVal('showSaved', isRtl ? 'لقد وفرت:' : 'You Saved:')} ${saved.toStringAsFixed(2)}',
                style: footerBold,
              ),

            pw.SizedBox(height: 3),

            // ═══════════════════════════════════════════════════════
            // TERMS & CONDITIONS
            // ═══════════════════════════════════════════════════════
            if (_cfgVisible('showTermsConditions')) ...[
              pw.Text(
                _cfgVal('showTermsConditions', ''),
                style: pw.TextStyle(
                    font: font, fontBold: fontBold, fontSize: fs(6)),
              ),
              pw.SizedBox(height: 3),
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
            pw.SizedBox(height: 6),

            // ═══════════════════════════════════════════════════════
            // SECTION 6: SIGNATURES
            // ═══════════════════════════════════════════════════════
            if (!isA5)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Receiver: ............................................',
                      style: signatureStyle),
                  pw.Text(
                      'Sales Man: ............................................',
                      style: signatureStyle),
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

  /// Padded table cell.
  pw.Widget _paddedCell(pw.Widget child, double p) {
    return pw.Padding(padding: pw.EdgeInsets.all(p), child: child);
  }

  /// Invoice From/To field row: "Label : Value      ArabicLabel"
  pw.Widget _fromToRow(String label, String value, String arLabel,
      pw.TextStyle normal, pw.TextStyle bold) {
    return pw.SizedBox(
      height: 9,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 0),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 52,
              child: pw.Text(
                label,
                style: normal,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                softWrap: false,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: bold,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                softWrap: false,
              ),
            ),
            pw.SizedBox(
              width: 52,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  arLabel,
                  style: normal,
                  textDirection: pw.TextDirection.rtl,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Totals table row.
  pw.TableRow _totalsRow(String label, String value, pw.TextStyle style) {
    return pw.TableRow(children: [
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(label, style: style)),
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(value, style: style))),
    ]);
  }

  /// Build the items table with bilingual headers.
  pw.Widget _buildItemsTable(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    dynamic config,
    pw.TextStyle headerStyle,
    pw.TextStyle bodyStyle,
  ) {
    bool _col(String key) => dc?[key]?.visible == true;

    final showSL = _col('showSLNumber');
    final showItems = _col('showParticulars');
    final showQty = _col('showQty');
    final showRate = _col('showRate');
    final showDiscount = _col('showDiscount');
    final showTax = _col('showTaxHeader');
    final showTotal = _col('showTotal');

    // Fixed column widths matching the reference image proportions
    final Map<int, pw.TableColumnWidth> colWidths = {};
    int ci = 0;
    if (showSL) colWidths[ci++] = const pw.FlexColumnWidth(0.6);
    if (showItems) colWidths[ci++] = const pw.FlexColumnWidth(3.5);
    if (showQty) colWidths[ci++] = const pw.FlexColumnWidth(1.0);
    if (showRate) colWidths[ci++] = const pw.FlexColumnWidth(1.0);
    if (showDiscount) colWidths[ci++] = const pw.FlexColumnWidth(1.0);
    // Taxable amount
    colWidths[ci++] = const pw.FlexColumnWidth(1.2);
    if (showTax) colWidths[ci++] = const pw.FlexColumnWidth(1.0);
    if (showTotal) colWidths[ci++] = const pw.FlexColumnWidth(1.3);

    // Bilingual header cell
    pw.Widget hdr(String en, String ar) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(en, style: headerStyle, textAlign: pw.TextAlign.center),
              if (ar.isNotEmpty)
                pw.Text(ar,
                    style: headerStyle,
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      );
    }

    // Build header cells
    final hdrs = <pw.Widget>[];
    if (showSL) hdrs.add(hdr('S No', ''));
    if (showItems) hdrs.add(hdr('Description', 'البيان'));
    if (showQty) hdrs.add(hdr('Qty', 'كمية'));
    if (showRate) hdrs.add(hdr('Rate', 'مجموع'));
    if (showDiscount) hdrs.add(hdr('Discount', 'خصم'));
    // Taxable Amount always shown
    hdrs.add(hdr('Taxable Amt', 'المبلغ الخاضع'));
    if (showTax) hdrs.add(hdr('VAT (15%)', 'الضريبة'));
    if (showTotal) hdrs.add(hdr('Total (Inc Vat)', 'الأجمالي'));

    // Build data rows
    final rows = <pw.TableRow>[];
    for (int i = 0; i < params.cartItems.length; i++) {
      final item = params.cartItems[i];
      String name = '';
      double qty = 0, unitPrice = 0, iDiscount = 0, iTax = 0, iTotal = 0;

      if (params.isFromLocalStorage) {
        name = item['productName']?.toString() ?? '';
        qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        unitPrice = double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0;
        iDiscount = double.tryParse(item['discount']?.toString() ?? '0') ?? 0;
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
        iDiscount = double.tryParse(item['discount']?.toString() ?? '0') ?? 0;
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
        try {
          iDiscount =
              double.tryParse(item.discountAmount?.toString() ?? '0') ?? 0;
        } catch (_) {}
      }

      double taxableAmt = iTotal - iTax;

      final cells = <pw.Widget>[];
      if (showSL) cells.add(_dataCell('${i + 1}', bodyStyle));
      if (showItems) {
        cells.add(_dataCell(name, bodyStyle,
            align: pw.Alignment.centerLeft, textDirection: pw.TextDirection.ltr));
      }
      if (showQty) {
        cells.add(_dataCell(qty.toStringAsFixed(3), bodyStyle));
      }
      if (showRate) {
        cells.add(_dataCell(unitPrice.toStringAsFixed(2), bodyStyle));
      }
      if (showDiscount) {
        cells.add(_dataCell(iDiscount.toStringAsFixed(2), bodyStyle));
      }
      // Taxable amount
      cells.add(_dataCell(taxableAmt.toStringAsFixed(2), bodyStyle));
      if (showTax) {
        cells.add(_dataCell(iTax.toStringAsFixed(2), bodyStyle));
      }
      if (showTotal) {
        cells.add(_dataCell(iTotal.toStringAsFixed(2), bodyStyle));
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
      {pw.Alignment align = pw.Alignment.center, pw.TextDirection? textDirection}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: style,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          textDirection: textDirection,
        ),
      ),
    );
  }
}
