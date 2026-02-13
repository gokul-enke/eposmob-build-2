import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
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
import '../thermal/debug_image_saver.dart';

/// Classic receipt layout - the original/default design.
///
/// This layout maintains the current receipt design with:
/// - Centered header with logo, store name, description
/// - Invoice information below header
/// - Customer details section
/// - Items table with configurable columns
/// - Totals section (supports bilingual for Arabic)
/// - QR code for payment
/// - Barcode and footer
class ClassicReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  @override
  String get layoutId => 'classic';

  @override
  String get displayName => 'Classic';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== CLASSIC LAYOUT: IMAGE-BASED THERMAL PRINTING ====");

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
      final textDirection = isEnglish ? TextDirection.ltr : TextDirection.rtl;
      debugPrint(
          "Language: ${isEnglish ? 'English' : 'Arabic'} ($textDirection)");

      // Setup print parameters
      final double printWidth = params.printWidth;
      final double baseFontSize = params.baseFontSize;

      // Build receipt rows
      List<ReceiptRow> part1Rows = [];
      List<ReceiptRow> part2Rows = [];

      // Add Logo at the top if enabled
      if (billDocumentConfig.showLogo == 1) {
        debugPrint("[LOGO_DEBUG] showLogo == 1, attempting to load logo");
        try {
          ui.Image? logo;
          if (billDocumentConfig.logo != null &&
              billDocumentConfig.logo.toString().isNotEmpty) {
            logo =
                await _fetchNetworkUiImage(billDocumentConfig.logo.toString());
          }

          if (logo != null) {
            debugPrint(
                "[LOGO_DEBUG] Logo loaded successfully: ${logo.width}x${logo.height}");
            part1Rows.add(ImageRow(logo, width: printWidth * 0.8));
            part1Rows.add(SpacingRow(10));
          }
        } catch (e) {
          debugPrint("[LOGO_DEBUG] Error loading logo: $e");
        }
      }

      // ========== HEADER SECTION ==========
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish);

      // ========== CART ITEMS SECTION ==========
      _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);

      // ========== TOTALS SECTION ==========
      _buildTotalsSection(
          part1Rows, params, displayConfig, isEnglish, appSettings);

      // ========== FOOTER SECTION (Part 2) ==========
      _buildFooterSection(part2Rows, params, displayConfig, isEnglish, context);

      // ========== RENDER IMAGES ==========
      debugPrint("Rendering receipt images...");

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

      // ========== DEBUG: SAVE IMAGES TO DESKTOP ==========
      if (kDebugMode) {
        try {
          await PrintDebugImageSaver.saveReceiptImages(
            imagePart1,
            imagePart2,
            params.selectedPaperSize,
          );
        } catch (e) {
          debugPrint("Error saving debug images: $e");
        }
      }
      // ===================================================

      // ========== GENERATE ESC/POS BYTES ==========
      debugPrint("Generating ESC/POS bytes...");
      final profile = await CapabilityProfile.load();
      final generator =
          Generator(params.is58mm ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      // Print images
      bytes += generator.image(imagePart1);
      bytes += generator.image(imagePart2);

      // Print native barcode
      String cleanOrderNumber = params.orderNumber
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
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

      // Feed and Cut
      bytes += generator.feed(2);
      bytes += generator.drawer();
      bytes += generator.cut();

      // ========== SEND TO PRINTER ==========
      debugPrint("Sending ${bytes.length} bytes to printer...");
      final printerManager = PrinterManager.instance;
      await printerManager.send(
          type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully.");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        // Note: Navigation is now handled by the caller
        // PrintPage has its own back button, auto-print doesn't need navigation
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR in Classic Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: "Error printing: ${e.toString()}");
      }
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("===== END CLASSIC LAYOUT PRINTING =====");
    }
  }

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) async {
    // For now, return an empty document - PDF logic will be migrated separately
    // The StandardPrinter will continue to handle PDF generation
    // until we fully migrate the PDF logic here
    debugPrint(
        "[ClassicReceiptLayout] buildPdf called - delegating to StandardPrinter");
    return pw.Document();
  }

  // ==================== PRIVATE HELPER METHODS ====================

  void _buildHeaderSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    dynamic appSettings,
  ) {
    final billDocumentConfig = params.billDocumentConfig;
    final isEnglish = params.isEnglish;

    // Store Name - use displayConfig value, then billDocumentConfig.header, then default
    if (displayConfig?['showStoreName']?.visible == true) {
      final storeName = _getDisplayValue(
        displayConfig?['showStoreName']?.value,
        billDocumentConfig.header,
        'STORE NAME',
      );

      double storeNameScale = 2.0;
      if (storeName.length > 20) {
        storeNameScale = 1.4;
      } else if (storeName.length > 14) {
        storeNameScale = 1.7;
      }

      rows.add(TextRow(storeName.isNotEmpty ? storeName : 'STORE NAME',
          isBold: true, scale: storeNameScale));
    }

    // Description/Subheader - use displayConfig value, then billDocumentConfig.subheader
    if (displayConfig?['showDescription']?.visible == true) {
      final description = _getDisplayValue(
        displayConfig?['showDescription']?.value,
        billDocumentConfig.subheader,
        '',
      );
      if (description.isNotEmpty) {
        rows.add(TextRow(description, isBold: true, scale: 1.1));
      }
    }

    // Store Address
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final storeAddress = displayConfig?['showStoreAddress']?.value as String?;
      if (storeAddress != null && storeAddress.isNotEmpty) {
        rows.add(TextRow(storeAddress, scale: 0.9, isBold: true));
      }
    }

    // FSSAI Info
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
      if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.9, isBold: true));
      }
    }

    // Extra Heading 1 (e.g., CR NO)
    if (displayConfig?['showExtraHeading1']?.visible == true) {
      final extraHeading1 = displayConfig?['showExtraHeading1']?.value as String?;
      if (extraHeading1 != null && extraHeading1.isNotEmpty) {
        rows.add(TextRow(extraHeading1, scale: 0.9, isBold: true));
      }
    }

    // Extra Heading 2 (e.g., VAT NO)
    if (displayConfig?['showExtraHeading2']?.visible == true) {
      final extraHeading2 = displayConfig?['showExtraHeading2']?.value as String?;
      if (extraHeading2 != null && extraHeading2.isNotEmpty) {
        rows.add(TextRow(extraHeading2, scale: 0.9, isBold: true));
      }
    }

    // Telephone
    if (displayConfig?['showTel']?.visible == true) {
      final telephone = _getDisplayValue(
        displayConfig?['showTel']?.value,
        appSettings?.customerCarePhone,
        '',
      );
      if (telephone.isNotEmpty) {
        rows.add(TextRow(telephone, scale: 0.8, isBold: true));
      }
    }

    // Email
    if (displayConfig?['showEmail']?.visible == true) {
      final email = _getDisplayValue(
        displayConfig?['showEmail']?.value,
        appSettings?.customerCareEmail,
        '',
      );
      if (email.isNotEmpty) {
        rows.add(TextRow(email, scale: 0.8, isBold: true));
      }
    }

    rows.add(SpacingRow(10));

    // Invoice Title - use displayConfig value, then appSettings.printTitle, then default
    // Note: billDocumentConfig.header is the store name, NOT the invoice title
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle = _getDisplayValue(
        displayConfig?['showInvoiceTitle']?.value,
        appSettings?.printTitle,
        isEnglish ? 'INVOICE' : 'فاتورة',
      );
      rows.add(TextRow(invoiceTitle.isNotEmpty ? invoiceTitle : 'INVOICE',
          isBold: true, scale: 1.2));
    }

    // Invoice/Token Number - Render on same row when both are visible
    final bool showInvoiceNumber =
        displayConfig?['showInvoiceNumber']?.visible == true;
    final bool showTokenNumber =
        displayConfig?['showTokenNumber']?.visible == true &&
            params.tokenNumber != null &&
            params.tokenNumber!.isNotEmpty;

    String? invoiceNumberText;
    if (showInvoiceNumber) {
      // Extract first significant number sequence (strip leading zeros and non-numeric prefixes)
      // For "ORD-000430", this extracts "430"
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      // Use number_prefix from document configuration as the invoice prefix
      final String invoicePrefix =
          params.billDocumentConfig.numberPrefix ?? 'INV-';

      invoiceNumberText = '$invoicePrefix$strippedNumber';
    }

    String? tokenText;
    if (showTokenNumber) {
      final tokenPrefix =
          displayConfig?['showTokenNumber']?.value as String? ?? '';
      tokenText = tokenPrefix.isNotEmpty
          ? '$tokenPrefix${params.tokenNumber!}'
          : params.tokenNumber!;
    }

    if (invoiceNumberText != null && tokenText != null) {
      final invoiceAlign = isEnglish ? TextAlign.left : TextAlign.right;
      final tokenAlign = isEnglish ? TextAlign.right : TextAlign.left;
      final invoiceCol = ReceiptTableColumn(invoiceNumberText,
        weight: 0.58, align: invoiceAlign, isBold: true);
      final tokenCol = ReceiptTableColumn(tokenText,
        weight: 0.38, align: tokenAlign, isBold: true, scale: 1.1);
      final spacerCol =
        ReceiptTableColumn('', weight: 0.04, align: TextAlign.center);

      rows.add(ReceiptTableRow(isEnglish
        ? [invoiceCol, spacerCol, tokenCol]
        : [tokenCol, spacerCol, invoiceCol]));
    } else if (invoiceNumberText != null) {
      rows.add(TextRow(invoiceNumberText, isBold: true));
    } else if (tokenText != null) {
      rows.add(TextRow(tokenText, scale: 1.4, isBold: true));
    }

    rows.add(DividerRow());
  }

  void _buildCustomerSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    // Check if customer section should be shown at all
    final showCustomerSection =
        displayConfig?['showCustomerNameAndPhone']?.visible ?? true;
    if (!showCustomerSection) {
      return;
    }

    if (params.customerName == null && params.customerPhone == null) {
      return;
    }

    // Get customer section labels from displayConfig or use defaults
    final customerLabel = _getLabel(displayConfig, 'showCustomerName', null,
        isEnglish ? "Customer:" : "العميل:");
    final phoneLabel = _getLabel(displayConfig, 'showCustomerPhone', null,
        isEnglish ? "Phone:" : "الهاتف:");
    final paymentLabel = _getLabel(
        displayConfig,
        displayConfig?.containsKey('showPaymentMethod') == true
            ? 'showPaymentMethod'
            : 'showPayment',
        null,
        isEnglish ? "Payment:" : "الدفع:");
    final addressLabel = _getLabel(displayConfig, 'showCustomerAddress', null,
        isEnglish ? "Address:" : "العنوان:");
    final commentLabel = _getLabel(
        displayConfig,
        displayConfig?.containsKey('showOrderComment') == true
            ? 'showOrderComment'
            : 'showComment',
        null,
        isEnglish ? "Comment:" : "تعليق:");

    if (isEnglish) {
      // English: Label: Value format
      if (params.customerName != null && params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (params.customerPhone != null && params.customerPhone!.isNotEmpty) {
        final bool maskPhone =
            displayConfig?['showCustomerPhoneMasked']?.visible ??
                displayConfig?['maskCustomerPhone']?.visible ??
                false;
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
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(phoneText, weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (params.paymentMethod != null && params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(addressLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerAddress!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (params.orderComment != null && params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
    } else {
      // Arabic: Label on right, Value on left (RTL reading flow)
      if (params.customerName != null && params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (params.customerPhone != null && params.customerPhone!.isNotEmpty) {
        final bool maskPhone =
            displayConfig?['showCustomerPhoneMasked']?.visible ??
                displayConfig?['maskCustomerPhone']?.visible ??
                false;
        final String displayedPhone = maskPhone
            ? StringHelper.maskStringShowLast4(params.customerPhone!)
            : params.customerPhone!;

        rows.add(ReceiptTableRow([
          ReceiptTableColumn(displayedPhone,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(phoneLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (params.paymentMethod != null && params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (params.orderComment != null && params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(TextRow(params.customerAddress!, scale: 0.9));
      }
      rows.add(DividerRow());
    }
  }

  void _buildCartItemsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    // Extract labels with fallbacks
    // Priority: displayConfig.value > resolvedLabels > default
    final String particularsLabel = _getLabel(displayConfig, 'showParticulars',
        resolvedLabels?.particulars, isEnglish ? "Item" : "الصنف");
    final String mrpLabel =
        _getLabel(displayConfig, 'showMRP', resolvedLabels?.mrp, "MRP");
    final String qtyLabel = _getLabel(displayConfig, 'showQty',
        resolvedLabels?.qty, isEnglish ? "Qty" : "الكمية");
    final String rateLabel = _getLabel(displayConfig, 'showRate',
        resolvedLabels?.rate, isEnglish ? "Rate" : "السعر");
    final String totalLabel = _getLabel(displayConfig, 'showTotal',
        resolvedLabels?.total, isEnglish ? "Total" : "الإجمالي");
    // Use showTaxHeader for table header, with fallback to resolvedLabels.tax
    final String taxHeaderLabel = _getLabel(displayConfig, 'showTaxHeader',
        resolvedLabels?.tax, isEnglish ? "Tax" : "الضريبة");
    final String slLabel = _getLabel(displayConfig, 'showSLNumber',
        resolvedLabels?.slNumber, isEnglish ? "SL#" : "#");

    // Build table header
    _buildTableHeader(rows, displayConfig, isEnglish, particularsLabel,
        mrpLabel, qtyLabel, rateLabel, totalLabel, taxHeaderLabel, slLabel);

    // Build cart items
    for (var i = 0; i < params.cartItems.length; i++) {
      _buildCartItemRow(rows, params.cartItems[i], i, params.isFromLocalStorage,
          displayConfig, isEnglish);
    }

    rows.add(SpacingRow(5));
    rows.add(DividerRow());
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
            weight:
                displayConfig?['showSLNumber']?.visible == true ? 0.17 : 0.25,
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
      // Use showTaxHeader for table header visibility
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
      // Use showTaxHeader for table header visibility
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
            weight:
                displayConfig?['showSLNumber']?.visible == true ? 0.17 : 0.25,
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
      rows.add(DividerRow());
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
      unitPrice = (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      totalPrice =
          (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      itemTaxAmount =
          (double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
    } else {
      // Handle bilingual names for Arabic template
      if (!isEnglish &&
          item.names != null &&
          item.names!.ar != null &&
          item.names!.ar!.isNotEmpty) {
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
      unitPrice = (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      totalPrice = (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      itemTaxAmount =
          (double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
    }

    String slNumber = (index + 1).toString();

    if (isEnglish) {
      // Product name row (English - single name or bilingual fallback)
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
      // Use showTaxHeader for item tax column (same as table header)
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
        String englishText = '';
        if (productNameArabic.isNotEmpty) {
          // Bilingual: Arabic on line 1, English on line 2
          if (displayConfig?['showSLNumber']?.visible == true) {
            itemText = '$slNumber. $productNameArabic';
          } else {
            itemText = productNameArabic;
          }
          englishText = productName;
        } else {
          // Fallback to single name (English or Arabic)
          if (displayConfig?['showSLNumber']?.visible == true) {
            itemText = '$slNumber. $productName';
          } else {
            itemText = productName;
          }
        }
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
        ]));

        // Add English name on second line when bilingual
        if (englishText.isNotEmpty) {
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(englishText,
                weight: 1.0, align: TextAlign.right),
          ]));
        }
      }
      // Price details row (RTL order)
      List<ReceiptTableColumn> priceCols = [];
      if (displayConfig?['showTotal']?.visible == true) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: 0.18, align: TextAlign.right));
      }
      // Use showTaxHeader for item tax column (same as table header)
      if (displayConfig?['showTaxHeader']?.visible == true) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: 0.15, align: TextAlign.right));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: 0.15, align: TextAlign.right));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceCols.add(
            ReceiptTableColumn(quantity, weight: 0.12, align: TextAlign.right));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        priceCols
            .add(ReceiptTableColumn(mrp, weight: 0.15, align: TextAlign.right));
      }
      priceCols.add(ReceiptTableColumn("", weight: 0.25));
      if (priceCols.length > 1) {
        rows.add(ReceiptTableRow(priceCols));
      }
    }
  }

  void _buildTotalsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    dynamic appSettings,
  ) {
    // Get currency from appSettings
    final String currency = appSettings?.currency ?? 'INR';
    final bool isDualLanguage = params.billDocumentConfig.language == 'ar';

    double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(params.formattedTotal) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double totalMrp = saved + total;
    double totalQuantity = params.totalQuantity;
    double taxAmount = params.totalTax;

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final qtyLabel = _getLabel(displayConfig, 'showQty', resolvedLabels?.qty,
        isEnglish ? "Qty" : "الكمية");

    if (isEnglish) {
      // Summary rows (English)
      final itemsCountLabel =
          _getLabel(displayConfig, 'showItemsCount', null, "Items:");
      final discountLabel =
          _getLabel(displayConfig, 'showDiscount', null, "Discount:");
      final mrpTotalLabel =
          _getLabel(displayConfig, 'showMRPTotal', null, "Total MRP:");
      final netAmountLabel =
          _getLabel(displayConfig, 'showNetAmount', null, "Net Total:");
      final taxLabel =
          _getLabel(displayConfig, 'showTax', resolvedLabels?.tax, "Tax :");

      // Check visibility settings
      final showItemsCount = displayConfig?['showItemsCount']?.visible ?? true;
      final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
      final showQty = displayConfig?['showQty']?.visible ?? true;
      final showTax = displayConfig?['showTax']?.visible ?? true;
      final showMRPTotal = displayConfig?['showMRPTotal']?.visible ?? true;
      final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

      // Items count and Discount row
      if (showItemsCount || showDiscount) {
        List<ReceiptTableColumn> summaryRow = [];

        if (showItemsCount) {
          summaryRow.add(ReceiptTableColumn(itemsCountLabel,
              weight: 0.25, align: TextAlign.left));
          summaryRow.add(ReceiptTableColumn(params.cartItems.length.toString(),
              weight: 0.25, align: TextAlign.left));
        } else {
          summaryRow.add(ReceiptTableColumn("", weight: 0.50));
        }

        summaryRow.add(ReceiptTableColumn(" ", weight: 0.05));

        if (showDiscount) {
          summaryRow.add(ReceiptTableColumn(discountLabel,
              weight: 0.25, align: TextAlign.right));
          summaryRow.add(ReceiptTableColumn(
              discountAmountValue.toStringAsFixed(2),
              weight: 0.20,
              align: TextAlign.right));
        } else {
          summaryRow.add(ReceiptTableColumn("", weight: 0.45));
        }

        rows.add(ReceiptTableRow(summaryRow));
      }

      // Total Qty and Tax row
      if (showQty || showTax) {
        final totalQtyLabel = "$qtyLabel Total:";
        List<ReceiptTableColumn> qtyTaxRow = [];

        if (showQty) {
          qtyTaxRow.add(ReceiptTableColumn(totalQtyLabel,
              weight: 0.25, align: TextAlign.left));
          qtyTaxRow.add(ReceiptTableColumn(
              totalQuantity % 1 == 0
                  ? totalQuantity.toInt().toString()
                  : totalQuantity.toStringAsFixed(2),
              weight: 0.25,
              align: TextAlign.left));
        } else {
          qtyTaxRow.add(ReceiptTableColumn("", weight: 0.50));
        }

        qtyTaxRow.add(ReceiptTableColumn(" ", weight: 0.05));

        if (showTax) {
          qtyTaxRow.add(ReceiptTableColumn(taxLabel,
              weight: 0.25, align: TextAlign.right));
          qtyTaxRow.add(ReceiptTableColumn(taxAmount.toStringAsFixed(2),
              weight: 0.20, align: TextAlign.right));
        } else {
          qtyTaxRow.add(ReceiptTableColumn("", weight: 0.45));
        }

        rows.add(ReceiptTableRow(qtyTaxRow));
      }

      if (showMRPTotal) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(mrpTotalLabel,
              weight: 0.25, align: TextAlign.left),
          ReceiptTableColumn(totalMrp.toStringAsFixed(2),
              weight: 0.25, align: TextAlign.left),
          ReceiptTableColumn(" ", weight: 0.50),
        ]));
      }

      rows.add(SpacingRow(5));

      // Net Total
      if (showNetAmount) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(netAmountLabel,
              weight: 0.5, align: TextAlign.center, isBold: true),
          ReceiptTableColumn(total.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.center, isBold: true),
        ]));
      }
    } else {
      // Arabic/Bilingual totals
      double totalDiscountAmount = discountAmountValue;

      // Calculate subtotal
      double subtotal;
      if (params.netExcTax != null) {
        subtotal =
            double.tryParse(params.netExcTax!) ?? (total + totalDiscountAmount);
      } else {
        subtotal = total + totalDiscountAmount;
      }

      final subtotalLabel =
          _getLabel(displayConfig, 'showMRPTotal', null, "SUBTOTAL المجموع");
      final discountLabel =
          _getLabel(displayConfig, 'showDiscount', null, "DISCOUNTS الخصم");
      final taxLabelArabic = _getLabel(
          displayConfig, 'showTax', resolvedLabels?.tax, "TAX الضريبة");
      final netTotalLabel = _getLabel(
          displayConfig, 'showNetAmount', null, "GRAND TOTAL المبلغ الاجمالي");

      // Check visibility settings
      final showMRPTotal = displayConfig?['showMRPTotal']?.visible ?? true;
      final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
      final showTax = displayConfig?['showTax']?.visible ?? true;
      final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

      // Subtotal
      if (showMRPTotal) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(subtotal.toStringAsFixed(2),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn(subtotalLabel,
              weight: 0.65, align: TextAlign.right),
        ]));
      }

      // Discounts
      if (showDiscount && totalDiscountAmount > 0) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(totalDiscountAmount.toStringAsFixed(2),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn(discountLabel,
              weight: 0.65, align: TextAlign.right),
        ]));
      }

      // Tax
      if (showTax) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(taxAmount.toStringAsFixed(2),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn(taxLabelArabic,
              weight: 0.65, align: TextAlign.right),
        ]));
      }

      rows.add(SpacingRow(5));

      // Net Total
      if (showNetAmount) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(total.toStringAsFixed(2),
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(netTotalLabel,
              weight: 0.65, align: TextAlign.right, isBold: true),
        ]));
      }
    }

    // Payment Breakthrough (Multi-payment)
    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible ?? true;
    if (params.paidAmount != null && showPaymentBreaked) {
      if (params.paymentBreakdown != null &&
          params.paymentBreakdown!.isNotEmpty) {
        rows.add(SpacingRow(5));
        params.paymentBreakdown!.forEach((method, amount) {
          double amt = double.tryParse(amount.toString()) ?? 0.0;
          if (amt > 0) {
            String label = method;
            if (method == 'CASH') {
              label = isEnglish ? "Cash" : "نقدي";
            } else if (method == 'CARD') {
              label = isEnglish ? "Card" : "بطاقة";
            }

            if (isEnglish) {
              rows.add(ReceiptTableRow([
                ReceiptTableColumn(label, weight: 0.5, align: TextAlign.left),
                ReceiptTableColumn(amt.toStringAsFixed(2),
                    weight: 0.5, align: TextAlign.right),
              ]));
            } else {
              rows.add(ReceiptTableRow([
                ReceiptTableColumn(amt.toStringAsFixed(2),
                    weight: 0.5, align: TextAlign.left),
                ReceiptTableColumn(label, weight: 0.5, align: TextAlign.right),
              ]));
            }
          }
        });
      }
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

    rows.add(DividerRow());

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(5));

      String amountInWords;

      if (isDualLanguage) {
        final arabicText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'ar');
        final englishText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'en');

        amountInWords = '$arabicText فقط.\n$englishText Only.';
      } else {
        final language = params.billDocumentConfig.language ?? 'en';
        final amountText = AmountHelper().convertNumberToWords(total,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';
        amountInWords = '$amountText$suffix';
      }

      rows.add(TextRow(amountInWords, scale: 0.9, isBold: true));
      rows.add(DividerRow());
    }

    // Customer Balance
    _buildCustomerBalance(rows, params, displayConfig, isEnglish);
  }

  void _buildCustomerBalance(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    // Check if customer balance section should be shown at all
    final showCustomerBalance =
        displayConfig?['showCustomerBalance']?.visible ?? true;
    if (!showCustomerBalance) {
      return;
    }

    // Hide balance information for default/walk-in customers
    if (params.isDefaultCustomer) {
      return;
    }

    if (params.customerOldBalance == null &&
        params.customerCurrentBalance == null &&
        params.paidAmount == null) {
      return;
    }

    // Check visibility for each balance field
    final showPrevBalance =
        displayConfig?['showCustomerPrevBalance']?.visible ?? true;
    final showPaidAmount =
        displayConfig?['showCustomerPaidAmount']?.visible ?? true;
    final showCurrentBalance =
        displayConfig?['showCustomerCurrentBalance']?.visible ?? true;

    // Get labels from displayConfig
    final prevBalanceLabel = _getLabel(displayConfig, 'showCustomerPrevBalance',
        null, isEnglish ? "Old Balanceance:" : "الرصيد السابق:");
    final paidAmountLabel = _getLabel(displayConfig, 'showCustomerPaidAmount',
        null, isEnglish ? "Paid Amount:" : "المدفوع:");
    final currentBalanceLabel = _getLabel(
        displayConfig,
        'showCustomerCurrentBalance',
        null,
        isEnglish ? "Current Balance:" : "الرصيد الحالي:");

    bool hasVisibleRows = false;

    if (isEnglish) {
      if (showPrevBalance && params.customerOldBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(prevBalanceLabel,
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showPaidAmount && params.paidAmount != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paidAmountLabel,
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showCurrentBalance && params.customerCurrentBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(currentBalanceLabel,
              weight: 0.5, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.right, isBold: true),
        ]));
      }
    } else {
      // Arabic balance display
      if (showPrevBalance && params.customerOldBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(prevBalanceLabel,
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showPaidAmount && params.paidAmount != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(paidAmountLabel,
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showCurrentBalance && params.customerCurrentBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(currentBalanceLabel,
              weight: 0.5, align: TextAlign.right, isBold: true),
        ]));
      }
    }

    if (hasVisibleRows) {
      rows.add(SpacingRow(10));
    }
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    // For now, use image-based printing for all cases
    // Native ESC/POS text mode can be implemented later for faster printing
    await printThermal(params);
  }

  void _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    BuildContext context,
  ) {
    rows.add(SpacingRow(10));

    // QR Code - ZATCA QR takes priority if credentials are available
    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';
      String qrMessage = '';

      // Check if ZATCA credentials are available
      if (params.hasZatcaCredentials) {
        // Generate ZATCA Phase 1 compliant QR code
        final zatcaHelper = ZatcaQrHelper();
        final zatcaQrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate,
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );

        if (zatcaQrData.isNotEmpty) {
          qrData = zatcaQrData;
          qrMessage = displayConfig?['showQRCode']?.value as String? ??
              (isEnglish ? 'Tax Invoice QR' : 'رمز الفاتورة الضريبية');
        }
      }

      // Fallback to payment gateway QR if no ZATCA credentials
      if (qrData.isEmpty) {
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
        rows.add(TextRow(qrMessage, isBold: true, scale: 0.9));
        rows.add(QrRow(qrData, size: 220));

        // Show VAT number below QR for ZATCA receipts
        if (params.hasZatcaCredentials && params.zatcaVatNumber != null) {
          rows.add(SpacingRow(5));
          final vatLabel = isEnglish ? 'VAT No:' : 'الرقم الضريبي:';
          rows.add(TextRow('$vatLabel ${params.zatcaVatNumber}', scale: 0.8));
        }
      }
    }

    rows.add(SpacingRow(15));

    // Date and Time - check visibility
    final showDate = displayConfig?['showDate']?.visible ?? true;
    if (showDate) {
      String formattedDate = params.isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
          : DateHelper.formatISODate(params.orderDate);
      String formattedTime = params.isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
          : DateHelper.formatISOTimeOnlyToIST(params.orderDate);

      final resolvedLabels = params.billDocumentConfig.resolvedLabels;
      final dateLabel = _getLabel(displayConfig, 'showDate',
          resolvedLabels?.date, isEnglish ? "Date:" : "التاريخ:");

      if (isEnglish) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(dateLabel, weight: 0.4, align: TextAlign.left),
          ReceiptTableColumn("$formattedDate $formattedTime",
              weight: 0.6, align: TextAlign.right),
        ]));
      } else {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn("$formattedDate $formattedTime",
              weight: 0.6, align: TextAlign.left),
          ReceiptTableColumn(dateLabel, weight: 0.4, align: TextAlign.right),
        ]));
      }

      rows.add(SpacingRow(5));
    }

    // Invoice number - check visibility
    final showOrderNumber = displayConfig?['showOrderNumber']?.visible ?? true;
    if (showOrderNumber) {
      // Extract first significant number sequence (strip leading zeros and non-numeric prefixes)
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      // Use number_prefix from document configuration as the invoice prefix
      final String invoicePrefix = params.billDocumentConfig.numberPrefix ?? 'INV-';

      rows.add(TextRow('$invoicePrefix$strippedNumber', scale: 0.8));
      rows.add(SpacingRow(5));
    }

    // Order Number in Footer
    if (displayConfig?['showOrderNumberInFooter']?.visible == true) {
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      // Use number_prefix from document configuration as the invoice prefix
      final String invoicePrefix = params.billDocumentConfig.numberPrefix ?? 'INV-';

      rows.add(SpacingRow(5));
      rows.add(DividerRow());
      rows.add(SpacingRow(5));
      rows.add(TextRow('$invoicePrefix$strippedNumber',
          scale: 1.1, isBold: true));
    }

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      String? terms = displayConfig?['showTermsConditions']?.value as String?;
      if (terms == null || terms.trim().isEmpty) {
        terms = params.billDocumentConfig.terms;
      }
      if (terms != null && terms.trim().isNotEmpty) {
        rows.add(TextRow(terms.trim(), scale: 0.8));
      }
    }

    rows.add(SpacingRow(5));

    // Thank You Message
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final String defaultThankYou =
          isEnglish ? 'Thank You... Visit Again' : 'شكراً لزيارتكم!';
      final message =
          (displayConfig?['showThankYouMessage']?.value as String?)
                      ?.isNotEmpty ==
                  true
              ? displayConfig!['showThankYouMessage']!.value as String
              : (params.billDocumentConfig.footer?.isNotEmpty == true
                  ? params.billDocumentConfig.footer!
                  : defaultThankYou);
      rows.add(TextRow(message, isBold: true));
    }

    rows.add(SpacingRow(20));
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
      debugPrint("[ClassicReceiptLayout] Error fetching image: $e");
    }
    return null;
  }

}
