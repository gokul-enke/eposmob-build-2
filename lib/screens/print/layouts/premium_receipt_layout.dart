import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/resources/app_url.dart';

import 'receipt_layout.dart';
import 'receipt_layout_params.dart';
import '../thermal/printer_utils.dart';

/// Premium receipt layout - Modern & Clean design.
///
/// This layout features:
/// - Generous whitespace between sections
/// - Thin solid line dividers
/// - Clean, centered header with balanced typography
/// - Bilingual support (English/Arabic) like the reference
/// - Streamlined totals section with clear hierarchy
/// - Minimal, elegant footer
class PremiumReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Premium theme spacing constants
  static const double _sectionGap = 20.0;
  static const double _itemGap = 8.0;
  static const double _headerGap = 15.0;

  @override
  String get layoutId => 'premium';

  @override
  String get displayName => 'Premium';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== PREMIUM LAYOUT: THERMAL PRINTING ====");

    final context = params.context;
    final selectedPrinter = params.selectedPrinter;
    final billDocumentConfig = params.billDocumentConfig;
    final displayConfig = params.displayConfig;

    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: ${params.selectedPaperSize}");

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    try {
      debugPrint("Connecting to printer...");
      await _printerUtils.connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully.");

      // Determine language direction
      final isEnglish = params.isEnglish;
      final isBilingual = params.isBilingual;
      final textDirection = isEnglish ? TextDirection.ltr : TextDirection.rtl;
      debugPrint(
          "Language: ${isEnglish ? 'English' : (isBilingual ? 'Bilingual' : 'Arabic')} ($textDirection)");

      // Setup print parameters
      final double printWidth = params.printWidth;
      final double baseFontSize = params.baseFontSize;

      // Build receipt rows
      List<ReceiptRow> part1Rows = [];
      List<ReceiptRow> part2Rows = [];

      // ========== LOAD SAR SYMBOL ==========
      ui.Image? sarSymbol;
      try {
        sarSymbol = await _loadAssetImage('assets/images/saudi_riyal_symbol.png');
        if (sarSymbol != null) {
          debugPrint("[PREMIUM] SAR symbol loaded: ${sarSymbol.width}x${sarSymbol.height}");
        }
      } catch (e) {
        debugPrint("[PREMIUM] Error loading SAR symbol: $e");
      }

      // ========== LOGO SECTION ==========
      if (billDocumentConfig.showLogo == 1) {
        try {
          ui.Image? logo;
          if (billDocumentConfig.logo != null &&
              billDocumentConfig.logo.toString().isNotEmpty) {
            logo =
                await _fetchNetworkUiImage(billDocumentConfig.logo.toString());
          }

          if (logo != null) {
            debugPrint(
                "[PREMIUM] Logo loaded: ${logo.width}x${logo.height}");
            part1Rows.add(ImageRow(logo, width: printWidth * 0.6));
            part1Rows.add(SpacingRow(_headerGap));
          }
        } catch (e) {
          debugPrint("[PREMIUM] Error loading logo: $e");
        }
      }

      // ========== HEADER SECTION (Modern & Clean) ==========
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish);

      // ========== CART ITEMS SECTION ==========
      _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);

      // ========== TOTALS SECTION (Bilingual Style) ==========
      _buildTotalsSection(part1Rows, params, displayConfig, isEnglish, sarSymbol);

      // ========== FOOTER SECTION (Part 2) ==========
      _buildFooterSection(part2Rows, params, displayConfig, isEnglish, context);

      // ========== RENDER IMAGES ==========
      debugPrint("Rendering premium receipt images...");

      final img.Image imagePart1 =
          await ArabicPrinterHelper.renderReceiptToImage(
        rows: part1Rows,
        width: printWidth,
        fontSize: baseFontSize,
        textDirection: textDirection,
      );

      final img.Image imagePart2 =
          await ArabicPrinterHelper.renderReceiptToImage(
        rows: part2Rows,
        width: printWidth,
        fontSize: baseFontSize,
        textDirection: textDirection,
      );

      // ========== GENERATE ESC/POS BYTES ==========
      debugPrint("Generating ESC/POS bytes...");
      final profile = await CapabilityProfile.load();
      final generator = Generator(
          params.is58mm ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.image(imagePart1);
      bytes += generator.image(imagePart2);

      // Native barcode
      String cleanOrderNumber =
          params.orderNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
      if (cleanOrderNumber.isNotEmpty) {
        try {
          List<String> code39Data = cleanOrderNumber.split("");
          bytes += generator.barcode(
            Barcode.code39(code39Data),
            width: 2,
            height: 50,
            textPos: BarcodeText.none,
            align: PosAlign.center,
          );
        } catch (e) {
          debugPrint("Barcode error: $e");
        }
      }

      bytes += generator.feed(2);
      bytes += generator.drawer();
      bytes += generator.cut();

      // ========== SEND TO PRINTER ==========
      debugPrint("Sending ${bytes.length} bytes to printer...");
      final printerManager = PrinterManager.instance;
      await printerManager.send(type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully.");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR in Premium Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: "Error printing: ${e.toString()}");
      }
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("===== END PREMIUM LAYOUT PRINTING =====");
    }
  }

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) async {
    debugPrint("[PremiumReceiptLayout] buildPdf - delegating to StandardPrinter");
    return pw.Document();
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    await printThermal(params);
  }

  // ==================== HEADER SECTION (Modern & Clean) ====================

  void _buildHeaderSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    dynamic appSettings,
  ) {
    final billDocumentConfig = params.billDocumentConfig;

    // Store Name - Large, centered, clean
    if (displayConfig?['showStoreName']?.visible == true) {
      final storeName = displayConfig?['showStoreName']?.value as String? ??
          billDocumentConfig.header ??
          'STORE NAME';

      // Dynamic scaling based on name length
      double storeNameScale = 1.8;
      if (storeName.length > 20) {
        storeNameScale = 1.3;
      } else if (storeName.length > 14) {
        storeNameScale = 1.5;
      }

      rows.add(TextRow(storeName.toUpperCase(),
          isBold: true, scale: storeNameScale));
    }

    // Description/Subheader - Arabic subtitle style
    if (displayConfig?['showDescription']?.visible == true) {
      final description =
          displayConfig?['showDescription']?.value as String? ??
              billDocumentConfig.subheader ??
              '';
      if (description.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(description, scale: 1.0));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final storeAddress =
          displayConfig?['showStoreAddress']?.value as String?;
      if (storeAddress != null && storeAddress.isNotEmpty) {
        rows.add(TextRow(storeAddress, scale: 0.85));
      }
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
      if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.85));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final telephone = displayConfig?['showTel']?.value as String? ??
          appSettings?.customerCarePhone ??
          '';
      if (telephone.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(telephone, scale: 0.8));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final email = displayConfig?['showEmail']?.value as String? ??
          appSettings?.customerCareEmail ??
          '';
      if (email.isNotEmpty) {
        rows.add(TextRow(email, scale: 0.8));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(ThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Invoice Title
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle = _getDisplayValue(
        displayConfig?['showInvoiceTitle']?.value,
        appSettings?.printTitle,
        'INVOICE',
      );
      rows.add(TextRow(invoiceTitle.toUpperCase(), isBold: true, scale: 1.1));
    }

    // Invoice Number - Clean format
    if (displayConfig?['showInvoiceNumber']?.visible == true) {
      final invoiceNumberText = billDocumentConfig.numberPrefix != null &&
              billDocumentConfig.numberPrefix!.isNotEmpty
          ? '${billDocumentConfig.numberPrefix}${params.orderNumber}'
          : '#${params.orderNumber}';
      rows.add(TextRow(invoiceNumberText, scale: 0.9));
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
  }

  // ==================== CUSTOMER SECTION ====================

  void _buildCustomerSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    // Check if customer section should be visible
    if (displayConfig?['showCustomerNameAndPhone']?.visible == false) {
      return;
    }

    if (params.customerName == null && params.customerPhone == null &&
        params.customerAddress == null && params.orderComment == null) {
      return;
    }

    // Paper size aware scaling
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;

    final customerLabel = _getLabel(displayConfig, 'showCustomerName', null,
        isEnglish ? "Customer:" : "العميل:");
    final phoneLabel = _getLabel(displayConfig, 'showCustomerPhone', null,
        isEnglish ? "Phone:" : "الهاتف:");
    final paymentLabel = _getLabel(displayConfig, 'showPaymentMethod', null,
        isEnglish ? "Payment:" : "الدفع:");
    final addressLabel = _getLabel(displayConfig, 'showCustomerAddress', null,
        isEnglish ? "Address:" : "العنوان:");
    final commentLabel = _getLabel(displayConfig, 'showOrderComment', null,
        isEnglish ? "Comment:" : "تعليق:");

    if (isEnglish) {
      // English: Label: Value format (left aligned for both)
      if (params.customerName != null && params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (params.customerPhone != null && params.customerPhone!.isNotEmpty) {
        final bool maskPhone =
            displayConfig?['maskCustomerPhone']?.visible ?? false;
        final String displayedPhone = maskPhone
            ? StringHelper.maskStringShowLast4(params.customerPhone!)
            : params.customerPhone!;

        String phoneText = displayedPhone;
        if (params.customerAlternatePhone != null &&
            params.customerAlternatePhone!.isNotEmpty) {
          phoneText += ", ${params.customerAlternatePhone}";
        }

        rows.add(ReceiptTableRow([
          ReceiptTableColumn(phoneLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(phoneText,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (params.paymentMethod != null && params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (params.customerAddress != null && params.customerAddress!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(addressLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerAddress!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (params.orderComment != null && params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }
    } else {
      // Arabic: Label on right, Value on left (RTL reading flow)
      if (params.customerName != null && params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (params.customerPhone != null && params.customerPhone!.isNotEmpty) {
        final bool maskPhone =
            displayConfig?['maskCustomerPhone']?.visible ?? false;
        final String displayedPhone = maskPhone
            ? StringHelper.maskStringShowLast4(params.customerPhone!)
            : params.customerPhone!;

        rows.add(ReceiptTableRow([
          ReceiptTableColumn(displayedPhone,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(phoneLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (params.paymentMethod != null && params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (params.orderComment != null && params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (params.customerAddress != null && params.customerAddress!.isNotEmpty) {
        rows.add(TextRow(params.customerAddress!, scale: 0.9));
      }
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
  }

  // ==================== CART ITEMS SECTION ====================

  void _buildCartItemsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    // Extract labels with fallbacks
    final String particularsLabel =
        _getLabel(displayConfig, 'showParticulars', resolvedLabels?.particulars,
            isEnglish ? "Item" : "الصنف");
    final String mrpLabel =
        _getLabel(displayConfig, 'showMRP', resolvedLabels?.mrp, "MRP");
    final String qtyLabel =
        _getLabel(displayConfig, 'showQty', resolvedLabels?.qty,
            isEnglish ? "Qty" : "الكمية");
    final String rateLabel =
        _getLabel(displayConfig, 'showRate', resolvedLabels?.rate,
            isEnglish ? "Rate" : "السعر");
    final String totalLabel =
        _getLabel(displayConfig, 'showTotal', resolvedLabels?.total,
            isEnglish ? "Total" : "الإجمالي");
    final String taxHeaderLabel =
        _getLabel(displayConfig, 'showTaxHeader', resolvedLabels?.tax,
            isEnglish ? "Tax" : "الضريبة");
    final String slLabel =
        _getLabel(displayConfig, 'showSLNumber', resolvedLabels?.slNumber,
            isEnglish ? "SL#" : "#");

    // Build table header
    _buildTableHeader(rows, displayConfig, isEnglish, particularsLabel,
        mrpLabel, qtyLabel, rateLabel, totalLabel, taxHeaderLabel, slLabel);

    // Build cart items
    for (var i = 0; i < params.cartItems.length; i++) {
      _buildCartItemRow(rows, params.cartItems[i], i, params.isFromLocalStorage,
          displayConfig, isEnglish);
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
  }

  void _buildTableHeader(
    List<ReceiptRow> rows,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    String particularsLabel,
    String mrpLabel,
    String qtyLabel,
    String rateLabel,
    String totalLabel,
    String taxHeaderLabel,
    String slLabel,
  ) {
    List<ReceiptTableColumn> headerCols = [];

    if (isEnglish) {
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: 0.08, align: TextAlign.left, isBold: true));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: displayConfig?['showSLNumber']?.visible == true ? 0.17 : 0.25,
            align: TextAlign.left,
            isBold: true));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: 0.15, align: TextAlign.center, isBold: true));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: 0.12, align: TextAlign.center, isBold: true));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: 0.15, align: TextAlign.right, isBold: true));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: 0.15, align: TextAlign.right, isBold: true));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: 0.18, align: TextAlign.right, isBold: true));
      }
    } else {
      // Arabic header (RTL)
      if (displayConfig?['showTotal']?.visible == true) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: 0.18, align: TextAlign.right, isBold: true));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: 0.15, align: TextAlign.right, isBold: true));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: 0.15, align: TextAlign.right, isBold: true));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: 0.12, align: TextAlign.right, isBold: true));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: 0.15, align: TextAlign.right, isBold: true));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: displayConfig?['showSLNumber']?.visible == true ? 0.17 : 0.25,
            align: TextAlign.right,
            isBold: true));
      }
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: 0.08, align: TextAlign.right, isBold: true));
      }
    }

    if (headerCols.isNotEmpty) {
      rows.add(ReceiptTableRow(headerCols));
      rows.add(ThinDividerRow());
    }
  }

  void _buildCartItemRow(
    List<ReceiptRow> rows,
    dynamic item,
    int index,
    bool isFromLocalStorage,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    String productName = '';
    String productNameArabic = ''; // Add Arabic name field
    String mrp = '';
    String quantity = '';
    String unitPrice = '';
    String totalPrice = '';
    String itemTaxAmount = '';

    if (isFromLocalStorage) {
      productName = item['productName'] ?? '';
      mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      quantity = item['quantity'] ?? '0';
      unitPrice =
          (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      totalPrice =
          (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      itemTaxAmount =
          (double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
    } else {
      // Handle bilingual names for Arabic template
      if (!isEnglish && item.names != null && item.names!.ar != null && item.names!.ar!.isNotEmpty) {
        // Arabic template with bilingual support: Arabic on line 1, English on line 2
        productNameArabic = item.names!.ar ?? '';
        productName = item.names!.en ?? item.productName ?? '';
      } else {
        // English template or no names: use single productName
        productName = item.productName ?? '';
        productNameArabic = '';
      }
      
      mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      quantity = item.quantity?.toString() ?? '0';
      unitPrice =
          (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      totalPrice =
          (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      itemTaxAmount =
          (double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
    }

    String slNumber = (index + 1).toString();

    if (isEnglish) {
      // Product name row (English - single name)
      if (displayConfig?['showParticulars']?.visible == true ||
          displayConfig?['showSLNumber']?.visible == true) {
        String itemText = displayConfig?['showSLNumber']?.visible == true
            ? '$slNumber. $productName'
            : productName;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.left),
        ]));
      }
      // Price details row
      List<ReceiptTableColumn> priceCols = [];
      priceCols.add(ReceiptTableColumn("", weight: 0.25));
      if (displayConfig?['showMRP']?.visible == true) {
        priceCols.add(
            ReceiptTableColumn(mrp, weight: 0.15, align: TextAlign.center));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: 0.12, align: TextAlign.center));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: 0.15, align: TextAlign.right));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: 0.15, align: TextAlign.right));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: 0.18, align: TextAlign.right));
      }
      if (priceCols.length > 1) {
        rows.add(ReceiptTableRow(priceCols));
      }
    } else {
      // Arabic: RTL layout with bilingual names
      if (displayConfig?['showParticulars']?.visible == true ||
          displayConfig?['showSLNumber']?.visible == true) {
        // Show Arabic name (line 1) and English name (line 2) when available
        String itemText = '';
        if (productNameArabic.isNotEmpty) {
          // Bilingual: Arabic on line 1, English on line 2
          if (displayConfig?['showSLNumber']?.visible == true) {
            itemText = '$slNumber. $productNameArabic';
          } else {
            itemText = productNameArabic;
          }
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
          ]));
          
          // Add English name on second line
          String englishText = displayConfig?['showSLNumber']?.visible == true
              ? '     $productName'
              : '  $productName';
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(englishText, weight: 1.0, align: TextAlign.right),
          ]));
        } else {
          // Fallback to single name (English or Arabic)
          String itemText = displayConfig?['showSLNumber']?.visible == true
              ? '$slNumber. $productName'
              : productName;
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
          ]));
        }
      }
      // Price details row (RTL order)
      List<ReceiptTableColumn> priceCols = [];
      if (displayConfig?['showTotal']?.visible == true) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: 0.18, align: TextAlign.right));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: 0.15, align: TextAlign.right));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: 0.15, align: TextAlign.right));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: 0.12, align: TextAlign.right));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        priceCols.add(
            ReceiptTableColumn(mrp, weight: 0.15, align: TextAlign.right));
      }
      priceCols.add(ReceiptTableColumn("", weight: 0.25));
      if (priceCols.length > 1) {
        rows.add(ReceiptTableRow(priceCols));
      }
    }
  }

  // ==================== TOTALS SECTION (Boxed Style) ====================

  void _buildTotalsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    ui.Image? sarSymbol,
  ) {
    rows.add(SpacingRow(_itemGap));

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    // Paper size aware scaling
    final bool is58mm = params.is58mm;

    double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(params.formattedTotal) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double taxAmount = params.totalTax;

    // Calculate subtotal
    double subtotal = total + discountAmountValue;

    // Get tax percentage
    double taxPercentage = 15.0;
    if (subtotal > 0 && taxAmount > 0) {
      taxPercentage = (taxAmount / (subtotal - taxAmount)) * 100;
    }
    String taxPercentageStr = taxPercentage.toStringAsFixed(1);

    // Labels
    final subtotalLabelBase = _getLabel(displayConfig, 'showMRPTotal', 
        null, isEnglish ? "SUBTOTAL" : "المجموع");
    final subtotalLabel = is58mm ? subtotalLabelBase : "$subtotalLabelBase ${isEnglish ? '' : 'المجموع'}".trim();
    
    final discountLabelBase = _getLabel(displayConfig, 'showDiscount', 
        null, isEnglish ? "DISCOUNTS" : "الخصم");
    final discountLabel = is58mm ? discountLabelBase : "$discountLabelBase ${isEnglish ? '' : 'الخصم'}".trim();
    
    final taxLabelBase = _getLabel(displayConfig, 'showTax', 
        resolvedLabels?.tax, "VAT");
    final vatLabel = is58mm 
        ? "$taxPercentageStr% $taxLabelBase" 
        : "$taxPercentageStr% $taxLabelBase $taxPercentageStr%     ${isEnglish ? '' : 'الضريبة'}".trim();
    
    final grandTotalLabelBase = _getLabel(displayConfig, 'showNetAmount', 
        resolvedLabels?.total, isEnglish ? "GRAND TOTAL" : "المبلغ الاجمالي");
    final grandTotalLabel = is58mm ? grandTotalLabelBase : "${grandTotalLabelBase} ${isEnglish ? '' : 'المبلغ الاجمالي'}".trim();

    final cashLabel = _getLabel(displayConfig, 'showCash', 
        null, isEnglish ? "Cash" : "نقدي");
    final changeLabel = _getLabel(displayConfig, 'showChange', 
        null, isEnglish ? "CHANGE" : "متبقي");
    final changeLabelFull = is58mm ? changeLabel : "$changeLabel ${isEnglish ? '' : 'متبقي'}".trim();

    // Visibility settings
    final showMRPTotal = displayConfig?['showMRPTotal']?.visible ?? true;
    final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
    final showTax = displayConfig?['showTax']?.visible ?? true;
    final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

    // Prepare boxed items
    List<BoxedLineItem> boxedItems = [];

    // 1. Subtotal
    if (showMRPTotal) {
      boxedItems.add(BoxedLineItem(
        label: subtotalLabel,
        value: subtotal.toStringAsFixed(2),
      ));
    }

    // 2. Discounts
    if (showDiscount && discountAmountValue > 0) {
      boxedItems.add(BoxedLineItem(
        label: discountLabel,
        value: discountAmountValue.toStringAsFixed(2),
      ));
    }

    // 3. VAT
    if (showTax) {
      boxedItems.add(BoxedLineItem(
        label: vatLabel,
        value: taxAmount.toStringAsFixed(2),
      ));
    }

    // 4. Grand Total (Bold)
    if (showNetAmount) {
      boxedItems.add(BoxedLineItem(
        label: grandTotalLabel,
        value: total.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
      ));
    }

    // 5. Payment details (Separator + Cash + Change)
    if (params.paidAmount != null) {
      boxedItems.add(BoxedLineItem(isSeparator: true));

      // Payment Method (Value | Label)
      boxedItems.add(BoxedLineItem(
        label: cashLabel,
        value: params.paidAmount!.toStringAsFixed(2),
      ));

      // Change
      double change = params.paidAmount! - total;
      if (change >= 0) {
        boxedItems.add(BoxedLineItem(
          label: changeLabelFull,
          value: change.toStringAsFixed(2),
          isBold: true,
        ));
      }
    }

    // Add the boxed row
    rows.add(BoxedTotalsRow(items: boxedItems));

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(_itemGap));
      final amountInWords =
          '${AmountHelper().convertNumberToWords(total)} Only.';
      rows.add(TextRow(amountInWords, scale: is58mm ? 0.7 : 0.85, isBold: true));
    }

    // You Saved
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      final savedLabel = _getLabel(displayConfig, 'showSaved', null,
          isEnglish ? "You Saved:" : "لقد وفرت:");
      rows.add(SpacingRow(5));
      rows.add(TextRow(
        "$savedLabel ${saved.toStringAsFixed(2)}",
        isBold: true,
        scale: 0.9,
      ));
    }

    rows.add(SpacingRow(_itemGap));
    
    // Customer Balance
    _buildCustomerBalance(rows, params, displayConfig, isEnglish);

    rows.add(SpacingRow(_sectionGap));
  }


  void _buildCustomerBalance(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    // Check if customer balance section should be visible
    if (displayConfig?['showCustomerBalance']?.visible == false) {
      return;
    }

    // Hide balance information for default/walk-in customers
    if (params.isDefaultCustomer) {
      return;
    }
    
    if (params.customerOldBalance == null &&
        params.customerCurrentBalance == null) {
      return;
    }

    // Paper size aware scaling
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    // Get labels from displayConfig - shorter for 58mm
    final prevBalanceLabelBase = _getLabel(displayConfig, 'showCustomerPrevBalance',
        null, isEnglish ? "Previous Balance" : "الرصيد السابق");
    final prevBalanceLabel = is58mm 
        ? (isEnglish ? "Prev Bal" : "السابق") 
        : prevBalanceLabelBase;
    
    final paidAmountLabelBase = _getLabel(displayConfig, 'showCustomerPaidAmount',
        null, isEnglish ? "Paid Amount" : "المبلغ المدفوع");
    final paidAmountLabel = is58mm 
        ? (isEnglish ? "Paid" : "المدفوع") 
        : paidAmountLabelBase;
    
    final currentBalanceLabelBase = _getLabel(
        displayConfig, 'showCustomerCurrentBalance',
        null, isEnglish ? "Current Balance" : "الرصيد الحالي");
    final currentBalanceLabel = is58mm 
        ? (isEnglish ? "Cur Bal" : "الحالي") 
        : currentBalanceLabelBase;

    // Previous Balance
    if (displayConfig?['showCustomerPrevBalance']?.visible != false &&
        params.customerOldBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(prevBalanceLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.left, scale: scale),
      ]));
    }

    // Paid Amount (this transaction)
    if (displayConfig?['showCustomerPaidAmount']?.visible != false &&
        params.paidAmount != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(paidAmountLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.left, scale: scale),
      ]));
    }

    // Current Balance
    if (displayConfig?['showCustomerCurrentBalance']?.visible != false &&
        params.customerCurrentBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(currentBalanceLabel,
            weight: 0.6, align: TextAlign.right, isBold: true, scale: scale),
        ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.left, isBold: true, scale: scale),
      ]));
    }
  }

  // ==================== FOOTER SECTION ====================

  void _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    BuildContext context,
  ) {
    rows.add(SpacingRow(_sectionGap));

    // QR Code - Use ZATCA QR if credentials available, otherwise fallback to payment QR
    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';
      String qrMessage = '';

      // Check if ZATCA credentials are available for Saudi Arabia e-invoicing
      if (params.hasZatcaCredentials) {
        debugPrint('[PremiumLayout] ZATCA credentials found, generating ZATCA QR');
        
        // Generate ZATCA Phase 1 compliant QR code
        final zatcaHelper = ZatcaQrHelper();
        qrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate,
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );
        
        qrMessage = isEnglish 
            ? 'ZATCA E-Invoice QR' 
            : 'فاتورة الكترونية';
        
        debugPrint('[PremiumLayout] ZATCA QR generated: ${qrData.isNotEmpty}');
      } else {
        debugPrint('[PremiumLayout] No ZATCA credentials, using payment QR');
        
        // Fallback to payment gateway QR
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

        qrData = manualPaymentGateway.link;
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

        qrMessage = displayConfig?['showQRCode']?.value as String? ??
            (isEnglish ? 'Scan to Pay' : 'امسح للدفع');
      }

      // Display QR code if data is available
      if (qrData.isNotEmpty) {
        rows.add(TextRow(qrMessage, scale: 0.9));
        rows.add(SpacingRow(5));
        rows.add(QrRow(qrData, size: 220));
        
        // Show VAT number below QR for ZATCA receipts
        if (params.hasZatcaCredentials && params.zatcaVatNumber != null) {
          rows.add(SpacingRow(5));
          final vatLabel = isEnglish ? 'VAT No:' : 'الرقم الضريبي:';
          rows.add(TextRow('$vatLabel ${params.zatcaVatNumber}', scale: 0.8));
        }
      }
    }

    rows.add(SpacingRow(_headerGap));

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    // Date and Time - Clean format (with visibility check)
    if (displayConfig?['showDate']?.visible != false) {
      String formattedDate = params.isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
          : DateHelper.formatISODate(params.orderDate);
      String formattedTime = params.isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
          : DateHelper.formatISOTimeOnlyToIST(params.orderDate);

      final dateLabel = _getLabel(displayConfig, 'showDate', resolvedLabels?.date, "");
      if (dateLabel.isNotEmpty) {
        rows.add(TextRow("$dateLabel: $formattedDate  $formattedTime", scale: 0.85));
      } else {
        rows.add(TextRow("$formattedDate  $formattedTime", scale: 0.85));
      }
    }

    // Order Number (with visibility check)
    if (displayConfig?['showOrderNumber']?.visible != false) {
      rows.add(SpacingRow(3));
      rows.add(TextRow('#${params.orderNumber}', scale: 0.8));
    }

    rows.add(SpacingRow(_itemGap));

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      String? terms = displayConfig?['showTermsConditions']?.value as String?;
      if (terms == null || terms.trim().isEmpty) {
        terms = params.billDocumentConfig.terms;
      }
      if (terms != null && terms.trim().isNotEmpty) {
        rows.add(TextRow(terms.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message - Elegant
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final String defaultThankYou =
          isEnglish ? 'Thank You for Your Visit!' : 'شكراً لزيارتكم!';
      final message =
          (displayConfig?['showThankYouMessage']?.value as String?)
                      ?.isNotEmpty ==
                  true
              ? displayConfig!['showThankYouMessage']!.value as String
              : (params.billDocumentConfig.footer?.isNotEmpty == true
                  ? params.billDocumentConfig.footer!
                  : defaultThankYou);
      rows.add(TextRow(message, isBold: true, scale: 0.95));
    }

    rows.add(SpacingRow(_sectionGap));
  }

  // ==================== UTILITY METHODS ====================

  /// Get a display value with priority: displayConfig value > fallback > default
  String _getDisplayValue(
    dynamic displayConfigValue,
    dynamic fallbackValue,
    String defaultValue,
  ) {
    if (displayConfigValue != null && 
        displayConfigValue is String && 
        displayConfigValue.isNotEmpty) {
      return displayConfigValue;
    }
    if (fallbackValue != null && 
        fallbackValue is String && 
        fallbackValue.isNotEmpty) {
      return fallbackValue;
    }
    return defaultValue;
  }

  /// Get a label with priority: displayConfig value > resolvedLabel > default
  String _getLabel(
    Map<String, DisplayOption>? displayConfig,
    String key,
    String? resolvedLabel,
    String defaultLabel,
  ) {
    final configValue = displayConfig?[key]?.value as String?;
    if (configValue != null && configValue.isNotEmpty) {
      return configValue;
    }
    if (resolvedLabel != null && resolvedLabel.isNotEmpty) {
      return resolvedLabel;
    }
    return defaultLabel;
  }

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
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
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final fi = await codec.getNextFrame();
        return fi.image;
      }
    } catch (e) {
      debugPrint("[PremiumReceiptLayout] Error fetching image: $e");
    }
    return null;
  }

  /// Load an image from Flutter assets
  Future<ui.Image?> _loadAssetImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final fi = await codec.getNextFrame();
      return fi.image;
    } catch (e) {
      debugPrint("[PremiumReceiptLayout] Error loading asset image: $e");
    }
    return null;
  }
}

/// Thin solid line divider for Premium theme
class ThinDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      6;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y + 3), Offset(width, y + 3), paint);
  }
}

/// Dotted divider for emphasis sections
class DottedDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      6;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    
    const double dashWidth = 4.0;
    const double dashSpace = 3.0;
    double currentX = 0;
    
    while (currentX < width) {
      canvas.drawLine(
        Offset(currentX, y + 3),
        Offset(currentX + dashWidth, y + 3),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }
}

/// Row that displays totals in a rounded box
class BoxedTotalsRow extends ReceiptRow {
  final List<BoxedLineItem> items;
  final double cornerRadius;
  final double padding;

  BoxedTotalsRow({
    required this.items,
    this.cornerRadius = 12.0,
    this.padding = 15.0,
  });

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    double h = padding * 2;
    for (var item in items) {
      if (item.isSeparator) {
        h += 12; // Space for separator
      } else {
        h += (fontSize * item.scale) + 8; // Line height + spacing
      }
    }
    return h;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    // Draw rounded border
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, y, width - 2, calculateHeight(width, fontSize, textDirection) - 2),
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(rect, paint);

    double currentY = y + padding;

    for (var item in items) {
      if (item.isSeparator) {
        // Draw dashed separator
        final sepPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1;
        
        const double dashWidth = 4.0;
        const double dashSpace = 3.0;
        double currentX = padding;
        double endX = width - padding;
        
        while (currentX < endX) {
          canvas.drawLine(
            Offset(currentX, currentY + 6),
            Offset(currentX + dashWidth, currentY + 6),
            sepPaint,
          );
          currentX += dashWidth + dashSpace;
        }
        currentY += 12;
      } else {
        final itemFontSize = fontSize * item.scale;
        
        // Value on Left
        final valuePainter = TextPainter(
          text: TextSpan(
            text: item.value,
            style: TextStyle(
              color: Colors.black,
              fontSize: itemFontSize,
              fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: ArabicPrinterHelper.fontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: width * 0.45);
        
        valuePainter.paint(canvas, Offset(padding, currentY));

        // Label on Right
        final labelPainter = TextPainter(
          text: TextSpan(
            text: item.label,
            style: TextStyle(
              color: Colors.black,
              fontSize: itemFontSize,
              fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: ArabicPrinterHelper.fontFamily,
            ),
          ),
          textDirection: textDirection,
          textAlign: TextAlign.right,
        )..layout(maxWidth: width * 0.45);
        
        labelPainter.paint(canvas, Offset(width - padding - labelPainter.width, currentY));
        
        currentY += itemFontSize + 8;
      }
    }
  }
}

class BoxedLineItem {
  final String label;
  final String value;
  final bool isBold;
  final double scale;
  final bool isSeparator;

  BoxedLineItem({
    this.label = '',
    this.value = '',
    this.isBold = false,
    this.scale = 1.0,
    this.isSeparator = false,
  });
}
