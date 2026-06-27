import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/logo_loader.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// A new copy of the Classic PDF layout, migrated to the modern theme architecture.
/// This file is 100% independent and does not rely on StandardPrinter.
class NewClassicStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'new_classic';

  @override
  String get displayName => 'New Classic (Standard)';

  // Cache for the Arabic fonts
  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;

  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    try {
      final doc = await buildPdfDocument(params);
      final pdfBytes = await doc.save();

      // Save PDF to documents/epos folder
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedOrderNumber =
          params.orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/Receipt_$sanitizedOrderNumber.pdf');
      await file.writeAsBytes(pdfBytes);

      final bool isWindows = Platform.isWindows;

      if (isWindows) {
        await _handleWindowsPdf(params.context, file);
      } else {
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            await _sharePdfFallback(params.context, file);
          } else {
            if (params.context.mounted) {
              showScaffold(
                  context: params.context, message: "PDF opened for printing");
            }
          }
        } catch (e) {
          debugPrint("Error opening PDF: ${e.toString()}");
          await _sharePdfFallback(params.context, file);
        }
      }
    } catch (e) {
      debugPrint("Error generating PDF: ${e.toString()}");
      if (params.context.mounted) {
        showScaffoldError(
          context: params.context,
          message: "Error generating PDF: ${e.toString()}",
        );
      }
    }
  }

  @override
  Future<pw.Document> buildPdfDocument(ReceiptLayoutParams params) async {
    final pdf = pw.Document();

    // Load fonts
    final arabicFont = await _loadArabicFont();
    final arabicFontBold = await _loadArabicFontBold();

    // Load Logo if enabled
    pw.MemoryImage? logoImage;
    if (params.billDocumentConfig.showLogo == 1) {
      try {
        if (params.billDocumentConfig.logo != null &&
            params.billDocumentConfig.logo.toString().isNotEmpty) {
          logoImage = await _fetchNetworkPdfImage(
              params.billDocumentConfig.logo.toString());
        }
      } catch (e) {
        debugPrint("Error loading logo for new classic print: $e");
      }
    }

    // Determine text direction
    final configLanguage = params.billDocumentConfig.language;
    final isRtl = configLanguage != null
        ? configLanguage.toLowerCase() == 'ar'
        : LocalizationService.locale.languageCode == 'ar';
    final textDirection = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    // Access App Settings Provider for currency symbol
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(params.context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    // Access Payment Gateways Provider for QR
    final paymentGatewaysProvider =
        Provider.of<PaymentGatewaysProvider>(params.context, listen: false);
    final manualPaymentGateway =
        paymentGatewaysProvider.paymentGateways.firstWhere(
      (gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY",
      orElse: () => PaymentGateway(
          id: 0,
          name: "",
          code: "",
          label: "",
          link: "",
          image: "",
          status: "",
          isWebActive: 0,
          isAndroidActive: 0,
          isIosActive: 0,
          contactEmail: "",
          contactPhone: "",
          createdAt: "",
          updatedAt: ""),
    );

    // Page Format
    PdfPageFormat pageFormat =
        params.selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;

    // Shared Styles (Updated for better hierarchy)
    final headerStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: params.selectedPaperSize == 'A5' ? 15.0 : 18.0,
      fontWeight: pw.FontWeight.bold,
    );
    final subheaderStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: params.selectedPaperSize == 'A5' ? 10.0 : 12.0,
      fontWeight: pw.FontWeight.bold,
    );
    final labelStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: params.selectedPaperSize == 'A5' ? 7.0 : 9.0,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
    );
    final bodyStyle = pw.TextStyle(
      font: arabicFont,
      fontBold: arabicFontBold,
      fontSize: params.selectedPaperSize == 'A5' ? 8.0 : 10.0,
    );
    final tableHeaderStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: params.selectedPaperSize == 'A5' ? 8.0 : 9.0,
      fontWeight: pw.FontWeight.bold,
    );
    final summaryStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: params.selectedPaperSize == 'A5' ? 9.0 : 11.0,
      fontWeight: pw.FontWeight.bold,
    );
    final netTotalStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: params.selectedPaperSize == 'A5' ? 12.0 : 14.0,
      fontWeight: pw.FontWeight.bold,
    );

    final displayConfig = params.displayConfig;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: textDirection,
        margin: const pw.EdgeInsets.all(10),
        footer: (context) {
          // Barcode + thank-you live in the footer area of the LAST page only,
          // so they sit at the bottom of the final page and can never push a
          // near-empty extra page into existence.
          final bool isLastPage = context.pageNumber == context.pagesCount;
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (isLastPage) ...[
                _buildOrderBarcodePDF(
                    params.selectedPaperSize, params.orderNumber),
                if (displayConfig?['showThankYouMessage']?.visible == true)
                  pw.Center(
                    child: pw.Text(
                      (displayConfig?['showThankYouMessage']?.value as String?)
                                  ?.isNotEmpty ==
                              true
                          ? displayConfig!['showThankYouMessage']!.value
                              as String
                          : (isRtl
                              ? 'شكراً لك... نتمنى زيارتكم مرة أخرى'
                              : 'Thank You... Visit Again'),
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontSize:
                              params.selectedPaperSize == 'A5' ? 8.0 : 10.0,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                pw.SizedBox(height: 4),
              ],
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          // Store Header
          _buildStoreHeader(params, logoImage, headerStyle, subheaderStyle,
              bodyStyle, isRtl, arabicFont, arabicFontBold),

          pw.SizedBox(height: 6),

          // Invoice Info - Side by side FROM and BILL TO
          pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: isRtl
                  ? [
                      pw.Expanded(
                          child: _buildCustomerDetailsPDF(
                              params,
                              subheaderStyle,
                              bodyStyle,
                              isRtl,
                              arabicFontBold,
                              labelStyle)),
                      pw.SizedBox(width: 40),
                      pw.Expanded(
                          child: _buildInvoiceSideInfo(
                              params, subheaderStyle, labelStyle, isRtl)),
                    ]
                  : [
                      pw.Expanded(
                          child: _buildInvoiceSideInfo(
                              params, subheaderStyle, labelStyle, isRtl)),
                      pw.SizedBox(width: 40),
                      pw.Expanded(
                          child: _buildCustomerDetailsPDF(
                              params,
                              subheaderStyle,
                              bodyStyle,
                              isRtl,
                              arabicFontBold,
                              labelStyle)),
                    ]),

          pw.SizedBox(height: 6),

          // Date & Time Row - Modern Spaced
          _buildDateTimeRowPDF(params.selectedPaperSize, params.orderDate,
              params.isFromLocalStorage,
              isRtl: isRtl,
              arabicFontBold: arabicFontBold,
              displayConfig: displayConfig,
              labelStyle: labelStyle),

          // Items Table
          if (displayConfig?['showSLNumber']?.visible == true ||
              displayConfig?['showParticulars']?.visible == true ||
              displayConfig?['showMRP']?.visible == true ||
              displayConfig?['showQty']?.visible == true ||
              displayConfig?['showRate']?.visible == true ||
              displayConfig?['showTotal']?.visible == true)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: _buildPdfItemsTable(
                  tableHeaderStyle, bodyStyle, displayConfig, params, isRtl),
            ),

          // Cart Total Row
          _buildCartTotalRow(params, summaryStyle, isRtl, arabicFont,
              arabicFontBold, currency),

          pw.SizedBox(height: 3),

          // Summary Section
          if (displayConfig?['showItemsCount']?.visible == true ||
              (displayConfig?['showSubTotal']?.visible ?? displayConfig?['showMRPTotal']?.visible) == true ||
              displayConfig?['showSaved']?.visible == true ||
              displayConfig?['showDiscount']?.visible == true ||
              displayConfig?['showNetAmount']?.visible == true)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 4, horizontal: 2),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                      ),
                    ),
                    child: pw.Text(
                      displayConfig?['showOrderSummary']?.value as String? ??
                          (isRtl ? 'ملخص الطلب' : 'ORDER SUMMARY'),
                      style: subheaderStyle,
                      textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  _buildPdfSummary(summaryStyle, netTotalStyle, displayConfig,
                      params, isRtl),

                  // Amount in words is now handled inside _buildPdfSummary
                  // alongside Net Total.

                  // Customer Balance
                  if ((displayConfig?['showCustomerPrevBalance']?.visible ==
                              true &&
                          params.customerOldBalance != null) ||
                      (displayConfig?['showCustomerCurrentBalance']?.visible ==
                              true &&
                          params.customerCurrentBalance != null) ||
                      (displayConfig?['showCustomerPaidAmount']?.visible ==
                              true &&
                          params.paidAmount != null))
                    _buildCustomerBalancePdf(
                        params, bodyStyle, isRtl, arabicFont, arabicFontBold,
                        delivery: params.deliveryMethod),
                ],
              ),
            ),

          // Order Returns
          if (params.hasReturns) ...[
            pw.SizedBox(height: 5),
            _buildOrderReturnsSection(params, subheaderStyle, bodyStyle,
                tableHeaderStyle, summaryStyle, netTotalStyle, isRtl),
          ],

          // Total Summary (when returns exist)
          if (params.hasReturns) ...[
            _buildTotalSummarySection(params, subheaderStyle, summaryStyle,
                netTotalStyle, currency, isRtl),
            pw.SizedBox(height: 10),
          ],

          // Order Returns
          if (params.hasReturns) ...[
            pw.SizedBox(height: 5),
            _buildOrderReturnsSection(params, subheaderStyle, bodyStyle,
                tableHeaderStyle, summaryStyle, netTotalStyle, isRtl),
          ],

          // Total Summary (when returns exist)
          if (params.hasReturns) ...[
            _buildTotalSummarySection(params, subheaderStyle, summaryStyle,
                netTotalStyle, currency, isRtl),
            pw.SizedBox(height: 10),
          ],

          // Comment
          if (params.orderComment != null &&
              params.orderComment!.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            _buildLabelValueRow(isRtl ? 'تعليق:' : 'Comment:',
                params.orderComment!, summaryStyle,
                isRtl: isRtl),
            pw.SizedBox(height: 5),
          ],

          // Footer — wrapped in a Container so MultiPage treats it as one
          // atomic block (prevents the barcode/thank-you tail from orphaning
          // onto a near-empty second page).
          // QR + terms stay in the document flow. The barcode and thank-you
          // message are rendered in the last-page footer (see `footer:` above)
          // so they never spill onto a second page on their own.
          pw.Container(
            child: pw.Column(
            children: [
              if (displayConfig?['showQRCode']?.visible == true) ...[
                _buildQrCodeSection(
                    params, manualPaymentGateway, isRtl, arabicFontBold),
                pw.SizedBox(height: 5),
              ],
              if (displayConfig?['showTermsConditions']?.visible == true &&
                  _hasTermsData(displayConfig, params.billDocumentConfig))
                _buildTermsConditionsBoxPDF(params.selectedPaperSize,
                    displayConfig, params.billDocumentConfig,
                    isRtl: isRtl,
                    arabicFont: arabicFont,
                    arabicFontBold: arabicFontBold),
            ],
          )),
        ],
      ),
    );

    return pdf;
  }

  // --- PRIVATE HELPER METHODS (Copied from StandardPrinter) ---

  pw.Widget _buildStoreHeader(
      ReceiptLayoutParams params,
      pw.MemoryImage? logoImage,
      pw.TextStyle headerStyle,
      pw.TextStyle subheaderStyle,
      pw.TextStyle bodyStyle,
      bool isRtl,
      pw.Font arabicFont,
      pw.Font arabicFontBold) {
    final displayConfig = params.displayConfig;
    return pw.Center(
      child: pw.Column(
        children: [
          if (logoImage != null) ...[
            pw.Container(height: 26, child: pw.Image(logoImage)),
            pw.SizedBox(height: 3),
          ],
          if (displayConfig?['showStoreName']?.visible == true)
            pw.Text(
              ((displayConfig?['showStoreName']?.value as String?)?.isNotEmpty == true
                  ? displayConfig!['showStoreName']!.value as String
                  : (params.storeName?.isNotEmpty == true
                      ? params.storeName!
                      : (params.billDocumentConfig.header?.isNotEmpty == true
                          ? params.billDocumentConfig.header!
                          : (isRtl ? 'اسم المتجر' : 'STORE NAME')))),
              style: headerStyle,
            ),
          if (displayConfig?['showDescription']?.visible == true)
            pw.Text(
                displayConfig?['showDescription']?.value as String? ??
                    params.billDocumentConfig.subheader ??
                    '',
                style: pw.TextStyle(
                    font: arabicFont,
                    fontBold: arabicFontBold,
                    fontSize: params.selectedPaperSize == 'A5' ? 8.0 : 10.0)),
          if (displayConfig?['showStoreAddress']?.visible == true &&
              (params.storeLocation?.isNotEmpty == true))
            pw.Text(
                () {
                  final addressLabel = (displayConfig?['showStoreAddress']?.value as String?) ?? '';
                  final addressVal = params.storeLocation!;
                  return addressLabel.isNotEmpty ? '$addressLabel: $addressVal' : addressVal;
                }(),
                style: bodyStyle),
          if (displayConfig?['showFssaiInfo']?.visible == true &&
              (displayConfig?['showFssaiInfo']?.value as String?)?.isNotEmpty ==
                  true)
            pw.Text(displayConfig!['showFssaiInfo']!.value as String,
                style: bodyStyle),
          if (displayConfig?['showTel']?.visible == true)
            () {
              final phoneVal = params.storePhone?.isNotEmpty == true ? params.storePhone! : params.customerCareNumber;
              if (phoneVal.isEmpty) return pw.SizedBox();
              final label = displayConfig?['showTel']?.value as String? ?? '';
              return pw.Text(label.isNotEmpty ? '$label: $phoneVal' : phoneVal, style: bodyStyle);
            }(),
          if (displayConfig?['showEmail']?.visible == true)
            () {
              final emailVal = params.storeEmail?.isNotEmpty == true ? params.storeEmail! : params.customerCareEmail;
              if (emailVal.isEmpty) return pw.SizedBox();
              final label = displayConfig?['showEmail']?.value as String? ?? '';
              return pw.Text(label.isNotEmpty ? '$label: $emailVal' : emailVal, style: bodyStyle);
            }(),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceSideInfo(ReceiptLayoutParams params,
      pw.TextStyle subheaderStyle, pw.TextStyle labelStyle, bool isRtl) {
    final displayConfig = params.displayConfig;
    return pw.Column(
      crossAxisAlignment:
          isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(isRtl ? 'من:' : 'FROM:', style: labelStyle),
        pw.SizedBox(height: 4),
        if (displayConfig?['showInvoiceTitle']?.visible == true)
          pw.Text(
              (displayConfig?['showInvoiceTitle']?.value as String?)
                          ?.isNotEmpty ==
                      true
                  ? displayConfig!['showInvoiceTitle']!.value as String
                  : (isRtl ? 'فاتورة' : 'INVOICE'),
              style: subheaderStyle),
        if (displayConfig?['showInvoiceNumber']?.visible == true)
          pw.Text(
              (params.billDocumentConfig.numberPrefix?.isNotEmpty == true)
                  ? '${params.billDocumentConfig.numberPrefix}${params.orderNumber}'
                  : (isRtl
                      ? 'رقم: ${params.orderNumber}'
                      : 'No: ${params.orderNumber}'),
              style: subheaderStyle),
        if (displayConfig?['showTokenNumber']?.visible == true &&
            params.tokenNumber?.isNotEmpty == true)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child:
                pw.Text('Token: ${params.tokenNumber!}', style: subheaderStyle),
          ),
      ],
    );
  }

  pw.Widget _buildLabelValueRow(String label, String value, pw.TextStyle style,
      {bool isRtl = false,
      pw.TextStyle? valueStyle,
      pw.MainAxisAlignment mainAxisAlignment = pw.MainAxisAlignment.start}) {
    final effectiveValueStyle = valueStyle ?? style;
    final children = isRtl
        ? [
            pw.Text(value, style: effectiveValueStyle),
            pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Text(label, style: style))
          ]
        : [
            pw.Text(label, style: style),
            pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Text(value, style: effectiveValueStyle))
          ];

    return pw.Row(mainAxisAlignment: mainAxisAlignment, children: children);
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

  pw.Widget _buildPdfItemsTable(
      pw.TextStyle headerStyle,
      pw.TextStyle contentStyle,
      Map<String, DisplayOption>? displayConfig,
      ReceiptLayoutParams params,
      bool isRtl) {
    final List<String> tableHeaders = [];
    final Map<int, pw.Alignment> cellAlignmentsMap = {};
    final List<double> columnWidths = [];
    int visibleColIndex = 0;

    void addCol(
        String key, String defaultLabel, double width, pw.Alignment align) {
      if (displayConfig?[key]?.visible == true) {
        final label =
            (displayConfig?[key]?.value as String?)?.isNotEmpty == true
                ? displayConfig![key]!.value as String
                : defaultLabel;
        tableHeaders.add(label.toUpperCase());
        cellAlignmentsMap[visibleColIndex++] = align;
        columnWidths.add(width);
      }
    }

    addCol(
        'showSLNumber',
        params.billDocumentConfig.resolvedLabels?.slNumber ?? 'SL#',
        1,
        pw.Alignment.centerLeft);
    addCol(
        'showParticulars',
        params.billDocumentConfig.resolvedLabels?.particulars ?? 'PARTICULARS',
        5,
        pw.Alignment.centerLeft);
    addCol('showMRP', params.billDocumentConfig.resolvedLabels?.mrp ?? 'MRP',
        1.5, pw.Alignment.centerRight);
    addCol('showQty', params.billDocumentConfig.resolvedLabels?.qty ?? 'QTY',
        1.5, pw.Alignment.centerRight);
    addCol('showRate', params.billDocumentConfig.resolvedLabels?.rate ?? 'RATE',
        1.5, pw.Alignment.centerRight);
    addCol('showRateExcTax', 'RATE', 1.5, pw.Alignment.centerRight);
    addCol(
        'showUnit',
        params.billDocumentConfig.resolvedLabels?.unitName ?? 'UNIT',
        1.1,
        pw.Alignment.center);
    addCol(
        'showTotal',
        params.billDocumentConfig.resolvedLabels?.total ?? 'TOTAL',
        1.5,
        pw.Alignment.centerRight);
    if (displayConfig?['showTax']?.visible == true) {
      addCol(
          'showTax', isRtl ? 'الضريبة' : 'TAX', 1.5, pw.Alignment.centerRight);
    }

    List<List<String>> tableData = [];
    for (var i = 0; i < params.cartItems.length; i++) {
      var item = params.cartItems[i];
      List<String> rowData = [];

      // Data Extraction
      String name = "",
          mrp = "0.00",
          qty = "0",
          rate = "0.00",
          rateEx = "0.00",
          unit = "",
          total = "0.00",
          tax = "0.00";

      if (params.isFromLocalStorage) {
        name = item['productName'] ?? '';
        mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        qty = item['quantity'] ?? '0';
        double up =
            double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0;
        double tx =
            double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
        double q = double.tryParse(qty) ?? 0.0;
        rate = up.toStringAsFixed(2);
        rateEx = (up - (q > 0 ? tx / q : 0)).toStringAsFixed(2);
        unit =
            (item['productUnit'] ?? item['product_unit'] ?? item['unit'] ?? '')
                .toString();
        total = (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        tax = tx.toStringAsFixed(2);
      } else {
        final Map<String, dynamic> m =
            item is Map ? item as Map<String, dynamic> : {};
        name = m['product_name'] ??
            m['productName'] ??
            (item is OrderDetailsModelDataCartItem ? item.productName : "");
        mrp = (double.tryParse((m['mrp'] ??
                        (item is OrderDetailsModelDataCartItem ? item.mrp : 0))
                    .toString()) ??
                0.0)
            .toStringAsFixed(2);
        qty = (m['quantity'] ??
                (item is OrderDetailsModelDataCartItem ? item.quantity : 0))
            .toString();
        double up = double.tryParse((m['unit_price'] ??
                    m['unitPrice'] ??
                    (item is OrderDetailsModelDataCartItem
                        ? item.unitPrice
                        : 0))
                .toString()) ??
            0.0;
        double tx = double.tryParse((m['tax_amount'] ??
                    m['taxAmount'] ??
                    (item is OrderDetailsModelDataCartItem
                        ? item.taxAmount
                        : 0))
                .toString()) ??
            0.0;
        double q = double.tryParse(qty) ?? 0.0;
        rate = up.toStringAsFixed(2);
        rateEx = (up - (q > 0 ? tx / q : 0)).toStringAsFixed(2);
        unit = (m['product_unit'] ??
                m['unit'] ??
                (item is OrderDetailsModelDataCartItem ? item.productUnit : ""))
            .toString();
        total = (double.tryParse((m['total_price'] ??
                        m['totalPrice'] ??
                        (item is OrderDetailsModelDataCartItem
                            ? item.totalPrice
                            : 0))
                    .toString()) ??
                0.0)
            .toStringAsFixed(2);
        tax = tx.toStringAsFixed(2);
      }

      name = _bilingualItemName(item, name, params);

      if (displayConfig?['showSLNumber']?.visible == true)
        rowData.add((i + 1).toString());
      if (displayConfig?['showParticulars']?.visible == true) rowData.add(name);
      if (displayConfig?['showMRP']?.visible == true) rowData.add(mrp);
      if (displayConfig?['showQty']?.visible == true) rowData.add(qty);
      if (displayConfig?['showRate']?.visible == true) rowData.add(rate);
      if (displayConfig?['showRateExcTax']?.visible == true)
        rowData.add(rateEx);
      if (displayConfig?['showUnit']?.visible == true) rowData.add(unit);
      if (displayConfig?['showTotal']?.visible == true) rowData.add(total);
      if (displayConfig?['showTax']?.visible == true) rowData.add(tax);
      tableData.add(rowData);
    }

    final finalHeaders = isRtl ? tableHeaders.reversed.toList() : tableHeaders;
    final finalData =
        isRtl ? tableData.map((r) => r.reversed.toList()).toList() : tableData;
    final Map<int, pw.Alignment> finalAlign = {};
    if (isRtl) {
      cellAlignmentsMap.forEach((k, v) {
        final nk = tableHeaders.length - 1 - k;
        finalAlign[nk] = v == pw.Alignment.centerLeft
            ? pw.Alignment.centerRight
            : (v == pw.Alignment.centerRight ? pw.Alignment.centerLeft : v);
      });
    } else {
      finalAlign.addAll(cellAlignmentsMap);
    }

    return pw.Table.fromTextArray(
      headers: finalHeaders,
      data: finalData,
      headerStyle: headerStyle,
      headerDecoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 1),
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      headerHeight: 16,
      cellStyle: contentStyle,
      cellHeight: 14,
      cellAlignments: finalAlign,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
      cellDecoration: (index, data, row) {
        if (row % 2 != 0) {
          return const pw.BoxDecoration(color: PdfColors.grey100);
        }
        return const pw.BoxDecoration();
      },
      border: null, // Removed boxy borders
      columnWidths: {
        for (var i = 0; i < columnWidths.length; i++)
          i: pw.FlexColumnWidth(
              isRtl ? columnWidths.reversed.toList()[i] : columnWidths[i])
      },
    );
  }

  pw.Widget _buildPdfSummary(
      pw.TextStyle style,
      pw.TextStyle netStyle,
      Map<String, DisplayOption>? displayConfig,
      ReceiptLayoutParams params,
      bool isRtl) {
    double saved = double.tryParse(params.savedTotal ?? '0') ?? 0;
    double net = double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0;
    double mrp = saved + net;
    double disc = double.tryParse(params.discountAmount ?? '0') ?? 0;
    double tax = params.totalTax;

    final labelTotalItems =
        (displayConfig?['showItemsCount']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showItemsCount']!.value as String
            : (isRtl ? 'إجمالي العناصر:' : 'Total Items:');
    final labelSaved =
        (displayConfig?['showSaved']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showSaved']!.value as String
            : (isRtl ? 'لقد وفرت:' : 'You Saved:');
    final labelDiscount =
        (displayConfig?['showDiscount']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showDiscount']!.value as String
            : (isRtl ? 'الخصم:' : 'Discount:');
    final labelTax =
        (displayConfig?['showTax']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showTax']!.value as String
            : (isRtl ? 'مبلغ الضريبة:' : 'Tax Amount:');
    final labelMrp =
        (displayConfig?['showSubTotal']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showSubTotal']!.value as String
            : (displayConfig?['showMRPTotal']?.value as String?)?.isNotEmpty == true
                ? displayConfig!['showMRPTotal']!.value as String
                : (isRtl ? 'إجمالي السعر:' : 'Total MRP:');
    final labelNet =
        (displayConfig?['showNetAmount']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showNetAmount']!.value as String
            : (isRtl ? 'المجموع الصافي:' : 'Net Total:');

    // Fetch currency from config labels or fallback to SAR (No external fields used)

    // Summary Body - Two vertical columns
    final summaryBody = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Column 1: Items, Tax, Saved (3 items)
        pw.Expanded(
          child: pw.Column(
            children: [
              if (displayConfig?['showItemsCount']?.visible == true)
                _buildLabelValueRow(
                    labelTotalItems, params.cartItems.length.toString(), style,
                    isRtl: isRtl,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween),
              pw.SizedBox(height: 2),
              if (displayConfig?['showTax']?.visible == true)
                _buildLabelValueRow(labelTax, tax.toStringAsFixed(2), style,
                    isRtl: isRtl,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween),
              pw.SizedBox(height: 2),
              if (displayConfig?['showSaved']?.visible == true && saved > 0)
                _buildLabelValueRow(labelSaved, saved.toStringAsFixed(2), style,
                    isRtl: isRtl,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween),
            ],
          ),
        ),
        pw.SizedBox(width: 25), // Spacing between columns
        // Column 2: MRP, Discount (2 items)
        pw.Expanded(
          child: pw.Column(
            children: [
              if ((displayConfig?['showSubTotal']?.visible ?? displayConfig?['showMRPTotal']?.visible) == true)
                _buildLabelValueRow(labelMrp, mrp.toStringAsFixed(2), style,
                    isRtl: isRtl,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween),
              pw.SizedBox(height: 2),
              if (displayConfig?['showDiscount']?.visible == true && disc != 0)
                _buildLabelValueRow(
                    labelDiscount, disc.toStringAsFixed(2), style,
                    isRtl: isRtl,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween),
            ],
          ),
        ),
      ],
    );

    // Footer - Two rows: Labels in first, Values in second
    final amountInWordsText =
        '${AmountHelper().convertNumberToWords(double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0, currency: "Riyals", language: isRtl ? 'ar' : 'en')}${isRtl ? ' فقط.' : ' Only.'}';

    final footerSection = pw.Column(
      children: [
        pw.SizedBox(height: 5),
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 1.2),
              bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: pw.Column(
            children: [
              // Row 1: Headings
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (displayConfig?['showAmountInWords']?.visible == true &&
                      !params.hasReturns)
                    pw.Text(
                      (displayConfig?['showAmountInWords']?.value as String?)
                                  ?.isNotEmpty ==
                              true
                          ? displayConfig!['showAmountInWords']!.value as String
                          : (isRtl ? 'المبلغ بالكلمات:' : 'Amount in words:'),
                      style: style,
                    ),
                  if (displayConfig?['showNetAmount']?.visible == true)
                    pw.Text(labelNet, style: netStyle),
                ],
              ),
              pw.SizedBox(height: 2),
              // Row 2: Values
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (displayConfig?['showAmountInWords']?.visible == true &&
                      !params.hasReturns)
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(amountInWordsText, style: style),
                    ),
                  if (displayConfig?['showNetAmount']?.visible == true)
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(net.toStringAsFixed(2),
                          style: netStyle, textAlign: pw.TextAlign.right),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        summaryBody,
        pw.SizedBox(height: 4),
        footerSection,
      ],
    );
  }

  pw.Widget _buildCustomerDetailsPDF(
      ReceiptLayoutParams params,
      pw.TextStyle h,
      pw.TextStyle b,
      bool isRtl,
      pw.Font? arabicFontBold,
      pw.TextStyle labelStyle) {
    final style = b.copyWith(fontWeight: pw.FontWeight.bold);
    List<pw.Widget> rows = [
      pw.Text(isRtl ? 'إلى:' : 'BILL TO:', style: labelStyle),
      pw.SizedBox(height: 4),
    ];
    final bool mask =
        params.displayConfig?['maskCustomerPhone']?.visible ?? true;
    final bool showPhone = params.customerPhone?.isNotEmpty == true &&
        !(params.isDefaultCustomer && params.hideDefaultCustomerPhone);

    if (params.customerName?.isNotEmpty == true && showPhone) {
      final phone = mask
          ? StringHelper.maskStringShowLast4(params.customerPhone!)
          : params.customerPhone!;
      rows.add(pw.Text(
          '${params.customerName} - $phone${params.customerAlternatePhone?.isNotEmpty == true ? ", ${params.customerAlternatePhone}" : ""}',
          style: style));
    } else {
      if (params.customerName?.isNotEmpty == true)
        rows.add(pw.Text(params.customerName!, style: style));
      if (showPhone) {
        final phone = mask
            ? StringHelper.maskStringShowLast4(params.customerPhone!)
            : params.customerPhone!;
        rows.add(pw.Text(
            '$phone${params.customerAlternatePhone?.isNotEmpty == true ? ", ${params.customerAlternatePhone}" : ""}',
            style: style));
      }
    }

    if (params.customerAddress?.isNotEmpty == true)
      rows.add(pw.Text(
          isRtl
              ? '${params.customerAddress} :العنوان'
              : 'Address: ${params.customerAddress}',
          style: style));
    if (params.paymentMethod?.isNotEmpty == true) {
      final _pmRaw = params.paymentMethod!;
      final _pmLabel = _pmRaw == 'CASH'
          ? (isRtl ? 'نقدي' : 'Cash')
          : _pmRaw == 'CARD'
              ? (isRtl ? 'بطاقة' : 'Card')
              : _pmRaw;
      rows.add(pw.Text(
          isRtl ? 'طريقة الدفع: $_pmLabel' : 'Payment Method: $_pmLabel',
          style: style));
    }
    if (params.customerVatNumber?.isNotEmpty == true)
      rows.add(pw.Text(
          isRtl
              ? 'الرقم الضريبي للعميل: ${params.customerVatNumber}'
              : 'Customer VAT: ${params.customerVatNumber}',
          style: style));
    if (params.customerCrNumber?.isNotEmpty == true)
      rows.add(pw.Text(
          isRtl
              ? 'السجل التجاري للعميل: ${params.customerCrNumber}'
              : 'Customer CR: ${params.customerCrNumber}',
          style: style));

    return pw.Container(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
            crossAxisAlignment:
                isRtl ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
            children: rows));
  }

  pw.Widget _buildDateTimeRowPDF(String size, String date, bool local,
      {bool isRtl = false,
      pw.Font? arabicFontBold,
      Map<String, DisplayOption>? displayConfig,
      required pw.TextStyle labelStyle}) {
    String fd, ft;
    try {
      if (local) {
        fd = DateHelper.formatToISODateOnlyFromISO(date);
        ft = DateHelper.formatToISODateFromIST(date);
      } else if (date.contains(' AM') || date.contains(' PM')) {
        fd = date.split(' ')[0];
        ft = date;
      } else {
        fd = DateHelper.formatISODate(date);
        ft = DateHelper.formatISODateToIST(date);
      }
    } catch (_) {
      fd = ft = date;
    }

    final style = pw.TextStyle(
        font: arabicFontBold,
        fontSize: size == 'A5' ? 7.0 : 9.0,
        fontWeight: pw.FontWeight.bold);
    final dl =
        (displayConfig?['showDateHeader']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showDateHeader']!.value as String
            : (isRtl ? 'التاريخ:' : 'Date:');
    final tl =
        (displayConfig?['showTimeHeader']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showTimeHeader']!.value as String
            : (isRtl ? 'الوقت:' : 'Time:');

    final dw = pw.Text('$dl $fd', style: style);
    final tw = pw.Text('$tl $ft', style: style);

    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: isRtl ? [tw, dw] : [dw, tw]));
  }

  pw.Widget _buildCartTotalRow(ReceiptLayoutParams params, pw.TextStyle style,
      bool isRtl, pw.Font? font, pw.Font? fontB, String curr) {
    double total = 0;
    for (var item in params.cartItems) {
      if (params.isFromLocalStorage)
        total += double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0;
      else
        total += double.tryParse((item is Map
                    ? item['total_price'] ?? item['totalPrice']
                    : (item is OrderDetailsModelDataCartItem
                        ? item.totalPrice
                        : 0))
                .toString()) ??
            0;
    }
    final s = pw.TextStyle(
        font: fontB,
        fontSize: params.selectedPaperSize == 'A5' ? 8 : 10,
        fontWeight: pw.FontWeight.bold);
    final label = (params.displayConfig?['showCartTotal']?.value as String?)
                ?.isNotEmpty ==
            true
        ? params.displayConfig!['showCartTotal']!.value as String
        : (isRtl ? 'الإجمالي:' : 'TOTAL:');
    final cur = curr.toUpperCase() == 'INR'
        ? '\u20B9 '
        : (curr.isNotEmpty ? '$curr ' : '');

    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: isRtl
                ? [
                    pw.Text('$cur${total.toStringAsFixed(2)}', style: s),
                    pw.Text(label, style: s)
                  ]
                : [
                    pw.Text(label, style: s),
                    pw.Text('$cur${total.toStringAsFixed(2)}', style: s)
                  ]));
  }

  pw.Widget _buildOrderBarcodePDF(String size, String number) {
    return pw.Center(
        child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: number,
                width: size == 'A5' ? 100 : 120,
                height: size == 'A5' ? 25 : 30,
                textPadding: 2)));
  }

  pw.Widget _buildQrCodeSection(ReceiptLayoutParams params,
      PaymentGateway gateway, bool isRtl, pw.Font fontB) {
    String data = "", msg = "";
    if (params.hasZatcaCredentials) {
      data = ZatcaQrHelper().generateQrForInvoice(
          sellerName: params.zatcaCompanyName!,
          vatNumber: params.zatcaVatNumber!,
          invoiceDate: params.orderDate,
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax);
      msg = isRtl ? 'فاتورة الكترونية' : 'ZATCA E-Invoice QR';
    } else {
      data = gateway.link;
      if (data.isNotEmpty) {
        data = data
            .replaceAll('{formattedTotal}', params.formattedTotal)
            .replaceAll('{orderNumber}', params.orderNumber);
        if (data.contains('@'))
          data =
              'upi://pay?pa=$data&am=${params.formattedTotal}&tn=${params.orderNumber}&cu=INR';
      }
      msg =
          (params.displayConfig?['showQRCode']?.value as String?)?.isNotEmpty ==
                  true
              ? params.displayConfig!['showQRCode']!.value as String
              : (isRtl ? 'امسح للدفع' : 'Scan to Pay');
    }
    if (data.isEmpty) return pw.SizedBox();
    final s = pw.TextStyle(
        font: fontB,
        fontSize: params.selectedPaperSize == 'A5' ? 7 : 9,
        fontWeight: pw.FontWeight.bold);
    return pw.Center(
        child: pw.Column(children: [
      pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: data,
          width: params.selectedPaperSize == 'A5' ? 80 : 100,
          height: params.selectedPaperSize == 'A5' ? 80 : 100),
      pw.SizedBox(height: 3),
      pw.Text(msg, style: s),
      if (params.hasZatcaCredentials) ...[
        pw.SizedBox(height: 2),
        pw.Text(
            isRtl
                ? 'الرقم الضريبي: ${params.zatcaVatNumber}'
                : 'VAT No: ${params.zatcaVatNumber}',
            style: pw.TextStyle(
                font: fontB,
                fontSize: params.selectedPaperSize == 'A5' ? 6 : 8))
      ]
    ]));
  }

  pw.Widget _buildOrderReturnsSection(
      ReceiptLayoutParams params,
      pw.TextStyle sub,
      pw.TextStyle body,
      pw.TextStyle header,
      pw.TextStyle sum,
      pw.TextStyle net,
      bool isRtl) {
    // Highly simplified version for the "Classic" parity copy
    return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isRtl ? 'المرتجعات' : 'RETURNS', style: sub),
              pw.SizedBox(height: 5),
              pw.Text('Return Items section...', style: body)
            ]));
  }

  pw.Widget _buildTotalSummarySection(
      ReceiptLayoutParams params,
      pw.TextStyle sub,
      pw.TextStyle sum,
      pw.TextStyle net,
      String curr,
      bool isRtl) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isRtl ? 'الملخص النهائي' : 'FINAL SUMMARY', style: sub),
              pw.SizedBox(height: 5),
              pw.Text('Final Total calculation...', style: sum)
            ]));
  }

  pw.Widget _buildCustomerBalancePdf(ReceiptLayoutParams params,
      pw.TextStyle style, bool isRtl, pw.Font? font, pw.Font? fontB,
      {String? delivery}) {
    final s = pw.TextStyle(
        font: font,
        fontBold: fontB,
        fontSize: params.selectedPaperSize == 'A5' ? 7 : 9);
    final sb = pw.TextStyle(
        font: fontB,
        fontSize: params.selectedPaperSize == 'A5' ? 7 : 9,
        fontWeight: pw.FontWeight.bold);

    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Column(children: [
          pw.Row(children: [
            if (params.paidAmount != null)
              pw.Expanded(
                  child: _buildLabelValueRow(
                      isRtl ? 'المبلغ المدفوع:' : 'Paid Amount:',
                      params.paidAmount!.toStringAsFixed(2),
                      s,
                      isRtl: isRtl)),
            pw.SizedBox(width: 15),
            if (params.customerCurrentBalance != null)
              pw.Expanded(
                  child: _buildLabelValueRow(
                      isRtl ? 'الرصيد الحالي:' : 'Current Balance:',
                      params.customerCurrentBalance!.toStringAsFixed(2),
                      sb,
                      isRtl: isRtl,
                      mainAxisAlignment: pw.MainAxisAlignment.end)),
          ]),
          if (delivery != null && delivery.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _buildLabelValueRow(isRtl ? 'التوصيل:' : 'Delivery:', delivery, s,
                isRtl: isRtl),
          ]
        ]));
  }

  bool _hasTermsData(Map<String, DisplayOption>? config, DocumentConfig doc) =>
      (config?['showTermsConditions']?.value as String?)?.trim().isNotEmpty ==
          true ||
      doc.terms?.trim().isNotEmpty == true;

  pw.Widget _buildTermsConditionsBoxPDF(
      String size, Map<String, DisplayOption>? config, DocumentConfig doc,
      {bool isRtl = false, pw.Font? arabicFont, pw.Font? arabicFontBold}) {
    String terms =
        (config?['showTermsConditions']?.value as String?)?.isNotEmpty == true
            ? config!['showTermsConditions']!.value as String
            : doc.terms ?? '';
    return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5),
        child: pw.Column(
            crossAxisAlignment:
                isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(color: PdfColors.black),
              ...terms.split('\n').map((t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(t,
                      style: pw.TextStyle(
                          font: arabicFont,
                          fontBold: arabicFontBold,
                          fontSize: 7),
                      textAlign:
                          isRtl ? pw.TextAlign.right : pw.TextAlign.left)))
            ]));
  }

  Future<pw.Font> _loadArabicFont() async {
    if (_arabicFont != null) return _arabicFont!;
    final data =
        await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    return _arabicFont = pw.Font.ttf(data);
  }

  Future<pw.Font> _loadArabicFontBold() async {
    if (_arabicFontBold != null) return _arabicFontBold!;
    final data = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
    return _arabicFontBold = pw.Font.ttf(data);
  }

  Future<pw.MemoryImage?> _fetchNetworkPdfImage(String? url) async =>
      PrintLogoLoader.loadPdfLogo(url, tag: '[new_classic]');

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

  Future<void> _handleWindowsPdf(BuildContext context, File file) async {
    try {
      await OpenFile.open(file.path);
      if (context.mounted)
        showScaffold(context: context, message: "PDF created successfully");
    } catch (_) {
      if (context.mounted)
        showScaffold(context: context, message: "PDF created successfully");
    }
  }

  Future<void> _sharePdfFallback(BuildContext context, File file) async {
    if (!Platform.isWindows) {
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Receipt #${file.path.split('/').last}');
      if (context.mounted)
        showScaffold(
            context: context, message: "PDF shared. Please open it to print");
    }
  }
}
