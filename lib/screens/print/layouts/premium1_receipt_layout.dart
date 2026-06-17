import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:convert';

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

import 'receipt_layout.dart';
import 'receipt_layout_params.dart';
import '../thermal/printer_utils.dart';
import '../thermal/debug_image_saver.dart';
import '../logo_loader.dart';

/// Premium receipt layout - Modern & Clean design.
///
/// This layout features:
/// - Generous whitespace between sections
/// - Thin solid line dividers
/// - Clean, centered header with balanced typography
/// - Bilingual support (English/Arabic) like the reference
/// - Streamlined totals section with clear hierarchy
/// - Minimal, elegant footer
class Premium1ReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Premium theme spacing constants
  static const double _sectionGap = 14.0;
  static const double _itemGap = 6.0;
  static const double _headerGap = 8.0;

  @override
  String get layoutId => 'premium1';

  @override
  String get displayName => 'Premium 1';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== PREMIUM 1 LAYOUT: THERMAL PRINTING ====");

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
        sarSymbol =
            await _loadAssetImage('assets/images/saudi_riyal_symbol.png');
        if (sarSymbol != null) {
          debugPrint(
              "[PREMIUM] SAR symbol loaded: ${sarSymbol.width}x${sarSymbol.height}");
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
            debugPrint("[PREMIUM] Logo loaded: ${logo.width}x${logo.height}");
            part1Rows.add(ImageRow(logo, width: printWidth * 0.6));
            part1Rows.add(SpacingRow(_headerGap));
          }
        } catch (e) {
          debugPrint("[PREMIUM] Error loading logo: $e");
        }
      }

      // ========== HEADER SECTION (Modern & Clean) ==========
      _buildHeaderSection(
          part1Rows, params, displayConfig, appSettings, isEnglish);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish);

      // ========== CART ITEMS SECTION ==========
      _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);

      // ========== TOTALS SECTION (Bilingual Style) ==========
      _buildTotalsSection(
          part1Rows, params, displayConfig, isEnglish, sarSymbol, appSettings);

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

      bytes += generator.image(imagePart1);
      bytes += generator.image(imagePart2);

      // Native barcode
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
    debugPrint(
        "[PremiumReceiptLayout] buildPdf - delegating to StandardPrinter");
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
    bool isEnglish,
  ) {
    final billDocumentConfig = params.billDocumentConfig;

    final documentHeader = (billDocumentConfig.header ?? '').trim();
    final documentSubheader = (billDocumentConfig.subheader ?? '').trim();

    if (documentHeader.isNotEmpty) {
      rows.add(TextRow(documentHeader,
          isBold: true, scale: 1.1, verticalPadding: 3, verticalOffset: 1));
    }

    if (documentSubheader.isNotEmpty) {
      rows.add(TextRow(documentSubheader,
          isBold: true, scale: 0.95, verticalPadding: 2, verticalOffset: 0));
    }

    // Store Name - Large, centered, clean
    if (displayConfig?['showStoreName']?.visible == true) {
      final _configStoreName = displayConfig?['showStoreName']?.value as String?;
      final storeName = (_configStoreName != null && _configStoreName.isNotEmpty)
          ? _configStoreName
          : (params.storeName?.isNotEmpty == true ? params.storeName! : 'STORE NAME');

      // Dynamic scaling based on name length
      double storeNameScale = 1.6;
      if (storeName.length > 20) {
        storeNameScale = 1.3;
      } else if (storeName.length > 14) {
        storeNameScale = 1.5;
      }

      rows.add(TextRow(storeName.trim().toUpperCase(),
          isBold: true,
          scale: storeNameScale,
          verticalPadding: 4,
          verticalOffset: 1));
    }

    // Description/Subheader - Arabic subtitle style
    if (displayConfig?['showDescription']?.visible == true) {
      final description =
          displayConfig?['showDescription']?.value as String? ?? '';
      if (description.isNotEmpty) {
        rows.add(SpacingRow(2));
        rows.add(TextRow(description.trim(),
            scale: 1.0, isBold: true, verticalPadding: 4, verticalOffset: 1));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final storeAddress = _getDisplayValue(
        params.storeLocation,
        displayConfig?['showStoreAddress']?.value,
        '',
      );
      if (storeAddress.isNotEmpty) {
        rows.add(TextRow(storeAddress, scale: 0.85, isBold: true));
      }
    }

    // Invoice Title (Moved above Tax/Fssai Info)
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle = _getDisplayValue(
        displayConfig?['showInvoiceTitle']?.value,
        appSettings?.printTitle,
        'INVOICE',
      );
      rows.add(SpacingRow(5));
      rows.add(TextRow(invoiceTitle.toUpperCase(), isBold: true, scale: 1.1));
      rows.add(SpacingRow(2));
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
      if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.85, isBold: true));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final telephone = _getDisplayValue(
        params.storePhone,
        _getDisplayValue(
          displayConfig?['showTel']?.value,
          appSettings?.customerCarePhone,
          '',
        ),
        '',
      );
      if (telephone.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(telephone, scale: 1.3, isBold: true));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final email = _getDisplayValue(
        params.storeEmail,
        _getDisplayValue(
          displayConfig?['showEmail']?.value,
          appSettings?.customerCareEmail,
          '',
        ),
        '',
      );
      if (email.isNotEmpty) {
        rows.add(TextRow(email, scale: 0.9, isBold: true));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Invoice/Token Number - hide header invoice when footer invoice number is enabled
    final bool showFooterInvoice =
        displayConfig?['showOrderNumberInFooter']?.visible == true;
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
      final boxText = '$invoiceNumberText - $tokenText';
      rows.add(BoxedInvoiceTokenRow(text: boxText, textScale: 1.1));
    } else if (invoiceNumberText != null) {
      rows.add(BoxedInvoiceTokenRow(text: invoiceNumberText, textScale: 1.3));
    } else if (tokenText != null) {
      rows.add(BoxedInvoiceTokenRow(text: 'Token $tokenText', textScale: 1.1));
    }

    rows.add(SpacingRow(_sectionGap));
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

    // Paper size aware scaling
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;
    final String paymentConfigKey =
        displayConfig?.containsKey('showPaymentMethod') == true
            ? 'showPaymentMethod'
            : 'showPayment';
    final String commentConfigKey =
        displayConfig?.containsKey('showOrderComment') == true
            ? 'showOrderComment'
            : 'showComment';

    final bool showCustomerName =
        displayConfig?['showCustomerName']?.visible != false;
    final bool showCustomerPhone =
        displayConfig?['showCustomerPhone']?.visible != false;
    final bool showPayment = displayConfig?[paymentConfigKey]?.visible != false;
    final bool showCustomerAddress =
        displayConfig?['showCustomerAddress']?.visible != false;
    final bool showComment = displayConfig?[commentConfigKey]?.visible != false;
    final bool showDeliveryMethod =
        displayConfig?['showDeliveryMethod']?.visible != false;
    final bool showCustomerVatNumber =
        displayConfig?['showCustomerVatNumber']?.visible == true;
    final bool showCustomerCrNumber =
        displayConfig?['showCustomerCrNumber']?.visible == true;

    final bool hasVisibleCustomerData = (showCustomerName &&
            params.customerName != null &&
            params.customerName!.isNotEmpty) ||
        (showCustomerPhone &&
            params.customerPhone != null &&
            params.customerPhone!.isNotEmpty &&
            !(params.isDefaultCustomer && params.hideDefaultCustomerPhone)) ||
        (showPayment &&
            params.paymentMethod != null &&
            params.paymentMethod!.isNotEmpty) ||
        (showCustomerAddress &&
            params.customerAddress != null &&
            params.customerAddress!.isNotEmpty) ||
        (showComment &&
            params.orderComment != null &&
            params.orderComment!.isNotEmpty) ||
        (showDeliveryMethod &&
            params.deliveryMethod != null &&
            params.deliveryMethod!.isNotEmpty) ||
        (showCustomerVatNumber &&
            params.customerVatNumber != null &&
            params.customerVatNumber!.isNotEmpty) ||
        (showCustomerCrNumber &&
            params.customerCrNumber != null &&
            params.customerCrNumber!.isNotEmpty);

    if (!hasVisibleCustomerData) {
      return;
    }

    final customerLabel = _getLabel(displayConfig, 'showCustomerName', null,
        isEnglish ? "Customer:" : "العميل:");
    final phoneLabel = _getLabel(displayConfig, 'showCustomerPhone', null,
        isEnglish ? "Phone:" : "الهاتف:");
    final paymentLabel = _getLabel(displayConfig, paymentConfigKey, null,
        isEnglish ? "Payment:" : "الدفع:");
    final addressLabel = _getLabel(displayConfig, 'showCustomerAddress', null,
        isEnglish ? "Address:" : "العنوان:");
    final commentLabel = _getLabel(displayConfig, commentConfigKey, null,
        isEnglish ? "Comment:" : "تعليق:");
    final deliveryLabel = _getLabel(displayConfig, 'showDeliveryMethod', null,
        isEnglish ? "Delivery:" : "التوصيل:");
    final customerVatLabel = _getLabel(displayConfig, 'showCustomerVatNumber',
        null, isEnglish ? "Customer VAT:" : "الرقم الضريبي للعميل:");
    final customerCrLabel = _getLabel(displayConfig, 'showCustomerCrNumber',
        null, isEnglish ? "Customer CR:" : "السجل التجاري للعميل:");

    if (isEnglish) {
      // English: Label: Value format (left aligned for both)
      if (showCustomerName &&
          params.customerName != null &&
          params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (showCustomerPhone &&
          params.customerPhone != null &&
          params.customerPhone!.isNotEmpty &&
          !(params.isDefaultCustomer && params.hideDefaultCustomerPhone)) {
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
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(phoneText,
              weight: 0.65, align: TextAlign.left, isBold: true, scale: scale),
        ]));
      }

      if (showPayment &&
          params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(addressLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerAddress!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(deliveryLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.deliveryMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }
      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerVatLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerVatNumber!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerCrLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerCrNumber!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }
    } else {
      // Arabic: Label on right, Value on left (RTL reading flow)
      if (showCustomerName &&
          params.customerName != null &&
          params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (showCustomerPhone &&
          params.customerPhone != null &&
          params.customerPhone!.isNotEmpty &&
          !(params.isDefaultCustomer && params.hideDefaultCustomerPhone)) {
        final bool maskPhone =
            displayConfig?['showCustomerPhoneMasked']?.visible ??
                displayConfig?['maskCustomerPhone']?.visible ??
                false;
        final String displayedPhone = maskPhone
            ? StringHelper.maskStringShowLast4(params.customerPhone!)
            : params.customerPhone!;

        rows.add(ReceiptTableRow([
          ReceiptTableColumn(displayedPhone,
              weight: 0.65, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(phoneLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (showPayment &&
          params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.deliveryMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(deliveryLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerVatNumber!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(customerVatLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerCrNumber!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(customerCrLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: scale),
        ]));
      }

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
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
    final String particularsLabel = _getLabel(displayConfig, 'showParticulars',
        resolvedLabels?.particulars, isEnglish ? "Item" : "الصنف");
    final String mrpLabel =
        _getLabel(displayConfig, 'showMRP', resolvedLabels?.mrp, "MRP");
    final String qtyLabel = _getLabel(displayConfig, 'showQty',
        resolvedLabels?.qty, isEnglish ? "Qty" : "الكمية");
    final String rateLabel = _getLabel(displayConfig, 'showRate',
        resolvedLabels?.rate, isEnglish ? "Rate" : "السعر");
    final String rateExcTaxLabel = _getLabel(displayConfig, 'showRateExcTax',
        null, isEnglish ? "Rate Ex Tax" : "السعر بدون ضريبة");
    final String unitLabel = _getLabel(displayConfig, 'showUnit',
        resolvedLabels?.unitName, isEnglish ? "Unit" : "الوحدة");
    final String totalLabel = _getLabel(displayConfig, 'showTotal',
        resolvedLabels?.total, isEnglish ? "Total" : "الإجمالي");
    final String taxHeaderLabel = _getLabel(displayConfig, 'showTaxHeader',
        resolvedLabels?.tax, isEnglish ? "Tax" : "الضريبة");
    final String slLabel = _getLabel(displayConfig, 'showSLNumber',
        resolvedLabels?.slNumber, isEnglish ? "SL#" : "#");
    final tableWeights = _buildNormalizedTableWeights(displayConfig);
    final tableColumnCount = tableWeights.length;
    final tableScale = _getTableScale(tableColumnCount);
    final tableMinScale = _getTableMinScale(tableColumnCount);
    final tableCellPadding = _getTableCellPadding(tableColumnCount);

    // Build table header
    _buildTableHeader(
        rows,
        displayConfig,
        isEnglish,
        particularsLabel,
        mrpLabel,
        qtyLabel,
        rateLabel,
        rateExcTaxLabel,
        unitLabel,
        totalLabel,
        taxHeaderLabel,
        slLabel,
        tableWeights,
        tableScale,
        tableMinScale,
        tableCellPadding);

    // Build cart items
    for (var i = 0; i < params.cartItems.length; i++) {
      _buildCartItemRow(
          rows,
          params.cartItems[i],
          i,
          params.isFromLocalStorage,
          displayConfig,
          isEnglish,
          tableWeights,
          tableScale,
          tableMinScale,
          tableCellPadding);
      if (i < params.cartItems.length - 1) {
        rows.add(ThinDividerRow());
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Items Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      final itemsCountLabel = _getLabel(
        displayConfig,
        'showItemsCount',
        null,
        isEnglish ? "Items" : "أغراض",
      );
      final int itemCount = params.cartItems.length;
      rows.add(TextRow(
        "$itemsCountLabel: $itemCount",
        scale: 0.9,
        isBold: true,
      ));
      rows.add(SpacingRow(_itemGap));
    }

    if (displayConfig?['showQuantityCount']?.visible == true) {
      final quantityCountLabel = _getLabel(
        displayConfig,
        'showQuantityCount',
        null,
        isEnglish ? "Total Qty" : "إجمالي الكمية",
      );
      final totalQuantity = params.totalQuantity;
      rows.add(TextRow(
        "$quantityCountLabel: ${totalQuantity % 1 == 0 ? totalQuantity.toInt().toString() : totalQuantity.toStringAsFixed(2)}",
        scale: 0.9,
        isBold: true,
      ));
      rows.add(SpacingRow(_itemGap));
    }
  }

  void _buildTableHeader(
    List<ReceiptRow> rows,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    String particularsLabel,
    String mrpLabel,
    String qtyLabel,
    String rateLabel,
    String rateExcTaxLabel,
    String unitLabel,
    String totalLabel,
    String taxHeaderLabel,
    String slLabel,
    Map<String, double> tableWeights,
    double tableScale,
    double tableMinScale,
    double tableCellPadding,
  ) {
    List<ReceiptTableColumn> headerCols = [];

    if (isEnglish) {
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: tableWeights['showSLNumber'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: tableWeights['showParticulars'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        headerCols.add(ReceiptTableColumn(rateExcTaxLabel,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        headerCols.add(ReceiptTableColumn(unitLabel,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: tableWeights['showTotal'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
    } else {
      // Arabic header (RTL)
      if (displayConfig?['showTotal']?.visible == true) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: tableWeights['showTotal'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        headerCols.add(ReceiptTableColumn(rateExcTaxLabel,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        headerCols.add(ReceiptTableColumn(unitLabel,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: tableWeights['showParticulars'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: tableWeights['showSLNumber'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
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
    Map<String, double> tableWeights,
    double tableScale,
    double tableMinScale,
    double tableCellPadding,
  ) {
    String productName = '';
    String productNameArabic = ''; // Add Arabic name field
    String mrp = '';
    String quantity = '';
    String unitPrice = '';
    String unitPriceExTax = '';
    String unitName = '';
    String totalPrice = '';
    String itemTaxAmount = '';

    if (isFromLocalStorage || item is Map) {
      productName =
          (item['productName'] ?? item['product_name'] ?? '').toString();
      mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      quantity = (item['quantity'] ?? '0').toString();
      final double unitPriceValue = (double.tryParse(
              (item['unitPrice'] ?? item['unit_price'])?.toString() ?? '0') ??
          0.0);
      final double taxValue = (double.tryParse(
              (item['tax_amount'] ?? item['taxAmount'])?.toString() ?? '0') ??
          0.0);
      final double quantityValue =
          (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0);
      final double taxPerUnit =
          quantityValue > 0 ? (taxValue / quantityValue) : 0.0;
      unitPrice = unitPriceValue.toStringAsFixed(2);
      unitPriceExTax = (unitPriceValue - taxPerUnit).toStringAsFixed(2);
      unitName =
          (item['productUnit'] ?? item['product_unit'] ?? item['unit'] ?? '')
              .toString();
      totalPrice = (double.tryParse(
                  (item['totalPrice'] ?? item['total_price'])?.toString() ??
                      '0') ??
              0.0)
          .toStringAsFixed(2);
      itemTaxAmount = taxValue.toStringAsFixed(2);
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
      final double unitPriceValue =
          (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0);
      final double taxValue =
          (double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0);
      final double quantityValue =
          (double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0);
      final double taxPerUnit =
          quantityValue > 0 ? (taxValue / quantityValue) : 0.0;
      unitPrice = unitPriceValue.toStringAsFixed(2);
      unitPriceExTax = (unitPriceValue - taxPerUnit).toStringAsFixed(2);
      unitName = (item.productUnit ?? '').toString();
      totalPrice = (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      itemTaxAmount = taxValue.toStringAsFixed(2);
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
          ReceiptTableColumn(itemText,
              weight: 1.0,
              align: TextAlign.left,
              textDirection: TextDirection.ltr),
        ]));
      }
      // Price details row
      List<ReceiptTableColumn> priceCols = [];
      final itemDetailsWeight = _getItemDetailsWeight(tableWeights);
      if (itemDetailsWeight > 0) {
        priceCols.add(ReceiptTableColumn("", weight: itemDetailsWeight));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        priceCols.add(ReceiptTableColumn(mrp,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.center,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.center,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPriceExTax,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitName,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.center,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: tableWeights['showTotal'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (priceCols.any((column) => column.text.isNotEmpty)) {
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
            ReceiptTableColumn(englishText,
                weight: 1.0,
                align: TextAlign.left,
                textDirection: TextDirection.ltr),
          ]));
        } else {
          // Fallback to single name (English or Arabic)
          String itemText = displayConfig?['showSLNumber']?.visible == true
              ? '$slNumber. $productName'
              : productName;
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText,
                weight: 1.0,
                align: TextAlign.left,
                textDirection: TextDirection.ltr),
          ]));
        }
      }
      // Price details row (RTL order)
      List<ReceiptTableColumn> priceCols = [];
      if (displayConfig?['showTotal']?.visible == true) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: tableWeights['showTotal'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPriceExTax,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitName,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        priceCols.add(ReceiptTableColumn(mrp,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale));
      }
      final itemDetailsWeight = _getItemDetailsWeight(tableWeights);
      if (itemDetailsWeight > 0) {
        priceCols.add(ReceiptTableColumn("", weight: itemDetailsWeight));
      }
      if (priceCols.any((column) => column.text.isNotEmpty)) {
        rows.add(ReceiptTableRow(priceCols));
      }
    }
  }

  Map<String, double> _buildNormalizedTableWeights(
    Map<String, DisplayOption>? displayConfig,
  ) {
    final bool showSlNumber = displayConfig?['showSLNumber']?.visible == true;
    final baseWeights = <String, double>{
      if (showSlNumber) 'showSLNumber': 0.08,
      if (displayConfig?['showParticulars']?.visible == true)
        'showParticulars': showSlNumber ? 0.17 : 0.25,
      if (displayConfig?['showMRP']?.visible == true) 'showMRP': 0.15,
      if (displayConfig?['showQty']?.visible == true) 'showQty': 0.12,
      if (displayConfig?['showRate']?.visible == true) 'showRate': 0.15,
      if (displayConfig?['showRateExcTax']?.visible == true)
        'showRateExcTax': 0.15,
      if (displayConfig?['showUnit']?.visible == true) 'showUnit': 0.12,
      if (displayConfig?['showTaxHeader']?.visible == true)
        'showTaxHeader': 0.15,
      if (displayConfig?['showTotal']?.visible == true) 'showTotal': 0.15,
    };

    final totalWeight =
        baseWeights.values.fold<double>(0, (sum, weight) => sum + weight);
    if (totalWeight <= 0) {
      return const {};
    }

    if (totalWeight < 1.0) {
      final remainingWeight = 1.0 - totalWeight;
      if (baseWeights.containsKey('showParticulars')) {
        baseWeights['showParticulars'] =
            baseWeights['showParticulars']! + remainingWeight;
      } else if (baseWeights.containsKey('showTotal')) {
        baseWeights['showTotal'] = baseWeights['showTotal']! + remainingWeight;
      } else {
        final fallbackKey = baseWeights.keys.last;
        baseWeights[fallbackKey] = baseWeights[fallbackKey]! + remainingWeight;
      }
      return baseWeights;
    }

    if (totalWeight == 1.0) {
      return baseWeights;
    }

    return {
      for (final entry in baseWeights.entries)
        entry.key: entry.value / totalWeight,
    };
  }

  double _getItemDetailsWeight(Map<String, double> tableWeights) {
    return (tableWeights['showSLNumber'] ?? 0) +
        (tableWeights['showParticulars'] ?? 0);
  }

  double _getTableScale(int columnCount) {
    if (columnCount >= 9) return 0.74;
    if (columnCount == 8) return 0.80;
    if (columnCount == 7) return 0.86;
    if (columnCount == 6) return 0.92;
    return 1.0;
  }

  double _getTableMinScale(int columnCount) {
    if (columnCount >= 9) return 0.48;
    if (columnCount == 8) return 0.52;
    if (columnCount == 7) return 0.56;
    return 0.62;
  }

  double _getTableCellPadding(int columnCount) {
    if (columnCount >= 8) return 2.0;
    if (columnCount >= 6) return 2.5;
    return 3.0;
  }

  // ==================== TOTALS SECTION (Boxed Style) ====================

  void _buildTotalsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    ui.Image? sarSymbol,
    dynamic appSettings,
  ) {
    rows.add(SpacingRow(_itemGap));

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    // Get currency from appSettings
    final String currency = appSettings?.currency ?? 'INR';
    final String? currencySymbol =
        currency.trim().toUpperCase() == 'INR' ? '\u20B9' : null;
    final ui.Image? currencyIcon = currencySymbol == null ? sarSymbol : null;

    // Paper size aware scaling
    final bool is58mm = params.is58mm;

    double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;
    double total =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double taxAmount = params.totalTax;

    // Calculate subtotal
    double subtotal;
    if (params.netExcTax != null) {
      subtotal =
          double.tryParse(params.netExcTax!) ?? (total + discountAmountValue);
    } else {
      subtotal = total;
    }

    // Visibility settings
    final showMRPTotal = displayConfig?['showSubTotal']?.visible ?? displayConfig?['showMRPTotal']?.visible ?? true;
    final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
    final showTax = displayConfig?['showTax']?.visible ?? true;
    final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

    // DEBUG LOGS
    debugPrint("===== PREMIUM LAYOUT TOTALS DEBUG =====");
    debugPrint("Raw Params:");
    debugPrint("  formattedTotal: ${params.formattedTotal}");
    debugPrint("  discountAmount: ${params.discountAmount}");
    debugPrint("  totalTax: ${params.totalTax}");
    debugPrint("  paidAmount: ${params.paidAmount}");

    debugPrint("Calculated:");
    debugPrint("  subtotal: $subtotal");
    debugPrint("  discountAmountValue: $discountAmountValue");
    debugPrint("  taxAmount: $taxAmount");
    debugPrint("  total: $total");

    debugPrint("Visibility Flags:");
    debugPrint(
        "  showSubTotal: $showMRPTotal (API showSubTotal: ${displayConfig?['showSubTotal']?.visible}, API showMRPTotal: ${displayConfig?['showMRPTotal']?.visible})");
    debugPrint(
        "  showDiscount: $showDiscount (API: ${displayConfig?['showDiscount']?.visible})");
    debugPrint(
        "  showTax: $showTax (API: ${displayConfig?['showTax']?.visible})");
    debugPrint(
        "  showNetAmount: $showNetAmount (API: ${displayConfig?['showNetAmount']?.visible})");
    debugPrint("=======================================");

    // Labels
    final subtotalLabelBase = _getLabel(displayConfig, 'showSubTotal', null,
        isEnglish ? "NET TOTAL (Exc Tax)" : "المجموع");
    final subtotalLabel = subtotalLabelBase;

    final discountLabelBase = _getLabel(
        displayConfig, 'showDiscount', null, isEnglish ? "DISCOUNTS" : "الخصم");
    final discountLabel = discountLabelBase;

    final taxLabelBase =
        _getLabel(displayConfig, 'showTax', resolvedLabels?.tax, "VAT");
    final vatLabel = taxLabelBase;

    final grandTotalLabel = _getLabel(displayConfig, 'showNetAmount', null,
        isEnglish ? "GRAND TOTAL" : "المبلغ الاجمالي");

    final cashLabel =
        _getLabel(displayConfig, 'showCash', null, isEnglish ? "Cash" : "نقدي");
    final changeLabel = _getLabel(
        displayConfig, 'showChange', null, isEnglish ? "CHANGE" : "متبقي");
    final changeLabelFull = changeLabel;

    // Prepare boxed items
    List<BoxedLineItem> boxedItems = [];

    // 1. Subtotal
    if (showMRPTotal) {
      boxedItems.add(BoxedLineItem(
        label: subtotalLabel,
        value: subtotal.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 2. Discounts
    if (showDiscount) {
      boxedItems.add(BoxedLineItem(
        label: discountLabel,
        value: discountAmountValue.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 3. VAT
    if (showTax) {
      boxedItems.add(BoxedLineItem(
        label: vatLabel,
        value: taxAmount.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 4. Grand Total (Bold)
    if (showNetAmount) {
      boxedItems.add(BoxedLineItem(
        label: grandTotalLabel,
        value: total.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 5. Payment details (Separator + Payment Methods)
    // Only show if paidAmount is provided (not null) and showPaymentBreaked is true or missing (default true)
    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible ?? true;

    if (params.paidAmount != null && showPaymentBreaked) {
      boxedItems.add(BoxedLineItem(isSeparator: true));

      bool isMultiPayment = false;

      // Check if paymentBreakdown is provided (preferred)
      if (params.paymentBreakdown != null &&
          params.paymentBreakdown!.isNotEmpty) {
        isMultiPayment = true;
        params.paymentBreakdown!.forEach((method, amount) {
          double amt = double.tryParse(amount.toString()) ?? 0.0;
          if (amt > 0) {
            // Map method code to label if possible
            String label = method;
            if (method == 'CASH')
              label = isEnglish ? "Cash" : "نقدي";
            else if (method == 'CARD')
              label = isEnglish ? "Card" : "بطاقة";
            else if (method == 'UPI') label = "UPI";

            boxedItems.add(BoxedLineItem(
              label: label,
              value: amt.toStringAsFixed(2),
              isBold: true,
              scale: 1.1,
              icon: currencyIcon,
              currencySymbol: currencySymbol,
            ));
          }
        });
      }
      // Fallback to parsing paymentMethod string if it looks like JSON
      else if (params.paymentMethod != null &&
          params.paymentMethod!.startsWith('{')) {
        try {
          final Map<String, dynamic> paymentData =
              json.decode(params.paymentMethod!);
          if (paymentData['isMultiPayment'] == true) {
            isMultiPayment = true;
            final Map<String, dynamic> amounts = paymentData['amounts'];
            amounts.forEach((method, amount) {
              double amt = double.tryParse(amount.toString()) ?? 0.0;
              if (amt > 0) {
                String label = method;
                if (method == 'CASH')
                  label = isEnglish ? "Cash" : "نقدي";
                else if (method == 'CARD')
                  label = isEnglish ? "Card" : "بطاقة";
                else if (method == 'UPI') label = "UPI";

                boxedItems.add(BoxedLineItem(
                  label: label,
                  value: amt.toStringAsFixed(2),
                  isBold: true,
                  scale: 1.1,
                  icon: currencyIcon,
                  currencySymbol: currencySymbol,
                ));
              }
            });
          }
        } catch (e) {
          debugPrint("Error parsing multi-payment: $e");
        }
      }

      if (!isMultiPayment) {
        // Single payment
        String label = cashLabel;
        if (params.paymentMethod != null && params.paymentMethod!.isNotEmpty) {
          if (params.paymentMethod == 'CASH') {
            label = cashLabel;
          } else {
            label = params.paymentMethod!;
          }
        }

        boxedItems.add(BoxedLineItem(
          label: label,
          value: params.paidAmount!.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol,
        ));
      }
    }

    // Add the boxed row
    rows.add(BoxedTotalsRow(items: boxedItems));

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(_itemGap));

      if (isDualLanguage) {
        final arabicText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'ar');
        final englishText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'en');

        rows.add(TextRow('$arabicText فقط.',
            scale: is58mm ? 0.7 : 0.85, isBold: true));
        rows.add(TextRow('$englishText Only.',
            scale: is58mm ? 0.7 : 0.85,
            isBold: true,
            textDirectionOverride: TextDirection.ltr));
      } else {
        final language =
            (params.billDocumentConfig.language ?? 'en').toLowerCase();
        final amountText = AmountHelper().convertNumberToWords(total,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';

        rows.add(TextRow('$amountText$suffix',
            scale: is58mm ? 0.7 : 0.85, isBold: true));
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

    // rows.add(SpacingRow(_itemGap));

    // Customer Balance
    _buildCustomerBalance(rows, params, displayConfig, isEnglish);

    // rows.add(SpacingRow(_sectionGap));
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
    final prevBalanceLabelBase = _getLabel(
        displayConfig,
        'showCustomerPrevBalance',
        null,
        isEnglish ? "Previous Balance" : "الرصيد السابق");
    final prevBalanceLabel = is58mm
        ? (isEnglish ? "Previous Balance" : "السابق")
        : prevBalanceLabelBase;

    final paidAmountLabelBase = _getLabel(
        displayConfig,
        'showCustomerPaidAmount',
        null,
        isEnglish ? "Paid Amount" : "المبلغ المدفوع");
    final paidAmountLabel =
        is58mm ? (isEnglish ? "Paid Amount" : "المدفوع") : paidAmountLabelBase;

    final currentBalanceLabelBase = _getLabel(
        displayConfig,
        'showCustomerCurrentBalance',
        null,
        isEnglish ? "Current Balance" : "الرصيد الحالي");
    final currentBalanceLabel = is58mm
        ? (isEnglish ? "Current Balance" : "الحالي")
        : currentBalanceLabelBase;

    // Previous Balance
    if (displayConfig?['showCustomerPrevBalance']?.visible != false &&
        params.customerOldBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(prevBalanceLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

    // Paid Amount (this transaction)
    if (displayConfig?['showCustomerPaidAmount']?.visible != false &&
        params.paidAmount != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(paidAmountLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

    // Current Balance
    if (displayConfig?['showCustomerCurrentBalance']?.visible != false &&
        params.customerCurrentBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(currentBalanceLabel,
            weight: 0.6, align: TextAlign.right, isBold: true, scale: scale),
        ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, isBold: true, scale: scale),
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
        debugPrint(
            '[PremiumLayout] ZATCA credentials found, generating ZATCA QR');

        // Generate ZATCA Phase 1 compliant QR code
        final zatcaHelper = ZatcaQrHelper();
        qrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate, // Pass true UTC ISO string
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );

        qrMessage = isEnglish ? 'ZATCA E-Invoice QR' : 'فاتورة الكترونية';

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

        // Show VAT footer based on document display configuration.
        final bool showVatFooter =
            displayConfig?['showVATFooter']?.visible == true;
        if (showVatFooter &&
            params.hasZatcaCredentials &&
            params.zatcaVatNumber != null) {
          rows.add(SpacingRow(5));
          final vatLabel =
              (displayConfig?['showVATFooter']?.value as String? ?? '').trim();
          final vatText = vatLabel.isNotEmpty
              ? '$vatLabel ${params.zatcaVatNumber}'
              : '${params.zatcaVatNumber}';
          rows.add(TextRow(vatText, scale: 0.8));
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

      final dateLabel =
          _getLabel(displayConfig, 'showDate', resolvedLabels?.date, "");
      if (dateLabel.isNotEmpty) {
        rows.add(
            TextRow("$dateLabel: $formattedDate  $formattedTime", scale: 0.85));
      } else {
        rows.add(TextRow("$formattedDate  $formattedTime", scale: 0.85));
      }
    }

    // Order Number Display (Prioritize Footer if both are active)
    final bool showFooterInvoice =
        displayConfig?['showOrderNumberInFooter']?.visible == true;

    if (showFooterInvoice) {
      // Extract number sequence (e.g., "1149" from "INV-1149")
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      final String lang = params.billDocumentConfig.language ?? 'en';

      // Determine prefix and style based on which setting is active
      String prefixKey =
          showFooterInvoice ? 'showOrderNumberInFooter' : 'showInvoiceNumber';
      if (showFooterInvoice &&
          displayConfig?['showOrderNumberInFooter']?.value == null) {
        // Fallback to general prefix if footer value is null
        prefixKey = 'showInvoiceNumber';
      }

      final String invoicePrefix = _getDisplayValue(
        displayConfig?[prefixKey]?.value ??
            displayConfig?['showInvoicePrefix']?.value,
        params.billDocumentConfig.numberPrefix ??
            displayConfig?['showInvoicePrefix']?.defaultValue,
        lang == 'ar' ? 'رقم الفاتورة:' : 'INV NO:',
      );

      rows.add(SpacingRow(3));
      if (showFooterInvoice) {
        rows.add(SpacingRow(5));
        rows.add(ThinDividerRow());
        rows.add(SpacingRow(5));
        rows.add(TextRow('$invoicePrefix $strippedNumber',
            scale: 0.85, isBold: true));
      } else {
        rows.add(TextRow('$invoicePrefix $strippedNumber', scale: 0.85));
      }
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
      final message = (displayConfig?['showThankYouMessage']?.value as String?)
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
    return PrintLogoLoader.loadUiLogo(url, tag: '[premium1_receipt_layout]');
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
      ..strokeWidth = 2;
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
      ..strokeWidth = 2;

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
      ..strokeWidth =
          2.0; // Changed from 1.5 to 2.0 to prevent dithering/dotted look

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          1, y, width - 2, calculateHeight(width, fontSize, textDirection) - 2),
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(rect, paint);

    double currentY = y + padding;

    for (var item in items) {
      if (item.isSeparator) {
        // Draw dashed separator
        final sepPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 2;

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

        // Draw Icon if present
        double valueOffsetX = padding;
        if (item.icon != null) {
          final double iconSize = itemFontSize * 0.75;
          final src = Rect.fromLTWH(
              0, 0, item.icon!.width.toDouble(), item.icon!.height.toDouble());
          final dst = Rect.fromLTWH(
              padding,
              currentY + (itemFontSize - iconSize) / 2 + (itemFontSize * 0.08),
              iconSize,
              iconSize);
          canvas.drawImageRect(item.icon!, src, dst, Paint());
          valueOffsetX += iconSize + 4; // Space after icon
        } else if (item.currencySymbol != null &&
            item.currencySymbol!.isNotEmpty) {
          final symbolPainter = TextPainter(
            text: TextSpan(
              text: item.currencySymbol!,
              style: TextStyle(
                color: Colors.black,
                fontSize: itemFontSize,
                fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          symbolPainter.paint(canvas, Offset(valueOffsetX, currentY));
          valueOffsetX += symbolPainter.width + 4;
        }

        // Value on Left (after icon)
        _drawScaledText(
          canvas,
          item.value,
          Offset(valueOffsetX, currentY),
          (width * 0.45) - (valueOffsetX - padding),
          itemFontSize,
          item.isBold,
          TextAlign.left,
          TextDirection.ltr,
        );

        // Label on Right
        _drawScaledText(
          canvas,
          item.label,
          Offset(width - padding, currentY), // Anchor at right
          width * 0.50,
          itemFontSize,
          item.isBold,
          TextAlign.right,
          textDirection,
        );

        currentY += itemFontSize + 8;
      }
    }
  }

  void _drawScaledText(
    Canvas canvas,
    String text,
    Offset offset,
    double maxWidth,
    double fontSize,
    bool isBold,
    TextAlign align,
    TextDirection textDirection,
  ) {
    double currentFontSize = fontSize;
    const double minFontSize = 8.0;

    while (currentFontSize >= minFontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black,
            fontSize: currentFontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: ArabicPrinterHelper.fontFamily,
          ),
        ),
        textDirection: textDirection,
        textAlign: align,
      )..layout();

      if (painter.width <= maxWidth) {
        // Fits! Paint it.
        // Adjust offset for Right alignment since we passed the right anchor point
        double x = offset.dx;
        if (align == TextAlign.right) {
          x -= painter.width;
        }
        painter.paint(canvas, Offset(x, offset.dy));
        return;
      }

      currentFontSize -= 1.0;
    }

    // If still doesn't fit, draw with ellipsis at min font size
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: minFontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);

    double x = offset.dx;
    if (align == TextAlign.right) {
      x -= painter.width;
    }
    painter.paint(canvas, Offset(x, offset.dy));
  }
}

class BoxedLineItem {
  final String label;
  final String value;
  final bool isBold;
  final double scale;
  final bool isSeparator;
  final ui.Image? icon;
  final String? currencySymbol;

  BoxedLineItem({
    this.label = '',
    this.value = '',
    this.isBold = false,
    this.scale = 1.0,
    this.isSeparator = false,
    this.icon,
    this.currencySymbol,
  });
}

/// Row class for displaying invoice and token numbers in a centered box
class BoxedInvoiceTokenRow extends ReceiptRow {
  final String text;
  final double cornerRadius;
  final double padding;
  final double textScale;

  BoxedInvoiceTokenRow({
    required this.text,
    this.cornerRadius = 8.0,
    this.padding = 12.0,
    this.textScale = 1.1,
  });

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    final textHeight = fontSize * textScale;
    return (padding * 2) + textHeight + 4;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    // Draw rounded border box
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final boxHeight = calculateHeight(width, fontSize, textDirection);

    // First, calculate text width to adjust box size
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize * textScale,
          fontWeight: FontWeight.bold,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: TextAlign.center,
    )..layout();

    // Calculate box width based on content with padding
    double boxWidth = textPainter.width + (padding * 2) + 4;

    // Set minimum and maximum box widths for consistency
    final double minBoxWidth = 60;
    final double maxBoxWidth = width - 16;

    boxWidth = boxWidth.clamp(minBoxWidth, maxBoxWidth);

    // Center the box horizontally
    final double boxX = (width - boxWidth) / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxX, y, boxWidth, boxHeight),
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(rect, paint);

    // Draw centered text inside the box
    final textX = boxX + (boxWidth - textPainter.width) / 2;
    final textY = y + (boxHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));
  }
}
