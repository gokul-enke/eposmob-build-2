import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/bank_provider.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_pdf_layout_factory.dart';
import 'package:pos_machine/screens/print/print_unit_helper.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/receipt_customer_segment.dart';
import 'logo_loader.dart';

class StandardPrinter {
  final BuildContext context;

  StandardPrinter(this.context);

  // Removed _maskPhone - now using StringHelper.maskStringShowLast4

  // Cache for the Arabic fonts to avoid loading multiple times
  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;

  // Load the Arabic fonts from assets (with caching)
  Future<pw.Font> _loadArabicFont() async {
    if (_arabicFont != null) {
      return _arabicFont!;
    }
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
      debugPrint('Arabic regular font loaded successfully');
      return _arabicFont!;
    } catch (e) {
      debugPrint('Error loading Arabic font: $e');
      rethrow;
    }
  }

  Future<pw.Font> _loadArabicFontBold() async {
    if (_arabicFontBold != null) {
      return _arabicFontBold!;
    }
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      _arabicFontBold = pw.Font.ttf(fontData);
      debugPrint('Arabic bold font loaded successfully');
      return _arabicFontBold!;
    } catch (e) {
      debugPrint('Error loading Arabic bold font: $e');
      rethrow;
    }
  }

  // Helper method to create RTL-aware label-value row
  pw.Widget _buildLabelValueRow(
    String label,
    String value,
    pw.TextStyle style, {
    bool isRtl = false,
    pw.TextStyle? valueStyle,
  }) {
    final effectiveValueStyle = valueStyle ?? style;
    final children = isRtl
        ? [
            pw.Text(value, style: effectiveValueStyle),
            pw.Text(label, style: style),
          ]
        : [
            pw.Text(label, style: style),
            pw.Text(value, style: effectiveValueStyle),
          ];

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: children,
    );
  }

  // Helper method to get or create the epos directory
  Future<Directory> _getEposDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final eposDir = Directory('${documentsDir.path}/epos');
      if (!await eposDir.exists()) {
        await eposDir.create(recursive: true);
        debugPrint('Created epos directory: ${eposDir.path}');
      }
      return eposDir;
    } catch (e) {
      debugPrint('Could not access Documents/epos directory, using temp: $e');
      return await getTemporaryDirectory();
    }
  }

  Future<void> generateAndPrintPDF({
    required BluetoothPrinter? selectedPrinter,
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    String? tokenNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    OrderReturns? orderReturns, // Add this parameter
    double? customerOldBalance,
    double? customerCurrentBalance,
    required double? paidAmount,
    String? orderComment,
    String? deliveryMethod,
    String? customerAlternatePhone,
    String? paymentMethod,
    // ZATCA fields for Saudi Arabia e-invoicing
    String? zatcaVatNumber,
    String? zatcaCompanyName,
    bool isDefaultCustomer = false,
    bool hideDefaultCustomerPhone = true,
    String? customerVatNumber,
    String? customerCrNumber,
    String? storeLocation,
    String? storePhone,
    String? storeEmail,
    bool isReturnOnly = false,
  }) async {
    debugPrint(
        "[LOGO_DEBUG] generateAndPrintPDF started for order: $orderNumber");
    try {
      // Ensure billDocumentConfig is loaded before printing
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: "Document configurations not loaded. Please wait.",
          );
        }
        return;
      }

      // Load Logo if enabled
      pw.MemoryImage? logoImage;
      if (billDocumentConfig.showLogo == 1) {
        debugPrint(
            "[LOGO_DEBUG] showLogo == 1, attempting to load dynamic logo for standard print: ${billDocumentConfig.logo}");
        try {
          if (billDocumentConfig.logo != null &&
              billDocumentConfig.logo.toString().isNotEmpty) {
            logoImage =
                await _fetchNetworkPdfImage(billDocumentConfig.logo.toString());
          }

          if (logoImage != null) {
            debugPrint(
                "[LOGO_DEBUG] Network logo resolved successfully for standard print");
          } else {
            debugPrint(
                "[LOGO_DEBUG] No logo fetched or URL empty, skipping logo for standard print");
          }
        } catch (e) {
          debugPrint("[LOGO_DEBUG] Error loading logo for standard print: $e");
        }
      } else {
        debugPrint(
            "[LOGO_DEBUG] showLogo != 1, skipping logo for standard print");
      }

      // Check if printer is selected before proceeding
      if (selectedPrinter == null) {
        debugPrint("ERROR: No printer selected for printing");
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: "No Printer Selected",
          );
        }
        return;
      }

      final displayConfig = billDocumentConfig.displayConfiguration?.options;

      // Debug the document configuration being used
      debugPrint("===== DOCUMENT CONFIG BEING USED FOR PRINTING =====");
      debugPrint("billDocumentConfig ID: ${billDocumentConfig.id}");
      debugPrint("billDocumentConfig Type: ${billDocumentConfig.type}");
      debugPrint(
          "billDocumentConfig Updated At: ${billDocumentConfig.updatedAt}");
      debugPrint(
          "billDocumentConfig Has Display Config: ${billDocumentConfig.displayConfiguration != null}");
      debugPrint("Display Config Options Count: ${displayConfig?.length ?? 0}");
      if (displayConfig != null) {
        debugPrint("Display Config Keys: ${displayConfig.keys.toList()}");
      }
      debugPrint("===== END DOCUMENT CONFIG INFO =====");

      _debugPrintTemplateSettings(displayConfig);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Preparing $selectedPaperSize document for printing...",
        );
      }

      // Create a PDF document
      final pdf = pw.Document();

      // Get settings from the loaded display configuration
      final updatedSettings = displayConfig;

      debugPrint("PDF Generation - Using user settings:");
      debugPrint(
          "showStoreName: ${updatedSettings?['showStoreName']?.visible}");
      debugPrint(
          "showDescription: ${updatedSettings?['showDescription']?.visible}");
      debugPrint(
          "showStoreAddress: ${updatedSettings?['showStoreAddress']?.visible}");
      debugPrint(
          "showFssaiInfo: ${updatedSettings?['showFssaiInfo']?.visible}");
      debugPrint("showTel: ${updatedSettings?['showTel']?.visible}");
      debugPrint("showEmail: ${updatedSettings?['showEmail']?.visible}");
      debugPrint(
          "showInvoiceTitle: ${updatedSettings?['showInvoiceTitle']?.visible}");
      debugPrint(
          "showInvoiceNumber: ${updatedSettings?['showInvoiceNumber']?.visible}");
      debugPrint(
          "showDateHeader: ${updatedSettings?['showDateHeader']?.visible}");
      debugPrint("showSLNumber: ${updatedSettings?['showSLNumber']?.visible}");
      debugPrint(
          "showParticulars: ${updatedSettings?['showParticulars']?.visible}");
      debugPrint("showMRP: ${updatedSettings?['showMRP']?.visible}");
      debugPrint("showQty: ${updatedSettings?['showQty']?.visible}");
      debugPrint("showRate: ${updatedSettings?['showRate']?.visible}");
      debugPrint("showTotal: ${updatedSettings?['showTotal']?.visible}");
      debugPrint("showDiscount: ${updatedSettings?['showDiscount']?.visible}");
      debugPrint(
          "showNetAmount: ${updatedSettings?['showNetAmount']?.visible}");
      debugPrint("showMRPTotal: ${updatedSettings?['showMRPTotal']?.visible}");
      debugPrint("showSaved: ${updatedSettings?['showSaved']?.visible}");
      debugPrint(
          "showAmountInWords: ${updatedSettings?['showAmountInWords']?.visible}");
      debugPrint(
          "showItemsCount: ${updatedSettings?['showItemsCount']?.visible}");
      debugPrint(
          "showThankYouMessage: ${updatedSettings?['showThankYouMessage']?.visible}");
      debugPrint("showQRCode: ${updatedSettings?['showQRCode']?.visible}");
      debugPrint(
          "showTermsConditions: ${updatedSettings?['showTermsConditions']?.visible}");

//display returns
      debugPrint(
          "showReturnSLNumber: ${updatedSettings?['showReturnSLNumber']?.visible}");
      debugPrint(
          "showReturnParticulars: ${updatedSettings?['showReturnParticulars']?.visible}");
      debugPrint(
          "showReturnQty: ${updatedSettings?['showReturnQty']?.visible}");
      debugPrint(
          "showReturnRate: ${updatedSettings?['showReturnRate']?.visible}");
      debugPrint(
          "showReturnTotal: ${updatedSettings?['showReturnTotal']?.visible}");
      debugPrint(
          "showReturnNetAmount: ${updatedSettings?['showReturnNetAmount']?.visible}");
      debugPrint(
          "showReturnTotalAmount: ${updatedSettings?['showReturnTotalAmount']?.visible}");
      debugPrint(
          "showReturnItemsCount: ${updatedSettings?['showReturnItemsCount']?.visible}");
      debugPrint(
          "showFinalNetAmount: ${updatedSettings?['showFinalNetAmount']?.visible}");
      debugPrint(
          "showFinalPurchase: ${updatedSettings?['showFinalPurchase']?.visible}");
      debugPrint(
          "showFinalReturn: ${updatedSettings?['showFinalReturn']?.visible}");
      debugPrint(
          "showFinalAmountInWords: ${updatedSettings?['showFinalAmountInWords']?.visible}");

      // Access Payment Gateways Provider for QR code link
      final paymentGatewaysProvider =
          Provider.of<PaymentGatewaysProvider>(context, listen: false);
      final manualPaymentGateway = paymentGatewaysProvider.paymentGateways
          .firstWhere((gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY",
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
                    updatedAt: "",
                  ));

      // Access App Settings Provider for currency symbol
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final currency = appSettingsProvider.appSettings?.currency ?? '';

      // Determine page format based on paper size
      PdfPageFormat pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;

      // Load Arabic fonts for multilingual support
      final arabicFont = await _loadArabicFont();
      final arabicFontBold = await _loadArabicFontBold();

      // Determine text direction based on configuration or app language
      final configLanguage = billDocumentConfig.language;
      final isRtl = configLanguage != null
          ? configLanguage.toLowerCase() == 'ar'
          : LocalizationService.locale.languageCode == 'ar';

      final textDirection = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
      debugPrint(
          'PDF generation - Language: ${configLanguage ?? LocalizationService.locale.languageCode}, Source: ${configLanguage != null ? 'Config' : 'App Locale'}, RTL: $isRtl');

      // Define styles with Arabic font for multilingual support
      // Use fontBold parameter for styles that need bold rendering
      final headerStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 16.0
            : 18.0, // Increased for better hierarchy
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final subheaderStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final bodyStyle = pw.TextStyle(
        font: arabicFont,
        fontBold: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table text
        color: PdfColors.black,
      );
      final smallStyle = pw.TextStyle(
        font: arabicFont,
        fontBold: arabicFontBold,
        fontSize: selectedPaperSize == 'A5' ? 5.0 : 7.0, // Reduced further
        color: PdfColors.black,
      );
      final tableHeaderStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table headers
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final summaryStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 8.0
            : 10.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final netTotalStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );

      // Calculate total tax from cart items for ZATCA QR
      double totalTax = 0.0;
      for (var item in cartItems) {
        if (isFromLocalStorage) {
          totalTax +=
              double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
        } else {
          totalTax += double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
        }
      }
      debugPrint('[StandardPrinter] Total tax calculated for QR: $totalTax');

      // Add content to a multi-page PDF with minimal margins and optimized spacing
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          textDirection: textDirection, // RTL support for Arabic
          margin: const pw.EdgeInsets.all(15), // Reduced from 30
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5), // Reduced from 10
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6), // Reduced from 8
              textAlign: pw.TextAlign.center,
            ),
          ),
          build: (pw.Context context) => [
            // Header with store information - compact design
            pw.Center(
              child: pw.Column(
                children: [
                  // Logo at the top
                  if (logoImage != null) ...[
                    pw.Container(
                      height: 35,
                      child: pw.Image(logoImage),
                    ),
                    pw.SizedBox(height: 5),
                  ],
                  // Store name
                  if (updatedSettings?['showStoreName']?.visible == true)
                    pw.Text(
                      (updatedSettings?['showStoreName']?.value as String?)
                                  ?.isNotEmpty ==
                              true
                          ? updatedSettings!['showStoreName']!.value as String
                          : (billDocumentConfig.header?.isNotEmpty == true
                              ? billDocumentConfig.header!
                              : (isRtl ? 'اسم المتجر' : 'STORE NAME')),
                      style: headerStyle,
                    ),

                  // Store description
                  if (updatedSettings?['showDescription']?.visible == true)
                    pw.Text(
                      updatedSettings?['showDescription']?.value as String? ??
                          billDocumentConfig.subheader ??
                          '',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontBold: arabicFontBold,
                        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                      ),
                    ),

                  // Store address - priority: store session > document config
                  if (updatedSettings?['showStoreAddress']?.visible ==
                      true) ...[
                    if ((storeLocation?.isNotEmpty == true) ||
                        (updatedSettings?['showStoreAddress']?.value as String?)
                                ?.isNotEmpty ==
                            true)
                      pw.Text(
                        storeLocation?.isNotEmpty == true
                            ? storeLocation!
                            : updatedSettings!['showStoreAddress']!.value
                                as String,
                        style: bodyStyle,
                      ),
                  ],

                  // FSSAI info - compact display
                  if (updatedSettings?['showFssaiInfo']?.visible == true) ...[
                    if ((updatedSettings?['showFssaiInfo']?.value as String?)
                            ?.isNotEmpty ==
                        true)
                      pw.Text(
                        updatedSettings!['showFssaiInfo']!.value as String,
                        style: bodyStyle,
                      ),
                  ],

                  // Contact information - priority: store session > document config > app settings
                  if (updatedSettings?['showTel']?.visible == true)
                    pw.Text(
                      storePhone?.isNotEmpty == true
                          ? storePhone!
                          : (updatedSettings?['showTel']?.value as String? ??
                              customerCareNumber),
                      style: bodyStyle,
                    ),

                  if (updatedSettings?['showEmail']?.visible == true)
                    pw.Text(
                      storeEmail?.isNotEmpty == true
                          ? storeEmail!
                          : (updatedSettings?['showEmail']?.value as String? ??
                              customerCareEmail),
                      style: bodyStyle,
                    ),
                ],
              ),
            ),

            pw.SizedBox(height: 5), // Reduced from 10

            // Invoice information - minimal design without borders
            if ((updatedSettings?['showInvoiceTitle']?.visible == true) ||
                (updatedSettings?['showInvoiceNumber']?.visible == true))
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 0, horizontal: 8), // Reduced padding
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: isRtl
                          ? [
                              if (updatedSettings?['showInvoiceNumber']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (billDocumentConfig.numberPrefix != null &&
                                            billDocumentConfig
                                                .numberPrefix!.isNotEmpty)
                                        ? '${billDocumentConfig.numberPrefix}$orderNumber'
                                        : (isRtl
                                            ? 'رقم: $orderNumber'
                                            : 'No: $orderNumber'),
                                    style: subheaderStyle),
                              if (updatedSettings?['showInvoiceTitle']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (updatedSettings?['showInvoiceTitle']?.value
                                                    as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? updatedSettings!['showInvoiceTitle']!
                                            .value as String
                                        : (billDocumentConfig
                                                    .header?.isNotEmpty ==
                                                true
                                            ? billDocumentConfig.header!
                                            : (isRtl ? 'فاتورة' : 'INVOICE')),
                                    style: subheaderStyle),
                            ]
                          : [
                              if (updatedSettings?['showInvoiceTitle']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (updatedSettings?['showInvoiceTitle']?.value
                                                    as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? updatedSettings!['showInvoiceTitle']!
                                            .value as String
                                        : (billDocumentConfig
                                                    .header?.isNotEmpty ==
                                                true
                                            ? billDocumentConfig.header!
                                            : (isRtl ? 'فاتورة' : 'INVOICE')),
                                    style: subheaderStyle),
                              if (updatedSettings?['showInvoiceNumber']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (billDocumentConfig.numberPrefix != null &&
                                            billDocumentConfig
                                                .numberPrefix!.isNotEmpty)
                                        ? '${billDocumentConfig.numberPrefix}$orderNumber'
                                        : (isRtl
                                            ? 'رقم: $orderNumber'
                                            : 'No: $orderNumber'),
                                    style: subheaderStyle),
                            ],
                    ),
                    // Token Number - display right after invoice number in big font (same as store name)
                    // Only show if showTokenNumber is explicitly enabled (default: false)
                    if (updatedSettings?['showTokenNumber']?.visible == true &&
                        tokenNumber != null &&
                        tokenNumber.isNotEmpty)
                      pw.Text(
                        tokenNumber,
                        style: headerStyle,
                      ),
                  ],
                ),
              ),

            // Date and Time Row - minimal design
            _buildDateTimeRowPDF(
                selectedPaperSize, orderDate, isFromLocalStorage,
                isRtl: isRtl,
                arabicFontBold: arabicFontBold,
                displayConfig: updatedSettings),

            // Customer Information Section - if available
            // Hidden when return-only with credit note config (customer shown in returns section)
            if ((customerName != null ||
                customerPhone != null ||
                customerEmail != null ||
                customerAddress != null) &&
                !(isReturnOnly && (billDocumentConfig?.resolvedLabels?.creditNoteNumber != null ||
                    billDocumentConfig?.resolvedLabels?.creditNoteDate != null)))
              _buildCustomerDetailsPDF(
                selectedPaperSize,
                customerName,
                customerPhone,
                customerEmail,
                customerAddress,
                subheaderStyle,
                bodyStyle,
                paymentMethod: paymentMethod,
                customerAlternatePhone: customerAlternatePhone,
                isDefaultCustomer: isDefaultCustomer,
                hideDefaultCustomerPhone: hideDefaultCustomerPhone,
                isRtl: isRtl,
                arabicFontBold: arabicFontBold,
                displayConfig: updatedSettings,
                customerVatNumber: customerVatNumber,
                customerCrNumber: customerCrNumber,
              ),

            // Items table - minimal design without borders
            if (!isReturnOnly &&
                ((updatedSettings?['showSLNumber']?.visible == true) ||
                    (updatedSettings?['showParticulars']?.visible == true) ||
                    (updatedSettings?['showMRP']?.visible == true) ||
                    (updatedSettings?['showQty']?.visible == true) ||
                    (updatedSettings?['showRate']?.visible == true) ||
                    (updatedSettings?['showTotal']?.visible == true)))
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 5, horizontal: 8), // Reduced padding
                child: _buildPdfItemsTable(
                  tableHeaderStyle,
                  bodyStyle,
                  updatedSettings,
                  cartItems,
                  isFromLocalStorage,
                  billDocumentConfig,
                  isRtl: isRtl,
                ),
              ),

            // Cart Total Row - added after items table
            if (!isReturnOnly)
              _buildCartTotalRow(selectedPaperSize, cartItems,
                  isFromLocalStorage, summaryStyle,
                  isRtl: isRtl,
                  arabicFont: arabicFont,
                  arabicFontBold: arabicFontBold,
                  displayConfig: updatedSettings,
                  currency: currency),

            pw.SizedBox(height: 5), // Reduced from 8

            // Summary - minimal design without borders
            if (!isReturnOnly &&
                ((updatedSettings?['showItemsCount']?.visible == true) ||
                    (updatedSettings?['showMRPTotal']?.visible == true) ||
                    (updatedSettings?['showSaved']?.visible == true) ||
                    (updatedSettings?['showDiscount']?.visible == true) ||
                    (updatedSettings?['showNetAmount']?.visible == true)))
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 5, horizontal: 8), // Reduced padding
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        displayConfig?['showOrderSummary']?.value as String? ??
                            (isRtl ? 'ملخص الطلب' : 'ORDER SUMMARY'),
                        style: subheaderStyle,
                        textAlign:
                            isRtl ? pw.TextAlign.right : pw.TextAlign.left),
                    pw.SizedBox(height: 5), // Reduced from 10
                    _buildPdfSummary(
                        summaryStyle,
                        netTotalStyle,
                        updatedSettings,
                        formattedTotal,
                        savedTotal,
                        discountAmount,
                        cartItems.length,
                        billDocumentConfig,
                        customerOldBalance,
                        customerCurrentBalance,
                        isRtl: isRtl,
                        cartItems: cartItems,
                        isFromLocalStorage: isFromLocalStorage),

                    // Add Amount in words under order summary when there are no returns
                    if (updatedSettings?['showAmountInWords']?.visible ==
                            true &&
                        (orderReturns == null ||
                            orderReturns.returnItems?.isEmpty == true))
                      pw.Column(
                        children: [
                          pw.SizedBox(height: 5),
                          _buildLabelValueRow(
                            (updatedSettings?['showAmountInWords']?.value
                                            as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? updatedSettings!['showAmountInWords']!.value
                                    as String
                                : (isRtl
                                    ? 'المبلغ بالكلمات:'
                                    : 'Amount in words:'),
                            '${AmountHelper().convertNumberToWords((double.tryParse(formattedTotal.replaceAll(',', '')) ?? 0), currency: currency, language: isRtl ? 'ar' : 'en')}${isRtl ? ' فقط.' : ' Only.'}',
                            summaryStyle,
                            isRtl: isRtl,
                          ),
                        ],
                      ),

                    // Add Customer Balance after Amount in words (small, aligned)
                    if ((updatedSettings?['showCustomerPrevBalance']?.visible ==
                                true &&
                            customerOldBalance != null) ||
                        (updatedSettings?['showCustomerCurrentBalance']
                                    ?.visible ==
                                true &&
                            customerCurrentBalance != null) ||
                        (updatedSettings?['showCustomerPaidAmount']?.visible ==
                                true &&
                            paidAmount != null))
                      _buildCustomerBalancePdf(
                        selectedPaperSize,
                        customerOldBalance,
                        customerCurrentBalance,
                        paidAmount,
                        bodyStyle,
                        displayConfig: updatedSettings,
                        isRtl: isRtl,
                        arabicFont: arabicFont,
                        arabicFontBold: arabicFontBold,
                      ),
                  ],
                ),
              ),

            // Add Order Returns section if orderReturns is not null and has items
            if (orderReturns != null &&
                (orderReturns.returnItems?.isNotEmpty ?? false)) ...[
              pw.SizedBox(height: 5), // Add spacing before return section
              _buildOrderReturnsSection(
                selectedPaperSize,
                orderReturns,
                subheaderStyle,
                bodyStyle,
                tableHeaderStyle,
                summaryStyle,
                netTotalStyle,
                cartItems, // Pass cartItems to match return items with original prices
                isFromLocalStorage,
                updatedSettings, // Pass displayConfig
                billDocumentConfig, // Pass billDocumentConfig for resolved_labels
                isRtl: isRtl,
                orderNumber: orderNumber,
                orderDate: orderDate,
                customerName: customerName,
                customerPhone: customerPhone,
                customerAddress: customerAddress,
              ),
            ],

            // Add Total Summary section ONLY when there are returns
            if (!isReturnOnly &&
                orderReturns != null &&
                orderReturns.returnItems != null &&
                orderReturns.returnItems!.isNotEmpty) ...[
              _buildTotalSummarySection(
                selectedPaperSize,
                formattedTotal,
                orderReturns,
                cartItems,
                isFromLocalStorage,
                subheaderStyle,
                summaryStyle,
                netTotalStyle,
                updatedSettings,
                currency,
                isRtl: isRtl,
              ),
              pw.SizedBox(height: 10),
            ],

            // Order Comment
            if (orderComment != null && orderComment.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              _buildLabelValueRow(
                isRtl ? 'تعليق:' : 'Comment:',
                orderComment,
                summaryStyle,
                isRtl: isRtl,
              ),
              pw.SizedBox(height: 5),
            ],

            if (deliveryMethod != null && deliveryMethod.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              _buildLabelValueRow(
                isRtl ? 'التوصيل:' : 'Delivery:',
                deliveryMethod,
                summaryStyle,
                isRtl: isRtl,
              ),
              pw.SizedBox(height: 5),
            ],

            // Footer section - compact design
            pw.Column(
              children: [
                // QR Code - ZATCA compliant if credentials available, otherwise payment QR
                if (updatedSettings?['showQRCode']?.visible == true) ...[
                  _buildQrCodeSection(
                    zatcaVatNumber: zatcaVatNumber,
                    zatcaCompanyName: zatcaCompanyName,
                    orderDate: orderDate,
                    isFromLocalStorage: isFromLocalStorage,
                    formattedTotal: formattedTotal,
                    totalTax: totalTax,
                    manualPaymentGateway: manualPaymentGateway,
                    orderNumber: orderNumber,
                    selectedPaperSize: selectedPaperSize,
                    isRtl: isRtl,
                    arabicFontBold: arabicFontBold,
                    updatedSettings: updatedSettings,
                  ),
                  pw.SizedBox(height: 5), // Reduced from 10
                ],

                // Order ID Barcode - compact size
                _buildOrderBarcodePDF(selectedPaperSize, orderNumber),

                // Thank You message - reduced font size
                if (updatedSettings?['showThankYouMessage']?.visible == true)
                  pw.Center(
                    child: pw.Text(
                      (updatedSettings?['showThankYouMessage']?.value
                                      as String?)
                                  ?.isNotEmpty ==
                              true
                          ? updatedSettings!['showThankYouMessage']!.value
                              as String
                          : (isRtl
                              ? 'شكراً لك... نتمنى زيارتكم مرة أخرى'
                              : 'Thank You... Visit Again'),
                      style: pw.TextStyle(
                        font: arabicFontBold,
                        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),

                // Terms & Conditions - compact design
                if (updatedSettings?['showTermsConditions']?.visible ==
                    true) ...[
                  if (_hasTermsData(updatedSettings, billDocumentConfig)) ...[
                    _buildTermsConditionsBoxPDF(
                        selectedPaperSize, updatedSettings, billDocumentConfig,
                        isRtl: isRtl,
                        arabicFont: arabicFont,
                        arabicFontBold: arabicFontBold),
                  ],
                ],
              ],
            ),
          ],
        ),
      );

      if (selectedPrinter.isDevelopment) {
        final savedFile = await DevelopmentPrinterService.savePdf(
          bytes: await pdf.save(),
          orderNumber: orderNumber,
          layoutId: 'classic',
        );
        if (context.mounted) {
          showScaffold(
            context: context,
            message: 'Development PDF saved to ${savedFile.path}',
          );
        }
        return;
      }

      // Save PDF to documents/epos folder for better organization
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedOrderNumber =
          orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/Receipt_$sanitizedOrderNumber.pdf');
      await file.writeAsBytes(await pdf.save());

      // Determine if running on Windows
      final bool isWindows = Platform.isWindows;

      if (isWindows) {
        await _handleWindowsPdf(file);
      } else {
        // Try to open the PDF directly for non-Windows platforms
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            if (!isWindows) {
              await _sharePdfFallback(file);
            } else {
              if (context.mounted) {
                showScaffold(
                    context: context, message: "PDF created successfully");
                // Note: Navigation is now handled by the caller
                // PrintPage has its own back button, auto-print doesn't need navigation
              }
            }
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context, message: "PDF opened for printing");
              // Note: Navigation is now handled by the caller
              // PrintPage has its own back button, auto-print doesn't need navigation
            }
          }
        } catch (e) {
          debugPrint("Error opening PDF: ${e.toString()}");
          if (!isWindows) {
            await _sharePdfFallback(file);
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context, message: "PDF created successfully");
              // Note: Navigation is now handled by the caller
              // PrintPage has its own back button, auto-print doesn't need navigation
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error generating PDF: ${e.toString()}");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: ${e.toString()}",
        );
      }
      if (selectedPrinter?.isDevelopment == true) {
        rethrow;
      }
    }
  }

  // Windows-specific handling for PDF
  Future<void> _handleWindowsPdf(File file) async {
    try {
      // First try to open with the default Windows PDF viewer
      final result = await OpenFile.open(file.path);

      // Always show success message
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        // Note: Navigation is now handled by the caller
        // PrintPage has its own back button, auto-print doesn't need navigation
      }
    } catch (e) {
      debugPrint("Windows PDF handling error: $e");
      // Still show success on error
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        // Note: Navigation is now handled by the caller
        // PrintPage has its own back button, auto-print doesn't need navigation
      }
    }
  }

  // Show information about file location (for Windows) - Now unused but kept for reference
  void _showFileLocationInfo(File file) {
    if (context.mounted) {
      // Note: Navigation is now handled by the caller
      // PrintPage has its own back button, auto-print doesn't need navigation
    }
  }

  // Fallback method to share PDF if direct opening fails (for mobile platforms)
  Future<void> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share PDF as fallback...");
      // Only try to share on non-Windows platforms
      if (!Platform.isWindows) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject:
              'Receipt #${file.path.split('/').last.replaceAll('.pdf', '').replaceAll('Receipt-', '')}',
          text: 'Your receipt for order',
        );

        if (context.mounted) {
          showScaffold(
              context: context, message: "PDF shared. Please open it to print");
          // Note: Navigation is now handled by the caller
          // PrintPage has its own back button, auto-print doesn't need navigation
        }
      } else {
        // For Windows, show the file location
        _showFileLocationInfo(file);
      }
    } catch (e) {
      debugPrint("Error sharing PDF fallback: ${e.toString()}");
      if (context.mounted) {
        if (Platform.isWindows) {
          // Show file location on Windows
          _showFileLocationInfo(file);
        } else {
          showScaffoldError(
            context: context,
            message:
                "Unable to open or share PDF: ${e.toString()}. Please check app permissions.",
          );
        }
      }
    }
  }

  pw.Widget _buildPdfItemsTable(
      pw.TextStyle headerStyle,
      pw.TextStyle contentStyle,
      Map<String, DisplayOption>? displayConfig,
      List<dynamic> cartItems,
      bool isFromLocalStorage,
      DocumentConfig? billDocumentConfig,
      {bool isRtl = false}) {
    // Create headers for the table based on visibility and resolved labels
    final List<String> tableHeaders = [];
    final Map<int, pw.Alignment> cellAlignmentsMap = {};
    final List<double> columnWidths = [];
    int visibleColIndex = 0;

    if (displayConfig?['showSLNumber']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final slLabel =
          (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSLNumber']!.value as String
              : (billDocumentConfig?.resolvedLabels?.slNumber?.isNotEmpty ==
                      true
                  ? billDocumentConfig!.resolvedLabels!.slNumber!
                  : 'SL#');
      tableHeaders.add(slLabel);
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(1); // Smaller width for serial number
    }
    if (displayConfig?['showParticulars']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label = (displayConfig?['showParticulars']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showParticulars']!.value as String
          : (billDocumentConfig?.resolvedLabels?.particulars?.isNotEmpty == true
              ? billDocumentConfig!.resolvedLabels!.particulars!
              : 'PARTICULARS');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(
          5); // Much larger width for product names to accommodate long names
    }
    if (displayConfig?['showMRP']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : (billDocumentConfig?.resolvedLabels?.mrp?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.mrp!
                  : 'MRP');
      tableHeaders.add(mrpLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showQty']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : (billDocumentConfig?.resolvedLabels?.qty?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.qty!
                  : 'QTY');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Compact for quantity
    }
    if (displayConfig?['showRate']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : (billDocumentConfig?.resolvedLabels?.rate?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.rate!
                  : 'RATE');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showRateExcTax']?.visible == true) {
      final label =
          (displayConfig?['showRateExcTax']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showRateExcTax']!.value as String
              : 'RATE';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }
    if (displayConfig?['showUnit']?.visible == true) {
      final label =
          (displayConfig?['showUnit']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showUnit']!.value as String
              : (billDocumentConfig?.resolvedLabels?.unitName?.isNotEmpty ==
                      true
                  ? billDocumentConfig!.resolvedLabels!.unitName!
                  : 'UNIT');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.center;
      columnWidths.add(1.1);
    }
    // Add Tax column header - only if showTax is visible
    if (displayConfig?['showTax']?.visible == true) {
      final taxLabel =
          (displayConfig?['showTax']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTax']!.value as String
              : (billDocumentConfig?.resolvedLabels?.tax?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.tax!
                  : (isRtl ? 'الضريبة' : 'TAX'));
      tableHeaders.add(taxLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Same width as other price columns
    }
    if (displayConfig?['showTotal']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : (billDocumentConfig?.resolvedLabels?.total?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.total!
                  : 'TOTAL');
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for total values
    }

    // Create table data based on visibility with smart product name handling
    List<List<String>> tableData = [];
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String unitPriceExTax = '';
      String unitName = '';
      String totalPrice = '';
      String itemTaxAmount = '';

      if (isFromLocalStorage) {
        productName = item['productName'] ?? '';
        mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        quantity = item['quantity'] ?? '0';
        final unitPriceValue =
            double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0;
        final taxValue =
            double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
        final quantityValue =
            double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
        unitPrice = unitPriceValue.toStringAsFixed(2);
        unitPriceExTax = (unitPriceValue -
                (quantityValue > 0 ? taxValue / quantityValue : 0))
            .toStringAsFixed(2);
        unitName = getPrintUnit(item);
        totalPrice =
            (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
        itemTaxAmount =
            (double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
      } else {
        // Handle different object types - check if it's a Map or an object
        if (item is Map<String, dynamic>) {
          // Handle Map case (from API responses or converted data)
          productName = item['product_name']?.toString() ??
              item['productName']?.toString() ??
              '';
          mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
          quantity = item['quantity']?.toString() ?? '0';
          final unitPriceValue = double.tryParse(
                  item['unit_price']?.toString() ??
                      item['unitPrice']?.toString() ??
                      '0') ??
              0.0;
          final taxValue = double.tryParse(item['tax_amount']?.toString() ??
                  item['taxAmount']?.toString() ??
                  '0') ??
              0.0;
          final quantityValue =
              double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
          unitPrice = unitPriceValue.toStringAsFixed(2);
          unitPriceExTax = (unitPriceValue -
                  (quantityValue > 0 ? taxValue / quantityValue : 0))
              .toStringAsFixed(2);
          unitName = getPrintUnit(item);
          totalPrice = (double.tryParse(item['total_price']?.toString() ??
                      item['totalPrice']?.toString() ??
                      '0') ??
                  0.0)
              .toStringAsFixed(2);
          itemTaxAmount = (double.tryParse(item['tax_amount']?.toString() ??
                      item['taxAmount']?.toString() ??
                      '0') ??
                  0.0)
              .toStringAsFixed(2);
        } else {
          // Handle object case (OrderDetailsModelDataCartItem or similar)
          try {
            productName = item.productName?.toString() ?? '';
            mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
            quantity = item.quantity?.toString() ?? '0';
            final unitPriceValue =
                double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0;
            final taxValue =
                double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
            final quantityValue =
                double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0;
            unitPrice = unitPriceValue.toStringAsFixed(2);
            unitPriceExTax = (unitPriceValue -
                    (quantityValue > 0 ? taxValue / quantityValue : 0))
                .toStringAsFixed(2);
            unitName = getPrintUnit(item);
            totalPrice =
                (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
                    .toStringAsFixed(2);
            itemTaxAmount =
                (double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0)
                    .toStringAsFixed(2);
          } catch (e) {
            debugPrint('Error accessing cart item properties: $e');
            debugPrint('Item type: ${item.runtimeType}');
            debugPrint('Item: $item');
            // Fallback to safe defaults
            productName = 'Unknown Product';
            mrp = '0.00';
            quantity = '0';
            unitPrice = '0.00';
            unitPriceExTax = '0.00';
            unitName = '';
            totalPrice = '0.00';
            itemTaxAmount = '0.00';
          }
        }
      }

      // Use full product name without truncation for PDF.
      // For Arabic templates, show the Arabic name on line 1 and English on
      // line 2 (mirrors the thermal layout).
      String? arabicItemName;
      try {
        if (isFromLocalStorage || item is Map) {
          final n =
              item['product_names'] ?? item['productNames'] ?? item['names'];
          if (n is Map) arabicItemName = (n['ar'] ?? n['arabic'])?.toString();
        } else {
          arabicItemName = item.names?.ar?.toString();
        }
      } catch (_) {}

      String displayProductName;
      if (isRtl && arabicItemName != null && arabicItemName.trim().isNotEmpty) {
        displayProductName = productName.trim().isNotEmpty
            ? '$arabicItemName\n\u200E$productName'
            : arabicItemName;
      } else {
        // Prepend LRM (Left-to-Right Mark) to force LTR rendering in RTL context
        displayProductName = '\u200E$productName';
      }

      List<String> rowData = [];
      if (displayConfig?['showSLNumber']?.visible == true) {
        rowData.add((i + 1).toString());
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        rowData.add(displayProductName);
      }
      if (displayConfig?['showMRP']?.visible == true) {
        rowData.add(mrp);
      }
      if (displayConfig?['showQty']?.visible == true) {
        rowData.add(quantity);
      }
      if (displayConfig?['showRate']?.visible == true) {
        rowData.add(unitPrice);
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        rowData.add(unitPriceExTax);
      }
      if (displayConfig?['showUnit']?.visible == true) {
        rowData.add(unitName);
      }
      // Add tax amount only if showTax is visible
      if (displayConfig?['showTax']?.visible == true) {
        rowData.add(itemTaxAmount);
      }
      if (displayConfig?['showTotal']?.visible == true) {
        rowData.add(totalPrice);
      }

      tableData.add(rowData);
    }

    // Apply RTL column reversal if needed
    final finalHeaders = isRtl ? tableHeaders.reversed.toList() : tableHeaders;
    final finalData = isRtl
        ? tableData.map((row) => row.reversed.toList()).toList()
        : tableData;
    final finalColumnWidths =
        isRtl ? columnWidths.reversed.toList() : columnWidths;

    // Remap cell alignments for RTL (swap left/right alignments and reverse order)
    final Map<int, pw.Alignment> finalCellAlignments = {};
    if (isRtl) {
      final numCols = tableHeaders.length;
      cellAlignmentsMap.forEach((key, value) {
        final newKey = numCols - 1 - key;
        // Swap left and right alignments
        if (value == pw.Alignment.centerLeft) {
          finalCellAlignments[newKey] = pw.Alignment.centerRight;
        } else if (value == pw.Alignment.centerRight) {
          finalCellAlignments[newKey] = pw.Alignment.centerLeft;
        } else {
          finalCellAlignments[newKey] = value;
        }
      });
    } else {
      finalCellAlignments.addAll(cellAlignmentsMap);
    }

    return pw.Table.fromTextArray(
      headers: finalHeaders,
      data: finalData,
      headerStyle: headerStyle,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      headerHeight: 20, // Reduced from 25
      cellStyle: contentStyle,
      cellHeight: 18, // Reduced from 25
      cellAlignments: finalCellAlignments,
      cellPadding: const pw.EdgeInsets.all(3), // Reduced from 5
      border: const pw.TableBorder(
        top: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        left: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        right: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        horizontalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
      ),
      columnWidths: {
        for (var i in finalColumnWidths.asMap().keys)
          i: pw.FlexColumnWidth(finalColumnWidths[i])
      },
    );
  }

  pw.Widget _buildPdfSummary(
      pw.TextStyle style,
      pw.TextStyle netTotalStyle,
      Map<String, DisplayOption>? displayConfig,
      String formattedTotal,
      String? savedTotal,
      String? discountAmount,
      int itemCount,
      DocumentConfig? billDocumentConfig,
      double? customerOldBalance,
      double? customerCurrentBalance,
      {bool isRtl = false,
      List<dynamic>? cartItems,
      bool isFromLocalStorage = false}) {
    double savedTotalValue = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double formattedTotalValue =
        double.tryParse(formattedTotal.replaceAll(',', '')) ?? 0.0;
    double discountAmountValue =
        double.tryParse(discountAmount ?? '0.0') ?? 0.0;
    double totalMRP = savedTotalValue + formattedTotalValue;

    // Calculate total tax from cart items
    double totalTax = 0.0;
    if (cartItems != null) {
      for (var item in cartItems) {
        if (isFromLocalStorage) {
          totalTax +=
              double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
        } else {
          totalTax += double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
        }
      }
    }

    List<pw.Widget> summaryWidgets = [];

    // Display Item Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      final itemsLabel =
          (displayConfig?['showItemsCount']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showItemsCount']!.value as String
              : (isRtl ? 'إجمالي العناصر:' : 'Total Items:');
      summaryWidgets.add(
        _buildLabelValueRow(itemsLabel, itemCount.toString(), style,
            isRtl: isRtl),
      );
      summaryWidgets.add(pw.SizedBox(height: 3));
    }

    // Display Total MRP
    if (displayConfig?['showMRPTotal']?.visible == true) {
      final mrpLabel =
          (displayConfig?['showMRPTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRPTotal']!.value as String
              : (isRtl ? 'إجمالي السعر:' : 'Total MRP:');
      summaryWidgets.add(
        _buildLabelValueRow(mrpLabel, totalMRP.toStringAsFixed(2), style,
            isRtl: isRtl),
      );
      summaryWidgets.add(pw.SizedBox(height: 3));
    }

    // Display You Saved - only show if value is greater than 0
    if (displayConfig?['showSaved']?.visible == true && savedTotalValue > 0) {
      final savedLabel =
          (displayConfig?['showSaved']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSaved']!.value as String
              : (isRtl ? 'لقد وفرت:' : 'You Saved:');
      summaryWidgets.add(
        _buildLabelValueRow(
            savedLabel, savedTotalValue.toStringAsFixed(2), style,
            isRtl: isRtl),
      );
      summaryWidgets.add(pw.SizedBox(height: 3));
    }

    // Display Discount
    if (displayConfig?['showDiscount']?.visible == true) {
      final discountLabel =
          (displayConfig?['showDiscount']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showDiscount']!.value as String
              : (isRtl ? 'الخصم:' : 'Discount:');
      summaryWidgets.add(
        _buildLabelValueRow(
            discountLabel, discountAmountValue.toStringAsFixed(2), style,
            isRtl: isRtl),
      );
      summaryWidgets.add(pw.SizedBox(height: 3));
    }

    // Display Tax Amount - only if showTax is visible
    if (displayConfig?['showTax']?.visible == true) {
      final taxLabel =
          (displayConfig?['showTax']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTax']!.value as String
              : (billDocumentConfig?.resolvedLabels?.tax?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.tax!
                  : (isRtl ? 'مبلغ الضريبة:' : 'Tax Amount:'));
      summaryWidgets.add(
        _buildLabelValueRow(taxLabel, totalTax.toStringAsFixed(2), style,
            isRtl: isRtl),
      );
      summaryWidgets.add(pw.SizedBox(height: 3));
    }

    // Display Net Total (Amount)
    if (displayConfig?['showNetAmount']?.visible == true) {
      final netLabel =
          (displayConfig?['showNetAmount']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showNetAmount']!.value as String
              : (isRtl ? 'المجموع الصافي:' : 'Net Total:');
      summaryWidgets.add(pw.Divider(color: PdfColors.black));
      summaryWidgets.add(
        _buildLabelValueRow(
            netLabel, formattedTotalValue.toStringAsFixed(2), netTotalStyle,
            isRtl: isRtl),
      );
    }

    return pw.Column(children: summaryWidgets);
  }

  // Helper method for customer balance display (3 lines with spacing)
  // Now respects displayConfig visibility flags for each balance line
  pw.Widget _buildCustomerBalancePdf(
    String selectedPaperSize,
    double? oldBalance,
    double? currentBalance,
    double? paidAmount,
    pw.TextStyle style, {
    bool isRtl = false,
    Map<String, DisplayOption>? displayConfig,
    pw.Font? arabicFont,
    pw.Font? arabicFontBold,
  }) {
    // Use smaller font size for balance display with Arabic font support
    final balanceStyle = pw.TextStyle(
      font: arabicFont,
      fontBold: arabicFontBold,
      fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
      color: PdfColors.black,
    );
    final balanceBoldStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );

    // Check visibility flags from displayConfig
    final showPrevBalance =
        displayConfig?['showCustomerPrevBalance']?.visible ?? true;
    final showPaidAmount =
        displayConfig?['showCustomerPaidAmount']?.visible ?? true;
    final showCurrentBalance =
        displayConfig?['showCustomerCurrentBalance']?.visible ?? true;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Column(
        children: [
          // Old Balanceance line - respects showCustomerPrevBalance visibility
          if (oldBalance != null && showPrevBalance)
            _buildLabelValueRow(
                (displayConfig?['showCustomerPrevBalance']?.value as String?)
                            ?.isNotEmpty ==
                        true
                    ? displayConfig!['showCustomerPrevBalance']!.value as String
                    : (isRtl ? 'الرصيد السابق:' : 'Old Balance:'),
                oldBalance.toStringAsFixed(2),
                balanceStyle,
                isRtl: isRtl),
          // Paid Amount line - respects showCustomerPaidAmount visibility
          if (paidAmount != null && showPaidAmount)
            _buildLabelValueRow(
                (displayConfig?['showCustomerPaidAmount']?.value as String?)
                            ?.isNotEmpty ==
                        true
                    ? displayConfig!['showCustomerPaidAmount']!.value as String
                    : (isRtl ? 'المبلغ المدفوع:' : 'Paid Amount:'),
                paidAmount.toStringAsFixed(2),
                balanceStyle,
                isRtl: isRtl),
          // Current Balance line - respects showCustomerCurrentBalance visibility
          if (currentBalance != null && showCurrentBalance)
            _buildLabelValueRow(
                (displayConfig?['showCustomerCurrentBalance']?.value as String?)
                            ?.isNotEmpty ==
                        true
                    ? displayConfig!['showCustomerCurrentBalance']!.value
                        as String
                    : (isRtl ? 'الرصيد الحالي:' : 'Current Balance:'),
                currentBalance.toStringAsFixed(2),
                balanceBoldStyle,
                isRtl: isRtl),
        ],
      ),
    );
  }

  // Date and Time Row for PDF - minimal design
  pw.Widget _buildDateTimeRowPDF(
      String selectedPaperSize, String orderDate, bool isFromLocalStorage,
      {bool isRtl = false,
      pw.Font? arabicFontBold,
      Map<String, DisplayOption>? displayConfig}) {
    // Use appropriate date formatting based on source
    String formattedDate;
    String formattedTime;

    try {
      // Try to parse as ISO string
      if (isFromLocalStorage) {
        formattedDate = DateHelper.formatToISODateOnlyFromISO(orderDate);
        formattedTime = DateHelper.formatToISODateFromIST(orderDate);
      } else {
        // Check if already formatted (contains AM/PM or specific format)
        if (orderDate.contains(' AM') || orderDate.contains(' PM')) {
          // Already formatted, split date and time
          final parts = orderDate.split(' ');
          formattedDate = parts[0];
          formattedTime = orderDate; // Use full string for time/datetime
        } else {
          formattedDate = DateHelper.formatISODate(orderDate);
          formattedTime = DateHelper.formatISODateToIST(orderDate);
        }
      }
    } catch (e) {
      // Fallback if parsing fails
      formattedDate = orderDate;
      formattedTime = orderDate;
    }

    final dateTimeStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
      fontWeight: pw.FontWeight.bold,
    );

    // Use displayConfig labels with fallback to RTL-aware defaults
    final dateLabel =
        (displayConfig?['showDateHeader']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showDateHeader']!.value as String
            : (isRtl ? 'التاريخ:' : 'Date:');
    final timeLabel =
        (displayConfig?['showTimeHeader']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showTimeHeader']!.value as String
            : (isRtl ? 'الوقت:' : 'Time:');
    final dateWidget =
        pw.Text('$dateLabel $formattedDate', style: dateTimeStyle);
    final timeWidget =
        pw.Text('$timeLabel $formattedTime', style: dateTimeStyle);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: isRtl ? [timeWidget, dateWidget] : [dateWidget, timeWidget],
      ),
    );
  }

  // Order ID Barcode for PDF - compact design with vertical padding
  pw.Widget _buildOrderBarcodePDF(
      String selectedPaperSize, String orderNumber) {
    return pw.Center(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            vertical: 5), // Added vertical padding
        child: pw.Column(
          children: [
            pw.BarcodeWidget(
              textPadding: 2,
              barcode: pw.Barcode.code128(),
              data: orderNumber,
              width: selectedPaperSize == 'A5' ? 100 : 120, // Smaller size
              height: selectedPaperSize == 'A5' ? 25 : 30, // Smaller height
            ),
            pw.SizedBox(height: 5), // Reduced from 10
          ],
        ),
      ),
    );
  }

  // Build QR Code Section - ZATCA compliant if credentials available
  pw.Widget _buildQrCodeSection({
    required String? zatcaVatNumber,
    required String? zatcaCompanyName,
    required String orderDate,
    required bool isFromLocalStorage,
    required String formattedTotal,
    required double totalTax,
    required PaymentGateway manualPaymentGateway,
    required String orderNumber,
    required String selectedPaperSize,
    required bool isRtl,
    required pw.Font arabicFontBold,
    required Map<String, DisplayOption>? updatedSettings,
  }) {
    String qrData = '';
    String qrMessage = '';

    // Check if ZATCA credentials are available for Saudi Arabia e-invoicing
    final bool hasZatcaCredentials = zatcaVatNumber != null &&
        zatcaVatNumber.isNotEmpty &&
        zatcaCompanyName != null &&
        zatcaCompanyName.isNotEmpty;

    if (hasZatcaCredentials) {
      debugPrint(
          '[StandardPrinter] ZATCA credentials found, generating ZATCA QR');

      // Generate ZATCA Phase 1 compliant QR code
      final zatcaHelper = ZatcaQrHelper();
      final totalAmount =
          double.tryParse(formattedTotal.replaceAll(',', '')) ?? 0.0;
      qrData = zatcaHelper.generateQrForInvoice(
        sellerName: zatcaCompanyName,
        vatNumber: zatcaVatNumber,
        invoiceDate: orderDate, // Pass true UTC ISO string
        totalAmount: totalAmount,
        vatAmount: totalTax,
      );

      qrMessage = isRtl ? 'فاتورة الكترونية' : 'ZATCA E-Invoice QR';

      debugPrint('[StandardPrinter] ZATCA QR generated: ${qrData.isNotEmpty}');
    } else {
      debugPrint('[StandardPrinter] No ZATCA credentials, using payment QR');

      // Fallback to payment gateway QR
      qrData = manualPaymentGateway.link;
      if (qrData.isNotEmpty) {
        if (qrData.contains('{formattedTotal}') ||
            qrData.contains('{orderNumber}')) {
          qrData = qrData
              .replaceAll('{formattedTotal}', formattedTotal)
              .replaceAll('{orderNumber}', orderNumber);
        } else if (qrData.contains('@')) {
          qrData =
              'upi://pay?pa=$qrData&am=$formattedTotal&tn=$orderNumber&cu=INR';
        }
      }

      qrMessage =
          (updatedSettings?['showQRCode']?.value as String?)?.isNotEmpty == true
              ? updatedSettings!['showQRCode']!.value as String
              : (isRtl ? 'امسح للدفع' : 'Scan to Pay');
    }

    // Return empty container if no QR data
    if (qrData.isEmpty) {
      return pw.SizedBox();
    }

    // Build QR code widget
    return pw.Center(
      child: pw.Column(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: selectedPaperSize == 'A5' ? 80 : 100,
            height: selectedPaperSize == 'A5' ? 80 : 100,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            qrMessage,
            style: pw.TextStyle(
              font: arabicFontBold,
              fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          // Show VAT number below QR for ZATCA receipts
          if (hasZatcaCredentials) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              isRtl
                  ? 'الرقم الضريبي: $zatcaVatNumber'
                  : 'VAT No: $zatcaVatNumber',
              style: pw.TextStyle(
                font: arabicFontBold,
                fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to check if terms data is available
  bool _hasTermsData(Map<String, DisplayOption>? displayConfig,
      DocumentConfig billDocumentConfig) {
    // Get terms from displayConfig value first, then fallback to billDocumentConfig
    String? terms = displayConfig?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      // Fallback to billDocumentConfig terms
      terms = billDocumentConfig.terms;
    }
    return terms != null && terms.trim().isNotEmpty;
  }

  // Terms & Conditions in a Box for PDF - minimal design
  pw.Widget _buildTermsConditionsBoxPDF(
      String selectedPaperSize,
      Map<String, DisplayOption>? displayConfig,
      DocumentConfig billDocumentConfig,
      {bool isRtl = false,
      pw.Font? arabicFont,
      pw.Font? arabicFontBold}) {
    // Get terms from displayConfig value first, then fallback to billDocumentConfig
    String? terms = displayConfig?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      terms = billDocumentConfig.terms;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5), // Reduced padding
      child: pw.Column(
        crossAxisAlignment:
            isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: PdfColors.black),
          ...terms!.split('\n').map((term) {
            if (term.trim().isEmpty) {
              return pw.SizedBox(height: 1); // Reduced from 2
            }
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2), // Reduced from 3
              child: pw.Text(
                term,
                style: pw.TextStyle(
                  font: arabicFont,
                  fontBold: arabicFontBold,
                  fontSize: selectedPaperSize == 'A5'
                      ? 7.0
                      : 7.0, // Reduced font size
                ),
                textAlign: isRtl ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    if (displayConfig == null) {
      debugPrint("ERROR: Display configuration is null!");
      return;
    }

    debugPrint("===== DISPLAY CONFIGURATION DEBUG ANALYSIS =====");
    debugPrint("DisplayConfig Map Type: ${displayConfig.runtimeType}");
    debugPrint("DisplayConfig Keys Count: ${displayConfig.keys.length}");
    debugPrint("DisplayConfig Keys: ${displayConfig.keys.toList()}");

    debugPrint("\nDETAILED DISPLAY CONFIGURATION:");
    displayConfig.forEach((key, value) {
      debugPrint("- $key:");
      debugPrint(
          "  * visible: ${value.visible} (${value.visible.runtimeType})");
      debugPrint("  * value: ${value.value} (${value.value.runtimeType})");
      debugPrint("  * DisplayOption object: $value");
    });

    // Special focus on showDiscount
    if (displayConfig.containsKey('showDiscount')) {
      final discountConfig = displayConfig['showDiscount']!;
      debugPrint("\n🔍 SHOWDISCOUNT DETAILED ANALYSIS:");
      debugPrint("  * Raw object: $discountConfig");
      debugPrint("  * Visible field: ${discountConfig.visible}");
      debugPrint("  * Visible type: ${discountConfig.visible.runtimeType}");
      debugPrint("  * Value field: ${discountConfig.value}");
      debugPrint("  * Value type: ${discountConfig.value.runtimeType}");
      debugPrint("  * Object hashCode: ${discountConfig.hashCode}");
    } else {
      debugPrint("\n⚠️ showDiscount key NOT FOUND in displayConfig!");
    }
    debugPrint("===== END DISPLAY CONFIGURATION DEBUG =====");
  }

  // Customer Details Section for PDF - compact design with increased font size
  pw.Widget _buildCustomerDetailsPDF(
    String selectedPaperSize,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    pw.TextStyle headerStyle,
    pw.TextStyle bodyStyle, {
    String? customerAlternatePhone,
    String? paymentMethod,
    bool isDefaultCustomer = false,
    bool hideDefaultCustomerPhone = true,
    bool isRtl = false,
    pw.Font? arabicFontBold,
    Map<String, DisplayOption>? displayConfig,
    String? customerVatNumber,
    String? customerCrNumber,
  }) {
    // Create a larger style for customer details with Arabic font support
    final customerDetailStyle = pw.TextStyle(
      font: arabicFontBold,
      fontSize:
          selectedPaperSize == 'A5' ? 8.0 : 10.0, // Increased from bodyStyle
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );

    List<pw.Widget> customerDetails = [];

    final bool maskPhone = displayConfig?['maskCustomerPhone']?.visible ?? true;
    final bool shouldShowPhone = customerPhone != null &&
        customerPhone.isNotEmpty &&
        !(isDefaultCustomer && hideDefaultCustomerPhone);

    if ((customerName != null && customerName.isNotEmpty) && shouldShowPhone) {
      final String displayedPhone = maskPhone
          ? StringHelper.maskStringShowLast4(customerPhone)
          : customerPhone;

      customerDetails.add(pw.Text(
          '$customerName - $displayedPhone${customerAlternatePhone != null && customerAlternatePhone.isNotEmpty ? ", $customerAlternatePhone" : ""}',
          style: customerDetailStyle));
    } else {
      if (customerName != null && customerName.isNotEmpty) {
        customerDetails.add(pw.Text(customerName, style: customerDetailStyle));
      }
      if (shouldShowPhone) {
        final String displayedPhone = maskPhone
            ? StringHelper.maskStringShowLast4(customerPhone)
            : customerPhone;

        customerDetails.add(pw.Text(
            '$displayedPhone${customerAlternatePhone != null && customerAlternatePhone.isNotEmpty ? ", $customerAlternatePhone" : ""}',
            style: customerDetailStyle));
      }
    }

    if (customerAddress != null && customerAddress.isNotEmpty) {
      if ((customerName == null || customerName.isEmpty) && !shouldShowPhone) {
        // If name/phone empty, add as just text
        customerDetails
            .add(pw.Text(customerAddress, style: customerDetailStyle));
      } else {
        // Add as formatted row if within details block
        customerDetails.add(pw.Text(
          isRtl ? '$customerAddress :العنوان' : 'Address: $customerAddress',
          style: customerDetailStyle,
        ));
      }
    }

    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      customerDetails.add(pw.Text(
        isRtl
            ? 'طريقة الدفع: $paymentMethod'
            : 'Payment Method: $paymentMethod',
        style: customerDetailStyle,
      ));
    }

    if (customerVatNumber != null && customerVatNumber.isNotEmpty) {
      customerDetails.add(pw.Text(
        isRtl
            ? 'الرقم الضريبي للعميل: $customerVatNumber'
            : 'Customer VAT: $customerVatNumber',
        style: customerDetailStyle,
      ));
    }

    if (customerCrNumber != null && customerCrNumber.isNotEmpty) {
      customerDetails.add(pw.Text(
        isRtl
            ? 'السجل التجاري للعميل: $customerCrNumber'
            : 'Customer CR: $customerCrNumber',
        style: customerDetailStyle,
      ));
    }

    if (customerDetails.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Column(
        crossAxisAlignment:
            isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: customerDetails,
      ),
    );
  }

  // Add this new method to build the order returns section
  pw.Widget _buildOrderReturnsSection(
    String selectedPaperSize,
    OrderReturns orderReturns,
    pw.TextStyle subheaderStyle,
    pw.TextStyle bodyStyle,
    pw.TextStyle tableHeaderStyle,
    pw.TextStyle summaryStyle,
    pw.TextStyle netTotalStyle,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    Map<String, DisplayOption>? displayConfig,
    DocumentConfig? billDocumentConfig, {
    bool isRtl = false,
    String? orderNumber,
    String? orderDate,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    // Credit Note / Customer config helpers
    final retDc = billDocumentConfig?.displayConfiguration?.options;
    final retLabels = billDocumentConfig?.resolvedLabels;
    final hasCreditNoteConfig = retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null;
    String retLbl(String key, String? resolved, String def) {
      final v = retDc?[key]?.visible == true
          ? (retDc?[key]?.value as String?)
          : null;
      if (v != null && v.isNotEmpty) return v;
      if (resolved != null && resolved.isNotEmpty) return resolved;
      return def;
    }

    // Create headers for the return table using configuration
    final List<String> tableHeaders = [];
    final Map<int, pw.Alignment> cellAlignmentsMap = {};
    final List<double> columnWidths = [];
    int visibleColIndex = 0;

    // Use configured labels with fallback: displayConfig > resolved_labels > default
    final slLabel =
        (displayConfig?['showReturnSLNumber']?.value as String?)?.isNotEmpty ==
                true
            ? displayConfig!['showReturnSLNumber']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnSlNumber?.isNotEmpty ==
                    true
                ? billDocumentConfig!.resolvedLabels!.returnSlNumber!
                : 'Sl#');

    final particularsLabel = (displayConfig?['showReturnParticulars']?.value
                    as String?)
                ?.isNotEmpty ==
            true
        ? displayConfig!['showReturnParticulars']!.value as String
        : (billDocumentConfig?.resolvedLabels?.returnParticulars?.isNotEmpty ==
                true
            ? billDocumentConfig!.resolvedLabels!.returnParticulars!
            : 'DESCRIPTION');

    final qtyLabel =
        (displayConfig?['showReturnQty']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showReturnQty']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnQty?.isNotEmpty == true
                ? billDocumentConfig!.resolvedLabels!.returnQty!
                : 'QTY');

    final rateLabel =
        (displayConfig?['showReturnRate']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showReturnRate']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnRate?.isNotEmpty ==
                    true
                ? billDocumentConfig!.resolvedLabels!.returnRate!
                : 'RATE');

    final totalLabel = (displayConfig?['showReturnTotal']?.value as String?)
                ?.isNotEmpty ==
            true
        ? displayConfig!['showReturnTotal']!.value as String
        : (billDocumentConfig?.resolvedLabels?.returnTotal?.isNotEmpty == true
            ? billDocumentConfig!.resolvedLabels!.returnTotal!
            : 'AMOUNT');

    final mrpLabel =
        (displayConfig?['showReturnMRP']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showReturnMRP']!.value as String
            : (billDocumentConfig?.resolvedLabels?.returnMrp?.isNotEmpty == true
                ? billDocumentConfig!.resolvedLabels!.returnMrp!
                : 'MRP');

    if (displayConfig?['showReturnSLNumber']?.visible == true) {
      tableHeaders.add(slLabel);
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(1);
    }
    if (displayConfig?['showReturnParticulars']?.visible == true) {
      tableHeaders.add(particularsLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(5);
    }
    if (displayConfig?['showReturnMRP']?.visible == true) {
      tableHeaders.add(mrpLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }
    if (displayConfig?['showReturnQty']?.visible == true) {
      tableHeaders.add(qtyLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }
    if (displayConfig?['showReturnRate']?.visible == true) {
      tableHeaders.add(rateLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }
    if (displayConfig?['showReturnTotal']?.visible == true) {
      tableHeaders.add(totalLabel.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5);
    }

    // Create table data for return items
    List<List<String>> tableData = [];
    double calculatedReturnTotal = 0.0;

    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final itemQuantity = returnItem.quantity ?? 0;

      String itemMrp = '0.00';
      String itemRate = '0.00';
      String itemAmount = '0.00';

      // Look for matching item in cartItems
      for (var cartItem in cartItems) {
        String cartItemProductName = '';
        String cartItemUnitPrice = '0.00';

        if (isFromLocalStorage) {
          cartItemProductName = cartItem['productName'] ?? '';
          cartItemUnitPrice =
              (double.tryParse(cartItem['unitPrice']?.toString() ?? '0') ?? 0.0)
                  .toStringAsFixed(2);
        } else {
          if (cartItem is Map<String, dynamic>) {
            cartItemProductName = cartItem['product_name']?.toString() ??
                cartItem['productName']?.toString() ??
                '';
            cartItemUnitPrice = (double.tryParse(
                        cartItem['unit_price']?.toString() ??
                            cartItem['unitPrice']?.toString() ??
                            '0') ??
                    0.0)
                .toStringAsFixed(2);
          } else {
            try {
              cartItemProductName = cartItem.productName?.toString() ?? '';
              cartItemUnitPrice =
                  (double.tryParse(cartItem.unitPrice?.toString() ?? '0') ??
                          0.0)
                      .toStringAsFixed(2);
            } catch (e) {
              cartItemProductName = '';
              cartItemUnitPrice = '0.00';
            }
          }
        }

        if (cartItemProductName == returnItem.productName) {
          itemRate = cartItemUnitPrice;

          // Fetch MRP from cartItem
          if (isFromLocalStorage) {
            itemMrp =
                (double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0)
                    .toStringAsFixed(2);
          } else {
            if (cartItem is Map<String, dynamic>) {
              itemMrp =
                  (double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0)
                      .toStringAsFixed(2);
            } else {
              try {
                itemMrp =
                    (double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0)
                        .toStringAsFixed(2);
              } catch (e) {
                itemMrp = '0.00';
              }
            }
          }

          final amount = itemQuantity * (double.tryParse(itemRate) ?? 0.0);
          itemAmount = amount.toStringAsFixed(2);
          calculatedReturnTotal += amount;
          break;
        }
      }

      // If no match found, fall back to average rate calculation
      if (itemRate == '0.00' && itemAmount == '0.00') {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;
        num totalQuantity = 0;
        for (var item in orderReturns.returnItems!) {
          totalQuantity += item.quantity ?? 0;
        }
        final averageRate =
            totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
        final amount = itemQuantity * averageRate;
        itemRate = averageRate.toStringAsFixed(2);
        itemAmount = amount.toStringAsFixed(2);
        calculatedReturnTotal += amount;
      }

      List<String> rowData = [];
      if (displayConfig?['showReturnSLNumber']?.visible == true) {
        rowData.add((i + 1).toString());
      }
      if (displayConfig?['showReturnParticulars']?.visible == true) {
        rowData.add(returnItem.productName ?? '');
      }
      if (displayConfig?['showReturnMRP']?.visible == true) {
        rowData.add(itemMrp);
      }
      if (displayConfig?['showReturnQty']?.visible == true) {
        rowData.add(returnItem.quantity?.toString() ?? '');
      }
      if (displayConfig?['showReturnRate']?.visible == true) {
        rowData.add(itemRate);
      }
      if (displayConfig?['showReturnTotal']?.visible == true) {
        rowData.add(itemAmount);
      }

      tableData.add(rowData);
    }

    // Apply RTL column reversal if needed
    final finalHeaders = isRtl ? tableHeaders.reversed.toList() : tableHeaders;
    final finalData = isRtl
        ? tableData.map((row) => row.reversed.toList()).toList()
        : tableData;
    final finalColumnWidths =
        isRtl ? columnWidths.reversed.toList() : columnWidths;

    // Remap cell alignments for RTL (swap left/right alignments and reverse order)
    final Map<int, pw.Alignment> finalCellAlignments = {};
    if (isRtl) {
      final numCols = tableHeaders.length;
      cellAlignmentsMap.forEach((key, value) {
        final newKey = numCols - 1 - key;
        // Swap left and right alignments
        if (value == pw.Alignment.centerLeft) {
          finalCellAlignments[newKey] = pw.Alignment.centerRight;
        } else if (value == pw.Alignment.centerRight) {
          finalCellAlignments[newKey] = pw.Alignment.centerLeft;
        } else {
          finalCellAlignments[newKey] = value;
        }
      });
    } else {
      finalCellAlignments.addAll(cellAlignmentsMap);
    }

    // Get Returns section label from config with fallback
    final returnsLabel =
        (displayConfig?['showReturnsHeader']?.value as String?)?.isNotEmpty ==
                true
            ? displayConfig!['showReturnsHeader']!.value as String
            : (isRtl ? 'المرتجعات' : 'RETURNS');

    // Get Return Summary section label from config with fallback
    final returnSummaryLabel =
        (displayConfig?['showReturnSummaryHeader']?.value as String?)
                    ?.isNotEmpty ==
                true
            ? displayConfig!['showReturnSummaryHeader']!.value as String
            : (isRtl ? 'ملخص المرتجعات' : 'RETURN SUMMARY');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (!hasCreditNoteConfig) ...[
            pw.Text(returnsLabel, style: subheaderStyle),
            pw.SizedBox(height: 10),
          ],

          // — Credit Note Details —
          if (retLabels?.creditNoteNumber != null ||
              retLabels?.creditNoteDate != null) ...[
            pw.Text(
              retLbl('showCreditNoteOrder', retLabels?.detailsHeading,
                  'CREDIT NOTE DETAILS'),
              style: subheaderStyle,
            ),
            pw.SizedBox(height: 3),
            if (retLabels?.creditNoteNumber != null &&
                orderNumber != null)
              _buildLabelValueRow(
                retLbl('showCreditNoteNumber', retLabels?.creditNoteNumber,
                    'Credit Note No:'),
                orderNumber,
                summaryStyle,
                isRtl: isRtl,
              ),
            if (retLabels?.creditNoteDate != null &&
                orderDate != null)
              _buildLabelValueRow(
                retLbl('showCreditNoteDate', retLabels?.creditNoteDate,
                    'Credit Note Date:'),
                orderDate,
                summaryStyle,
                isRtl: isRtl,
              ),
            if (retLabels?.creditNoteReason != null)
              _buildLabelValueRow(
                retLbl('showCreditNoteReason', retLabels?.creditNoteReason,
                    'Reason:'),
                '',
                summaryStyle,
                isRtl: isRtl,
              ),
            pw.SizedBox(height: 8),
          ],

          // — Customer Details —
          if (customerName != null && customerName.trim().isNotEmpty) ...[
            pw.Text(retLabels?.customerHeading ?? 'CUSTOMER DETAILS', style: subheaderStyle),
            pw.SizedBox(height: 3),
            _buildLabelValueRow(
              'Customer Name:',
              customerName,
              summaryStyle,
              isRtl: isRtl,
            ),
            if (customerPhone != null && customerPhone.trim().isNotEmpty)
              _buildLabelValueRow(
                  'Phone:', customerPhone, summaryStyle, isRtl: isRtl),
            if (customerAddress != null && customerAddress.trim().isNotEmpty)
              _buildLabelValueRow('Billing Address:', customerAddress,
                  summaryStyle, isRtl: isRtl),
            pw.SizedBox(height: 8),
          ],

          if (retLabels?.itemsHeading != null) ...[
            pw.Text(retLabels!.itemsHeading!, style: subheaderStyle),
            pw.SizedBox(height: 3),
          ],

          // Return Items Table
          if (tableHeaders.isNotEmpty && tableData.isNotEmpty)
            pw.Table.fromTextArray(
              headers: finalHeaders,
              data: finalData,
              headerStyle: tableHeaderStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headerHeight: 20,
              cellStyle: bodyStyle,
              cellHeight: 18,
              cellAlignments: finalCellAlignments,
              cellPadding: const pw.EdgeInsets.all(3),
              border: const pw.TableBorder(
                top: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                left: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                right: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                horizontalInside:
                    pw.BorderSide(color: PdfColors.grey700, width: 0.5),
                verticalInside:
                    pw.BorderSide(color: PdfColors.grey700, width: 0.5),
              ),
              columnWidths: {
                for (var i in finalColumnWidths.asMap().keys)
                  i: pw.FlexColumnWidth(finalColumnWidths[i])
              },
            )
          else
            pw.Text('No return items to display', style: bodyStyle),
          pw.SizedBox(height: 15),
          // Return Summary
          if (displayConfig?['showReturnNetAmount']?.visible == true ||
              displayConfig?['showReturnTotalAmount']?.visible == true ||
              displayConfig?['showReturnItemsCount']?.visible == true ||
              retLabels?.creditNoteItemsCount != null ||
              retLabels?.creditNoteTotalAmount != null ||
              retLabels?.creditNoteRefund != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (!hasCreditNoteConfig) ...[
                  pw.Text(returnSummaryLabel, style: subheaderStyle),
                  pw.SizedBox(height: 3),
                ],
                // Display Item Count
                if (displayConfig?['showReturnItemsCount']?.visible == true ||
                    retLabels?.creditNoteItemsCount != null) ...[
                  _buildLabelValueRow(
                      retLabels?.creditNoteItemsCount != null
                          ? retLbl('showCreditNoteItemsCount',
                              retLabels?.creditNoteItemsCount, 'Total Items:')
                          : ((displayConfig?['showReturnItemsCount']?.value
                                          as String?)
                                      ?.isNotEmpty ==
                                  true
                              ? displayConfig!['showReturnItemsCount']!.value
                                  as String
                              : (isRtl
                                  ? 'إجمالي العناصر:'
                                  : 'Total Items:')),
                      orderReturns.returnItems!.length.toString(),
                      summaryStyle,
                      isRtl: isRtl),
                  pw.SizedBox(height: 2),
                ],
                // Display Total MRP
                if (displayConfig?['showReturnTotalAmount']?.visible == true ||
                    retLabels?.creditNoteTotalAmount != null) ...[
                  _buildLabelValueRow(
                      retLabels?.creditNoteTotalAmount != null
                          ? retLbl(
                              'showCreditNoteTotalAmount',
                              retLabels?.creditNoteTotalAmount,
                              'Total Amount:')
                          : ((displayConfig?['showReturnTotalAmount']?.value
                                          as String?)
                                      ?.isNotEmpty ==
                                  true
                              ? displayConfig!['showReturnTotalAmount']!.value
                                  as String
                              : (isRtl ? 'إجمالي السعر:' : 'Total MRP:')),
                      calculatedReturnTotal.toStringAsFixed(2),
                      summaryStyle,
                      isRtl: isRtl),
                  pw.SizedBox(height: 2),
                ],
                // Display Net Total
                if (displayConfig?['showReturnNetAmount']?.visible == true ||
                    retLabels?.creditNoteRefund != null) ...[
                  pw.Divider(color: PdfColors.black),
                  _buildLabelValueRow(
                      retLabels?.creditNoteRefund != null
                          ? retLbl('showCreditNoteRefund',
                              retLabels?.creditNoteRefund, 'Credit Note Total:')
                          : ((displayConfig?['showReturnNetAmount']?.value
                                          as String?)
                                      ?.isNotEmpty ==
                                  true
                              ? displayConfig!['showReturnNetAmount']!.value
                                  as String
                              : (isRtl
                                  ? 'المجموع الصافي:'
                                  : 'Net Total:')),
                      calculatedReturnTotal.toStringAsFixed(2),
                      netTotalStyle,
                      isRtl: isRtl),
                ],
              ],
            ),
          if (hasCreditNoteConfig) ...[
            pw.SizedBox(height: 4),
            pw.Text('Amount in Words:', style: subheaderStyle),
            pw.Text(
              '${AmountHelper().convertNumberToWords(calculatedReturnTotal, language: isRtl ? 'ar' : 'en')}${isRtl ? ' فقط.' : ' Only.'}',
              style: summaryStyle,
            ),
          ],
          pw.SizedBox(height: 15),
        ],
      ),
    );
  }

  // Add this new method to build the total summary section
  pw.Widget _buildTotalSummarySection(
    String selectedPaperSize,
    String formattedTotal,
    OrderReturns? orderReturns,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    pw.TextStyle subheaderStyle,
    pw.TextStyle summaryStyle,
    pw.TextStyle netTotalStyle,
    Map<String, DisplayOption>? displayConfig,
    String currency, {
    bool isRtl = false,
  }) {
    double orderTotal =
        double.tryParse(formattedTotal.replaceAll(',', '')) ?? 0.0;
    double returnTotal = 0.0;

    // Calculate return total (same logic as before)
    if (orderReturns != null &&
        orderReturns.returnItems != null &&
        orderReturns.returnItems!.isNotEmpty) {
      for (var i = 0; i < orderReturns.returnItems!.length; i++) {
        final returnItem = orderReturns.returnItems![i];
        final itemQuantity = returnItem.quantity ?? 0;
        String itemRate = '0.00';

        for (var cartItem in cartItems) {
          String cartItemProductName = '';
          String cartItemUnitPrice = '0.00';

          if (isFromLocalStorage) {
            cartItemProductName = cartItem['productName'] ?? '';
            cartItemUnitPrice =
                (double.tryParse(cartItem['unitPrice']?.toString() ?? '0') ??
                        0.0)
                    .toStringAsFixed(2);
          } else {
            if (cartItem is Map<String, dynamic>) {
              cartItemProductName = cartItem['product_name']?.toString() ??
                  cartItem['productName']?.toString() ??
                  '';
              cartItemUnitPrice = (double.tryParse(
                          cartItem['unit_price']?.toString() ??
                              cartItem['unitPrice']?.toString() ??
                              '0') ??
                      0.0)
                  .toStringAsFixed(2);
            } else {
              try {
                cartItemProductName = cartItem.productName?.toString() ?? '';
                cartItemUnitPrice =
                    (double.tryParse(cartItem.unitPrice?.toString() ?? '0') ??
                            0.0)
                        .toStringAsFixed(2);
              } catch (e) {
                cartItemProductName = '';
                cartItemUnitPrice = '0.00';
              }
            }
          }

          if (cartItemProductName == returnItem.productName) {
            itemRate = cartItemUnitPrice;
            final amount = itemQuantity * (double.tryParse(itemRate) ?? 0.0);
            returnTotal += amount;
            break;
          }
        }

        if (itemRate == '0.00' && orderReturns.returnTotalAmount != null) {
          final totalReturnAmount =
              double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;
          num totalQuantity = 0;
          for (var item in orderReturns.returnItems!) {
            totalQuantity += item.quantity ?? 0;
          }
          final averageRate =
              totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
          final amount = itemQuantity * averageRate;
          returnTotal += amount;
        }
      }
    }

    double finalTotal = orderTotal - returnTotal;

    // Get Final Summary section label from config with fallback
    final finalSummaryLabel =
        (displayConfig?['showFinalSummaryHeader']?.value as String?)
                    ?.isNotEmpty ==
                true
            ? displayConfig!['showFinalSummaryHeader']!.value as String
            : (isRtl ? 'الملخص النهائي' : 'FINAL SUMMARY');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(finalSummaryLabel, style: subheaderStyle),
          pw.SizedBox(height: 5),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Display Order Total
              if (displayConfig?['showFinalPurchase']?.visible == true)
                _buildLabelValueRow(
                    (displayConfig?['showFinalPurchase']?.value as String?)
                                ?.isNotEmpty ==
                            true
                        ? displayConfig!['showFinalPurchase']!.value as String
                        : (isRtl ? 'إجمالي المشتريات:' : 'Total Purchase:'),
                    orderTotal.toStringAsFixed(2),
                    summaryStyle,
                    isRtl: isRtl),
              if (displayConfig?['showFinalPurchase']?.visible == true)
                pw.SizedBox(height: 2),
              // Display Return Total
              if (displayConfig?['showFinalReturn']?.visible == true &&
                  orderReturns != null &&
                  orderReturns.returnItems != null &&
                  orderReturns.returnItems!.isNotEmpty)
                _buildLabelValueRow(
                    (displayConfig?['showFinalReturn']?.value as String?)
                                ?.isNotEmpty ==
                            true
                        ? displayConfig!['showFinalReturn']!.value as String
                        : (isRtl ? 'إجمالي المرتجعات:' : 'Total Return:'),
                    returnTotal.toStringAsFixed(2),
                    summaryStyle,
                    isRtl: isRtl),
              if (displayConfig?['showFinalReturn']?.visible == true &&
                  orderReturns != null &&
                  orderReturns.returnItems != null &&
                  orderReturns.returnItems!.isNotEmpty)
                pw.SizedBox(height: 2),
              // Display Final Total
              if (displayConfig?['showFinalNetAmount']?.visible == true) ...[
                pw.Divider(color: PdfColors.black),
                _buildLabelValueRow(
                    (displayConfig?['showFinalNetAmount']?.value as String?)
                                ?.isNotEmpty ==
                            true
                        ? displayConfig!['showFinalNetAmount']!.value as String
                        : (isRtl ? 'المجموع الصافي:' : 'Net Total:'),
                    finalTotal.toStringAsFixed(2),
                    netTotalStyle,
                    isRtl: isRtl),
              ],
              // Amount in words
              if (displayConfig?['showFinalAmountInWords']?.visible ==
                  true) ...[
                pw.SizedBox(height: 5),
                _buildLabelValueRow(
                  (displayConfig?['showFinalAmountInWords']?.value as String?)
                              ?.isNotEmpty ==
                          true
                      ? displayConfig!['showFinalAmountInWords']!.value
                          as String
                      : (isRtl ? 'المبلغ بالكلمات:' : 'Amount in words:'),
                  '${AmountHelper().convertNumberToWords(finalTotal, currency: currency, language: isRtl ? 'ar' : 'en')}${isRtl ? ' فقط.' : ' Only.'}',
                  summaryStyle,
                  isRtl: isRtl,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to calculate cart total from items
  double _calculateCartTotal(List<dynamic> cartItems, bool isFromLocalStorage) {
    double total = 0.0;

    for (var item in cartItems) {
      double itemTotal = 0.0;

      if (isFromLocalStorage) {
        itemTotal =
            double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0;
      } else {
        if (item is Map<String, dynamic>) {
          itemTotal = double.tryParse(item['total_price']?.toString() ??
                  item['totalPrice']?.toString() ??
                  '0') ??
              0.0;
        } else {
          try {
            itemTotal =
                double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0;
          } catch (e) {
            debugPrint('Error accessing item totalPrice: $e');
            itemTotal = 0.0;
          }
        }
      }

      total += itemTotal;
    }

    return total;
  }

  // Helper method to build cart total row after items table
  pw.Widget _buildCartTotalRow(
    String selectedPaperSize,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    pw.TextStyle summaryStyle, {
    bool isRtl = false,
    pw.Font? arabicFont,
    pw.Font? arabicFontBold,
    Map<String, DisplayOption>? displayConfig,
    String currency = '',
  }) {
    final cartTotal = _calculateCartTotal(cartItems, isFromLocalStorage);

    final totalStyle = pw.TextStyle(
      font: arabicFontBold,
      fontBold: arabicFontBold,
      fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );

    // Get total label from config with fallback
    final totalLabel =
        (displayConfig?['showCartTotal']?.value as String?)?.isNotEmpty == true
            ? displayConfig!['showCartTotal']!.value as String
            : (isRtl ? 'الإجمالي:' : 'TOTAL:');

    // Use INR symbol when app currency is INR; otherwise keep configured code.
    final currencySymbol = currency.trim().toUpperCase() == 'INR'
        ? '\u20B9 '
        : (currency.isNotEmpty ? '$currency ' : '');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: isRtl
            ? [
                pw.Text('$currencySymbol${cartTotal.toStringAsFixed(2)}',
                    style: totalStyle),
                pw.Text(totalLabel, style: totalStyle),
              ]
            : [
                pw.Text(totalLabel, style: totalStyle),
                pw.Text('$currencySymbol${cartTotal.toStringAsFixed(2)}',
                    style: totalStyle),
              ],
      ),
    );
  }

  // Generate PDF for sharing without printing
  /// Generates a shareable PDF that honors the matching B2B/B2C Billing Printer
  /// settings (paper size + receipt theme), rendering through
  /// [StandardPdfLayoutFactory] so the selected template (e.g. Simplified Tax
  /// Invoice) is used instead of the hardcoded classic layout.
  ///
  /// Resolution order:
  /// - B2B paper size: `default_paper_size_b2b` → `default_paper_size` → `A4`
  /// - B2C paper size: `default_paper_size` → `A4`
  ///   (thermal sizes are coerced to A4 since share output is an A-series PDF).
  /// - B2B theme: `billing_receipt_theme_b2b` → `billing_receipt_theme`
  /// - B2C theme: `billing_receipt_theme`
  /// - Theme fallback: document config `activeTheme` → `classic`.
  ///
  /// All Share-PDF buttons route through here. Returns the saved [File] or null.
  Future<File?> generateThemedPDFForSharing({
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    OrderReturns? orderReturns,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double? paidAmount,
    String? orderComment,
    String? deliveryMethod,
    String? customerAlternatePhone,
    String? paymentMethod,
    Map<String, dynamic>? paymentBreakdown,
    bool isDefaultCustomer = false,
    bool hideDefaultCustomerPhone = true,
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
    String? documentTitleOverride,
    String? netExcTax,
    String? storeName,
    String? storeLocation,
    String? storePhone,
    String? storeEmail,
  }) async {
    try {
      if (billDocumentConfig == null) {
        debugPrint(
            "ERROR: Bill document configuration not loaded yet (themed share).");
        return null;
      }

      final prefs = await SharedPreferences.getInstance();

      final isB2B = ReceiptCustomerSegment.isBusiness(
        customerType: customerType,
        vatNumber: customerVatNumber,
        crNumber: customerCrNumber,
      );
      String paperSize = (isB2B
              ? prefs.getString('default_paper_size_b2b') ??
                  prefs.getString('default_paper_size')
              : prefs.getString('default_paper_size')) ??
          'A4';
      // Shared output is an A-series PDF; coerce thermal sizes to A4.
      if (paperSize != 'A4' && paperSize != 'A5') {
        paperSize = 'A4';
      }

      final theme = (isB2B
              ? prefs.getString('billing_receipt_theme_b2b') ??
                  prefs.getString('billing_receipt_theme')
              : prefs.getString('billing_receipt_theme')) ??
          billDocumentConfig.activeTheme ??
          'classic';

      debugPrint(
          '[StandardPrinter.share] Using ${isB2B ? 'B2B' : 'B2C'} billing settings -> paperSize=$paperSize, theme=$theme');

      // ZATCA credentials for Saudi Arabia e-invoicing.
      final sharedPrefProvider = SharedPreferenceProvider();
      final zatcaVatNumber = await sharedPrefProvider.getZatcaVatNumber();
      final zatcaCompanyName = await sharedPrefProvider.getZatcaCompanyName();

      final bankProvider = Provider.of<BankProvider>(context, listen: false);

      final params = ReceiptLayoutParams(
        context: context,
        // No physical printer is used when sharing a PDF file.
        selectedPrinter: BluetoothPrinter(deviceName: 'share'),
        cartItems: cartItems,
        formattedTotal: formattedTotal,
        savedTotal: savedTotal,
        discountAmount: discountAmount,
        orderDate: orderDate,
        orderNumber: orderNumber,
        isFromLocalStorage: isFromLocalStorage,
        selectedPaperSize: paperSize,
        billDocumentConfig: billDocumentConfig,
        customerCareNumber: customerCareNumber,
        customerCareEmail: customerCareEmail,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        orderReturns: orderReturns,
        customerOldBalance: customerOldBalance,
        customerCurrentBalance: customerCurrentBalance,
        paidAmount: paidAmount,
        orderComment: orderComment,
        deliveryMethod: deliveryMethod,
        customerAlternatePhone: customerAlternatePhone,
        paymentMethod: paymentMethod,
        customerVatNumber: customerVatNumber,
        customerCrNumber: customerCrNumber,
        customerType: customerType,
        documentTitleOverride: documentTitleOverride,
        paymentBreakdown: paymentBreakdown,
        zatcaVatNumber: zatcaVatNumber,
        zatcaCompanyName: zatcaCompanyName,
        isDefaultCustomer: isDefaultCustomer,
        hideDefaultCustomerPhone: hideDefaultCustomerPhone,
        netExcTax: netExcTax,
        bankDetails: bankProvider.banks,
        storeName: storeName,
        storeLocation: storeLocation,
        storePhone: storePhone,
        storeEmail: storeEmail,
      );

      // Build the themed PDF via the same factory used by the print flow.
      final layout = StandardPdfLayoutFactory.getLayout(theme);
      final pdf = await layout.buildPdfDocument(params);

      // Save to the shared epos directory.
      final output = await _getEposDirectory();
      final sanitizedOrderNumber =
          orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/Invoice_$sanitizedOrderNumber.pdf');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      final fileExists = await file.exists();
      final fileSize = fileExists ? await file.length() : 0;
      debugPrint(
          '[StandardPrinter.share] Themed PDF generated: ${file.path} (exists=$fileExists, size=$fileSize)');

      if (!fileExists || fileSize == 0) {
        debugPrint('ERROR: Themed share PDF was not created properly');
        return null;
      }

      return file;
    } catch (e) {
      debugPrint("Error generating themed PDF for sharing: ${e.toString()}");
      return null;
    }
  }

  Future<File?> generatePDFForSharing({
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    OrderReturns? orderReturns,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double? paidAmount,
    String? orderComment,
    String? deliveryMethod,
    String? customerAlternatePhone,
    String? paymentMethod,
    bool isDefaultCustomer = false,
    bool hideDefaultCustomerPhone = true,
    String? customerVatNumber,
    String? customerCrNumber,
    String? customerType,
    String? documentTitleOverride,
    String? storeLocation,
    String? storePhone,
    String? storeEmail,
    bool isReturnOnly = false,
  }) async {
    try {
      // Ensure billDocumentConfig is loaded before generating PDF
      if (billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        return null;
      }

      final displayConfig = billDocumentConfig.displayConfiguration?.options;

      // Debug the document configuration being used
      debugPrint("===== DOCUMENT CONFIG BEING USED FOR SHARING =====");
      debugPrint("billDocumentConfig ID: ${billDocumentConfig.id}");
      debugPrint("billDocumentConfig Type: ${billDocumentConfig.type}");
      debugPrint(
          "billDocumentConfig Updated At: ${billDocumentConfig.updatedAt}");
      debugPrint(
          "billDocumentConfig Has Display Config: ${billDocumentConfig.displayConfiguration != null}");
      debugPrint("Display Config Options Count: ${displayConfig?.length ?? 0}");
      if (displayConfig != null) {
        debugPrint("Display Config Keys: ${displayConfig.keys.toList()}");
      }
      debugPrint("===== END DOCUMENT CONFIG INFO =====");

      _debugPrintTemplateSettings(displayConfig);

      // Create a PDF document
      final pdf = pw.Document();

      // Resolve B2B/B2C invoice title — mirrors ReceiptLayoutParams.displayConfig logic
      Map<String, DisplayOption>? updatedSettings = displayConfig;
      if (displayConfig != null) {
        final normalizedType = customerType?.trim().toUpperCase();
        final hasKycDetails = (customerVatNumber?.trim().isNotEmpty ?? false) ||
            (customerCrNumber?.trim().isNotEmpty ?? false);
        final isB2B = normalizedType == 'B2B' ||
            ((normalizedType == null || normalizedType.isEmpty) &&
                hasKycDetails);
        final titleOverride = documentTitleOverride?.trim();

        final b2bInvoiceTitle = displayConfig['showInvoiceTitleB2B'] ??
            displayConfig['showInvoiceTitleB2b'];

        if (isB2B &&
            b2bInvoiceTitle != null &&
            (b2bInvoiceTitle.visible == true ||
                (b2bInvoiceTitle.value?.toString().trim().isNotEmpty ??
                    false))) {
          final merged = Map<String, DisplayOption>.from(displayConfig);
          merged['showInvoiceTitle'] =
              titleOverride != null && titleOverride.isNotEmpty
                  ? DisplayOption(
                      visible: true,
                      value: titleOverride,
                      defaultValue: b2bInvoiceTitle.defaultValue,
                    )
                  : b2bInvoiceTitle;
          updatedSettings = merged;
          debugPrint(
              '[PDF Share] B2B customer — using showInvoiceTitleB2B: visible=${b2bInvoiceTitle.visible}, value=${b2bInvoiceTitle.value}');
        } else if (titleOverride != null && titleOverride.isNotEmpty) {
          final merged = Map<String, DisplayOption>.from(displayConfig);
          merged['showInvoiceTitle'] = DisplayOption(
            visible: true,
            value: titleOverride,
            defaultValue: displayConfig['showInvoiceTitle']?.defaultValue,
          );
          updatedSettings = merged;
          debugPrint('[PDF Share] Using documentTitleOverride: $titleOverride');
        }
      }

      debugPrint("PDF Generation - Using user settings:");
      debugPrint(
          "showStoreName: ${updatedSettings?['showStoreName']?.visible}");
      debugPrint(
          "showDescription: ${updatedSettings?['showDescription']?.visible}");
      debugPrint(
          "showStoreAddress: ${updatedSettings?['showStoreAddress']?.visible}");
      debugPrint(
          "showFssaiInfo: ${updatedSettings?['showFssaiInfo']?.visible}");
      debugPrint("showTel: ${updatedSettings?['showTel']?.visible}");
      debugPrint("showEmail: ${updatedSettings?['showEmail']?.visible}");
      debugPrint(
          "showInvoiceTitle: ${updatedSettings?['showInvoiceTitle']?.visible}");
      debugPrint(
          "showInvoiceNumber: ${updatedSettings?['showInvoiceNumber']?.visible}");
      debugPrint(
          "showDateHeader: ${updatedSettings?['showDateHeader']?.visible}");
      debugPrint("showSLNumber: ${updatedSettings?['showSLNumber']?.visible}");
      debugPrint(
          "showParticulars: ${updatedSettings?['showParticulars']?.visible}");
      debugPrint("showMRP: ${updatedSettings?['showMRP']?.visible}");
      debugPrint("showQty: ${updatedSettings?['showQty']?.visible}");
      debugPrint("showRate: ${updatedSettings?['showRate']?.visible}");
      debugPrint("showTotal: ${updatedSettings?['showTotal']?.visible}");
      debugPrint("showDiscount: ${updatedSettings?['showDiscount']?.visible}");
      debugPrint(
          "showNetAmount: ${updatedSettings?['showNetAmount']?.visible}");
      debugPrint("showMRPTotal: ${updatedSettings?['showMRPTotal']?.visible}");
      debugPrint("showSaved: ${updatedSettings?['showSaved']?.visible}");
      debugPrint(
          "showAmountInWords: ${updatedSettings?['showAmountInWords']?.visible}");
      debugPrint(
          "showItemsCount: ${updatedSettings?['showItemsCount']?.visible}");
      debugPrint(
          "showThankYouMessage: ${updatedSettings?['showThankYouMessage']?.visible}");
      debugPrint("showQRCode: ${updatedSettings?['showQRCode']?.visible}");
      debugPrint(
          "showTermsConditions: ${updatedSettings?['showTermsConditions']?.visible}");

      // Access Payment Gateways Provider for QR code link
      final paymentGatewaysProvider =
          Provider.of<PaymentGatewaysProvider>(context, listen: false);
      final manualPaymentGateway = paymentGatewaysProvider.paymentGateways
          .firstWhere((gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY",
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
                    updatedAt: "",
                  ));

      // Access App Settings Provider for currency symbol
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final currency = appSettingsProvider.appSettings?.currency ?? '';

      // Determine page format based on paper size
      PdfPageFormat pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;

      // Load Arabic fonts for multilingual support
      final arabicFont = await _loadArabicFont();
      final arabicFontBold = await _loadArabicFontBold();

      // Determine text direction based on configuration or app language
      final configLanguage = billDocumentConfig.language;
      final isRtl = configLanguage != null
          ? configLanguage.toLowerCase() == 'ar'
          : LocalizationService.locale.languageCode == 'ar';

      final textDirection = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
      debugPrint(
          'PDF (Share) - Language: ${configLanguage ?? LocalizationService.locale.languageCode}, Source: ${configLanguage != null ? 'Config' : 'App Locale'}, RTL: $isRtl');

      // Define styles with Arabic font for multilingual support
      // Use fontBold parameter for styles that need bold rendering
      final headerStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 16.0
            : 18.0, // Increased for better hierarchy
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final subheaderStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final bodyStyle = pw.TextStyle(
        font: arabicFont,
        fontBold: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table text
        color: PdfColors.black,
      );
      final smallStyle = pw.TextStyle(
        font: arabicFont,
        fontBold: arabicFontBold,
        fontSize: selectedPaperSize == 'A5' ? 5.0 : 7.0, // Reduced further
        color: PdfColors.black,
      );
      final tableHeaderStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 6.0
            : 8.0, // Reduced for smaller table headers
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final summaryStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 8.0
            : 10.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );
      final netTotalStyle = pw.TextStyle(
        font: arabicFontBold,
        fontSize: selectedPaperSize == 'A5'
            ? 9.0
            : 11.0, // Reduced for better proportion
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      );

      // Add content to a multi-page PDF with minimal margins and optimized spacing
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          textDirection: textDirection,
          margin: const pw.EdgeInsets.all(15), // Reduced from 30
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5), // Reduced from 10
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 6), // Reduced from 8
              textAlign: pw.TextAlign.center,
            ),
          ),
          build: (pw.Context context) => [
            // Wrap entire content in a Column so it flows
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with store information - compact design
                pw.Center(
                  child: pw.Column(
                    children: [
                      // Store name
                      if (updatedSettings?['showStoreName']?.visible == true)
                        pw.Text(
                          (updatedSettings?['showStoreName']?.value as String?)
                                      ?.isNotEmpty ==
                                  true
                              ? updatedSettings!['showStoreName']!.value
                                  as String
                              : (billDocumentConfig.header?.isNotEmpty == true
                                  ? billDocumentConfig.header!
                                  : (isRtl ? 'اسم المتجر' : 'STORE NAME')),
                          style: headerStyle,
                        ),

                      // Store description
                      if (updatedSettings?['showDescription']?.visible == true)
                        pw.Text(
                          updatedSettings?['showDescription']?.value
                                  as String? ??
                              billDocumentConfig.subheader ??
                              '',
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontBold: arabicFontBold,
                            fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                          ),
                        ),

                      // Store address - priority: store session > document config
                      if (updatedSettings?['showStoreAddress']?.visible ==
                          true) ...[
                        if ((storeLocation?.isNotEmpty == true) ||
                            (updatedSettings?['showStoreAddress']?.value
                                        as String?)
                                    ?.isNotEmpty ==
                                true)
                          pw.Text(
                            storeLocation?.isNotEmpty == true
                                ? storeLocation!
                                : updatedSettings!['showStoreAddress']!.value
                                    as String,
                            style: bodyStyle,
                          ),
                      ],

                      // FSSAI info - compact display
                      if (updatedSettings?['showFssaiInfo']?.visible ==
                          true) ...[
                        if ((updatedSettings?['showFssaiInfo']?.value
                                    as String?)
                                ?.isNotEmpty ==
                            true)
                          pw.Text(
                            updatedSettings!['showFssaiInfo']!.value as String,
                            style: bodyStyle,
                          ),
                      ],

                      // Contact information - priority: store session > document config > app settings
                      if (updatedSettings?['showTel']?.visible == true)
                        pw.Text(
                          storePhone?.isNotEmpty == true
                              ? storePhone!
                              : (updatedSettings?['showTel']?.value
                                      as String? ??
                                  customerCareNumber),
                          style: bodyStyle,
                        ),

                      if (updatedSettings?['showEmail']?.visible == true)
                        pw.Text(
                          storeEmail?.isNotEmpty == true
                              ? storeEmail!
                              : (updatedSettings?['showEmail']?.value
                                      as String? ??
                                  customerCareEmail),
                          style: bodyStyle,
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 5), // Reduced from 10

                // Invoice information - minimal design without borders
                if ((updatedSettings?['showInvoiceTitle']?.visible == true) ||
                    (updatedSettings?['showInvoiceNumber']?.visible == true))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8), // Reduced padding
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: isRtl
                          ? [
                              if (updatedSettings?['showInvoiceNumber']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (billDocumentConfig.numberPrefix != null &&
                                            billDocumentConfig
                                                .numberPrefix!.isNotEmpty)
                                        ? '${billDocumentConfig.numberPrefix}$orderNumber'
                                        : (isRtl
                                            ? 'رقم: $orderNumber'
                                            : 'No: $orderNumber'),
                                    style: subheaderStyle),
                              if (updatedSettings?['showInvoiceTitle']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (updatedSettings?['showInvoiceTitle']?.value
                                                    as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? updatedSettings!['showInvoiceTitle']!
                                            .value as String
                                        : (billDocumentConfig
                                                    .header?.isNotEmpty ==
                                                true
                                            ? billDocumentConfig.header!
                                            : (isRtl ? 'فاتورة' : 'INVOICE')),
                                    style: subheaderStyle),
                            ]
                          : [
                              if (updatedSettings?['showInvoiceTitle']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (updatedSettings?['showInvoiceTitle']?.value
                                                    as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? updatedSettings!['showInvoiceTitle']!
                                            .value as String
                                        : (billDocumentConfig
                                                    .header?.isNotEmpty ==
                                                true
                                            ? billDocumentConfig.header!
                                            : (isRtl ? 'فاتورة' : 'INVOICE')),
                                    style: subheaderStyle),
                              if (updatedSettings?['showInvoiceNumber']
                                      ?.visible ==
                                  true)
                                pw.Text(
                                    (billDocumentConfig.numberPrefix != null &&
                                            billDocumentConfig
                                                .numberPrefix!.isNotEmpty)
                                        ? '${billDocumentConfig.numberPrefix}$orderNumber'
                                        : (isRtl
                                            ? 'رقم: $orderNumber'
                                            : 'No: $orderNumber'),
                                    style: subheaderStyle),
                            ],
                    ),
                  ),

                // Date and Time Row - minimal design
                _buildDateTimeRowPDF(
                    selectedPaperSize, orderDate, isFromLocalStorage,
                    isRtl: isRtl,
                    arabicFontBold: arabicFontBold,
                    displayConfig: updatedSettings),
                if (customerName != null ||
                    customerPhone != null ||
                    customerEmail != null ||
                    customerAddress != null)
                  _buildCustomerDetailsPDF(
                    selectedPaperSize,
                    customerName,
                    customerPhone,
                    customerEmail,
                    customerAddress,
                    subheaderStyle,
                    bodyStyle,
                    paymentMethod: paymentMethod,
                    customerAlternatePhone: customerAlternatePhone,
                    isDefaultCustomer: isDefaultCustomer,
                    hideDefaultCustomerPhone: hideDefaultCustomerPhone,
                    isRtl: isRtl,
                    arabicFontBold: arabicFontBold,
                    customerVatNumber: customerVatNumber,
                    customerCrNumber: customerCrNumber,
                  ),

                // Items table - minimal design without borders
                if (!isReturnOnly &&
                    ((updatedSettings?['showSLNumber']?.visible == true) ||
                        (updatedSettings?['showParticulars']?.visible ==
                            true) ||
                        (updatedSettings?['showMRP']?.visible == true) ||
                        (updatedSettings?['showQty']?.visible == true) ||
                        (updatedSettings?['showRate']?.visible == true) ||
                        (updatedSettings?['showTotal']?.visible == true)))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8), // Reduced padding
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfItemsTable(
                            tableHeaderStyle,
                            bodyStyle,
                            updatedSettings,
                            cartItems,
                            isFromLocalStorage,
                            billDocumentConfig,
                            isRtl: isRtl),
                      ],
                    ),
                  ),

                // Cart Total Row - added after items table
                if (!isReturnOnly)
                  _buildCartTotalRow(selectedPaperSize, cartItems,
                      isFromLocalStorage, summaryStyle,
                      isRtl: isRtl,
                      arabicFont: arabicFont,
                      arabicFontBold: arabicFontBold,
                      displayConfig: updatedSettings,
                      currency: currency),

                pw.SizedBox(height: 5), // Reduced from 8

                // Summary - minimal design without borders
                if (!isReturnOnly &&
                    ((updatedSettings?['showItemsCount']?.visible == true) ||
                        (updatedSettings?['showMRPTotal']?.visible == true) ||
                        (updatedSettings?['showSaved']?.visible == true) ||
                        (updatedSettings?['showDiscount']?.visible == true) ||
                        (updatedSettings?['showNetAmount']?.visible == true)))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8), // Reduced padding
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            displayConfig?['showOrderSummary']?.value
                                    as String? ??
                                (isRtl ? 'ملخص الطلب' : 'ORDER SUMMARY'),
                            style: subheaderStyle,
                            textAlign:
                                isRtl ? pw.TextAlign.right : pw.TextAlign.left),
                        pw.SizedBox(height: 5), // Reduced from 10
                        _buildPdfSummary(
                            summaryStyle,
                            netTotalStyle,
                            updatedSettings,
                            formattedTotal,
                            savedTotal,
                            discountAmount,
                            cartItems.length,
                            billDocumentConfig,
                            customerOldBalance,
                            customerCurrentBalance,
                            isRtl: isRtl,
                            cartItems: cartItems,
                            isFromLocalStorage: isFromLocalStorage),
                      ],
                    ),
                  ),

                // Order Returns section - added when returns exist
                if (orderReturns != null &&
                    (orderReturns.returnItems?.isNotEmpty ?? false)) ...[
                  pw.SizedBox(height: 5), // Add spacing before return section
                  _buildOrderReturnsSection(
                    selectedPaperSize,
                    orderReturns,
                    subheaderStyle,
                    bodyStyle,
                    tableHeaderStyle,
                    summaryStyle,
                    netTotalStyle,
                    cartItems,
                    isFromLocalStorage,
                    updatedSettings,
                    billDocumentConfig, // Pass billDocumentConfig for resolved_labels
                    isRtl: isRtl,
                    orderNumber: orderNumber,
                    orderDate: orderDate,
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerAddress: customerAddress,
                  ),
                ],

                // Order Comment
                if (orderComment != null && orderComment.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8),
                    child: _buildLabelValueRow(
                      isRtl ? 'تعليق:' : 'Comment:',
                      orderComment,
                      summaryStyle,
                      isRtl: isRtl,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                ],

                if (deliveryMethod != null && deliveryMethod.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8),
                    child: _buildLabelValueRow(
                      isRtl ? 'التوصيل:' : 'Delivery:',
                      deliveryMethod,
                      summaryStyle,
                      isRtl: isRtl,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                ],

                // Total Summary section - ONLY when there are returns
                if (!isReturnOnly &&
                    orderReturns != null &&
                    (orderReturns.returnItems?.isNotEmpty ?? false)) ...[
                  _buildTotalSummarySection(
                    selectedPaperSize,
                    formattedTotal,
                    orderReturns,
                    cartItems,
                    isFromLocalStorage,
                    subheaderStyle,
                    summaryStyle,
                    netTotalStyle,
                    updatedSettings,
                    currency,
                    isRtl: isRtl,
                  ),
                ],

                // Amount in words - consistent with summary layout
                // Only show when there are NO returns (when returns exist, it's shown in Total Summary)
                if (updatedSettings?['showAmountInWords']?.visible == true &&
                    (orderReturns == null ||
                        orderReturns.returnItems == null ||
                        orderReturns.returnItems!.isEmpty))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 0, horizontal: 8), // Same padding as summary
                    child: _buildLabelValueRow(
                      (updatedSettings?['showAmountInWords']?.value as String?)
                                  ?.isNotEmpty ==
                              true
                          ? updatedSettings!['showAmountInWords']!.value
                              as String
                          : (isRtl ? 'المبلغ بالكلمات:' : 'Amount in words:'),
                      '${AmountHelper().convertNumberToWords((double.tryParse(formattedTotal.replaceAll(',', '')) ?? 0), currency: currency, language: isRtl ? 'ar' : 'en')}${isRtl ? ' فقط.' : ' Only.'}',
                      summaryStyle,
                      isRtl: isRtl,
                    ),
                  ),

                // Add Customer Balance after Amount in words (small, aligned)
                if ((updatedSettings?['showCustomerPrevBalance']?.visible ==
                            true &&
                        customerOldBalance != null) ||
                    (updatedSettings?['showCustomerCurrentBalance']?.visible ==
                            true &&
                        customerCurrentBalance != null) ||
                    (updatedSettings?['showCustomerPaidAmount']?.visible ==
                            true &&
                        paidAmount != null))
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                    child: _buildCustomerBalancePdf(
                      selectedPaperSize,
                      customerOldBalance,
                      customerCurrentBalance,
                      paidAmount,
                      bodyStyle,
                      isRtl: isRtl,
                      displayConfig: updatedSettings,
                      arabicFont: arabicFont,
                      arabicFontBold: arabicFontBold,
                    ),
                  ),

                pw.SizedBox(height: 5), // Reduced from 10

                // Footer section - compact design
                pw.Column(
                  children: [
                    // QR Code for payment - compact size (no ZATCA in sharing method)
                    if (updatedSettings?['showQRCode']?.visible == true) ...[
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: manualPaymentGateway.link
                                  .replaceAll(
                                      '{formattedTotal}', formattedTotal)
                                  .replaceAll('{orderNumber}', orderNumber),
                              width: selectedPaperSize == 'A5'
                                  ? 80
                                  : 100, // Reduced size
                              height: selectedPaperSize == 'A5'
                                  ? 80
                                  : 100, // Reduced size
                            ),
                            pw.SizedBox(height: 3), // Reduced from 5
                            pw.Text(
                              (updatedSettings?['showQRCode']?.value as String?)
                                          ?.isNotEmpty ==
                                      true
                                  ? updatedSettings!['showQRCode']!.value
                                      as String
                                  : (isRtl ? 'امسح للدفع' : 'Scan to Pay'),
                              style: pw.TextStyle(
                                font: arabicFontBold,
                                fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 5), // Reduced from 10
                    ],

                    // Order ID Barcode - compact size
                    _buildOrderBarcodePDF(selectedPaperSize, orderNumber),

                    // Thank You message - reduced font size
                    if (updatedSettings?['showThankYouMessage']?.visible ==
                        true)
                      pw.Center(
                        child: pw.Text(
                          (updatedSettings?['showThankYouMessage']?.value
                                          as String?)
                                      ?.isNotEmpty ==
                                  true
                              ? updatedSettings!['showThankYouMessage']!.value
                                  as String
                              : (isRtl
                                  ? 'شكراً لك... نتمنى زيارتكم مرة أخرى'
                                  : 'Thank You... Visit Again'),
                          style: pw.TextStyle(
                            font: arabicFontBold,
                            fontSize: selectedPaperSize == 'A5'
                                ? 8.0
                                : 10.0, // Reduced from subheaderStyle
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),

                    // Terms & Conditions - compact design
                    if (updatedSettings?['showTermsConditions']?.visible ==
                        true) ...[
                      if (_hasTermsData(
                          updatedSettings, billDocumentConfig)) ...[
                        _buildTermsConditionsBoxPDF(selectedPaperSize,
                            updatedSettings, billDocumentConfig,
                            isRtl: isRtl,
                            arabicFont: arabicFont,
                            arabicFontBold: arabicFontBold),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Save PDF to a more accessible location for sharing in documents/epos folder
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedOrderNumber =
          orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/Invoice_$sanitizedOrderNumber.pdf');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      // Verify file was created successfully
      final fileExists = await file.exists();
      final fileSize = fileExists ? await file.length() : 0;

      debugPrint('PDF generated for sharing: ${file.path}');
      debugPrint(
          'PDF directory type: ${output.path.contains('epos') ? 'Documents/epos' : (output.path.contains('Documents') ? 'Documents' : 'Temp')}');
      debugPrint('PDF file exists: $fileExists');
      debugPrint('PDF file size: $fileSize bytes');

      if (!fileExists || fileSize == 0) {
        debugPrint('ERROR: PDF file was not created properly');
        return null;
      }

      return file;
    } catch (e) {
      debugPrint("Error generating PDF for sharing: ${e.toString()}");
      return null;
    }
  }

  /// Fetches an image from a network URL and returns it as a pw.MemoryImage
  Future<pw.MemoryImage?> _fetchNetworkPdfImage(String? url) async {
    return PrintLogoLoader.loadPdfLogo(url, tag: '[print_standard]');
  }
}
