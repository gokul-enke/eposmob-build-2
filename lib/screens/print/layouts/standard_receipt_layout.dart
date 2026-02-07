import 'package:flutter/foundation.dart';
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

/// Standard receipt layout - Modern & Clean design.
///
/// This layout features:
/// - Generous whitespace between sections
/// - Thin solid line dividers
/// - Clean, centered header with balanced typography
/// - Bilingual support (English/Arabic) like the reference
/// - Streamlined totals section with clear hierarchy
/// - Minimal, elegant footer
class StandardReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Standard theme spacing constants
  static const double _sectionGap = 20.0;
  static const double _itemGap = 8.0;
  static const double _headerGap = 15.0;

  @override
  String get layoutId => 'standard';

  @override
  String get displayName => 'Standard';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== STANDARD LAYOUT: THERMAL PRINTING ====");

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
            part1Rows.add(SpacingRow(_headerGap));
          }
        } catch (e) {
          debugPrint("[STANDARD] Error loading logo: $e");
        }
      }

      // ========== HEADER SECTION (Modern & Clean) ==========
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings);

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
      debugPrint("Rendering standard receipt images...");

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
          final String desktopPath = 'C:/Users/gokul/Desktop';
          final String timestamp =
              DateTime.now().millisecondsSinceEpoch.toString();

          final File file1 =
              File('$desktopPath/receipt_${timestamp}_part1.png');
          await file1.writeAsBytes(img.encodePng(imagePart1));
          debugPrint("Saved debug image to: ${file1.path}");

          final File file2 =
              File('$desktopPath/receipt_${timestamp}_part2.png');
          await file2.writeAsBytes(img.encodePng(imagePart2));
          debugPrint("Saved debug image to: ${file2.path}");
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
        "[StandardReceiptLayout] buildPdf - delegating to StandardPrinter");
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
    final bool isDualLanguage = params.billDocumentConfig.language == 'ar';

    // Store Name - Large, centered, clean
    if (displayConfig?['showStoreName']?.visible == true) {
      String storeNameText;

      if (isDualLanguage) {
        // Dual Language mode (ar): Arabic on top, English on bottom
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicName =
            displayConfig?['showStoreName']?.value as String? ?? '';
        String englishName =
            displayConfig?['showStoreName']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        if (arabicName.isEmpty && englishName.isEmpty) {
          englishName = billDocumentConfig.header ?? 'STORE NAME';
        }

        storeNameText =
            _getBilingualText(arabic: arabicName, english: englishName);
      } else {
        // Single language mode
        storeNameText = displayConfig?['showStoreName']?.value as String? ??
            billDocumentConfig.header ??
            'STORE NAME';
      }

      // Dynamic scaling based on name length
      double storeNameScale = 1.8;
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

      rows.add(TextRow(storeNameText.toUpperCase(),
          isBold: true, scale: storeNameScale));
    }

    // Description/Subheader - Arabic subtitle style
    if (displayConfig?['showDescription']?.visible == true) {
      String descriptionText;

      if (isDualLanguage) {
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicDesc =
            displayConfig?['showDescription']?.value as String? ?? '';
        String englishDesc =
            displayConfig?['showDescription']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        if (arabicDesc.isEmpty && englishDesc.isEmpty) {
          englishDesc = billDocumentConfig.subheader ?? '';
        }

        descriptionText =
            _getBilingualText(arabic: arabicDesc, english: englishDesc);
      } else {
        descriptionText = displayConfig?['showDescription']?.value as String? ??
            billDocumentConfig.subheader ??
            '';
      }

      if (descriptionText.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(descriptionText, scale: 1.0, isBold: true));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      String addressText;

      if (isDualLanguage) {
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicAddress =
            displayConfig?['showStoreAddress']?.value as String? ?? '';
        String englishAddress =
            displayConfig?['showStoreAddress']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        // No fallback available for address - just use empty string
        if (arabicAddress.isEmpty && englishAddress.isEmpty) {
          // No fallback - keep both empty
        }

        addressText =
            _getBilingualText(arabic: arabicAddress, english: englishAddress);
      } else {
        addressText =
            displayConfig?['showStoreAddress']?.value as String? ?? '';
      }

      if (addressText.isNotEmpty) {
        rows.add(TextRow(addressText, scale: 0.85, isBold: true));
      }
    }

    // Invoice Title (Moved above Tax/Fssai Info)
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitleText = isDualLanguage
          ? _getBilingualLabel(
              displayConfig, 'showInvoiceTitle', null, null, '', 'INVOICE')
          : _getDisplayValue(
              displayConfig?['showInvoiceTitle']?.value,
              appSettings?.printTitle,
              'INVOICE',
            );

      if (invoiceTitleText.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(
            TextRow(invoiceTitleText.toUpperCase(), isBold: true, scale: 1.1));
        rows.add(SpacingRow(2));
      }
    }

    // Extra Heading 1
    if (displayConfig?['showExtraHeading1']?.visible == true) {
      String extraHeading1Text;

      if (isDualLanguage) {
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicExtra1 =
            displayConfig?['showExtraHeading1']?.value as String? ?? '';
        String englishExtra1 =
            displayConfig?['showExtraHeading1']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        if (arabicExtra1.isEmpty && englishExtra1.isEmpty) {
          // No fallback available for extra headings - keep both empty
        }

        extraHeading1Text =
            _getBilingualText(arabic: arabicExtra1, english: englishExtra1);
      } else {
        extraHeading1Text =
            displayConfig?['showExtraHeading1']?.value as String? ?? '';
      }

      if (extraHeading1Text.isNotEmpty) {
        rows.add(SpacingRow(2));
        rows.add(TextRow(extraHeading1Text, scale: 0.95, isBold: true));
      }
    }

    // Extra Heading 2
    if (displayConfig?['showExtraHeading2']?.visible == true) {
      String extraHeading2Text;

      if (isDualLanguage) {
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicExtra2 =
            displayConfig?['showExtraHeading2']?.value as String? ?? '';
        String englishExtra2 =
            displayConfig?['showExtraHeading2']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        if (arabicExtra2.isEmpty && englishExtra2.isEmpty) {
          // No fallback available for extra headings - keep both empty
        }

        extraHeading2Text =
            _getBilingualText(arabic: arabicExtra2, english: englishExtra2);
      } else {
        extraHeading2Text =
            displayConfig?['showExtraHeading2']?.value as String? ?? '';
      }

      if (extraHeading2Text.isNotEmpty) {
        rows.add(SpacingRow(2));
        rows.add(TextRow(extraHeading2Text, scale: 0.95, isBold: true));
      }
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      String fssaiInfoText;

      if (isDualLanguage) {
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicFssai =
            displayConfig?['showFssaiInfo']?.value as String? ?? '';
        String englishFssai =
            displayConfig?['showFssaiInfo']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        // No fallback available for FSSAI info - keep both empty
        if (arabicFssai.isEmpty && englishFssai.isEmpty) {
          // No fallback - keep both empty
        }

        fssaiInfoText =
            _getBilingualText(arabic: arabicFssai, english: englishFssai);
      } else {
        fssaiInfoText = displayConfig?['showFssaiInfo']?.value as String? ?? '';
      }

      if (fssaiInfoText.isNotEmpty) {
        rows.add(TextRow(fssaiInfoText, scale: 0.85, isBold: true));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      String telephoneText;

      if (isDualLanguage) {
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicTel = displayConfig?['showTel']?.value as String? ?? '';
        String englishTel = displayConfig?['showTel']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        if (arabicTel.isEmpty && englishTel.isEmpty) {
          englishTel = appSettings?.customerCarePhone ?? '';
        }

        telephoneText =
            _getBilingualText(arabic: arabicTel, english: englishTel);
      } else {
        telephoneText = displayConfig?['showTel']?.value as String? ??
            appSettings?.customerCarePhone ??
            '';
      }

      if (telephoneText.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(telephoneText, scale: 0.9, isBold: true));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      String emailText;

      if (isDualLanguage) {
        // Refined fallback: Only use fallback if BOTH config values are empty
        final arabicEmail = displayConfig?['showEmail']?.value as String? ?? '';
        String englishEmail = displayConfig?['showEmail']?.defaultValue ?? '';

        // Only use fallback if both config values are empty
        if (arabicEmail.isEmpty && englishEmail.isEmpty) {
          englishEmail = appSettings?.customerCareEmail ?? '';
        }

        emailText =
            _getBilingualText(arabic: arabicEmail, english: englishEmail);
      } else {
        emailText = displayConfig?['showEmail']?.value as String? ??
            appSettings?.customerCareEmail ??
            '';
      }

      if (emailText.isNotEmpty) {
        rows.add(TextRow(emailText, scale: 0.9, isBold: true));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(StandardThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Invoice Number - Use API prefix with stripped zeros/prefixes
    if (displayConfig?['showInvoiceNumber']?.visible == true) {
      // Extract first significant number sequence (strip leading zeros and non-numeric prefixes)
      // For "ORD-000430", this extracts "430"
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      // Use number_prefix from document configuration as the invoice prefix
      final String invoicePrefix = params.billDocumentConfig.numberPrefix ?? 'INV-';

      final invoiceNumberText = '$invoicePrefix$strippedNumber';
      rows.add(TextRow(invoiceNumberText, scale: 0.9, isBold: true));
    }

    // Token Number - Display right after invoice number in big font (same as store name)
    // Only show if showTokenNumber is explicitly enabled (default: false)
    if (displayConfig?['showTokenNumber']?.visible == true &&
        params.tokenNumber != null && 
        params.tokenNumber!.isNotEmpty) {
      final tokenPrefix = displayConfig?['showTokenNumber']?.value as String? ?? '';
      final tokenText = tokenPrefix.isNotEmpty
          ? '$tokenPrefix${params.tokenNumber!}'
          : params.tokenNumber!;
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

    if (params.customerName == null &&
        params.customerPhone == null &&
        params.customerAddress == null &&
        params.orderComment == null) {
      return;
    }

    // Paper size aware scaling
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;
    final bool isDualLanguage = params.billDocumentConfig.language == 'ar';

    // Use horizontal bilingual format for labels in dual language mode
    final customerLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(displayConfig, 'showCustomerName', null,
            null, "العميل:", "Customer:")
        : _getLabel(displayConfig, 'showCustomerName', null,
            isEnglish ? "Customer:" : "العميل:");
    final phoneLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(
            displayConfig, 'showCustomerPhone', null, null, "الهاتف:", "Phone:")
        : _getLabel(displayConfig, 'showCustomerPhone', null,
            isEnglish ? "Phone:" : "الهاتف:");
    final paymentLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(
            displayConfig,
            displayConfig?.containsKey('showPaymentMethod') == true
                ? 'showPaymentMethod'
                : 'showPayment',
            null,
            null,
            "الدفع:",
            "Payment:")
        : _getLabel(
            displayConfig,
            displayConfig?.containsKey('showPaymentMethod') == true
                ? 'showPaymentMethod'
                : 'showPayment',
            null,
            isEnglish ? "Payment:" : "الدفع:");
    final addressLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(displayConfig, 'showCustomerAddress',
            null, null, "العنوان:", "Address:")
        : _getLabel(displayConfig, 'showCustomerAddress', null,
            isEnglish ? "Address:" : "العنوان:");
    final commentLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(
            displayConfig,
            displayConfig?.containsKey('showOrderComment') == true
                ? 'showOrderComment'
                : 'showComment',
            null,
            null,
            "تعليق:",
            "Comment:")
        : _getLabel(
            displayConfig,
            displayConfig?.containsKey('showOrderComment') == true
                ? 'showOrderComment'
                : 'showComment',
            null,
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

      if (params.paymentMethod != null && params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
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

      if (params.customerAddress != null &&
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
    final bool isDualLanguage = params.billDocumentConfig.language == 'ar';

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
    final String mrpLabel =
        _getLabel(displayConfig, 'showMRP', resolvedLabels?.mrp, "MRP");
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
            "#",
            "SL#")
        : _getLabel(displayConfig, 'showSLNumber', resolvedLabels?.slNumber,
            isEnglish ? "SL#" : "#");

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
          // Left aligned, no padding needed
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(productName, weight: 1.0, align: TextAlign.left),
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
    final bool isDualLanguage = params.billDocumentConfig.language == 'ar';

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

    // Labels - Use horizontal bilingual format for dual language mode
    final subtotalLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(displayConfig, 'showMRPTotal', null,
            null, "المجموع", "NET TOTAL (Exc Tax)")
        : _getLabel(displayConfig, 'showMRPTotal', null,
            isEnglish ? "NET TOTAL (Exc Tax)" : "المجموع");

    final discountLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(
            displayConfig, 'showDiscount', null, null, "الخصم", "DISCOUNTS")
        : _getLabel(displayConfig, 'showDiscount', null,
            isEnglish ? "DISCOUNTS" : "الخصم");

    final vatLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(displayConfig, 'showTax',
            resolvedLabels?.tax, resolvedLabels?.taxDefault, "الضريبة", "VAT")
        : _getLabel(displayConfig, 'showTax', resolvedLabels?.tax, "VAT");

    final grandTotalLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(displayConfig, 'showNetAmount', null,
            null, "المبلغ الاجمالي", "GRAND TOTAL")
        : _getLabel(displayConfig, 'showNetAmount', null,
            isEnglish ? "GRAND TOTAL" : "المبلغ الاجمالي");

    final cashLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(
            displayConfig, 'showCash', null, null, "نقدي", "Cash")
        : _getLabel(
            displayConfig, 'showCash', null, isEnglish ? "Cash" : "نقدي");
    final changeLabel = isDualLanguage
        ? _getBilingualLabelHorizontal(
            displayConfig, 'showChange', null, null, "متبقي", "CHANGE")
        : _getLabel(
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
    // Only show if paidAmount is provided (not null) and showPaymentBreaked is true or missing (default true)
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

      rows.add(
          TextRow(amountInWords, scale: is58mm ? 0.7 : 0.85, isBold: true));
    }

    // Items Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      final itemsCountText = isDualLanguage
          ? _getBilingualText(
              arabic:
                  displayConfig?['showItemsCount']?.value as String? ?? 'العدد',
              english:
                  displayConfig?['showItemsCount']?.defaultValue ?? 'Items')
          : (displayConfig?['showItemsCount']?.value as String? ?? 'Items');

      if (itemsCountText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow('$itemsCountText: ${params.cartItems.length}',
            scale: is58mm ? 0.75 : 0.85, isBold: true));
      }
    }

    // You Saved
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      final savedLabel = isDualLanguage
          ? _getBilingualLabelHorizontal(
              displayConfig, 'showSaved', null, null, "لقد وفرت:", "You Saved:")
          : _getLabel(displayConfig, 'showSaved', null,
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
    final bool isDualLanguage = params.billDocumentConfig.language == 'ar';

    rows.add(SpacingRow(_itemGap));
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    // Get labels from displayConfig - shorter for 58mm
    // Use horizontal bilingual format for dual language mode
    final prevBalanceLabelBase = isDualLanguage
        ? _getBilingualLabelHorizontal(displayConfig, 'showCustomerPrevBalance',
            null, null, "الرصيد السابق", "Previous Balance")
        : _getLabel(displayConfig, 'showCustomerPrevBalance', null,
            isEnglish ? "Previous Balance" : "الرصيد السابق");
    final prevBalanceLabel =
        is58mm && isDualLanguage ? "السابق   Previous" : prevBalanceLabelBase;

    final paidAmountLabelBase = isDualLanguage
        ? _getBilingualLabelHorizontal(displayConfig, 'showCustomerPaidAmount',
            null, null, "المبلغ المدفوع", "Paid Amount")
        : _getLabel(displayConfig, 'showCustomerPaidAmount', null,
            isEnglish ? "Paid Amount" : "المبلغ المدفوع");
    final paidAmountLabel =
        is58mm && isDualLanguage ? "المدفوع   Paid" : paidAmountLabelBase;

    final currentBalanceLabelBase = isDualLanguage
        ? _getBilingualLabelHorizontal(
            displayConfig,
            'showCustomerCurrentBalance',
            null,
            null,
            "الرصيد الحالي",
            "Current Balance")
        : _getLabel(displayConfig, 'showCustomerCurrentBalance', null,
            isEnglish ? "Current Balance" : "الرصيد الحالي");
    final currentBalanceLabel =
        is58mm && isDualLanguage ? "الحالي   Current" : currentBalanceLabelBase;

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

    final bool isDualLanguage = params.billDocumentConfig.language == 'ar';

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
          invoiceDate: params.orderDate,
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
        rows.add(SpacingRow(5));
        rows.add(QrRow(qrData, size: 220));

        // Show VAT number below QR for ZATCA receipts
        if (params.hasZatcaCredentials && params.zatcaVatNumber != null) {
          rows.add(SpacingRow(5));
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

    // Order Number (with visibility check)
    if (displayConfig?['showOrderNumber']?.visible != false) {
      // Extract first significant number sequence (strip leading zeros and non-numeric prefixes)
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      // Use number_prefix from document configuration as the invoice prefix
      final String invoicePrefix = params.billDocumentConfig.numberPrefix ?? 'INV-';

      rows.add(SpacingRow(3));
      rows.add(TextRow('$invoicePrefix$strippedNumber', scale: 0.8));
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
      rows.add(StandardThinDividerRow());
      rows.add(SpacingRow(5));
      rows.add(
          TextRow('$invoicePrefix$strippedNumber', scale: 1.1, isBold: true));
    }

    rows.add(SpacingRow(_itemGap));

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      String termsText;
      if (isDualLanguage) {
        final arabicTerms =
            displayConfig?['showTermsConditions']?.value as String? ?? '';
        final englishTerms =
            displayConfig?['showTermsConditions']?.defaultValue ?? '';

        // Fallback to billDocumentConfig.terms if both config values are empty
        if (arabicTerms.isEmpty && englishTerms.isEmpty) {
          final docTerms = params.billDocumentConfig.terms ?? '';
          if (docTerms.isNotEmpty) {
            termsText = docTerms;
          } else {
            termsText =
                _getBilingualText(arabic: arabicTerms, english: englishTerms);
          }
        } else {
          termsText =
              _getBilingualText(arabic: arabicTerms, english: englishTerms);
        }
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
        final arabicMessage =
            displayConfig?['showThankYouMessage']?.value as String? ?? '';
        final englishMessage =
            displayConfig?['showThankYouMessage']?.defaultValue ?? '';

        // Fallback to billDocumentConfig.footer if both config values are empty
        if (arabicMessage.isEmpty && englishMessage.isEmpty) {
          final docFooter = params.billDocumentConfig.footer ?? '';
          if (docFooter.isNotEmpty) {
            messageText = docFooter;
          } else {
            // Use default bilingual thank you message
            messageText = _getBilingualText(
                arabic: 'شكراً لزيارتكم!',
                english: 'Thank You for Your Visit!');
          }
        } else {
          messageText =
              _getBilingualText(arabic: arabicMessage, english: englishMessage);
        }
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
  /// Returns Arabic on top, English on bottom separated by newline
  String _getBilingualText({String? arabic, String? english}) {
    if (arabic != null && arabic.isNotEmpty) {
      if (english != null && english.isNotEmpty) {
        return '$arabic\n$english';
      }
      return arabic;
    } else if (english != null && english.isNotEmpty) {
      return english;
    }
    return '';
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
    final configValueArabic = displayConfig?[key]?.value as String?;
    final configValueEnglish = displayConfig?[key]?.defaultValue;

    // Check for presence of custom Arabic text
    final bool hasCustomArabic =
        (configValueArabic != null && configValueArabic.isNotEmpty) ||
            (resolvedLabelArabic != null && resolvedLabelArabic.isNotEmpty);

    // Check for presence of custom English text
    final bool hasCustomEnglish =
        (configValueEnglish != null && configValueEnglish.isNotEmpty) ||
            (resolvedLabelEnglish != null && resolvedLabelEnglish.isNotEmpty);

    // Determine whether to use static fallbacks
    final bool useStaticFallback = !hasCustomArabic && !hasCustomEnglish;

    // Get Arabic part
    String arabic = '';
    if (hasCustomArabic) {
      if (configValueArabic != null && configValueArabic.isNotEmpty) {
        arabic = configValueArabic;
      } else if (resolvedLabelArabic != null &&
          resolvedLabelArabic.isNotEmpty) {
        arabic = resolvedLabelArabic;
      }
    } else if (useStaticFallback) {
      arabic = defaultArabic;
    }

    // Get English part
    String english = '';
    if (hasCustomEnglish) {
      if (configValueEnglish != null && configValueEnglish.isNotEmpty) {
        english = configValueEnglish;
      } else if (resolvedLabelEnglish != null &&
          resolvedLabelEnglish.isNotEmpty) {
        english = resolvedLabelEnglish;
      }
    } else if (useStaticFallback) {
      english = defaultEnglish;
    }

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
    final configValueArabic = displayConfig?[key]?.value as String?;
    final configValueEnglish = displayConfig?[key]?.defaultValue;

    // Check for presence of custom Arabic text
    final bool hasCustomArabic =
        (configValueArabic != null && configValueArabic.isNotEmpty) ||
            (resolvedLabelArabic != null && resolvedLabelArabic.isNotEmpty);

    // Check for presence of custom English text
    final bool hasCustomEnglish =
        (configValueEnglish != null && configValueEnglish.isNotEmpty) ||
            (resolvedLabelEnglish != null && resolvedLabelEnglish.isNotEmpty);

    // Determine whether to use static fallbacks
    final bool useStaticFallback = !hasCustomArabic && !hasCustomEnglish;

    // Get Arabic part
    String arabic = '';
    if (hasCustomArabic) {
      if (configValueArabic != null && configValueArabic.isNotEmpty) {
        arabic = configValueArabic;
      } else if (resolvedLabelArabic != null &&
          resolvedLabelArabic.isNotEmpty) {
        arabic = resolvedLabelArabic;
      }
    } else if (useStaticFallback) {
      arabic = defaultArabic;
    }

    // Get English part
    String english = '';
    if (hasCustomEnglish) {
      if (configValueEnglish != null && configValueEnglish.isNotEmpty) {
        english = configValueEnglish;
      } else if (resolvedLabelEnglish != null &&
          resolvedLabelEnglish.isNotEmpty) {
        english = resolvedLabelEnglish;
      }
    } else if (useStaticFallback) {
      english = defaultEnglish;
    }

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
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final fi = await codec.getNextFrame();
        return fi.image;
      }
    } catch (e) {
      debugPrint("[StandardReceiptLayout] Error fetching image: $e");
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
      debugPrint("[StandardReceiptLayout] Error loading asset image: $e");
    }
    return null;
  }
}

/// Thin solid line divider for Standard theme
class StandardThinDividerRow extends ReceiptRow {
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

    canvas.drawLine(
      Offset(0, y + 3),
      Offset(width, y + 3),
      paint,
    );
  }
}

/// Dotted divider for emphasis sections
class StandardDottedDividerRow extends ReceiptRow {
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
class StandardBoxedTotalsRow extends ReceiptRow {
  final List<StandardBoxedLineItem> items;
  final double cornerRadius;
  final double padding;

  StandardBoxedTotalsRow({
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
          final double iconSize = itemFontSize * 1.2;
          final src = Rect.fromLTWH(
              0, 0, item.icon!.width.toDouble(), item.icon!.height.toDouble());
          final dst = Rect.fromLTWH(
              padding, currentY - (iconSize * 0.1), iconSize, iconSize);
          canvas.drawImageRect(item.icon!, src, dst, Paint());
          valueOffsetX += iconSize + 4; // Space after icon
        }

        // Value on Left (after icon)
        _drawScaledText(
          canvas,
          item.value,
          Offset(valueOffsetX, currentY),
          (width * 0.50) - (valueOffsetX - padding),
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
          width * 0.70,
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

class StandardBoxedLineItem {
  final String label;
  final String value;
  final bool isBold;
  final double scale;
  final bool isSeparator;
  final ui.Image? icon;

  StandardBoxedLineItem({
    this.label = '',
    this.value = '',
    this.isBold = false,
    this.scale = 1.0,
    this.isSeparator = false,
    this.icon,
  });
}
