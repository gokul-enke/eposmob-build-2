import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';

import 'receipt_layout.dart';
import 'receipt_layout_params.dart';
import 'contract_receipt_layout.dart';
import '../logo_loader.dart';
import 'package:pos_machine/screens/print/thermal/debug_image_saver.dart';
// import 'thermal/printer_utils.dart';

/// Standard receipt layout - Modern & Clean design.
///
/// This layout features:
/// - Generous whitespace between sections
/// - Thin solid line dividers
/// - Clean, centered header with balanced typography
/// - Bilingual support (English/Arabic) like the reference
/// - Streamlined totals section with clear hierarchy
/// - Minimal, elegant footer
class supermarket3ReciptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Ultra-compact spacing for Supermarket
  static const double _sectionGap = 0.0;
  static const double _itemGap = 0.0;
  static const double _smallItemGap = 3.0;
  static const double _headerGap = 0.0;

  /// Helper to check visibility from display config.
  /// Defaults to true (visible) when displayConfig is null or key is missing.
  bool _isVisible(Map<String, DisplayOption>? displayConfig, String key) {
    return displayConfig?[key]?.visible ?? true;
  }

  @override
  String get layoutId => 'supermarkerrecpt3';

  @override
  String get displayName => 'Supermarker Recpt3';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    if (ReceiptContractDelegate.enabled) {
      await ReceiptContractDelegate.printThermal(params);
      return;
    }
    debugPrint("===== supermarket LAYOUT: THERMAL PRINTING ====");

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
            part1Rows.add(ImageRow(logo, height: printWidth * 0.22));
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
      if (!params.isReturnOnly) {
        _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);
      }

      // ========== TOTALS SECTION (Bilingual Style) ==========
      if (!params.isReturnOnly) {
        _buildTotalsSection(part1Rows, params, displayConfig, isEnglish,
            sarSymbol, appSettings?.currency ?? 'INR');
      }

      // ========== RETURN ITEMS SECTION ==========
      if (params.orderReturns != null &&
          params.orderReturns!.returnItems != null &&
          params.orderReturns!.returnItems!.isNotEmpty) {
        _buildReturnSection(part1Rows, params, displayConfig, isEnglish,
            sarSymbol, appSettings?.currency ?? 'INR');
        if (!params.isReturnOnly) {
          _buildFinalSummarySection(part1Rows, params, displayConfig, isEnglish,
              sarSymbol, appSettings?.currency ?? 'INR');
        }
      }

      // ========== FOOTER SECTION (Part 2) ==========
      await _buildFooterSection(
          part2Rows, params, displayConfig, isEnglish, context);

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
      if (kDebugMode || selectedPrinter.isDevelopment) {
        try {
          final savedFile = await PrintDebugImageSaver.saveReceiptImages(
            imagePart1,
            imagePart2,
            params.selectedPaperSize,
            developmentOutput: selectedPrinter.isDevelopment,
            orderNumber: params.orderNumber,
            layoutId: layoutId,
          );
          if (selectedPrinter.isDevelopment) {
            if (savedFile != null && context.mounted) {
              showScaffold(
                context: context,
                message: 'print.development_print_saved'.trParams({'path': savedFile.path}),
              );
            }
            return;
          }
        } catch (e) {
          debugPrint("Error saving debug images: $e");
          if (selectedPrinter.isDevelopment) {
            rethrow;
          }
        }
      }
      // ===================================================

      // ========== GENERATE ESC/POS BYTES ==========
      debugPrint("Generating ESC/POS bytes...");
      final profile = await CapabilityProfile.load();
      final generator = params.thermalPaperProfile.createGenerator(profile);
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
      await _printerUtils.sendPrintJob(selectedPrinter, bytes);
      debugPrint("Print job sent successfully.");

      if (context.mounted) {
        showScaffold(context: context, message: 'print.job_sent_successfully'.tr);
        // Note: Navigation is now handled by the caller
        // PrintPage has its own back button, auto-print doesn't need navigation
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR in Standard Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: 'print.error_printing'.trParams({'error': e.toString()}));
      }
      rethrow;
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("===== END STANDARD LAYOUT PRINTING =====");
    }
  }

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) async {
    if (ReceiptContractDelegate.enabled) {
      return ReceiptContractDelegate.buildPdf(params);
    }
    debugPrint("[Templet1Layout] buildPdf - delegating to StandardPrinter");
    return pw.Document();
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    if (ReceiptContractDelegate.enabled) {
      await ReceiptContractDelegate.printThermalNative(params);
      return;
    }
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
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    final documentHeader = (billDocumentConfig.header ?? '').trim();
    final documentSubheader = (billDocumentConfig.subheader ?? '').trim();

    if (documentHeader.isNotEmpty) {
      rows.add(TextRow(documentHeader, isBold: true, scale: 1.0));
      rows.add(SpacingRow(_itemGap));
    }

    if (documentSubheader.isNotEmpty) {
      rows.add(TextRow(documentSubheader, isBold: true, scale: 0.85));
      rows.add(SpacingRow(_itemGap));
    }

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
          englishName = params.storeName?.isNotEmpty == true
              ? params.storeName!
              : 'STORE NAME';
        }

        storeNameText =
            _getBilingualText(arabic: arabicName, english: englishName);
      } else {
        // Single language mode
        final _configSN = displayConfig?['showStoreName']?.value as String?;
        storeNameText = (_configSN != null && _configSN.isNotEmpty)
            ? _configSN
            : (params.storeName?.isNotEmpty == true
                ? params.storeName!
                : 'STORE NAME');
      }

      // Dynamic scaling based on name length
      double storeNameScale = 1.5;
      // For bilingual, consider the longer of the two languages
      int maxLength = storeNameText
          .split('\n')
          .map((s) => s.length)
          .reduce((a, b) => a > b ? a : b);
      if (maxLength > 20) {
        storeNameScale = 1.15;
      } else if (maxLength > 14) {
        storeNameScale = 1.3;
      }

      rows.add(TextRow(storeNameText.trim().toUpperCase(),
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
          englishDesc = '';
        }

        descriptionText =
            _getBilingualText(arabic: arabicDesc, english: englishDesc);
      } else {
        descriptionText =
            displayConfig?['showDescription']?.value as String? ?? '';
      }

      if (descriptionText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(descriptionText.trim(), scale: 0.9, isBold: true));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final addressVal = params.storeLocation ?? '';
      String addressText = '';
      if (addressVal.isNotEmpty) {
        if (isDualLanguage) {
          final arabicLabel =
              displayConfig?['showStoreAddress']?.value as String? ?? '';
          final englishLabel =
              displayConfig?['showStoreAddress']?.defaultValue ?? '';
          final label =
              _getBilingualText(arabic: arabicLabel, english: englishLabel);
          addressText = label.isNotEmpty ? '$label: $addressVal' : addressVal;
        } else {
          final label =
              displayConfig?['showStoreAddress']?.value as String? ?? '';
          addressText = label.isNotEmpty ? '$label: $addressVal' : addressVal;
        }
      }
      if (addressText.isNotEmpty) {
        rows.add(TextRow(addressText, scale: 0.75, isBold: true));
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
        rows.add(SpacingRow(_itemGap));
        rows.add(
            TextRow(invoiceTitleText.toUpperCase(), isBold: true, scale: 1.0));
        rows.add(SpacingRow(_itemGap));
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
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(extraHeading1Text, scale: 0.75, isBold: true));
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
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(extraHeading2Text, scale: 0.75, isBold: true));
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
        rows.add(TextRow(fssaiInfoText, scale: 0.75, isBold: true));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final phoneVal = params.storePhone?.isNotEmpty == true
          ? params.storePhone!
          : (appSettings?.customerCarePhone ?? '');
      String telephoneText = '';
      if (phoneVal.isNotEmpty) {
        if (isDualLanguage) {
          final arabicLabel = displayConfig?['showTel']?.value as String? ?? '';
          final englishLabel = displayConfig?['showTel']?.defaultValue ?? '';
          final label =
              _getBilingualText(arabic: arabicLabel, english: englishLabel);
          telephoneText = label.isNotEmpty ? '$label: $phoneVal' : phoneVal;
        } else {
          final label = displayConfig?['showTel']?.value as String? ?? '';
          telephoneText = label.isNotEmpty ? '$label: $phoneVal' : phoneVal;
        }
      }
      if (telephoneText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(telephoneText, scale: 0.75, isBold: true));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final emailVal = params.storeEmail?.isNotEmpty == true
          ? params.storeEmail!
          : (appSettings?.customerCareEmail ?? '');
      String emailText = '';
      if (emailVal.isNotEmpty) {
        if (isDualLanguage) {
          final arabicLabel =
              displayConfig?['showEmail']?.value as String? ?? '';
          final englishLabel = displayConfig?['showEmail']?.defaultValue ?? '';
          final label =
              _getBilingualText(arabic: arabicLabel, english: englishLabel);
          emailText = label.isNotEmpty ? '$label: $emailVal' : emailVal;
        } else {
          final label = displayConfig?['showEmail']?.value as String? ?? '';
          emailText = label.isNotEmpty ? '$label: $emailVal' : emailVal;
        }
      }
      if (emailText.isNotEmpty) {
        rows.add(TextRow(emailText, scale: 0.75, isBold: true));
      }
    }

    rows.add(SpacingRow(_sectionGap));
    rows.add(SpacingRow(_smallItemGap));
    // Thin divider line
    rows.add(StandardThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Token Number
    if (displayConfig?['showTokenNumber']?.visible == true &&
        params.tokenNumber != null &&
        params.tokenNumber!.isNotEmpty) {
      final String tokenPrefix =
          displayConfig?['showTokenNumber']?.value as String? ?? 'Token: ';
      rows.add(SpacingRow(_itemGap));
      rows.add(TextRow('$tokenPrefix${params.tokenNumber}',
          scale: 1.0, isBold: true));
    }
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

    // 1. InvNo | Date | Time Row
    final String orderDateStr = DateHelper.formatISODate(params.orderDate);
    final String orderTimeStr =
        DateHelper.formatISOTimeOnlyToIST(params.orderDate);

    final regex = RegExp(r'[1-9]\d*');
    final match = regex.firstMatch(params.orderNumber);
    final strippedNumber = match != null ? match.group(0)! : params.orderNumber;

    rows.add(ReceiptTableRow([
      ReceiptTableColumn('InvNo: $strippedNumber',
          weight: 0.3, align: TextAlign.left, scale: 0.7, isBold: true),
      ReceiptTableColumn('Date: $orderDateStr',
          weight: 0.35, align: TextAlign.center, scale: 0.7, isBold: true),
      ReceiptTableColumn('Time: $orderTimeStr',
          weight: 0.35, align: TextAlign.right, scale: 0.7, isBold: true),
    ]));
    rows.add(SpacingRow(_itemGap));

    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';
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
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
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
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(phoneText,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      }

      if (showPayment &&
          params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      }

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(addressLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(params.customerAddress!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      }

      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      }

      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(deliveryLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(params.deliveryMethod!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      }

      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty &&
          displayConfig?['showCustomerVatNumber']?.visible == true) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerVatLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(params.customerVatNumber!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerCrLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(params.customerCrNumber!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      }
    } else {
      // Arabic: Label on right, Value on left (RTL reading flow)
      if (showCustomerName &&
          params.customerName != null &&
          params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
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
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(phoneLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
        ]));
      }

      if (showPayment &&
          params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
        ]));
      }

      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
        ]));
      }

      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.deliveryMethod!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(deliveryLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
        ]));
      }

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(TextRow(params.customerAddress!, scale: 0.75));
      }

      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty &&
          displayConfig?['showCustomerVatNumber']?.visible == true) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerVatNumber!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(customerVatLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
        ]));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerCrNumber!,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(customerCrLabel,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
        ]));
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
    debugPrint("===== SUPERMARKET2 CART ITEMS DEBUG =====");
    debugPrint("Cart items count: ${params.cartItems.length}");
    debugPrint("isFromLocalStorage: ${params.isFromLocalStorage}");
    debugPrint("isEnglish: $isEnglish");
    debugPrint(
        "isDualLanguage: ${(params.billDocumentConfig.language ?? '').toLowerCase() == 'ar'}");
    debugPrint("displayConfig keys: ${displayConfig?.keys.toList() ?? 'null'}");
    debugPrint(
        "showParticulars visible: ${displayConfig?['showParticulars']?.visible}");
    debugPrint(
        "showSLNumber visible: ${displayConfig?['showSLNumber']?.visible}");
    debugPrint("showMRP visible: ${displayConfig?['showMRP']?.visible}");
    debugPrint("showQty visible: ${displayConfig?['showQty']?.visible}");
    debugPrint("showRate visible: ${displayConfig?['showRate']?.visible}");
    debugPrint("showTotal visible: ${displayConfig?['showTotal']?.visible}");
    debugPrint(
        "showTaxHeader visible: ${displayConfig?['showTaxHeader']?.visible}");
    for (int i = 0; i < params.cartItems.length; i++) {
      final item = params.cartItems[i];
      if (params.isFromLocalStorage) {
        debugPrint(
            "Item $i: name=${item['productName']}, qty=${item['quantity']}, total=${item['totalPrice']}");
      } else {
        debugPrint(
            "Item $i: name=${item.productName}, qty=${item.quantity}, total=${item.totalPrice}, tax=${item.taxAmount}");
      }
    }
    debugPrint("=========================================");

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
      if (_isVisible(displayConfig, 'showSLNumber')) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: 0.10, align: TextAlign.left, isBold: true, scale: 0.7));
      }
      if (_isVisible(displayConfig, 'showParticulars')) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.7));
      }
      if (_isVisible(displayConfig, 'showQty')) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: 0.10, align: TextAlign.center, isBold: true, scale: 0.7));
      }
      if (_isVisible(displayConfig, 'showRate')) {
        headerCols.add(ReceiptTableColumn('JRP', // As per image reference
            weight: 0.15,
            align: TextAlign.right,
            isBold: true,
            scale: 0.7));
      }
      if (_isVisible(displayConfig, 'showTaxHeader')) {
        headerCols.add(ReceiptTableColumn('GST%',
            weight: 0.10, align: TextAlign.right, isBold: true, scale: 0.7));
      }
      if (_isVisible(displayConfig, 'showTotal')) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: 0.20, align: TextAlign.right, isBold: true, scale: 0.7));
      }
    } else {
      // Arabic header (RTL)
      if (_isVisible(displayConfig, 'showTotal')) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: 0.18, align: TextAlign.right, isBold: true, scale: 0.75));
      }
      if (_isVisible(displayConfig, 'showTaxHeader')) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: 0.15, align: TextAlign.right, isBold: true, scale: 0.75));
      }
      if (_isVisible(displayConfig, 'showRate')) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: 0.15, align: TextAlign.right, isBold: true, scale: 0.75));
      }
      if (_isVisible(displayConfig, 'showQty')) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: 0.12, align: TextAlign.right, isBold: true, scale: 0.75));
      }
      if (_isVisible(displayConfig, 'showMRP')) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: 0.15, align: TextAlign.right, isBold: true, scale: 0.75));
      }
      if (_isVisible(displayConfig, 'showParticulars')) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: _isVisible(displayConfig, 'showSLNumber') ? 0.17 : 0.25,
            align: TextAlign.right,
            isBold: true,
            scale: 0.75));
      }
      if (_isVisible(displayConfig, 'showSLNumber')) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: 0.08, align: TextAlign.right, isBold: true, scale: 0.75));
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

    debugPrint(
        "_buildCartItemRow[$index]: productName='$productName', qty='$quantity', mrp='$mrp', unitPrice='$unitPrice', totalPrice='$totalPrice', tax='$itemTaxAmount', isEnglish=$isEnglish");

    if (isEnglish) {
      // 1. PRODUCT NAME (BOLD & UPPERCASE)
      String nameToDisplay = productName.toUpperCase();
      if (_isVisible(displayConfig, 'showParticulars') ||
          _isVisible(displayConfig, 'showSLNumber')) {
        String itemLabel = _isVisible(displayConfig, 'showSLNumber')
            ? '$slNumber $nameToDisplay'
            : nameToDisplay;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(itemLabel,
              weight: 1.0, align: TextAlign.left, scale: 0.75, isBold: true),
        ]));
      }

      // 2. BARCODE | QTY UNIT X PRICE | TAX% | AMOUNT
      List<ReceiptTableColumn> detailCols = [];

      // Barcode column (if visible)
      final barcode = _getCartItemText(item, isFromLocalStorage, 'barcode');

      bool showBarcode = _isVisible(displayConfig, 'showBarcode');
      detailCols.add(ReceiptTableColumn(showBarcode ? barcode : "",
          weight: 0.25, align: TextAlign.left, scale: 0.65));

      // Qty details: 0.27 KGs X 198.00
      String unit = '';
      if (!isFromLocalStorage) {
        unit = getPrintUnit(item);
      } else if (isFromLocalStorage) {
        unit = getPrintUnit(item);
      }
      String qtyDetails = '$quantity $unit X $unitPrice';
      detailCols.add(ReceiptTableColumn(qtyDetails,
          weight: 0.45, align: TextAlign.left, scale: 0.65));

      // GST%
      final gstPerc = _getCartItemTaxRate(item, isFromLocalStorage);
      detailCols.add(ReceiptTableColumn('$gstPerc%',
          weight: 0.10, align: TextAlign.right, scale: 0.65));

      // Total Price
      detailCols.add(ReceiptTableColumn(totalPrice,
          weight: 0.20, align: TextAlign.right, scale: 0.7, isBold: true));

      rows.add(ReceiptTableRow(detailCols));

      // 3. MRP | HSN | DD
      List<ReceiptTableColumn> subDetailCols = [];
      subDetailCols.add(ReceiptTableColumn("", weight: 0.10)); // Indent

      // MRP
      if (_isVisible(displayConfig, 'showMRP')) {
        subDetailCols.add(ReceiptTableColumn('MRP: $mrp',
            weight: 0.30, align: TextAlign.left, scale: 0.6));
      }

      // HSN
      final hsn = _getCartItemText(item, isFromLocalStorage, 'hsn_code');
      if (_isVisible(displayConfig, 'showHSNCode')) {
        subDetailCols.add(ReceiptTableColumn('HSN: $hsn',
            weight: 0.30, align: TextAlign.left, scale: 0.6));
      }

      // DD (Discount?)
      String dd = '0.00'; // Placeholder for DD from image
      if (_isVisible(displayConfig, 'showDiscount')) {
        subDetailCols.add(ReceiptTableColumn('DD $dd',
            weight: 0.30, align: TextAlign.right, scale: 0.6));
      }

      if (subDetailCols.length > 1) {
        rows.add(ReceiptTableRow(subDetailCols));
      }
    } else {
      // Arabic: RTL layout with bilingual names
      if (_isVisible(displayConfig, 'showParticulars') ||
          _isVisible(displayConfig, 'showSLNumber')) {
        // Show Arabic name (line 1) and English name (line 2) when available
        String itemText = '';
        if (productNameArabic.isNotEmpty) {
          // Bilingual: Arabic on line 1, English on line 2
          if (_isVisible(displayConfig, 'showSLNumber')) {
            itemText = '$slNumber. $productNameArabic';
          } else {
            itemText = productNameArabic;
          }
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText,
                weight: 1.0, align: TextAlign.right, scale: 0.75, isBold: true),
          ]));

          // Add English name on second line
          // Left aligned, no padding needed
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(productName,
                weight: 1.0, align: TextAlign.left, scale: 0.7),
          ]));
        } else {
          // Fallback to single name (English or Arabic)
          String itemText = _isVisible(displayConfig, 'showSLNumber')
              ? '$slNumber. $productName'
              : productName;
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText,
                weight: 1.0, align: TextAlign.right, scale: 0.75, isBold: true),
          ]));
        }
      }
      // Price details row (RTL order)
      List<ReceiptTableColumn> priceCols = [];
      if (_isVisible(displayConfig, 'showTotal')) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: 0.25, align: TextAlign.right, scale: 0.7, isBold: true));
      }
      if (_isVisible(displayConfig, 'showTaxHeader')) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: 0.15, align: TextAlign.right, scale: 0.7, isBold: true));
      }
      if (_isVisible(displayConfig, 'showRate')) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: 0.15, align: TextAlign.right, scale: 0.7, isBold: true));
      }
      if (_isVisible(displayConfig, 'showQty')) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: 0.12, align: TextAlign.right, scale: 0.7, isBold: true));
      }
      if (_isVisible(displayConfig, 'showMRP')) {
        priceCols.add(ReceiptTableColumn(mrp,
            weight: 0.15, align: TextAlign.right, scale: 0.7, isBold: true));
      }
      priceCols.add(ReceiptTableColumn("", weight: 0.18));
      if (priceCols.length > 1) {
        rows.add(ReceiptTableRow(priceCols));
      }
    }
  }

  String _getCartItemText(
    dynamic item,
    bool isFromLocalStorage,
    String key,
  ) {
    if (isFromLocalStorage || item is Map) {
      if (key == 'hsn_code') {
        return (item[key] ?? item['hsnCode'])?.toString() ?? '';
      }
      return item[key]?.toString() ?? '';
    }

    // Some API cart item types do not expose optional product metadata.
    try {
      return item.toJson()?[key]?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _getCartItemTaxRate(dynamic item, bool isFromLocalStorage) {
    dynamic taxes;
    if (isFromLocalStorage || item is Map) {
      taxes = item['taxes'];
    } else {
      try {
        taxes = item.taxes;
      } catch (_) {
        return '0';
      }
    }

    if (taxes is! List || taxes.isEmpty) {
      return '0';
    }

    final firstTax = taxes.first;
    if (firstTax is Map) {
      return firstTax['rate']?.toString() ?? '0';
    }

    try {
      return firstTax.rate?.toString() ?? '0';
    } catch (_) {
      return '0';
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
    final showMRPTotal = displayConfig?['showSubTotal']?.visible ??
        displayConfig?['showMRPTotal']?.visible ??
        true;
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
        isEnglish ? "Net Amount" : "صافي المبلغ");

    final discountLabel = _getLabel(displayConfig, 'showDiscount', null,
        isEnglish ? "E&OE Discount" : "خصم");

    final returnLabel = isEnglish ? "Sales Return" : "مرتجع المبيعات";
    final roundOffLabel = isEnglish ? "RoundOff" : "التقريب";

    final grandTotalLabel = _getLabel(displayConfig, 'showNetAmount', null,
        isEnglish ? "Invoice Total" : "إجمالي الفاتورة");

    // Prepare boxed items
    List<StandardBoxedLineItem> boxedItems = [];
    final totalsScale = 0.85;

    // 1. Subtotal
    if (showMRPTotal) {
      boxedItems.add(StandardBoxedLineItem(
        label: subtotalLabel,
        value: subtotal.toStringAsFixed(2),
        isBold: true,
        scale: 0.75,
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
        scale: 0.75,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 3. Sales Return
    boxedItems.add(StandardBoxedLineItem(
      label: returnLabel,
      value: "0.00", // Placeholder for now
      isBold: true,
      scale: 0.75,
      icon: currencyIcon,
      currencySymbol: currencySymbol,
    ));

    // 4. Round Off
    double roundOff = 0.0;
    try {
      // Simple calculation for round off if needed
      roundOff = total - (subtotal - discountAmountValue + taxAmount);
    } catch (e) {}

    boxedItems.add(StandardBoxedLineItem(
      label: roundOffLabel,
      value: roundOff.toStringAsFixed(2),
      isBold: true,
      scale: 0.75,
      icon: currencyIcon,
      currencySymbol: currencySymbol,
    ));

    // 5. Grand Total (Bold)
    if (showNetAmount) {
      boxedItems.add(StandardBoxedLineItem(
        label: grandTotalLabel,
        value: total.toStringAsFixed(2),
        isBold: true,
        scale: 0.9,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 5. Payment details (Separator + Payment Methods)
    // Only show if paidAmount is provided (not null) and showPaymentBreaked is true or missing (default true)
    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible ?? true;

    if (params.paidAmount != null && showPaymentBreaked) {
      boxedItems.add(StandardBoxedLineItem(isSeparator: true));

      bool isMultiPayment = false;
      final String cashLabel = isEnglish ? "Cash" : "نقدي";

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
              scale: totalsScale,
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
                  scale: totalsScale,
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
          scale: totalsScale,
          icon: currencyIcon,
          currencySymbol: currencySymbol,
        ));
      }
    }

    // Add the boxed row
    rows.add(StandardBoxedTotalsRow(items: boxedItems));

    // Payment breakdown table (CASH | CARD | COUPON | CHANGE style)
    if (showPaymentBreaked && params.paidAmount != null) {
      rows.add(SpacingRow(_itemGap));
      rows.add(StandardThinDividerRow());
      rows.add(ReceiptTableRow([
        ReceiptTableColumn("CASH",
            weight: 0.25, align: TextAlign.center, scale: 0.7, isBold: true),
        ReceiptTableColumn("CARD",
            weight: 0.25, align: TextAlign.center, scale: 0.7, isBold: true),
        ReceiptTableColumn("COUPON",
            weight: 0.25, align: TextAlign.center, scale: 0.7, isBold: true),
        ReceiptTableColumn("CHANGE",
            weight: 0.25, align: TextAlign.center, scale: 0.7, isBold: true),
      ]));

      double cashAmt = 0;
      double cardAmt = 0;
      double couponAmt = 0;
      double changeAmt = 0;

      if (params.paymentMethod == 'CASH')
        cashAmt = params.paidAmount ?? 0;
      else if (params.paymentMethod == 'CARD') cardAmt = params.paidAmount ?? 0;

      // Handle multi-payment if present
      if (params.paymentBreakdown != null) {
        cashAmt = double.tryParse(
                params.paymentBreakdown!['CASH']?.toString() ?? '0') ??
            0;
        cardAmt = double.tryParse(
                params.paymentBreakdown!['CARD']?.toString() ?? '0') ??
            0;
        couponAmt = double.tryParse(
                params.paymentBreakdown!['COUPON']?.toString() ?? '0') ??
            0;
      }

      rows.add(ReceiptTableRow([
        ReceiptTableColumn(cashAmt.toStringAsFixed(2),
            weight: 0.25, align: TextAlign.center, scale: 0.7),
        ReceiptTableColumn(cardAmt.toStringAsFixed(2),
            weight: 0.25, align: TextAlign.center, scale: 0.7),
        ReceiptTableColumn(couponAmt.toStringAsFixed(2),
            weight: 0.25, align: TextAlign.center, scale: 0.7),
        ReceiptTableColumn(changeAmt.toStringAsFixed(2),
            weight: 0.25, align: TextAlign.center, scale: 0.7),
      ]));
      rows.add(StandardThinDividerRow());
    }

    // You Saved
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      rows.add(SpacingRow(_itemGap));
      rows.add(TextRow(
        "You Have Saved ${saved.toStringAsFixed(2)}",
        isBold: true,
        scale: 0.9,
      ));
    }

    // GST Table
    if (showTax) {
      rows.add(SpacingRow(_itemGap));
      rows.add(StandardThinDividerRow());
      rows.add(ReceiptTableRow([
        ReceiptTableColumn("GST",
            weight: 0.2, align: TextAlign.left, scale: 0.65, isBold: true),
        ReceiptTableColumn("TaxableAmt",
            weight: 0.3, align: TextAlign.center, scale: 0.65, isBold: true),
        ReceiptTableColumn("SGST",
            weight: 0.15, align: TextAlign.center, scale: 0.65, isBold: true),
        ReceiptTableColumn("CGST",
            weight: 0.15, align: TextAlign.center, scale: 0.65, isBold: true),
        ReceiptTableColumn("TotalGST",
            weight: 0.2, align: TextAlign.right, scale: 0.65, isBold: true),
      ]));

      // Group taxes for the table
      // group taxes logic could be added here if needed

      rows.add(ReceiptTableRow([
        ReceiptTableColumn("0%",
            weight: 0.2, align: TextAlign.left, scale: 0.65),
        ReceiptTableColumn("0.00",
            weight: 0.3, align: TextAlign.center, scale: 0.65),
        ReceiptTableColumn("0.00",
            weight: 0.15, align: TextAlign.center, scale: 0.65),
        ReceiptTableColumn("0.00",
            weight: 0.15, align: TextAlign.center, scale: 0.65),
        ReceiptTableColumn("0.00",
            weight: 0.2, align: TextAlign.right, scale: 0.65),
      ]));
      rows.add(StandardThinDividerRow());
    }

    // Loyalty Section
    rows.add(SpacingRow(_itemGap));
    rows.add(ReceiptTableRow([
      ReceiptTableColumn("NewPoint",
          weight: 0.25, align: TextAlign.center, scale: 0.65, isBold: true),
      ReceiptTableColumn("Redeem",
          weight: 0.25, align: TextAlign.center, scale: 0.65, isBold: true),
      ReceiptTableColumn("Balance",
          weight: 0.25, align: TextAlign.center, scale: 0.65, isBold: true),
      ReceiptTableColumn("CardBalance",
          weight: 0.25, align: TextAlign.center, scale: 0.65, isBold: true),
    ]));
    rows.add(ReceiptTableRow([
      ReceiptTableColumn("0.00",
          weight: 0.25, align: TextAlign.center, scale: 0.65),
      ReceiptTableColumn("0.00",
          weight: 0.25, align: TextAlign.center, scale: 0.65),
      ReceiptTableColumn("0.00",
          weight: 0.25, align: TextAlign.center, scale: 0.65),
      ReceiptTableColumn("0.00",
          weight: 0.25, align: TextAlign.center, scale: 0.65),
    ]));
    rows.add(StandardThinDividerRow());

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(_itemGap));
      final language =
          (params.billDocumentConfig.language ?? 'en').toLowerCase();
      final amountText = AmountHelper()
          .convertNumberToWords(total, currency: currency, language: language);
      final suffix = language == 'ar' ? ' فقط.' : ' INR Only.';
      rows.add(TextRow('$amountText$suffix',
          scale: is58mm ? 0.7 : 0.8, isBold: true));
    }

    // Metadata Footer (5 Columns as per image)
    final String printDateTime =
        DateHelper.getCurrentFormattedTimeWithSecondsAMPM();

    rows.add(SpacingRow(_itemGap));
    rows.add(ReceiptTableRow([
      ReceiptTableColumn('Served by',
          weight: 0.18, align: TextAlign.left, scale: 0.55, isBold: true),
      ReceiptTableColumn('Total Item',
          weight: 0.15, align: TextAlign.center, scale: 0.55, isBold: true),
      ReceiptTableColumn('Print Date & Time',
          weight: 0.35, align: TextAlign.center, scale: 0.55, isBold: true),
      ReceiptTableColumn('Counter',
          weight: 0.16, align: TextAlign.center, scale: 0.55, isBold: true),
      ReceiptTableColumn('DD',
          weight: 0.16, align: TextAlign.right, scale: 0.55, isBold: true),
    ]));
    rows.add(ReceiptTableRow([
      ReceiptTableColumn('RECEPTION',
          weight: 0.18, align: TextAlign.left, scale: 0.55),
      ReceiptTableColumn('${params.cartItems.length}',
          weight: 0.15, align: TextAlign.center, scale: 0.55),
      ReceiptTableColumn(printDateTime,
          weight: 0.35, align: TextAlign.center, scale: 0.5),
      ReceiptTableColumn('POS-3',
          weight: 0.16, align: TextAlign.center, scale: 0.55),
      ReceiptTableColumn('0.00',
          weight: 0.16, align: TextAlign.right, scale: 0.55),
    ]));

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

  Future<void> _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    BuildContext context,
  ) async {
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
        rows.add(TextRow(qrMessage, scale: 0.75));
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
            TextRow("$dateLabel: $formattedDate  $formattedTime", scale: 0.75));
      } else {
        rows.add(TextRow("$formattedDate  $formattedTime", scale: 0.75));
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

      rows.add(SpacingRow(_itemGap));
      if (showFooterInvoice) {
        rows.add(StandardThinDividerRow());
        rows.add(SpacingRow(_itemGap));
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
        rows.add(TextRow(messageText, isBold: true, scale: 0.85));
      }
    }

    // Delivery Icon + Phone Row
    final billDocConfig = params.billDocumentConfig;
    final bool showDeliveryIcon = billDocConfig.showIcon == 1;
    final bool showDeliveryPhone =
        displayConfig?['showDeliveryPhone']?.visible == true;

    if (showDeliveryIcon || showDeliveryPhone) {
      rows.add(SpacingRow(_itemGap));

      ui.Image? deliveryIcon;
      if (showDeliveryIcon) {
        final iconUrl = billDocConfig.icon?.toString();
        if (iconUrl != null && iconUrl.isNotEmpty) {
          try {
            deliveryIcon = await _fetchNetworkUiImage(iconUrl);
          } catch (e) {
            debugPrint('[SupermarketLayout] Error loading delivery icon: $e');
          }
        }
      }

      String deliveryPhone =
          displayConfig?['showDeliveryPhone']?.value as String? ?? '';
      if (deliveryPhone.isEmpty && showDeliveryPhone) {
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        deliveryPhone =
            appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ??
                '';
      }

      if (deliveryIcon != null && deliveryPhone.isNotEmpty) {
        // Show a large icon with the phone number centered below it.
        rows.add(DeliveryInfoRow(
          icon: deliveryIcon,
          phone: deliveryPhone,
          iconSize: params.is58mm ? 110.0 : 150.0,
          scale: params.is58mm ? 1.0 : 1.1,
        ));
      } else if (deliveryIcon != null) {
        rows.add(ImageRow(
          deliveryIcon,
          width: params.is58mm ? 110 : 200,
          height: params.is58mm ? 110 : 200,
        ));
      } else if (deliveryPhone.isNotEmpty) {
        rows.add(TextRow(deliveryPhone, scale: 0.85));
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

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    return PrintLogoLoader.loadUiLogo(url,
        tag: '[supermarket3_receipt_layout]');
  }

  /// Load an image from Flutter assets
  Future<ui.Image?> _loadAssetImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final fi = await codec.getNextFrame();
      return fi.image;
    } catch (e) {
      debugPrint("[Templet1Layout] Error loading asset image: $e");
    }
    return null;
  }

  // ==================== HELPER METHODS FOR REUSABLE STYLED LINES ====================

  // ==================== RETURN ITEMS SECTION ====================

  void _buildReturnSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    ui.Image? sarSymbol,
    String currency,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty)
      return;

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;

    final retDc = params.returnBillDisplayConfig;
    final retLabels = params.returnBillResolvedLabels;
    final hasCreditNoteConfig = retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null;

    rows.add(SpacingRow(_sectionGap));
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));
    if (!hasCreditNoteConfig)
      rows.add(TextRow(params.returnsSectionHeading, isBold: true, scale: 1.1));
    rows.add(SpacingRow(_itemGap));

    // — Credit Note Details section —
    if (retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null) {
      final detailsHeading = _getLabel(retDc, 'showCreditNoteOrder',
          retLabels?.detailsHeading, 'CREDIT NOTE DETAILS');
      rows.add(TextRow(detailsHeading, isBold: true, scale: scale));
      rows.add(SpacingRow(_itemGap));
      if (retLabels?.creditNoteNumber != null) {
        final cnLabel = _getLabel(
            retDc,
            'showCreditNoteNumber',
            retLabels?.creditNoteNumber,
            isEnglish ? 'Credit Note No:' : 'رقم إشعار الائتمان:');
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(cnLabel,
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.orderNumber,
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      if (retLabels?.creditNoteDate != null) {
        final dateLabel = _getLabel(
            retDc,
            'showCreditNoteDate',
            retLabels?.creditNoteDate,
            isEnglish ? 'Credit Note Date:' : 'تاريخ إشعار الائتمان:');
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(dateLabel,
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.orderDate,
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      if (retLabels?.creditNoteReason != null) {
        final reasonLabel = _getLabel(retDc, 'showCreditNoteReason',
            retLabels?.creditNoteReason, isEnglish ? 'Reason:' : 'السبب:');
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(reasonLabel,
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn('',
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      rows.add(SpacingRow(_itemGap));
    }

    // — Customer Details section —
    if (params.customerName != null && params.customerName!.trim().isNotEmpty) {
      rows.add(TextRow(retLabels?.customerHeading ?? 'CUSTOMER DETAILS',
          isBold: true, scale: scale));
      rows.add(SpacingRow(_itemGap));
      final custLabel = isEnglish ? 'Customer Name:' : 'اسم العميل:';
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(custLabel,
            weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
        ReceiptTableColumn(params.customerName!,
            weight: 0.55, align: TextAlign.left, scale: scale),
      ]));
      if (params.customerPhone != null &&
          params.customerPhone!.trim().isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(isEnglish ? 'Phone:' : 'الهاتف:',
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerPhone!,
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      if (params.customerAddress != null &&
          params.customerAddress!.trim().isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(isEnglish ? 'Billing Address:' : 'عنوان الفاتورة:',
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerAddress!,
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      rows.add(SpacingRow(_itemGap));
    }

    if (retLabels?.itemsHeading != null) {
      rows.add(TextRow(retLabels!.itemsHeading!, isBold: true, scale: scale));
      rows.add(SpacingRow(_itemGap));
    }

    final slLabel = _getLabel(displayConfig, 'showReturnSLNumber',
        resolvedLabels?.returnSlNumber, isEnglish ? 'SL#' : '#');
    final particularsLabel = _getLabel(
        displayConfig,
        'showReturnParticulars',
        resolvedLabels?.returnParticulars,
        isEnglish ? 'PARTICULARS' : 'البيان');
    final mrpLabel = _getLabel(
        displayConfig, 'showReturnMRP', resolvedLabels?.returnMrp, 'MRP');
    final qtyLabel = _getLabel(displayConfig, 'showReturnQty',
        resolvedLabels?.returnQty, isEnglish ? 'QTY' : 'الكمية');
    final rateLabel = _getLabel(displayConfig, 'showReturnRate',
        resolvedLabels?.returnRate, isEnglish ? 'RATE' : 'السعر');
    final totalLabel = _getLabel(displayConfig, 'showReturnTotal',
        resolvedLabels?.returnTotal, isEnglish ? 'TOTAL' : 'الإجمالي');

    final bool showSl = displayConfig?['showReturnSLNumber']?.visible == true;
    final bool showParticulars =
        displayConfig?['showReturnParticulars']?.visible == true;
    final bool showMrp = displayConfig?['showReturnMRP']?.visible == true;
    final bool showQty = displayConfig?['showReturnQty']?.visible == true;
    final bool showRate = displayConfig?['showReturnRate']?.visible == true;
    final bool showTotal = displayConfig?['showReturnTotal']?.visible == true;

    final Map<String, double> baseWeights = {
      if (showSl) 'sl': 0.08,
      if (showParticulars) 'particulars': showSl ? 0.25 : 0.33,
      if (showMrp) 'mrp': 0.15,
      if (showQty) 'qty': 0.12,
      if (showRate) 'rate': 0.15,
      if (showTotal) 'total': 0.15,
    };
    final double totalW = baseWeights.values.fold<double>(0, (s, w) => s + w);
    final Map<String, double> weights = totalW > 0
        ? {for (final e in baseWeights.entries) e.key: e.value / totalW}
        : baseWeights;

    if (showSl ||
        showParticulars ||
        showMrp ||
        showQty ||
        showRate ||
        showTotal) {
      List<ReceiptTableColumn> headerCols = [];
      if (showSl)
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: weights['sl'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: scale));
      if (showParticulars)
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: weights['particulars'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: scale));
      if (showMrp)
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: weights['mrp'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: scale));
      if (showQty)
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: weights['qty'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: scale));
      if (showRate)
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: weights['rate'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: scale));
      if (showTotal)
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: weights['total'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: scale));
      rows.add(ReceiptTableRow(headerCols));
      rows.add(StandardThinDividerRow());
    }

    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final num itemQty = returnItem.quantity ?? 0;
      final String productName = returnItem.productName ?? '';
      double itemMrp = 0.0, itemRate = 0.0;
      for (var cartItem in params.cartItems) {
        String cartName = '';
        double cartRate = 0.0, cartMrp = 0.0;
        if (params.isFromLocalStorage || cartItem is Map) {
          cartName = (cartItem['product_name'] ?? cartItem['productName'] ?? '')
              .toString();
          cartRate = double.tryParse(
                  (cartItem['unit_price'] ?? cartItem['unitPrice'])
                          ?.toString() ??
                      '0') ??
              0.0;
          cartMrp = double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
        } else {
          try {
            cartName = cartItem.productName?.toString() ?? '';
            cartRate =
                double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
            cartMrp = double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0;
          } catch (_) {}
        }
        if (cartName == productName) {
          itemRate = cartRate;
          itemMrp = cartMrp;
          break;
        }
      }
      if (itemRate == 0.0) {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
        num totalQty = 0;
        for (var ri in orderReturns.returnItems!) {
          totalQty += ri.quantity ?? 0;
        }
        itemRate = totalQty > 0 ? totalReturnAmount / totalQty : 0.0;
        itemMrp = itemRate;
      }
      final double itemTotal = itemQty * itemRate;
      if (showParticulars || showSl) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(showSl ? '${i + 1}. $productName' : productName,
              weight: 1.0, align: TextAlign.left, scale: scale)
        ]));
      }
      final double dw = (weights['sl'] ?? 0) + (weights['particulars'] ?? 0);
      List<ReceiptTableColumn> priceCols = [];
      if (dw > 0) priceCols.add(ReceiptTableColumn('', weight: dw));
      if (showMrp)
        priceCols.add(ReceiptTableColumn(itemMrp.toStringAsFixed(2),
            weight: weights['mrp'] ?? 0,
            align: TextAlign.center,
            scale: scale));
      if (showQty)
        priceCols.add(ReceiptTableColumn(itemQty.toString(),
            weight: weights['qty'] ?? 0,
            align: TextAlign.center,
            scale: scale));
      if (showRate)
        priceCols.add(ReceiptTableColumn(itemRate.toStringAsFixed(2),
            weight: weights['rate'] ?? 0,
            align: TextAlign.right,
            scale: scale));
      if (showTotal)
        priceCols.add(ReceiptTableColumn(itemTotal.toStringAsFixed(2),
            weight: weights['total'] ?? 0,
            align: TextAlign.right,
            scale: scale));
      if (priceCols.any((c) => c.text.isNotEmpty))
        rows.add(ReceiptTableRow(priceCols));
      if (i < orderReturns.returnItems!.length - 1)
        rows.add(StandardThinDividerRow());
    }

    rows.add(SpacingRow(_itemGap));

    if (displayConfig?['showReturnItemsCount']?.visible == true) {
      final countLabel = (retLabels?.creditNoteItemsCount != null)
          ? _getLabel(
              retDc,
              'showCreditNoteItemsCount',
              retLabels?.creditNoteItemsCount,
              isEnglish ? 'Total Items:' : 'إجمالي العناصر:')
          : (isEnglish ? 'Return Items:' : 'عناصر المرتجع:');
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(countLabel,
            weight: 0.6, align: TextAlign.left, isBold: true, scale: scale),
        ReceiptTableColumn(orderReturns.returnItems!.length.toString(),
            weight: 0.4, align: TextAlign.right, isBold: true, scale: scale),
      ]));
    }

    final bool showReturnTotalAmt =
        displayConfig?['showReturnTotalAmount']?.visible == true;
    final bool showReturnNetAmt =
        displayConfig?['showReturnNetAmount']?.visible == true;
    if (showReturnTotalAmt || showReturnNetAmt) {
      final String? currencySymbol =
          currency.trim().toUpperCase() == 'INR' ? '₹' : null;
      final ui.Image? currencyIcon = currencySymbol == null ? sarSymbol : null;
      final double returnRateTotal =
          double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
      final List<StandardBoxedLineItem> returnSummaryItems = [];
      if (showReturnTotalAmt) {
        returnSummaryItems.add(StandardBoxedLineItem(
            label: (retLabels?.creditNoteTotalAmount != null)
                ? _getLabel(
                    retDc,
                    'showCreditNoteTotalAmount',
                    retLabels?.creditNoteTotalAmount,
                    isEnglish ? 'Total Amount:' : 'المبلغ الإجمالي:')
                : _getLabel(displayConfig, 'showReturnTotalAmount', null,
                    isEnglish ? 'Return Total:' : 'إجمالي المرتجع:'),
            value: returnRateTotal.toStringAsFixed(2),
            isBold: true,
            scale: 1.1,
            icon: currencyIcon,
            currencySymbol: currencySymbol));
      }
      if (showReturnNetAmt) {
        returnSummaryItems.add(StandardBoxedLineItem(
            label: (retLabels?.creditNoteRefund != null)
                ? _getLabel(
                    retDc,
                    'showCreditNoteRefund',
                    retLabels?.creditNoteRefund,
                    isEnglish ? 'Credit Note Total:' : 'إجمالي إشعار الائتمان:')
                : _getLabel(displayConfig, 'showReturnNetAmount', null,
                    isEnglish ? 'Return Net Amount:' : 'صافي مبلغ الإرجاع:'),
            value: returnRateTotal.toStringAsFixed(2),
            isBold: true,
            scale: 1.1,
            icon: currencyIcon,
            currencySymbol: currencySymbol));
      }
      rows.add(SpacingRow(_itemGap));
      rows.add(StandardBoxedTotalsRow(items: returnSummaryItems));
      if (hasCreditNoteConfig) {
        final amountText = AmountHelper().convertNumberToWords(returnRateTotal,
            currency: currency, language: isEnglish ? 'en' : 'ar');
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow('Amount in Words:', isBold: true, scale: 0.9));
        rows.add(TextRow(amountText, isBold: false, scale: 0.85));
      }
    }
  }

  // ==================== FINAL SUMMARY SECTION (after returns) ====================

  void _buildFinalSummarySection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    ui.Image? sarSymbol,
    String currency,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty)
      return;

    final bool showFinalPurchase =
        displayConfig?['showFinalPurchase']?.visible != false;
    final bool showFinalReturn =
        displayConfig?['showFinalReturn']?.visible != false;
    final bool showFinalNetAmount =
        displayConfig?['showFinalNetAmount']?.visible != false;
    final bool showFinalAmountInWords =
        displayConfig?['showFinalAmountInWords']?.visible == true;
    if (!showFinalPurchase && !showFinalReturn && !showFinalNetAmount) return;

    final String? currencySymbol =
        currency.trim().toUpperCase() == 'INR' ? '₹' : null;
    final ui.Image? currencyIcon = currencySymbol == null ? sarSymbol : null;

    double returnTotal = 0.0;
    for (final returnItem in orderReturns.returnItems!) {
      final num itemQty = returnItem.quantity ?? 0;
      double itemRate = 0.0;
      for (var cartItem in params.cartItems) {
        String cartName = '';
        double cartRate = 0.0;
        if (params.isFromLocalStorage || cartItem is Map) {
          cartName = (cartItem['product_name'] ?? cartItem['productName'] ?? '')
              .toString();
          cartRate = double.tryParse(
                  (cartItem['unit_price'] ?? cartItem['unitPrice'])
                          ?.toString() ??
                      '0') ??
              0.0;
        } else {
          try {
            cartName = cartItem.productName?.toString() ?? '';
            cartRate =
                double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
          } catch (_) {}
        }
        if (cartName == returnItem.productName) {
          itemRate = cartRate;
          break;
        }
      }
      if (itemRate == 0.0) {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
        num totalQty = 0;
        for (var ri in orderReturns.returnItems!) {
          totalQty += ri.quantity ?? 0;
        }
        itemRate = totalQty > 0 ? totalReturnAmount / totalQty : 0.0;
      }
      returnTotal += itemQty * itemRate;
    }

    final double orderTotal =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    final double finalTotal = orderTotal - returnTotal;

    rows.add(SpacingRow(_sectionGap));
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    List<StandardBoxedLineItem> summaryItems = [];
    if (showFinalPurchase) {
      summaryItems.add(StandardBoxedLineItem(
          label: _getLabel(displayConfig, 'showFinalPurchase', null,
              isEnglish ? 'ORDER TOTAL' : 'إجمالي الطلب'),
          value: orderTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (showFinalReturn) {
      summaryItems.add(StandardBoxedLineItem(
          label: _getLabel(displayConfig, 'showFinalReturn', null,
              isEnglish ? 'RETURN TOTAL' : 'إجمالي المرتجع'),
          value: returnTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (showFinalNetAmount) {
      summaryItems.add(StandardBoxedLineItem(isSeparator: true));
      summaryItems.add(StandardBoxedLineItem(
          label: _getLabel(displayConfig, 'showFinalNetAmount', null,
              isEnglish ? 'FINAL TOTAL  ' : 'المبلغ النهائي'),
          value: finalTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (summaryItems.isNotEmpty)
      rows.add(StandardBoxedTotalsRow(items: summaryItems));

    if (showFinalAmountInWords) {
      rows.add(SpacingRow(_itemGap));
      final language =
          (params.billDocumentConfig.language ?? 'en').toLowerCase();
      final amountText = AmountHelper().convertNumberToWords(finalTotal,
          currency: currency, language: language);
      final suffix = language == 'ar' ? ' فقط.' : ' Only.';
      rows.add(TextRow('$amountText$suffix', scale: 0.85, isBold: true));
    }
    rows.add(SpacingRow(_itemGap));
  }
}

/// Thin solid line divider for Standard theme
class StandardThinDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      1.2;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;

    const double dashWidth = 3.0;
    const double dashSpace = 2.0;
    double currentX = 0;

    while (currentX < width) {
      canvas.drawLine(
        Offset(currentX, y + 0.6),
        Offset(currentX + dashWidth, y + 0.6),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }
}

/// Dotted divider for emphasis sections
class StandardDottedDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      3;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;

    const double dashWidth = 3.0;
    const double dashSpace = 2.0;
    double currentX = 0;

    while (currentX < width) {
      canvas.drawLine(
        Offset(currentX, y + 1.5),
        Offset(currentX + dashWidth, y + 1.5),
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
    this.padding = 12.0,
  });

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    double h = padding * 2;
    for (var item in items) {
      if (item.isSeparator) {
        h += 6; // Space for separator
      } else {
        h += (fontSize * item.scale) + 2; // Line height + spacing
      }
    }
    return h;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;

    // Draw top dotted line
    const double dashWidth = 3.0;
    const double dashSpace = 2.0;
    double currentX = 0;
    while (currentX < width) {
      canvas.drawLine(
        Offset(currentX, y),
        Offset(currentX + dashWidth, y),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }

    // Draw bottom dotted line
    currentX = 0;
    double bottomY = y + calculateHeight(width, fontSize, textDirection);
    while (currentX < width) {
      canvas.drawLine(
        Offset(currentX, bottomY),
        Offset(currentX + dashWidth, bottomY),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }

    double currentY = y + padding;

    for (var item in items) {
      if (item.isSeparator) {
        // Draw dashed separator
        final sepPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.5;

        const double dashWidth = 3.0;
        const double dashSpace = 2.0;
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

        if (textDirection == TextDirection.ltr) {
          // English: Label on Left, Value + Icon on Right
          // Label on Left
          _drawScaledText(
            canvas,
            item.label,
            Offset(padding, currentY),
            (width * 0.55) - padding,
            itemFontSize,
            item.isBold,
            TextAlign.left,
            TextDirection.ltr,
          );

          // Value on Right, then currency mark to the left of value.
          double rightEdge = width - padding;
          double currencyMarkSpace = 0;
          TextPainter? symbolPainter;
          if (item.icon != null) {
            final double iconSize = itemFontSize * 1.0;
            currencyMarkSpace = iconSize + 4;
          } else if (item.currencySymbol != null &&
              item.currencySymbol!.isNotEmpty) {
            symbolPainter = TextPainter(
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
            currencyMarkSpace = symbolPainter.width + 4;
          }

          // Draw value text right-aligned, leaving room for the currency mark.
          _drawScaledText(
            canvas,
            item.value,
            Offset(rightEdge, currentY),
            width * 0.40 - currencyMarkSpace,
            itemFontSize,
            item.isBold,
            TextAlign.right,
            TextDirection.ltr,
          );

          final valuePainter = TextPainter(
            text: TextSpan(
              text: item.value,
              style: TextStyle(
                fontSize: itemFontSize,
                fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          if (item.icon != null) {
            final double iconSize = itemFontSize * 1.0;
            final double iconX = rightEdge - valuePainter.width - iconSize - 4;
            final src = Rect.fromLTWH(0, 0, item.icon!.width.toDouble(),
                item.icon!.height.toDouble());
            final dst = Rect.fromLTWH(
                iconX,
                currentY +
                    (itemFontSize - iconSize) / 2 +
                    (itemFontSize * 0.08),
                iconSize,
                iconSize);
            canvas.drawImageRect(item.icon!, src, dst, Paint());
          } else if (symbolPainter != null) {
            final double symbolX =
                rightEdge - valuePainter.width - symbolPainter.width - 4;
            symbolPainter.paint(canvas, Offset(symbolX, currentY));
          }
        } else {
          // Arabic: Value + Icon on Left, Label on Right
          double valueOffsetX = padding;
          if (item.icon != null) {
            final double iconSize = itemFontSize * 0.75;
            final src = Rect.fromLTWH(0, 0, item.icon!.width.toDouble(),
                item.icon!.height.toDouble());
            final dst = Rect.fromLTWH(
                padding,
                currentY +
                    (itemFontSize - iconSize) / 2 +
                    (itemFontSize * 0.08),
                iconSize,
                iconSize);
            canvas.drawImageRect(item.icon!, src, dst, Paint());
            valueOffsetX += iconSize + 4;
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

          // Value on Left
          _drawScaledText(
            canvas,
            item.value,
            Offset(valueOffsetX, currentY),
            (width * 0.50) - (valueOffsetX - padding),
            itemFontSize,
            item.isBold,
            TextAlign.left,
            TextDirection.rtl,
          );

          // Label on Right
          _drawScaledText(
            canvas,
            item.label,
            Offset(width - padding, currentY),
            width * 0.70,
            itemFontSize,
            item.isBold,
            TextAlign.right,
            TextDirection.rtl,
          );
        }

        currentY += itemFontSize + 2;
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
  final String? currencySymbol;

  StandardBoxedLineItem({
    this.label = '',
    this.value = '',
    this.isBold = false,
    this.scale = 1.0,
    this.isSeparator = false,
    this.icon,
    this.currencySymbol,
  });
}

/// Local compact implementation of TextRow for Templet 1
class TextRow extends ReceiptRow {
  final String text;
  final TextAlign align;
  final bool isBold;
  final double scale;
  final TextDirection? textDirectionOverride;

  TextRow(this.text,
      {this.align = TextAlign.center,
      this.isBold = false,
      this.scale = 1.0,
      this.textDirectionOverride});

  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      _createPainter(width, fontSize, textDirectionOverride ?? textDirection)
          .height;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final tp =
        _createPainter(width, fontSize, textDirectionOverride ?? textDirection);
    double x = 0;
    if (align == TextAlign.center) {
      x = (width - tp.width) / 2;
    } else if (align == TextAlign.right) {
      x = width - tp.width;
    }
    tp.paint(canvas, Offset(x, y));
  }

  TextPainter _createPainter(
      double width, double fontSize, TextDirection textDirection) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize * scale,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: align,
    )..layout(maxWidth: width);
  }
}

/// Local compact implementation of ReceiptTableRow for Templet 1
class ReceiptTableRow extends ReceiptRow {
  final List<ReceiptTableColumn> columns;

  ReceiptTableRow(this.columns);

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    double maxHeight = 0;
    for (var col in columns) {
      final tp = col.createPainter(width, fontSize, textDirection);
      if (tp.height > maxHeight) maxHeight = tp.height;
    }
    return maxHeight;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    double currentX = 0;
    for (var col in columns) {
      final colWidth = width * col.weight;
      final tp = col.createPainter(width, fontSize, textDirection);
      double xOffset = 0;
      if (col.align == TextAlign.center) {
        xOffset = (colWidth - tp.width) / 2;
      } else if (col.align == TextAlign.right) {
        xOffset = colWidth - tp.width;
      }
      tp.paint(canvas, Offset(currentX + xOffset, y));
      currentX += colWidth;
    }
  }
}

/// Reusable styled line item for consistent formatting throughout receipts
/// Used for displaying simple text lines with standardized boldness and scaling
class StandardLineItem {
  final String text;
  final bool isBold;
  final double scale;
  final TextAlign align;
  final bool isSeparator;

  StandardLineItem({
    this.text = '',
    this.isBold = true,
    this.scale = 0.75,
    this.align = TextAlign.center,
    this.isSeparator = false,
  });
}

/// Reusable row for rendering styled lines with consistent formatting
/// Perfect for Amount in Words, Items Count, You Saved, and other simple displays
/// Can render multiple lines with separator support
class StandardLineRow extends ReceiptRow {
  final List<StandardLineItem> items;
  final double lineGap;

  StandardLineRow({
    required this.items,
    this.lineGap = 2.0,
  });

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    double totalHeight = 0;
    for (int i = 0; i < items.length; i++) {
      if (items[i].isSeparator) {
        totalHeight += 1.2; // Height for separator line
      } else {
        final tp = _createPainter(items[i], width, fontSize, textDirection);
        totalHeight += tp.height;
      }
      if (i < items.length - 1) {
        totalHeight += lineGap;
      }
    }
    return totalHeight;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    double currentY = y;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      if (item.isSeparator) {
        // Draw a thin dashed line
        final paint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.5;

        const double dashWidth = 3.0;
        const double dashSpace = 2.0;
        double currentX = 0;

        while (currentX < width) {
          canvas.drawLine(
            Offset(currentX, currentY),
            Offset((currentX + dashWidth).clamp(0, width), currentY),
            paint,
          );
          currentX += dashWidth + dashSpace;
        }
        currentY += 1.2;
      } else {
        final tp = _createPainter(item, width, fontSize, textDirection);
        double x = 0;
        if (item.align == TextAlign.center) {
          x = (width - tp.width) / 2;
        } else if (item.align == TextAlign.right) {
          x = width - tp.width;
        }
        tp.paint(canvas, Offset(x, currentY));
        currentY += tp.height;
      }

      if (i < items.length - 1) {
        currentY += lineGap;
      }
    }
  }

  TextPainter _createPainter(StandardLineItem item, double width,
      double fontSize, TextDirection textDirection) {
    return TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          fontSize: fontSize * item.scale,
          fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: textDirection,
      textAlign: item.align,
    )..layout(maxWidth: width);
  }
}

/// Row that displays a delivery icon and phone number side by side, centered
class DeliveryInfoRow extends ReceiptRow {
  final ui.Image icon;
  final String phone;
  final double iconSize;
  final double scale;
  final double gap;

  DeliveryInfoRow({
    required this.icon,
    required this.phone,
    this.iconSize = 40.0,
    this.scale = 0.85,
    this.gap = 10.0,
  });

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    final scaledFontSize = fontSize * scale;
    final phonePainter = TextPainter(
      text: TextSpan(
        text: phone,
        style: TextStyle(
          color: Colors.black,
          fontSize: scaledFontSize,
          fontWeight: FontWeight.bold,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
    )..layout(maxWidth: width);

    return iconSize + gap + phonePainter.height;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final scaledFontSize = fontSize * scale;

    final phonePainter = TextPainter(
      text: TextSpan(
        text: phone,
        style: TextStyle(
          color: Colors.black,
          fontSize: scaledFontSize,
          fontWeight: FontWeight.bold,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
    )..layout(maxWidth: width);

    final iconX = (width - iconSize) / 2;
    final textX = (width - phonePainter.width) / 2;

    // Draw the icon centered and allow the target size to dominate even when the source image is small.
    canvas.drawImageRect(
      icon,
      Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
      Rect.fromLTWH(iconX, y, iconSize, iconSize),
      Paint(),
    );

    final textY = y + iconSize + gap;
    phonePainter.paint(canvas, Offset(textX, textY));
  }
}
