import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
import 'common/layout_rows.dart';
import 'package:pos_machine/screens/print/thermal/debug_image_saver.dart';
// import 'thermal/printer_utils.dart';

/// Standard receipt layout - Modern & Clean design.
///
/// This layout features:
/// - Generous whitespace between sections
/// - Thin solid line dividers
/// - Clean, centered header with balanced typography
/// - Bilingual table headers with value-only labels elsewhere
/// - Streamlined totals section with clear hierarchy
/// - Minimal, elegant footer
class ArabicEnglishTableHeadersReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Standard theme spacing constants
  static const double _sectionGap = 0.0;
  static const double _itemGap = 0.0;
  static const double _headerGap = 0.0;

  @override
  String get layoutId => 'arabic_english_table_headers';

  @override
  String get displayName => 'Arabic & English Table Headers';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint(
        "===== ARABIC AND ENGLISH HEADERS ONLY LAYOUT: THERMAL PRINTING ====");

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
              "[STANDARD] SAR symbol loaded: ${sarSymbol.width}x${sarSymbol.height}");
        }
      } catch (e) {
        debugPrint("[STANDARD] Error loading SAR symbol: $e");
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
            debugPrint("[STANDARD] Logo loaded: ${logo.width}x${logo.height}");
            part1Rows.add(ImageRow(logo, width: printWidth * 0.6));
          }
        } catch (e) {
          debugPrint("[STANDARD] Error loading logo: $e");
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
      _buildTotalsSection(part1Rows, params, displayConfig, isEnglish,
          sarSymbol, appSettings?.currency ?? 'INR');

      // ========== FOOTER SECTION (Part 2) ==========
      _buildFooterSection(part2Rows, params, displayConfig, isEnglish, context);

      // ========== RENDER IMAGES ==========
      debugPrint("Rendering Arabic and English receipt images...");

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
      debugPrint("ERROR in Standard Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: "Error printing: ${e.toString()}");
      }
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("===== END STANDARD LAYOUT PRINTING =====");
    }
  }

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) async {
    debugPrint(
        "[ArabicEnglishTableHeadersReceiptLayout] buildPdf - delegating to StandardPrinter");
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
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    // Store Name - Large, centered, clean
    if (displayConfig?['showStoreName']?.visible == true) {
      String storeNameText;

      if (isDualLanguage) {
        storeNameText = _getDisplayValue(
          displayConfig?['showStoreName']?.value,
          billDocumentConfig.header,
          'STORE NAME',
        );
      } else {
        // Single language mode
        storeNameText = displayConfig?['showStoreName']?.value as String? ??
            billDocumentConfig.header ??
            'STORE NAME';
      }

      // Dynamic scaling based on name length
      double storeNameScale = 1.6;
      // For bilingual, consider the longer of the two languages
      int maxLength = storeNameText
          .split('\n')
          .map((s) => s.length)
          .reduce((a, b) => a > b ? a : b);
      if (maxLength > 20) {
        storeNameScale = 1.3;
      } else if (maxLength > 14) {
        storeNameScale = 1.5;
      }

      rows.add(TextRow(storeNameText.trim().toUpperCase(),
          isBold: true,
          scale: storeNameScale,
          verticalPadding: 0,
          verticalOffset: 1));
    }

    // Description/Subheader - Arabic subtitle style
    if (displayConfig?['showDescription']?.visible == true) {
      String descriptionText;

      if (isDualLanguage) {
        descriptionText = _getDisplayValue(
          displayConfig?['showDescription']?.value,
          billDocumentConfig.subheader,
          '',
        );
      } else {
        descriptionText = displayConfig?['showDescription']?.value as String? ??
            billDocumentConfig.subheader ??
            '';
      }

      if (descriptionText.isNotEmpty) {
        rows.add(TextRow(descriptionText.trim(),
            scale: 1.0, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      String addressText;

      if (isDualLanguage) {
        addressText = _getDisplayValue(
          displayConfig?['showStoreAddress']?.value,
          null,
          '',
        );
      } else {
        addressText =
            displayConfig?['showStoreAddress']?.value as String? ?? '';
      }

      if (addressText.isNotEmpty) {
        rows.add(TextRow(addressText, scale: 0.85, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Invoice Title (Moved above Tax/Fssai Info)
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitleText = _getDisplayValue(
        displayConfig?['showInvoiceTitle']?.value,
        appSettings?.printTitle,
        'INVOICE',
      );

      if (invoiceTitleText.isNotEmpty) {
        rows.add(
            TextRow(invoiceTitleText.toUpperCase(), isBold: true, scale: 1.1, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Extra Heading 1
    if (displayConfig?['showExtraHeading1']?.visible == true) {
      String extraHeading1Text;

      if (isDualLanguage) {
        extraHeading1Text = _getDisplayValue(
          displayConfig?['showExtraHeading1']?.value,
          displayConfig?['showExtraHeading1']?.defaultValue,
          '',
        );
      } else {
        extraHeading1Text =
            displayConfig?['showExtraHeading1']?.value as String? ?? '';
      }

      if (extraHeading1Text.isNotEmpty) {
        rows.add(TextRow(extraHeading1Text, scale: 0.95, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Extra Heading 2
    if (displayConfig?['showExtraHeading2']?.visible == true) {
      String extraHeading2Text;

      if (isDualLanguage) {
        extraHeading2Text = _getDisplayValue(
          displayConfig?['showExtraHeading2']?.value,
          displayConfig?['showExtraHeading2']?.defaultValue,
          '',
        );
      } else {
        extraHeading2Text =
            displayConfig?['showExtraHeading2']?.value as String? ?? '';
      }

      if (extraHeading2Text.isNotEmpty) {
        rows.add(TextRow(extraHeading2Text, scale: 0.95, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      String fssaiInfoText;

      if (isDualLanguage) {
        fssaiInfoText = _getDisplayValue(
          displayConfig?['showFssaiInfo']?.value,
          displayConfig?['showFssaiInfo']?.defaultValue,
          '',
        );
      } else {
        fssaiInfoText = displayConfig?['showFssaiInfo']?.value as String? ?? '';
      }

      if (fssaiInfoText.isNotEmpty) {
        rows.add(TextRow(fssaiInfoText, scale: 0.85, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      String telephoneText;

      if (isDualLanguage) {
        telephoneText = _getDisplayValue(
          displayConfig?['showTel']?.value,
          appSettings?.customerCarePhone,
          '',
        );
      } else {
        telephoneText = displayConfig?['showTel']?.value as String? ??
            appSettings?.customerCarePhone ??
            '';
      }

      if (telephoneText.isNotEmpty) {
        rows.add(TextRow(telephoneText, scale: 0.9, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      String emailText;

      if (isDualLanguage) {
        emailText = _getDisplayValue(
          displayConfig?['showEmail']?.value,
          appSettings?.customerCareEmail,
          '',
        );
      } else {
        emailText = displayConfig?['showEmail']?.value as String? ??
            appSettings?.customerCareEmail ??
            '';
      }

      if (emailText.isNotEmpty) {
        rows.add(TextRow(emailText, scale: 0.9, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(StandardThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Invoice/Token Number - hide header invoice when footer invoice number is enabled
    final bool showFooterInvoice =
        displayConfig?['showOrderNumberInFooter']?.visible == true;
    final bool showInvoiceNumber = !showFooterInvoice &&
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
          weight: 0.58, align: invoiceAlign, isBold: true, scale: 0.9);
      final tokenCol = ReceiptTableColumn(tokenText,
          weight: 0.38, align: tokenAlign, isBold: true, scale: 1.1);
      final spacerCol =
          ReceiptTableColumn('', weight: 0.04, align: TextAlign.center);

      rows.add(ReceiptTableRow(isEnglish
          ? [invoiceCol, spacerCol, tokenCol]
          : [tokenCol, spacerCol, invoiceCol]));
    } else if (invoiceNumberText != null) {
      rows.add(TextRow(invoiceNumberText, scale: 0.9, isBold: true));
    } else if (tokenText != null) {
      rows.add(TextRow(tokenText, scale: 1.4, isBold: true));
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(StandardThinDividerRow());
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
            params.deliveryMethod!.isNotEmpty);

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
              weight: 0.65, align: TextAlign.left, scale: scale),
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
              weight: 0.65, align: TextAlign.left, scale: scale),
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

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(TextRow(params.customerAddress!, scale: 0.9));
      }
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(StandardThinDividerRow());
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
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    // Extract labels with fallbacks
    // For dual language mode, we use stacked headers (Arabic on top, English below)
    final String particularsLabel = isDualLanguage
        ? _getBilingualLabel(
            displayConfig,
            'showParticulars',
            resolvedLabels?.particulars,
            resolvedLabels?.particularsDefault,
            "الصنف",
            "Item")
        : _getLabel(displayConfig, 'showParticulars',
            resolvedLabels?.particulars, isEnglish ? "Item" : "الصنف");
    final String mrpLabel = isDualLanguage
        ? _getBilingualLabel(
            displayConfig, 'showMRP', resolvedLabels?.mrp, null, "السعر", "MRP")
        : _getLabel(displayConfig, 'showMRP', resolvedLabels?.mrp, "MRP");
    final String qtyLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showQty', resolvedLabels?.qty,
            resolvedLabels?.qtyDefault, "الكمية", "Qty")
        : _getLabel(displayConfig, 'showQty', resolvedLabels?.qty,
            isEnglish ? "Qty" : "الكمية");
    final String rateLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showRate', resolvedLabels?.rate,
            resolvedLabels?.rateDefault, "السعر", "Rate")
        : _getLabel(displayConfig, 'showRate', resolvedLabels?.rate,
            isEnglish ? "Rate" : "السعر");
    final String totalLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showTotal', resolvedLabels?.total,
            resolvedLabels?.totalDefault, "الإجمالي", "Total")
        : _getLabel(displayConfig, 'showTotal', resolvedLabels?.total,
            isEnglish ? "Total" : "الإجمالي");
    final String taxHeaderLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showTaxHeader',
            resolvedLabels?.tax, resolvedLabels?.taxDefault, "الضريبة", "Tax")
        : _getLabel(displayConfig, 'showTaxHeader', resolvedLabels?.tax,
            isEnglish ? "Tax" : "الضريبة");
    final String slLabel = isDualLanguage
        ? _getBilingualLabel(
            displayConfig,
            'showSLNumber',
            resolvedLabels?.slNumber,
            resolvedLabels?.slNumberDefault,
            "م",
            "SL#")
        : _getLabel(displayConfig, 'showSLNumber', resolvedLabels?.slNumber,
            isEnglish ? "SL#" : "م");

    // Build table header
    _buildTableHeader(
        rows,
        displayConfig,
        isEnglish,
        isDualLanguage,
        particularsLabel,
        mrpLabel,
        qtyLabel,
        rateLabel,
        totalLabel,
        taxHeaderLabel,
        slLabel);

    // Build cart items
    for (var i = 0; i < params.cartItems.length; i++) {
      _buildCartItemRow(rows, params.cartItems[i], i, params.isFromLocalStorage,
          displayConfig, isEnglish, isDualLanguage);
      if (i < params.cartItems.length - 1) {
        rows.add(StandardThinDividerRow());
      }
    }

    rows.add(SpacingRow(_itemGap));
  }

  /// Calculate normalized column weights so they always sum to 1.0
  /// When a column like MRP is hidden, its space is distributed proportionally.
  Map<String, double> _calcColumnWeights(Map<String, DisplayOption>? displayConfig) {
    final bool hasSL = displayConfig?['showSLNumber']?.visible == true;
    final bool hasMRP = displayConfig?['showMRP']?.visible == true;
    final bool hasQty = displayConfig?['showQty']?.visible == true;
    final bool hasRate = displayConfig?['showRate']?.visible == true;
    final bool hasTax = displayConfig?['showTaxHeader']?.visible == true;
    final bool hasTotal = displayConfig?['showTotal']?.visible == true;
    final bool hasPRT = displayConfig?['showParticulars']?.visible == true;

    // Base weights for each column
    double sum = 0;
    final Map<String, double> base = {};
    if (hasSL)    { base['sl'] = 0.08;  sum += 0.08; }
    if (hasPRT)   { base['prt'] = 0.20; sum += 0.20; }
    if (hasMRP)   { base['mrp'] = 0.14; sum += 0.14; }
    if (hasQty)   { base['qty'] = 0.10; sum += 0.10; }
    if (hasRate)  { base['rate'] = 0.14; sum += 0.14; }
    if (hasTax)   { base['tax'] = 0.14; sum += 0.14; }
    if (hasTotal) { base['total'] = 0.16; sum += 0.16; }

    // Normalize so they sum to 1.0
    if (sum > 0) {
      final scale = 1.0 / sum;
      base.updateAll((key, value) => value * scale);
    }
    return base;
  }

  void _buildTableHeader(
    List<ReceiptRow> rows,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isDualLanguage,
    String particularsLabel,
    String mrpLabel,
    String qtyLabel,
    String rateLabel,
    String totalLabel,
    String taxHeaderLabel,
    String slLabel,
  ) {
    List<ReceiptTableColumn> headerCols = [];
    final w = _calcColumnWeights(displayConfig);

    if (isEnglish) {
      if (w.containsKey('sl'))
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: w['sl']!, align: TextAlign.left, scale: 0.8, isBold: true));
      if (w.containsKey('prt'))
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: w['prt']!, align: TextAlign.left, scale: 0.85, isBold: true));
      if (w.containsKey('mrp'))
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: w['mrp']!, align: TextAlign.center, scale: 0.85, isBold: true));
      if (w.containsKey('qty'))
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: w['qty']!, align: TextAlign.center, scale: 0.85, isBold: true));
      if (w.containsKey('rate'))
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: w['rate']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('tax'))
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: w['tax']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('total'))
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: w['total']!, align: TextAlign.right, scale: 0.85, isBold: true));
    } else {
      // Arabic header (RTL)
      if (w.containsKey('total'))
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: w['total']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('tax'))
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: w['tax']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('rate'))
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: w['rate']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('qty'))
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: w['qty']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('mrp'))
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: w['mrp']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('prt'))
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: w['prt']!, align: TextAlign.right, scale: 0.85, isBold: true));
      if (w.containsKey('sl'))
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: w['sl']!, align: TextAlign.right, scale: 0.8, isBold: true));
    }

    if (headerCols.isNotEmpty) {
      if (isDualLanguage) {
        rows.add(MultiLineReceiptTableRow(headerCols));
      } else {
        rows.add(ReceiptTableRow(headerCols));
      }
      rows.add(StandardThinDividerRow());
    }
  }

  void _buildCartItemRow(
    List<ReceiptRow> rows,
    dynamic item,
    int index,
    bool isFromLocalStorage,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isDualLanguage,
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

    // Use same normalized weights as header
    final w = _calcColumnWeights(displayConfig);
    final double spacerWeight = (w['sl'] ?? 0) + (w['prt'] ?? 0);

    if (isEnglish) {
      // Product name row (full width)
      if (w.containsKey('prt') || w.containsKey('sl')) {
        String itemText = w.containsKey('sl')
            ? '$slNumber. $productName'
            : productName;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.left),
        ]));
      }
      // Price details row with spacer matching header name columns
      List<ReceiptTableColumn> priceCols = [];
      priceCols.add(ReceiptTableColumn("", weight: spacerWeight));
      if (w.containsKey('mrp')) {
        priceCols.add(ReceiptTableColumn(mrp,
            weight: w['mrp']!, align: TextAlign.center));
      }
      if (w.containsKey('qty')) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: w['qty']!, align: TextAlign.center));
      }
      if (w.containsKey('rate')) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: w['rate']!, align: TextAlign.right));
      }
      if (w.containsKey('tax')) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: w['tax']!, align: TextAlign.right));
      }
      if (w.containsKey('total')) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: w['total']!, align: TextAlign.right));
      }
      if (priceCols.length > 1) {
        rows.add(ReceiptTableRow(priceCols));
      }
    } else {
      // Arabic: RTL layout with bilingual names
      if (w.containsKey('prt') || w.containsKey('sl')) {
        String itemText = '';
        if (productNameArabic.isNotEmpty) {
          itemText = w.containsKey('sl')
              ? '$slNumber. $productNameArabic'
              : productNameArabic;
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
          ]));
          // English name on second line
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(productName, weight: 1.0, align: TextAlign.left),
          ]));
        } else {
          itemText = w.containsKey('sl')
              ? '$slNumber. $productName'
              : productName;
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
          ]));
        }
      }
      // Price details row (RTL order) with spacer on right
      List<ReceiptTableColumn> priceCols = [];
      if (w.containsKey('total')) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: w['total']!, align: TextAlign.right));
      }
      if (w.containsKey('tax')) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: w['tax']!, align: TextAlign.right));
      }
      if (w.containsKey('rate')) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: w['rate']!, align: TextAlign.right));
      }
      if (w.containsKey('qty')) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: w['qty']!, align: TextAlign.right));
      }
      if (w.containsKey('mrp')) {
        priceCols.add(ReceiptTableColumn(mrp,
            weight: w['mrp']!, align: TextAlign.right));
      }
      priceCols.add(ReceiptTableColumn("", weight: spacerWeight));
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
    String currency,
  ) {
    rows.add(SpacingRow(_itemGap));

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

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
    final showMRPTotal = displayConfig?['showMRPTotal']?.visible ?? true;
    final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
    final showTax = displayConfig?['showTax']?.visible ?? true;
    final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

    // DEBUG LOGS
    debugPrint("===== STANDARD LAYOUT TOTALS DEBUG =====");
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
        "  showMRPTotal: $showMRPTotal (API: ${displayConfig?['showMRPTotal']?.visible})");
    debugPrint(
        "  showDiscount: $showDiscount (API: ${displayConfig?['showDiscount']?.visible})");
    debugPrint(
        "  showTax: $showTax (API: ${displayConfig?['showTax']?.visible})");
    debugPrint(
        "  showNetAmount: $showNetAmount (API: ${displayConfig?['showNetAmount']?.visible})");
    debugPrint("=======================================");

    final subtotalLabel = _getLabel(displayConfig, 'showMRPTotal', null,
        isEnglish ? "NET TOTAL (Exc Tax)" : "المجموع");

    final discountLabel = _getLabel(
        displayConfig, 'showDiscount', null, isEnglish ? "DISCOUNTS" : "الخصم");

    final vatLabel = _getLabel(displayConfig, 'showTax', resolvedLabels?.tax,
        isEnglish ? "VAT" : "الضريبة");

    final grandTotalLabel = _getLabel(displayConfig, 'showNetAmount', null,
        isEnglish ? "GRAND TOTAL" : "المبلغ الاجمالي");

    final cashLabel =
        _getLabel(displayConfig, 'showCash', null, isEnglish ? "Cash" : "نقدي");
    final changeLabel = _getLabel(
        displayConfig, 'showChange', null, isEnglish ? "CHANGE" : "متبقي");

    // Prepare boxed items
    List<StandardBoxedLineItem> boxedItems = [];

    // 1. Subtotal
    if (showMRPTotal) {
      boxedItems.add(StandardBoxedLineItem(
        label: subtotalLabel,
        value: subtotal.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: sarSymbol,
      ));
    }

    // 2. Discounts
    if (showDiscount) {
      boxedItems.add(StandardBoxedLineItem(
        label: discountLabel,
        value: discountAmountValue.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: sarSymbol,
      ));
    }

    // 3. VAT
    if (showTax) {
      boxedItems.add(StandardBoxedLineItem(
        label: vatLabel,
        value: taxAmount.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: sarSymbol,
      ));
    }

    // 4. Grand Total (Bold)
    if (showNetAmount) {
      boxedItems.add(StandardBoxedLineItem(
        label: grandTotalLabel,
        value: total.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: sarSymbol,
      ));
    }

    // 5. Payment details (Separator + Payment Methods)
    // Only show if paidAmount is provided (not null)
    if (params.paidAmount != null) {
      boxedItems.add(StandardBoxedLineItem(isSeparator: true));

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
            if (method == 'CASH') {
              label = isDualLanguage
                  ? "نقدي   Cash"
                  : (isEnglish ? "Cash" : "نقدي");
            } else if (method == 'CARD') {
              label = isDualLanguage
                  ? "بطاقة   Card"
                  : (isEnglish ? "Card" : "بطاقة");
            } else if (method == 'UPI') {
              label = "UPI";
            }

            boxedItems.add(StandardBoxedLineItem(
              label: label,
              value: amt.toStringAsFixed(2),
              isBold: true,
              scale: 1,
              icon: sarSymbol,
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
                if (method == 'CASH') {
                  label = isDualLanguage
                      ? "نقدي   Cash"
                      : (isEnglish ? "Cash" : "نقدي");
                } else if (method == 'CARD') {
                  label = isDualLanguage
                      ? "بطاقة   Card"
                      : (isEnglish ? "Card" : "بطاقة");
                } else if (method == 'UPI') {
                  label = "UPI";
                }

                boxedItems.add(StandardBoxedLineItem(
                  label: label,
                  value: amt.toStringAsFixed(2),
                  isBold: true,
                  scale: 1,
                  icon: sarSymbol,
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

        boxedItems.add(StandardBoxedLineItem(
          label: label,
          value: params.paidAmount!.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: sarSymbol,
        ));
      }
    }

    // Add the boxed row
    rows.add(StandardBoxedTotalsRow(items: boxedItems));

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

    // Items Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      final itemsCountText = _getDisplayValue(
        displayConfig?['showItemsCount']?.value,
        null,
        isEnglish ? 'Items' : 'العدد',
      );

      if (itemsCountText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow('$itemsCountText: ${params.cartItems.length}',
            scale: is58mm ? 0.75 : 0.85, isBold: true));
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
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    final prevBalanceLabel = _getLabel(displayConfig, 'showCustomerPrevBalance',
        null, isEnglish ? "Previous Balance" : "الرصيد السابق");

    final paidAmountLabel = _getLabel(displayConfig, 'showCustomerPaidAmount',
        null, isEnglish ? "Paid Amount" : "المبلغ المدفوع");

    final currentBalanceLabel = _getLabel(
        displayConfig,
        'showCustomerCurrentBalance',
        null,
        isEnglish ? "Current Balance" : "الرصيد الحالي");

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

    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    // QR Code - Use ZATCA QR if credentials available, otherwise fallback to payment QR
    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';
      String qrMessage = '';

      // Check if ZATCA credentials are available for Saudi Arabia e-invoicing
      if (params.hasZatcaCredentials) {
        debugPrint(
            '[StandardLayout] ZATCA credentials found, generating ZATCA QR');

        // Generate ZATCA Phase 1 compliant QR code
        final zatcaHelper = ZatcaQrHelper();
        qrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate, // Pass true UTC ISO string
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );

        qrMessage = isDualLanguage
            ? 'فاتورة الكترونية\nZATCA E-Invoice QR'
            : (isEnglish ? 'ZATCA E-Invoice QR' : 'فاتورة الكترونية');

        debugPrint('[StandardLayout] ZATCA QR generated: ${qrData.isNotEmpty}');
      } else {
        debugPrint('[StandardLayout] No ZATCA credentials, using payment QR');

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
        rows.add(SpacingRow(_itemGap));
        rows.add(QrRow(qrData, size: 220));

        // Show VAT number below QR for ZATCA receipts
        if (params.hasZatcaCredentials && params.zatcaVatNumber != null) {
          rows.add(SpacingRow(_itemGap));
          final vatLabel = isDualLanguage
              ? 'الرقم الضريبي:   VAT No:'
              : (isEnglish ? 'VAT No:' : 'الرقم الضريبي:');
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

      final dateLabel =
          _getLabel(displayConfig, 'showDate', resolvedLabels?.date, "");
      if (dateLabel.isNotEmpty) {
        rows.add(
            TextRow("$dateLabel: $formattedDate  $formattedTime", scale: 0.85));
      } else {
        rows.add(TextRow("$formattedDate  $formattedTime", scale: 0.85));
      }
    }

    // Order Number Display (Footer only)
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

      if (showFooterInvoice) {
        rows.add(StandardThinDividerRow());
        rows.add(TextRow('$invoicePrefix $strippedNumber',
            scale: 0.85, isBold: true));
      } else {
        rows.add(TextRow('$invoicePrefix $strippedNumber', scale: 0.85));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      String termsText;
      if (isDualLanguage) {
        termsText = _getDisplayValue(
          displayConfig?['showTermsConditions']?.value,
          params.billDocumentConfig.terms,
          '',
        );
      } else {
        termsText = displayConfig?['showTermsConditions']?.value as String? ??
            params.billDocumentConfig.terms ??
            '';
      }

      if (termsText.isNotEmpty) {
        rows.add(TextRow(termsText.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message - Elegant
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      String messageText;
      if (isDualLanguage) {
        messageText = _getDisplayValue(
          displayConfig?['showThankYouMessage']?.value,
          params.billDocumentConfig.footer,
          'شكراً لزيارتكم!',
        );
      } else {
        final configMessage =
            displayConfig?['showThankYouMessage']?.value as String?;
        final docFooter = params.billDocumentConfig.footer ?? '';
        final defaultThankYou =
            isEnglish ? 'Thank You for Your Visit!' : 'شكراً لزيارتكم!';

        messageText = _getDisplayValue(
          configMessage,
          docFooter,
          defaultThankYou,
        );
      }

      if (messageText.isNotEmpty) {
        rows.add(TextRow(messageText, isBold: true, scale: 0.95));
      }
    }

    rows.add(SpacingRow(_sectionGap));
  }

  // ==================== UTILITY METHODS ====================

  /// Helper method to create bilingual text (Arabic + English)
  /// Returns English on top, Arabic on bottom separated by newline
  String _getBilingualText({String? arabic, String? english}) {
    if (english != null && english.isNotEmpty) {
      if (arabic != null && arabic.isNotEmpty) {
        // Only hide if exactly same to avoid missing Arabic when backend is untranslated
        if (english.trim() == arabic.trim()) {
          return english;
        }
        return '$english\n$arabic';
      }
      return english;
    } else if (arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return '';
  }

  /// Helper to ensure we actually have Arabic script in the Arabic part
  String _getArabicFallback(
      String? candidate, String defaultAr, String currentEn, String defaultEn) {
    if (candidate == null || candidate.isEmpty) return defaultAr;

    final trimmed = candidate.trim();
    // 1. If it matches the English text currently being used
    if (trimmed.toLowerCase() == currentEn.trim().toLowerCase())
      return defaultAr;
    // 2. If it matches the English default
    if (trimmed.toLowerCase() == defaultEn.trim().toLowerCase())
      return defaultAr;
    // 3. If it contains NO Arabic characters and is not different symbol
    if (!RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed) && trimmed.length > 1) {
      return defaultAr;
    }

    return trimmed;
  }

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

  /// Get bilingual label using DisplayOption defaultValue for English part
  String _getBilingualLabel(
    Map<String, DisplayOption>? displayConfig,
    String key,
    String? resolvedLabelArabic,
    String? resolvedLabelEnglish,
    String defaultArabic,
    String defaultEnglish,
  ) {
    // 1. English part
    String english = '';
    final configEn = displayConfig?[key]?.defaultValue;
    if (configEn != null && configEn.isNotEmpty) {
      english = configEn;
    } else if (resolvedLabelEnglish != null &&
        resolvedLabelEnglish.isNotEmpty) {
      english = resolvedLabelEnglish;
    } else {
      english = defaultEnglish;
    }

    // 2. Arabic part with robust fallback
    final configAr = displayConfig?[key]?.value as String?;
    String? candidateAr;
    if (configAr != null && configAr.isNotEmpty) {
      candidateAr = configAr;
    } else if (resolvedLabelArabic != null && resolvedLabelArabic.isNotEmpty) {
      candidateAr = resolvedLabelArabic;
    }

    String arabic =
        _getArabicFallback(candidateAr, defaultArabic, english, defaultEnglish);

    return _getBilingualText(arabic: arabic, english: english);
  }

  /// Get bilingual label for totals/sections with "English   Arabic" format
  /// Used for totals and section labels where we want both on the same line
  String _getBilingualLabelHorizontal(
    Map<String, DisplayOption>? displayConfig,
    String key,
    String? resolvedLabelArabic,
    String? resolvedLabelEnglish,
    String defaultArabic,
    String defaultEnglish,
  ) {
    // 1. English part
    String english = '';
    final configEn = displayConfig?[key]?.defaultValue;
    if (configEn != null && configEn.isNotEmpty) {
      english = configEn;
    } else if (resolvedLabelEnglish != null &&
        resolvedLabelEnglish.isNotEmpty) {
      english = resolvedLabelEnglish;
    } else {
      english = defaultEnglish;
    }

    // 2. Arabic part with robust fallback
    final configAr = displayConfig?[key]?.value as String?;
    String? candidateAr;
    if (configAr != null && configAr.isNotEmpty) {
      candidateAr = configAr;
    } else if (resolvedLabelArabic != null && resolvedLabelArabic.isNotEmpty) {
      candidateAr = resolvedLabelArabic;
    }

    String arabic =
        _getArabicFallback(candidateAr, defaultArabic, english, defaultEnglish);

    // Return in "English   Arabic" format
    if (english.isNotEmpty && arabic.isNotEmpty) {
      return '$english   $arabic';
    } else if (english.isNotEmpty) {
      return english;
    } else if (arabic.isNotEmpty) {
      return arabic;
    }
    return '';
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
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final fi = await codec.getNextFrame();
        return fi.image;
      }
    } catch (e) {
      debugPrint(
          "[ArabicEnglishTableHeadersReceiptLayout] Error fetching image: $e");
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
      debugPrint(
          "[ArabicEnglishTableHeadersReceiptLayout] Error loading asset image: $e");
    }
    return null;
  }
}

/// Thin solid line divider for Standard theme
