import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:convert';
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

import 'receipt_layout.dart';
import 'receipt_layout_params.dart';
import '../logo_loader.dart';
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
class MultiStoreReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Standard theme spacing constants
  static const double _sectionGap = 0.0;
  static const double _itemGap = 0.0;
  static const double _headerGap = 0.0;

  @override
  String get layoutId => 'multi_store_table_headers';

  @override
  String get displayName => 'Multi Store Table Headers';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== MULTI STORE TABLE HEADERS LAYOUT: THERMAL PRINTING ====");

    final context = params.context;
    final selectedPrinter = params.selectedPrinter;
    final billDocumentConfig = params.billDocumentConfig;
    final displayConfig = params.displayConfig;

    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: ${params.selectedPaperSize}");

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;
    final paymentGatewaysProvider =
        Provider.of<PaymentGatewaysProvider>(context, listen: false);

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
      final activeStoreDetails = await _loadActiveStoreDetails();

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
          part1Rows, params, displayConfig, appSettings, isEnglish,
          activeStoreDetails: activeStoreDetails);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish);

      // ========== CART ITEMS SECTION ==========
      _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);

      // ========== TOTALS SECTION (Bilingual Style) ==========
      _buildTotalsSection(part1Rows, params, displayConfig, isEnglish,
          sarSymbol, appSettings?.currency ?? 'INR');

      // ========== FOOTER SECTION (Part 2) ==========
      _buildFooterSection(part2Rows, params, displayConfig, isEnglish,
          appSettings: appSettings,
          paymentGatewaysProvider: paymentGatewaysProvider,
          activeStoreDetails: activeStoreDetails);

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
        "[MultiStoreReceiptLayout] buildPdf - delegating to StandardPrinter");
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
    bool isEnglish, {
    Map<String, dynamic>? activeStoreDetails,
  }) {
    final billDocumentConfig = params.billDocumentConfig;
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

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
      final storeNameText = _storeText(
        activeStoreDetails,
        ['store_name', 'storeName', 'name'],
        fallback: params.storeName?.isNotEmpty == true
            ? params.storeName!
            : _getOptionText(
                displayConfig,
                'showStoreName',
                defaultValue: 'STORE NAME',
              ),
      );

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
      final descriptionText = _getOptionText(displayConfig, 'showDescription');

      if (descriptionText.isNotEmpty) {
        rows.add(TextRow(descriptionText.trim(),
            scale: 1.0, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final addressLabel = _getOptionText(displayConfig, 'showStoreAddress');
      final addressVal = params.storeLocation?.isNotEmpty == true
          ? params.storeLocation!
          : _storeText(activeStoreDetails, ['location', 'address', 'store_address', 'storeAddress'], fallback: '');
      final addressText = addressVal.isNotEmpty
          ? (addressLabel.isNotEmpty ? '$addressLabel: $addressVal' : addressVal)
          : '';

      if (addressText.isNotEmpty) {
        rows.add(TextRow(addressText,
            scale: 0.85, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Invoice Title (Moved above Tax/Fssai Info)
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitleText = _getOptionText(
        displayConfig,
        'showInvoiceTitle',
        fallback: appSettings?.printTitle,
        defaultValue: 'INVOICE',
      );

      if (invoiceTitleText.isNotEmpty) {
        rows.add(TextRow(invoiceTitleText.toUpperCase(),
            isBold: true, scale: 1.1, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Extra Heading 1
    if (displayConfig?['showExtraHeading1']?.visible == true) {
      final extraHeading1Text =
          _getOptionText(displayConfig, 'showExtraHeading1');

      if (extraHeading1Text.isNotEmpty) {
        rows.add(TextRow(extraHeading1Text,
            scale: 0.95, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Extra Heading 2
    if (displayConfig?['showExtraHeading2']?.visible == true) {
      final extraHeading2Text =
          _getOptionText(displayConfig, 'showExtraHeading2');

      if (extraHeading2Text.isNotEmpty) {
        rows.add(TextRow(extraHeading2Text,
            scale: 0.95, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfoText = _getOptionText(displayConfig, 'showFssaiInfo');

      if (fssaiInfoText.isNotEmpty) {
        rows.add(TextRow(fssaiInfoText,
            scale: 0.85, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final telLabel = _getOptionText(displayConfig, 'showTel');
      final phoneVal = params.storePhone?.isNotEmpty == true
          ? params.storePhone!
          : _storeText(activeStoreDetails, ['phone', 'store_phone', 'storePhone'], fallback: appSettings?.customerCarePhone ?? '');
      final telephoneText = phoneVal.isNotEmpty ? (telLabel.isNotEmpty ? '$telLabel: $phoneVal' : phoneVal) : '';

      if (telephoneText.isNotEmpty) {
        rows.add(TextRow(telephoneText,
            scale: 0.9, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final emailLabel = _getOptionText(displayConfig, 'showEmail');
      final emailVal = params.storeEmail?.isNotEmpty == true
          ? params.storeEmail!
          : _storeText(activeStoreDetails, ['email', 'store_email', 'storeEmail'], fallback: appSettings?.customerCareEmail ?? '');
      final emailText = emailVal.isNotEmpty ? (emailLabel.isNotEmpty ? '$emailLabel: $emailVal' : emailVal) : '';

      if (emailText.isNotEmpty) {
        rows.add(TextRow(emailText,
            scale: 0.9, isBold: true, verticalPadding: 0, verticalOffset: 0));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(StandardThinDividerRow());

    rows.add(SpacingRow(_itemGap));

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
      final String invoicePrefix = _getOptionText(
        displayConfig,
        'showInvoicePrefix',
        fallback: params.billDocumentConfig.numberPrefix,
        defaultValue: 'INV-',
      );

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

    final String particularsLabel = isDualLanguage
        ? _getBilingualLabel(
            displayConfig,
            'showParticulars',
            resolvedLabels?.particulars,
            resolvedLabels?.particularsDefault,
            'Item',
            'Item')
        : _getLabel(displayConfig, 'showParticulars',
            resolvedLabels?.particulars, isEnglish ? 'Item' : 'Item');
    final String mrpLabel = isDualLanguage
        ? _getBilingualLabel(
            displayConfig, 'showMRP', resolvedLabels?.mrp, null, 'MRP', 'MRP')
        : _getLabel(displayConfig, 'showMRP', resolvedLabels?.mrp, 'MRP');
    final String qtyLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showQty', resolvedLabels?.qty,
            resolvedLabels?.qtyDefault, 'Qty', 'Qty')
        : _getLabel(displayConfig, 'showQty', resolvedLabels?.qty,
            isEnglish ? 'Qty' : 'Qty');
    final String rateLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showRate', resolvedLabels?.rate,
            resolvedLabels?.rateDefault, 'Rate', 'Rate')
        : _getLabel(displayConfig, 'showRate', resolvedLabels?.rate,
            isEnglish ? 'Rate' : 'Rate');
    final String rateExcTaxLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showRateExcTax', null, null,
            'Rate Ex Tax', 'Rate Ex Tax')
        : _getLabel(displayConfig, 'showRateExcTax', null,
            isEnglish ? 'Rate Ex Tax' : 'Rate Ex Tax');
    final String unitLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showUnit',
            resolvedLabels?.unitName, null, 'Unit', 'Unit')
        : _getLabel(displayConfig, 'showUnit', resolvedLabels?.unitName,
            isEnglish ? 'Unit' : 'Unit');
    final String totalLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showTotal', resolvedLabels?.total,
            resolvedLabels?.totalDefault, 'Total', 'Total')
        : _getLabel(displayConfig, 'showTotal', resolvedLabels?.total,
            isEnglish ? 'Total' : 'Total');
    final String taxHeaderLabel = isDualLanguage
        ? _getBilingualLabel(displayConfig, 'showTaxHeader',
            resolvedLabels?.tax, resolvedLabels?.taxDefault, 'Tax', 'Tax')
        : _getLabel(displayConfig, 'showTaxHeader', resolvedLabels?.tax,
            isEnglish ? 'Tax' : 'Tax');
    final String slLabel = isDualLanguage
        ? _getBilingualLabel(
            displayConfig,
            'showSLNumber',
            resolvedLabels?.slNumber,
            resolvedLabels?.slNumberDefault,
            '#',
            'SL#')
        : _getLabel(displayConfig, 'showSLNumber', resolvedLabels?.slNumber,
            isEnglish ? 'SL#' : '#');

    final tableWeights = _buildNormalizedTableWeights(displayConfig);
    final tableColumnCount = tableWeights.length;
    final tableScale = _getTableScale(tableColumnCount);
    final tableMinScale = _getTableMinScale(tableColumnCount);
    final tableCellPadding = _getTableCellPadding(tableColumnCount);

    _buildTableHeader(
      rows,
      displayConfig,
      isEnglish,
      isDualLanguage,
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
      tableCellPadding,
    );

    for (var i = 0; i < params.cartItems.length; i++) {
      _buildCartItemRow(
        rows,
        params.cartItems[i],
        i,
        params.isFromLocalStorage,
        displayConfig,
        isEnglish,
        isDualLanguage,
        tableWeights,
        tableScale,
        tableMinScale,
        tableCellPadding,
      );
      if (i < params.cartItems.length - 1) {
        rows.add(StandardThinDividerRow());
      }
    }

    rows.add(SpacingRow(_itemGap));
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
    final headerCols = <ReceiptTableColumn>[];

    ReceiptTableColumn col(
      String text,
      String key, {
      TextAlign align = TextAlign.center,
    }) {
      return ReceiptTableColumn(
        text,
        weight: tableWeights[key] ?? 0,
        align: align,
        isBold: true,
        scale: tableScale,
        minScale: tableMinScale,
        horizontalPadding: tableCellPadding,
      );
    }

    if (isEnglish) {
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(col(slLabel, 'showSLNumber', align: TextAlign.left));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(
            col(particularsLabel, 'showParticulars', align: TextAlign.left));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(col(mrpLabel, 'showMRP'));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(col(qtyLabel, 'showQty'));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(col(rateLabel, 'showRate'));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        headerCols.add(col(rateExcTaxLabel, 'showRateExcTax'));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        headerCols.add(col(unitLabel, 'showUnit'));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(col(taxHeaderLabel, 'showTaxHeader'));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        headerCols.add(col(totalLabel, 'showTotal'));
      }
    } else {
      if (displayConfig?['showTotal']?.visible == true) {
        headerCols.add(col(totalLabel, 'showTotal', align: TextAlign.right));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols
            .add(col(taxHeaderLabel, 'showTaxHeader', align: TextAlign.right));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(col(rateLabel, 'showRate', align: TextAlign.right));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        headerCols.add(
            col(rateExcTaxLabel, 'showRateExcTax', align: TextAlign.right));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        headerCols.add(col(unitLabel, 'showUnit', align: TextAlign.right));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(col(qtyLabel, 'showQty', align: TextAlign.right));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(col(mrpLabel, 'showMRP', align: TextAlign.right));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(
            col(particularsLabel, 'showParticulars', align: TextAlign.right));
      }
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(col(slLabel, 'showSLNumber', align: TextAlign.right));
      }
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
    Map<String, double> tableWeights,
    double tableScale,
    double tableMinScale,
    double tableCellPadding,
  ) {
    String productName = '';
    String productNameArabic = '';
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
      final unitPriceValue = double.tryParse(
              (item['unitPrice'] ?? item['unit_price'])?.toString() ?? '0') ??
          0.0;
      final taxValue = double.tryParse(
              (item['tax_amount'] ?? item['taxAmount'])?.toString() ?? '0') ??
          0.0;
      final quantityValue =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
      final taxPerUnit = quantityValue > 0 ? taxValue / quantityValue : 0.0;
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
      if (!isEnglish &&
          item.names != null &&
          item.names!.ar != null &&
          item.names!.ar!.isNotEmpty) {
        productNameArabic = item.names!.ar ?? '';
        productName = item.names!.en ?? item.productName ?? '';
      } else {
        productName = item.productName ?? '';
      }

      mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      quantity = item.quantity?.toString() ?? '0';
      final unitPriceValue =
          double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0;
      final taxValue =
          double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
      final quantityValue =
          double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0;
      final taxPerUnit = quantityValue > 0 ? taxValue / quantityValue : 0.0;
      unitPrice = unitPriceValue.toStringAsFixed(2);
      unitPriceExTax = (unitPriceValue - taxPerUnit).toStringAsFixed(2);
      unitName = (item.productUnit ?? '').toString();
      totalPrice = (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      itemTaxAmount = taxValue.toStringAsFixed(2);
    }

    final slNumber = (index + 1).toString();

    ReceiptTableColumn valueCol(
      String text,
      String key, {
      TextAlign align = TextAlign.right,
    }) {
      return ReceiptTableColumn(
        text,
        weight: tableWeights[key] ?? 0,
        align: align,
        scale: tableScale,
        minScale: tableMinScale,
        horizontalPadding: tableCellPadding,
      );
    }

    if (isEnglish) {
      if (displayConfig?['showParticulars']?.visible == true ||
          displayConfig?['showSLNumber']?.visible == true) {
        final itemText = displayConfig?['showSLNumber']?.visible == true
            ? '$slNumber. $productName'
            : productName;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(itemText,
              weight: 1.0,
              align: TextAlign.left,
              textDirection: TextDirection.ltr),
        ]));
      }

      final priceCols = <ReceiptTableColumn>[];
      final itemDetailsWeight = _getItemDetailsWeight(tableWeights);
      if (itemDetailsWeight > 0) {
        priceCols.add(ReceiptTableColumn('', weight: itemDetailsWeight));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        priceCols.add(valueCol(mrp, 'showMRP', align: TextAlign.center));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceCols.add(valueCol(quantity, 'showQty', align: TextAlign.center));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceCols.add(valueCol(unitPrice, 'showRate'));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        priceCols.add(valueCol(unitPriceExTax, 'showRateExcTax'));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        priceCols.add(valueCol(unitName, 'showUnit', align: TextAlign.center));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        priceCols.add(valueCol(itemTaxAmount, 'showTaxHeader'));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        priceCols.add(valueCol(totalPrice, 'showTotal'));
      }
      if (priceCols.any((column) => column.text.isNotEmpty)) {
        rows.add(ReceiptTableRow(priceCols));
      }
      return;
    }

    if (displayConfig?['showParticulars']?.visible == true ||
        displayConfig?['showSLNumber']?.visible == true) {
      if (productNameArabic.isNotEmpty) {
        final arabicText = displayConfig?['showSLNumber']?.visible == true
            ? '$slNumber. $productNameArabic'
            : productNameArabic;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(arabicText, weight: 1.0, align: TextAlign.right),
        ]));
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(productName,
              weight: 1.0,
              align: TextAlign.left,
              textDirection: TextDirection.ltr),
        ]));
      } else {
        final itemText = displayConfig?['showSLNumber']?.visible == true
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

    final priceCols = <ReceiptTableColumn>[];
    if (displayConfig?['showTotal']?.visible == true) {
      priceCols.add(valueCol(totalPrice, 'showTotal'));
    }
    if (displayConfig?['showTaxHeader']?.visible == true) {
      priceCols.add(valueCol(itemTaxAmount, 'showTaxHeader'));
    }
    if (displayConfig?['showRate']?.visible == true) {
      priceCols.add(valueCol(unitPrice, 'showRate'));
    }
    if (displayConfig?['showRateExcTax']?.visible == true) {
      priceCols.add(valueCol(unitPriceExTax, 'showRateExcTax'));
    }
    if (displayConfig?['showUnit']?.visible == true) {
      priceCols.add(valueCol(unitName, 'showUnit'));
    }
    if (displayConfig?['showQty']?.visible == true) {
      priceCols.add(valueCol(quantity, 'showQty'));
    }
    if (displayConfig?['showMRP']?.visible == true) {
      priceCols.add(valueCol(mrp, 'showMRP'));
    }
    final itemDetailsWeight = _getItemDetailsWeight(tableWeights);
    if (itemDetailsWeight > 0) {
      priceCols.add(ReceiptTableColumn('', weight: itemDetailsWeight));
    }
    if (priceCols.any((column) => column.text.isNotEmpty)) {
      rows.add(ReceiptTableRow(priceCols));
    }
  }

  Map<String, double> _buildNormalizedTableWeights(
    Map<String, DisplayOption>? displayConfig,
  ) {
    final showSlNumber = displayConfig?['showSLNumber']?.visible == true;
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
        'showTaxHeader': 0.13,
      if (displayConfig?['showTotal']?.visible == true) 'showTotal': 0.15,
    };

    final totalWeight =
        baseWeights.values.fold<double>(0, (sum, weight) => sum + weight);
    if (totalWeight <= 0) {
      return const {};
    }

    return baseWeights.map(
      (key, value) => MapEntry(key, value / totalWeight),
    );
  }

  double _getItemDetailsWeight(Map<String, double> tableWeights) {
    return (tableWeights['showSLNumber'] ?? 0) +
        (tableWeights['showParticulars'] ?? 0);
  }

  double _getTableScale(int columnCount) {
    if (columnCount >= 8) return 0.72;
    if (columnCount >= 6) return 0.8;
    return 0.9;
  }

  double _getTableMinScale(int columnCount) {
    if (columnCount >= 8) return 0.6;
    if (columnCount >= 6) return 0.68;
    return 0.75;
  }

  double _getTableCellPadding(int columnCount) {
    if (columnCount >= 8) return 1.5;
    if (columnCount >= 6) return 1.0;
    return 0.0;
  }

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
        "  showSubTotal: $showMRPTotal (API showSubTotal: ${displayConfig?['showSubTotal']?.visible}, API showMRPTotal: ${displayConfig?['showMRPTotal']?.visible})");
    debugPrint(
        "  showDiscount: $showDiscount (API: ${displayConfig?['showDiscount']?.visible})");
    debugPrint(
        "  showTax: $showTax (API: ${displayConfig?['showTax']?.visible})");
    debugPrint(
        "  showNetAmount: $showNetAmount (API: ${displayConfig?['showNetAmount']?.visible})");
    debugPrint("=======================================");

    final subtotalLabel = _getLabel(displayConfig, 'showSubTotal', null,
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
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 2. Discounts
    if (showDiscount && discountAmountValue != 0) {
      boxedItems.add(StandardBoxedLineItem(
        label: discountLabel,
        value: discountAmountValue.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 3. VAT
    if (showTax) {
      boxedItems.add(StandardBoxedLineItem(
        label: vatLabel,
        value: taxAmount.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 4. Grand Total (Bold)
    if (showNetAmount) {
      boxedItems.add(StandardBoxedLineItem(
        label: grandTotalLabel,
        value: total.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 5. Payment details (Separator + Payment Methods)
    // Only show if paidAmount is provided (not null)
    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible ?? true;

    if (params.paidAmount != null && showPaymentBreaked) {
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
              label = isEnglish ? "Cash" : "نقدي";
            } else if (method == 'CARD') {
              label = isEnglish ? "Card" : "بطاقة";
            } else if (method == 'UPI') {
              label = "UPI";
            }

            boxedItems.add(StandardBoxedLineItem(
              label: label,
              value: amt.toStringAsFixed(2),
              isBold: true,
              scale: 1,
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
                if (method == 'CASH') {
                  label = isEnglish ? "Cash" : "نقدي";
                } else if (method == 'CARD') {
                  label = isEnglish ? "Card" : "بطاقة";
                } else if (method == 'UPI') {
                  label = "UPI";
                }

                boxedItems.add(StandardBoxedLineItem(
                  label: label,
                  value: amt.toStringAsFixed(2),
                  isBold: true,
                  scale: 1,
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

        boxedItems.add(StandardBoxedLineItem(
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
      final itemsCountText = _getOptionText(
        displayConfig,
        'showItemsCount',
        defaultValue: isEnglish ? 'Items' : 'العدد',
      );

      if (itemsCountText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow('$itemsCountText: ${params.cartItems.length}',
            scale: is58mm ? 0.75 : 0.85, isBold: true));
      }
    }

    if (displayConfig?['showQuantityCount']?.visible == true) {
      final quantityCountText = _getOptionText(
        displayConfig,
        'showQuantityCount',
        defaultValue: isEnglish ? 'Total Qty' : 'إجمالي الكمية',
      );

      if (quantityCountText.isNotEmpty) {
        final totalQuantity = params.totalQuantity;
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(
            '$quantityCountText: ${totalQuantity % 1 == 0 ? totalQuantity.toInt().toString() : totalQuantity.toStringAsFixed(2)}',
            scale: is58mm ? 0.75 : 0.85,
            isBold: true));
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
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

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
    bool isEnglish, {
    dynamic appSettings,
    required PaymentGatewaysProvider paymentGatewaysProvider,
    Map<String, dynamic>? activeStoreDetails,
  }) {
    rows.add(SpacingRow(_sectionGap));

    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    if (displayConfig?['showDeliveryPhone']?.visible == true) {
      final deliveryPhone = _storeText(
        activeStoreDetails,
        [
          'delivery_phone',
          'deliveryPhone',
          'phone',
          'store_phone',
          'storePhone'
        ],
        fallback: _getOptionText(
          displayConfig,
          'showDeliveryPhone',
          fallback: appSettings?.autoAssignDefaultCustomerPhone,
        ),
      );

      if (deliveryPhone.isNotEmpty) {
        rows.add(TextRow(deliveryPhone, scale: 0.85, isBold: true));
        rows.add(SpacingRow(_itemGap));
      }
    }

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

        qrMessage = _getOptionText(
          displayConfig,
          'showQRCode',
          defaultValue: isDualLanguage
              ? 'فاتورة الكترونية\nZATCA E-Invoice QR'
              : (isEnglish ? 'ZATCA E-Invoice QR' : 'فاتورة الكترونية'),
        );

        debugPrint('[StandardLayout] ZATCA QR generated: ${qrData.isNotEmpty}');
      } else {
        debugPrint('[StandardLayout] No ZATCA credentials, using payment QR');

        // Fallback to payment gateway QR
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

        qrMessage = _getOptionText(
          displayConfig,
          'showQRCode',
          defaultValue: isEnglish ? 'Scan to Pay' : 'امسح للدفع',
        );
      }

      // Display QR code if data is available
      if (qrData.isNotEmpty) {
        rows.add(TextRow(qrMessage, scale: 0.9));
        rows.add(SpacingRow(_itemGap));
        rows.add(QrRow(qrData, size: 220));

        // Show VAT footer based on document display configuration.
        final bool showVatFooter =
            displayConfig?['showVATFooter']?.visible == true;
        if (showVatFooter &&
            params.hasZatcaCredentials &&
            params.zatcaVatNumber != null) {
          rows.add(SpacingRow(_itemGap));
          final vatLabel =
              _getOptionText(displayConfig, 'showVATFooter').trim();
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
      final termsText = _getOptionText(
        displayConfig,
        'showTermsConditions',
        fallback: params.billDocumentConfig.terms,
      );

      if (termsText.isNotEmpty) {
        rows.add(TextRow(termsText.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message - Elegant
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final messageText = _getOptionText(
        displayConfig,
        'showThankYouMessage',
        fallback: params.billDocumentConfig.footer,
        defaultValue:
            isEnglish ? 'Thank You for Your Visit!' : 'شكراً لزيارتكم!',
      );

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

  /// Get text from display config with priority: value > defaultValue > fallback > default
  String _getOptionText(
    Map<String, DisplayOption>? displayConfig,
    String key, {
    String? fallback,
    String defaultValue = '',
  }) {
    final option = displayConfig?[key];
    final value = option?.value;
    if (value is String && value.isNotEmpty) {
      return value;
    }

    final configuredDefault = option?.defaultValue;
    if (configuredDefault != null && configuredDefault.isNotEmpty) {
      return configuredDefault;
    }

    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return defaultValue;
  }

  Future<Map<String, dynamic>?> _loadActiveStoreDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeStoreJson = prefs.getString('active_store');
      if (activeStoreJson == null || activeStoreJson.isEmpty) {
        return null;
      }

      final decoded = json.decode(activeStoreJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (e) {
      debugPrint('[MultiStoreReceiptLayout] Error loading active store: $e');
    }
    return null;
  }

  String _storeText(
    Map<String, dynamic>? activeStoreDetails,
    List<String> keys, {
    String fallback = '',
  }) {
    if (activeStoreDetails != null) {
      for (final key in keys) {
        final value = activeStoreDetails[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }
    return fallback.trim();
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

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    return PrintLogoLoader.loadUiLogo(url, tag: '[multi_store_receipt_layout]');
  }

  /// Load an image from Flutter assets
  Future<ui.Image?> _loadAssetImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final fi = await codec.getNextFrame();
      return fi.image;
    } catch (e) {
      debugPrint("[MultiStoreReceiptLayout] Error loading asset image: $e");
    }
    return null;
  }
}

/// Thin solid line divider for Standard theme
