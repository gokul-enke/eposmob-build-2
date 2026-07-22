import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../logo_loader.dart';
import 'package:pos_machine/screens/print/thermal/debug_image_saver.dart';
import 'supermarket2_receipt_layout.dart' hide TextRow, ReceiptTableRow;

/// Supermarket 2 Bilingual receipt layout.
/// Combines the compact spacing of Supermarket 2 with the bilingual support of Premium 2 Bilingual.
class Supermarket2BilingualReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Spacing gaps matching supermarket2
  static const double _sectionGap = 0.0;
  static const double _itemGap = 0.0;
  static const double _smallItemGap = 3.0;
  static const double _headerGap = 0.0;

  // Debug override switch
  static const String? _debugLanguageOverride = null;

  @override
  String get layoutId => 'supermarket2_bilingual';

  @override
  String get displayName => 'Supermarket 2 Bilingual';


  String _normalizedDocumentLanguage(ReceiptLayoutParams params) {
    final raw = (((kDebugMode ? _debugLanguageOverride : null) ??
            params.billDocumentConfig.language ??
            '')
        .trim()
        .toUpperCase());
    if (raw == 'EN_AR' ||
        raw == 'EN/AR' ||
        raw == 'AR/EN' ||
        raw == 'BILINGUAL') {
      return 'EN_AR';
    }
    if (raw == 'AR' || raw == 'ARABIC') return 'AR';
    if (raw == 'EN' || raw == 'ENGLISH') return 'EN';
    return 'AR';
  }

  bool _isEnglishContent(ReceiptLayoutParams params) {
    return _normalizedDocumentLanguage(params) == 'EN';
  }

  bool _isBilingualContent(ReceiptLayoutParams params) {
    return _normalizedDocumentLanguage(params) == 'EN_AR';
  }

  bool _isLtrLayout(ReceiptLayoutParams params) {
    return _normalizedDocumentLanguage(params) == 'EN';
  }


  String _getModeLabel({
    required Map<String, DisplayOption>? displayConfig,
    required String key,
    String? resolvedArabic,
    String? resolvedEnglish,
    required bool isEnglish,
    required bool isBilingual,
    required String english,
    required String arabic,
    bool inlineBilingual = false,
  }) {
    final option = displayConfig?[key];
    final configuredArabic =
        option?.value is String ? (option!.value as String).trim() : '';
    final configuredEnglish = option?.defaultValue?.trim() ?? '';
    final arabicText = configuredArabic.isNotEmpty
        ? configuredArabic
        : (resolvedArabic?.trim().isNotEmpty == true
            ? resolvedArabic!.trim()
            : arabic);
    final englishText = configuredEnglish.isNotEmpty
        ? configuredEnglish
        : (resolvedEnglish?.trim().isNotEmpty == true
            ? resolvedEnglish!.trim()
            : english);

    if (isEnglish) return englishText;
    if (!isBilingual) return arabicText;
    if (inlineBilingual) {
      return _getInlineBilingualText(arabic: arabicText, english: englishText);
    }
    return _getBilingualText(arabic: arabicText, english: englishText);
  }

  String _getInlineBilingualText(
      {required String arabic, required String english}) {
    final arabicText = arabic.trim();
    final englishText = english.trim();
    if (arabicText.isEmpty) return englishText;
    if (englishText.isEmpty) return arabicText;
    if (arabicText.toLowerCase() == englishText.toLowerCase()) {
      return arabicText;
    }
    return '$arabicText / $englishText';
  }

  String _getBilingualText({required String arabic, required String english}) {
    final arabicText = arabic.trim();
    final englishText = english.trim();
    if (arabicText.isEmpty) return englishText;
    if (englishText.isEmpty) return arabicText;
    if (arabicText.toLowerCase() == englishText.toLowerCase()) {
      return arabicText;
    }
    return '$arabicText\n$englishText';
  }

  String _appendValueToModeLabel(String label, String value, bool isBilingual) {
    final cleanValue = value.trim();
    if (!isBilingual || !label.contains('\n')) {
      return cleanValue.isEmpty ? label : '${label.trim()} $cleanValue';
    }

    return label
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) =>
            cleanValue.isEmpty ? line.trim() : '${line.trim()} $cleanValue')
        .join('\n');
  }


  String _formatInvoiceIdentifier(String prefix, String number) {
    final trimmedPrefix = prefix.trim();
    final needsTightJoin = trimmedPrefix.endsWith('-') ||
        trimmedPrefix.endsWith('/') ||
        trimmedPrefix.endsWith('#');
    final joined =
        needsTightJoin ? '$trimmedPrefix$number' : '$trimmedPrefix $number';

    if (RegExp(r'^[A-Za-z0-9\-/#\s]+$').hasMatch(trimmedPrefix)) {
      return '\u202A$joined\u202C';
    }

    return joined;
  }

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    return PrintLogoLoader.loadUiLogo(url,
        tag: '[supermarket2_bilingual_receipt_layout]');
  }

  Future<ui.Image?> _loadAssetImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final fi = await codec.getNextFrame();
      return fi.image;
    } catch (e) {
      debugPrint("[Supermarket2BilingualReceiptLayout] Error loading asset image: $e");
    }
    return null;
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

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== supermarket 2 BILINGUAL LAYOUT: THERMAL PRINTING ====");

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

      // Determine content language and layout direction from document config.
      final isEnglish = _isEnglishContent(params);
      final isBilingual = _isBilingualContent(params);
      final isLtrLayout = _isLtrLayout(params);
      final textDirection = isLtrLayout ? TextDirection.ltr : TextDirection.rtl;
      debugPrint(
          "Language: ${isEnglish ? 'English' : (isBilingual ? 'Bilingual' : 'Arabic')} (layout=${isLtrLayout ? 'LTR' : 'RTL'})");

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

      // ========== HEADER SECTION ==========
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings, isEnglish, isBilingual);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish, isBilingual);

      // ========== CART ITEMS SECTION ==========
      if (!params.isReturnOnly) {
        _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish, isBilingual);
      }

      // ========== TOTALS SECTION ==========
      if (!params.isReturnOnly) {
        _buildTotalsSection(part1Rows, params, displayConfig, isEnglish, isBilingual,
            sarSymbol, appSettings?.currency ?? 'INR');
      }

      // ========== RETURN ITEMS SECTION ==========
      if (params.orderReturns != null &&
          params.orderReturns!.returnItems != null &&
          params.orderReturns!.returnItems!.isNotEmpty) {
        _buildReturnSection(part1Rows, params, displayConfig, isEnglish, isBilingual,
            sarSymbol, appSettings?.currency ?? 'INR');
        if (!params.isReturnOnly) {
          _buildFinalSummarySection(part1Rows, params, displayConfig, isEnglish, isBilingual,
              sarSymbol, appSettings?.currency ?? 'INR');
        }
      }

      // ========== FOOTER SECTION ==========
      await _buildFooterSection(
          part2Rows, params, displayConfig, isEnglish, isBilingual, context);

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

      // Send to printer
      debugPrint("Sending ${bytes.length} bytes to printer...");
      await _printerUtils.sendPrintJob(selectedPrinter, bytes);
      debugPrint("Print job sent successfully.");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR in Standard Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: "Error printing: ${e.toString()}");
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
    debugPrint("[Supermarket2BilingualReceiptLayout] buildPdf - delegating to StandardPrinter");
    return pw.Document();
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    await printThermal(params);
  }

  void _buildHeaderSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    dynamic appSettings,
    bool isEnglish,
    bool isBilingual,
  ) {
    final billDocumentConfig = params.billDocumentConfig;

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
      final fallbackStoreName = params.storeName?.isNotEmpty == true
          ? params.storeName!
          : 'STORE NAME';
      final storeName = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showStoreName',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: fallbackStoreName,
        arabic: fallbackStoreName,
      );

      // Dynamic scaling based on name length
      double storeNameScale = 1.5;
      int maxLength = storeName
          .split('\n')
          .map((s) => s.length)
          .fold<int>(0, (max, len) => len > max ? len : max);
      if (maxLength > 20) {
        storeNameScale = 1.15;
      } else if (maxLength > 14) {
        storeNameScale = 1.3;
      }

      rows.add(TextRow(storeName.trim().toUpperCase(),
          isBold: true, scale: storeNameScale));
    }

    // Description/Subheader - Arabic subtitle style
    if (displayConfig?['showDescription']?.visible == true) {
      final descriptionText = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDescription',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );

      if (descriptionText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(descriptionText.trim(), scale: 0.9, isBold: true));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final addressVal = params.storeLocation ?? '';
      final label = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showStoreAddress',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Address',
        arabic: 'العنوان',
      );
      if (addressVal.isNotEmpty) {
        final addressText = label.isNotEmpty
            ? _appendValueToModeLabel(label, ': $addressVal', isBilingual)
            : addressVal;
        rows.add(TextRow(addressText, scale: 0.75, isBold: true));
      }
    }

    // Invoice Title
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitleText = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showInvoiceTitle',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: appSettings?.printTitle ?? 'INVOICE',
        arabic: 'فاتورة',
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
      final extraHeading1Text = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showExtraHeading1',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );

      if (extraHeading1Text.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(extraHeading1Text, scale: 0.75, isBold: true));
      }
    }

    // Extra Heading 2
    if (displayConfig?['showExtraHeading2']?.visible == true) {
      final extraHeading2Text = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showExtraHeading2',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );

      if (extraHeading2Text.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(extraHeading2Text, scale: 0.75, isBold: true));
      }
    }

    // Location/Fssai info
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfoText = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showFssaiInfo',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'FSSAI / Tax Information',
        arabic: 'معلومات FSSAI / الضريبة',
      );

      if (fssaiInfoText.isNotEmpty) {
        rows.add(TextRow(fssaiInfoText, scale: 0.75, isBold: true));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final label = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTel',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Phone',
        arabic: 'رقم الهاتف',
      );
      final phoneVal = params.storePhone?.isNotEmpty == true
          ? params.storePhone!
          : (appSettings?.customerCarePhone ?? '');
      if (phoneVal.isNotEmpty) {
        final telephoneText = label.isNotEmpty
            ? _appendValueToModeLabel(label, ': $phoneVal', isBilingual)
            : phoneVal;
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(telephoneText, scale: 0.75, isBold: true));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final label = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showEmail',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Email',
        arabic: 'البريد الإلكتروني',
      );
      final emailVal = params.storeEmail?.isNotEmpty == true
          ? params.storeEmail!
          : (appSettings?.customerCareEmail ?? '');
      if (emailVal.isNotEmpty) {
        final emailText = label.isNotEmpty
            ? _appendValueToModeLabel(label, ': $emailVal', isBilingual)
            : emailVal;
        rows.add(TextRow(emailText, scale: 0.75, isBold: true));
      }
    }

    rows.add(SpacingRow(_sectionGap));
    rows.add(SpacingRow(_smallItemGap));
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    // Token Number
    if (displayConfig?['showTokenNumber']?.visible == true &&
        params.tokenNumber != null &&
        params.tokenNumber!.isNotEmpty) {
      final String tokenPrefix = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTokenNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Token: ',
        arabic: 'الرمز: ',
        inlineBilingual: true,
      );
      rows.add(SpacingRow(_itemGap));
      rows.add(TextRow('$tokenPrefix${params.tokenNumber}',
          scale: 1.0, isBold: true));
    }
    rows.add(SpacingRow(_itemGap));
  }

  void _buildCustomerSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
  ) {
    if (displayConfig?['showCustomerNameAndPhone']?.visible == false) {
      return;
    }

    final bool showInvoiceNumber =
        displayConfig?['showInvoiceNumber']?.visible == true;

    if (showInvoiceNumber) {
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      final invoicePrefix = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showInvoicePrefix',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: params.billDocumentConfig.numberPrefix ?? 'Invoice No:',
        arabic: 'رقم الفاتورة:',
        inlineBilingual: true,
      );

      final invoiceNumberText =
          _formatInvoiceIdentifier(invoicePrefix, strippedNumber);
      rows.add(TextRow(invoiceNumberText, isBold: true, scale: 1.0));
      rows.add(SpacingRow(_itemGap));
    }

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

    final customerLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerName',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Customer:',
        arabic: 'العميل:',
        inlineBilingual: true);
    final phoneLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerPhone',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Phone:',
        arabic: 'الهاتف:',
        inlineBilingual: true);
    final paymentLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: paymentConfigKey,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Payment:',
        arabic: 'الدفع:',
        inlineBilingual: true);
    final addressLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerAddress',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Address:',
        arabic: 'العنوان:',
        inlineBilingual: true);
    final commentLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: commentConfigKey,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Comment:',
        arabic: 'تعليق:',
        inlineBilingual: true);
    final deliveryLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDeliveryMethod',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Delivery:',
        arabic: 'التوصيل:',
        inlineBilingual: true);
    final customerVatLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerVatNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Customer VAT:',
        arabic: 'الرقم الضريبي للعميل:',
        inlineBilingual: true);
    final customerCrLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerCrNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Customer CR:',
        arabic: 'السجل التجاري للعميل:',
        inlineBilingual: true);

    void addCustomerRow(String label, String value) {
      if (isEnglish) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(label,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: 0.75),
          ReceiptTableColumn(value,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
        ]));
      } else {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(value,
              weight: 0.65, align: TextAlign.left, scale: 0.75),
          ReceiptTableColumn(label,
              weight: 0.35, align: TextAlign.right, isBold: true, scale: 0.75),
        ]));
      }
    }

    if (showCustomerName &&
        params.customerName != null &&
        params.customerName!.isNotEmpty) {
      addCustomerRow(customerLabel, params.customerName!);
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
      addCustomerRow(phoneLabel, phoneText);
    }

    if (showPayment &&
        params.paymentMethod != null &&
        params.paymentMethod!.isNotEmpty) {
      addCustomerRow(paymentLabel, params.paymentMethod!);
    }

    if (showCustomerAddress &&
        params.customerAddress != null &&
        params.customerAddress!.isNotEmpty) {
      addCustomerRow(addressLabel, params.customerAddress!);
    }

    if (showComment &&
        params.orderComment != null &&
        params.orderComment!.isNotEmpty) {
      addCustomerRow(commentLabel, params.orderComment!);
    }

    if (showDeliveryMethod &&
        params.deliveryMethod != null &&
        params.deliveryMethod!.isNotEmpty) {
      addCustomerRow(deliveryLabel, params.deliveryMethod!);
    }

    if (showCustomerVatNumber &&
        params.customerVatNumber != null &&
        params.customerVatNumber!.isNotEmpty) {
      addCustomerRow(customerVatLabel, params.customerVatNumber!);
    }

    if (showCustomerCrNumber &&
        params.customerCrNumber != null &&
        params.customerCrNumber!.isNotEmpty) {
      addCustomerRow(customerCrLabel, params.customerCrNumber!);
    }
  }

  void _buildCartItemsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
  ) {
    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    final String particularsLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showParticulars',
      resolvedArabic: resolvedLabels?.particulars,
      resolvedEnglish: resolvedLabels?.particularsDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Item',
      arabic: 'الصنف',
    );
    final String mrpLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showMRP',
      resolvedArabic: resolvedLabels?.mrp,
      resolvedEnglish: resolvedLabels?.mrpDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'MRP',
      arabic: 'MRP',
    );
    final String qtyLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showQty',
      resolvedArabic: resolvedLabels?.qty,
      resolvedEnglish: resolvedLabels?.qtyDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Qty',
      arabic: 'الكمية',
    );
    final String rateLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showRate',
      resolvedArabic: resolvedLabels?.rate,
      resolvedEnglish: resolvedLabels?.rateDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Rate',
      arabic: 'السعر',
    );
    final String rateExcTaxLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showRateExcTax',
      resolvedArabic: resolvedLabels?.rateExcTax,
      resolvedEnglish: resolvedLabels?.rateExcTaxDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Rate Ex Tax',
      arabic: 'السعر بدون ضريبة',
    );
    final String unitLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showUnit',
      resolvedArabic: resolvedLabels?.unitName,
      resolvedEnglish: resolvedLabels?.unitNameDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Unit',
      arabic: 'الوحدة',
    );
    final String totalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showTotal',
      resolvedArabic: resolvedLabels?.total,
      resolvedEnglish: resolvedLabels?.totalDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Total',
      arabic: 'الإجمالي',
    );
    final String taxHeaderLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showTaxHeader',
      resolvedArabic: resolvedLabels?.tax,
      resolvedEnglish: resolvedLabels?.taxDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Tax',
      arabic: 'الضريبة',
    );
    final String slLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showSLNumber',
      resolvedArabic: resolvedLabels?.slNumber,
      resolvedEnglish: resolvedLabels?.slNumberDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'SL#',
      arabic: 'م',
    );

    final tableWeights = _buildNormalizedTableWeights(displayConfig);
    final tableColumnCount = tableWeights.length;
    final tableScale = _getTableScale(tableColumnCount);
    final tableMinScale = _getTableMinScale(tableColumnCount);
    final tableCellPadding = _getTableCellPadding(tableColumnCount);

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
      tableCellPadding,
    );

    int serialNumber = 1;
    for (var item in params.cartItems) {
      _buildCartItemRow(
        rows,
        item,
        serialNumber++,
        params.isFromLocalStorage,
        displayConfig,
        isEnglish,
        isBilingual,
        tableWeights,
        tableScale,
        tableMinScale,
        tableCellPadding,
      );
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
    bool isBilingual,
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
      unitName = getPrintUnit(item);
      totalPrice = (double.tryParse(
                  (item['totalPrice'] ?? item['total_price'])?.toString() ??
                      '0') ??
              0.0)
          .toStringAsFixed(2);
      itemTaxAmount = taxValue.toStringAsFixed(2);
    } else {
      if (item.names != null &&
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
      unitName = getPrintUnit(item);
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
      }
      if (isBilingual || productNameArabic.isEmpty) {
        final englishText = (displayConfig?['showSLNumber']?.visible == true && productNameArabic.isEmpty)
            ? '$slNumber. $productName'
            : productName;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(englishText,
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

  void _buildTotalsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
    ui.Image? sarSymbol,
    String currency,
  ) {
    rows.add(SpacingRow(_itemGap));

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final String? currencySymbol =
        currency.trim().toUpperCase() == 'INR' ? '\u20B9' : null;
    final ui.Image? currencyIcon = currencySymbol == null ? sarSymbol : null;

    final bool is58mm = params.is58mm;

    double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;
    double total =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double taxAmount = params.totalTax;

    double subtotal;
    if (params.netExcTax != null) {
      subtotal =
          double.tryParse(params.netExcTax!) ?? (total + discountAmountValue);
    } else {
      subtotal = total;
    }

    final showMRPTotal = displayConfig?['showSubTotal']?.visible ??
        displayConfig?['showMRPTotal']?.visible ??
        true;
    final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
    final showTax = displayConfig?['showTax']?.visible ?? true;
    final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

    final subtotalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showSubTotal',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'NET TOTAL (Exc Tax)',
      arabic: 'المجموع',
    );

    final discountLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showDiscount',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'DISCOUNTS',
      arabic: 'الخصم',
    );

    final vatLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showTax',
      resolvedArabic: resolvedLabels?.tax,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'VAT',
      arabic: 'الضريبة',
    );

    final grandTotalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showNetAmount',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'GRAND TOTAL',
      arabic: 'المبلغ الاجمالي',
    );

    final cashLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCash',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Cash',
      arabic: 'نقدي',
    );

    List<StandardBoxedLineItem> boxedItems = [];
    final totalsScale = 0.85;

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

    if (showTax) {
      boxedItems.add(StandardBoxedLineItem(
        label: vatLabel,
        value: taxAmount.toStringAsFixed(2),
        isBold: true,
        scale: 0.75,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

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

    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible ?? true;

    if (params.paidAmount != null && showPaymentBreaked) {
      boxedItems.add(StandardBoxedLineItem(isSeparator: true));

      bool isMultiPayment = false;

      if (params.paymentBreakdown != null &&
          params.paymentBreakdown!.isNotEmpty) {
        isMultiPayment = true;
        params.paymentBreakdown!.forEach((method, amount) {
          double amt = double.tryParse(amount.toString()) ?? 0.0;
          if (amt > 0) {
            String label = method;
            if (method == 'CASH') {
              label = isEnglish ? "Cash" : (isBilingual ? "نقدي\nCash" : "نقدي");
            } else if (method == 'CARD') {
              label = isEnglish ? "Card" : (isBilingual ? "بطاقة\nCard" : "بطاقة");
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
      } else if (params.paymentMethod != null &&
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
                  label = isEnglish ? "Cash" : (isBilingual ? "نقدي\nCash" : "نقدي");
                } else if (method == 'CARD') {
                  label = isEnglish ? "Card" : (isBilingual ? "بطاقة\nCard" : "بطاقة");
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

    rows.add(StandardBoxedTotalsRow(items: boxedItems));

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(_itemGap));

      if (isBilingual) {
        final arabicText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'ar');
        final englishText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'en');

        rows.add(TextRow('$arabicText فقط.',
            scale: is58mm ? 0.65 : 0.75, isBold: true));
        rows.add(TextRow('$englishText Only.',
            scale: is58mm ? 0.65 : 0.75,
            isBold: true,
            textDirectionOverride: TextDirection.ltr));
      } else {
        final language = isEnglish ? 'en' : 'ar';
        final amountText = AmountHelper().convertNumberToWords(total,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';
        rows.add(TextRow('$amountText$suffix',
            scale: is58mm ? 0.65 : 0.75, isBold: true));
      }
    }

    // Items Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      final itemsCountLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showItemsCount',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Items',
        arabic: 'العدد',
        inlineBilingual: true,
      );

      if (itemsCountLabel.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow('$itemsCountLabel: ${params.cartItems.length}',
            scale: is58mm ? 0.7 : 0.8, isBold: true));
      }
    }

    // Quantity Count
    if (displayConfig?['showQuantityCount']?.visible == true) {
      final quantityCountLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showQuantityCount',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Total Qty',
        arabic: 'إجمالي الكمية',
        inlineBilingual: true,
      );

      if (quantityCountLabel.isNotEmpty) {
        final totalQuantity = params.totalQuantity;
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(
            '$quantityCountLabel: ${totalQuantity % 1 == 0 ? totalQuantity.toInt().toString() : totalQuantity.toStringAsFixed(2)}',
            scale: is58mm ? 0.7 : 0.8,
            isBold: true));
      }
    }

    // You Saved
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      final savedLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showSaved',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'You Saved:',
        arabic: 'لقد وفرت:',
        inlineBilingual: true,
      );
      rows.add(SpacingRow(_itemGap));
      rows.add(TextRow(
        "$savedLabel ${saved.toStringAsFixed(2)}",
        isBold: true,
        scale: 0.8,
      ));
    }

    _buildCustomerBalance(rows, params, displayConfig, isEnglish, isBilingual);
  }

  void _buildCustomerBalance(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
  ) {
    if (displayConfig?['showCustomerBalance']?.visible == false) {
      return;
    }

    if (params.isDefaultCustomer) {
      return;
    }

    if (params.customerOldBalance == null &&
        params.customerCurrentBalance == null) {
      return;
    }

    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;

    rows.add(SpacingRow(_itemGap));
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    final prevBalanceLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerPrevBalance',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Previous Balance',
      arabic: 'الرصيد السابق',
      inlineBilingual: true,
    );
    final prevBalanceLabel = is58mm
        ? (isBilingual
            ? _getInlineBilingualText(
                arabic: 'السابق', english: 'Previous Balance')
            : (isEnglish ? "Previous Balance" : "السابق"))
        : prevBalanceLabelBase;

    final paidAmountLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerPaidAmount',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Paid Amount',
      arabic: 'المبلغ المدفوع',
      inlineBilingual: true,
    );
    final paidAmountLabel = is58mm
        ? (isBilingual
            ? _getInlineBilingualText(arabic: 'المدفوع', english: 'Paid Amount')
            : (isEnglish ? "Paid Amount" : "المدفوع"))
        : paidAmountLabelBase;

    final currentBalanceLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerCurrentBalance',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Current Balance',
      arabic: 'الرصيد الحالي',
      inlineBilingual: true,
    );
    final currentBalanceLabel = is58mm
        ? (isBilingual
            ? _getInlineBilingualText(
                arabic: 'الحالي', english: 'Current Balance')
            : (isEnglish ? "Current Balance" : "الحالي"))
        : currentBalanceLabelBase;

    if (displayConfig?['showCustomerPrevBalance']?.visible != false &&
        params.customerOldBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(prevBalanceLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

    if (displayConfig?['showCustomerPaidAmount']?.visible != false &&
        params.paidAmount != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(paidAmountLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

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

  Future<void> _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
    BuildContext context,
  ) async {
    rows.add(SpacingRow(_sectionGap));

    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';
      String qrMessage = '';

      if (params.hasZatcaCredentials) {
        debugPrint(
            '[StandardLayout] ZATCA credentials found, generating ZATCA QR');

        final zatcaHelper = ZatcaQrHelper();
        qrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate,
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );

        qrMessage = _getModeLabel(
          displayConfig: displayConfig,
          key: 'showQRCode',
          isEnglish: isEnglish,
          isBilingual: isBilingual,
          english: 'ZATCA E-Invoice QR',
          arabic: 'فاتورة الكترونية',
        );

        debugPrint('[StandardLayout] ZATCA QR generated: ${qrData.isNotEmpty}');
      } else {
        debugPrint('[StandardLayout] No ZATCA credentials, using payment QR');

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

        qrMessage = _getModeLabel(
          displayConfig: displayConfig,
          key: 'showQRCode',
          isEnglish: isEnglish,
          isBilingual: isBilingual,
          english: 'Scan to Pay',
          arabic: 'امسح للدفع',
        );
      }

      if (qrData.isNotEmpty) {
        rows.add(TextRow(qrMessage, scale: 0.75));
        rows.add(SpacingRow(_itemGap));
        rows.add(QrRow(qrData, size: 220));

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

    // Date and Time
    if (displayConfig?['showDate']?.visible != false) {
      String formattedDate = params.isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
          : DateHelper.formatISODate(params.orderDate);
      String formattedTime = params.isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
          : DateHelper.formatISOTimeOnlyToIST(params.orderDate);

      final dateLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDate',
        resolvedArabic: resolvedLabels?.date,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Date',
        arabic: 'التاريخ',
        inlineBilingual: true,
      );

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
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      String prefixKey =
          showFooterInvoice ? 'showOrderNumberInFooter' : 'showInvoiceNumber';
      if (showFooterInvoice &&
          displayConfig?['showOrderNumberInFooter']?.value == null) {
        prefixKey = 'showInvoiceNumber';
      }

      final invoicePrefix = _getModeLabel(
        displayConfig: displayConfig,
        key: prefixKey,
        resolvedEnglish: displayConfig?['showInvoicePrefix']?.value ?? params.billDocumentConfig.numberPrefix,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'INV NO:',
        arabic: 'رقم الفاتورة:',
        inlineBilingual: true,
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
      final termsText = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTermsConditions',
        resolvedEnglish: params.billDocumentConfig.terms,
        resolvedArabic: params.billDocumentConfig.terms,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );

      if (termsText.isNotEmpty) {
        rows.add(TextRow(termsText.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final messageText = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showThankYouMessage',
        resolvedEnglish: params.billDocumentConfig.footer,
        resolvedArabic: params.billDocumentConfig.footer,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Thank You for Your Visit!',
        arabic: 'شكراً لزيارتكم!',
      );

      if (messageText.isNotEmpty) {
        rows.add(TextRow(messageText, isBold: true, scale: 0.85));
      }
    }

    // Delivery Icon/Phone Center Center
    final bool showDeliveryIcon =
        displayConfig?['showDeliveryIcon']?.visible == true;
    final bool showDeliveryPhone =
        displayConfig?['showDeliveryPhone']?.visible == true;
    final billDocConfig = params.billDocumentConfig;

    if (showDeliveryIcon || showDeliveryPhone) {
      rows.add(SpacingRow(_itemGap));

      ui.Image? deliveryIcon;
      if (showDeliveryIcon) {
        final iconUrl = billDocConfig.icon?.toString();
        if (iconUrl != null && iconUrl.isNotEmpty) {
          try {
            deliveryIcon = await _fetchNetworkUiImage(iconUrl);
          } catch (e) {
            debugPrint('[Supermarket2BilingualLayout] Error loading delivery icon: $e');
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

  void _buildReturnSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
    ui.Image? sarSymbol,
    String currency,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty)
      return;

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;

    rows.add(SpacingRow(_sectionGap));
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    final returnTitle = isEnglish ? 'RETURNS' : (isBilingual ? 'المرتجعات\nRETURNS' : 'المرتجعات');
    rows.add(TextRow(returnTitle, isBold: true, scale: 1.1));
    rows.add(SpacingRow(_itemGap));

    final slLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showReturnSLNumber',
      resolvedArabic: resolvedLabels?.returnSlNumber,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'SL#',
      arabic: '#',
    );
    final particularsLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showReturnParticulars',
      resolvedArabic: resolvedLabels?.returnParticulars,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'PARTICULARS',
      arabic: 'البيان',
    );
    final mrpLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showReturnMRP',
      resolvedArabic: resolvedLabels?.returnMrp,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'MRP',
      arabic: 'MRP',
    );
    final qtyLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showReturnQty',
      resolvedArabic: resolvedLabels?.returnQty,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'QTY',
      arabic: 'الكمية',
    );
    final rateLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showReturnRate',
      resolvedArabic: resolvedLabels?.returnRate,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'RATE',
      arabic: 'السعر',
    );
    final totalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showReturnTotal',
      resolvedArabic: resolvedLabels?.returnTotal,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'TOTAL',
      arabic: 'الإجمالي',
    );

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
      final int itemQty = returnItem.quantity ?? 0;
      final String returnItemName = returnItem.productName ?? '';
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
        if (cartName == returnItemName) {
          itemRate = cartRate;
          itemMrp = cartMrp;
          break;
        }
      }
      if (itemRate == 0.0) {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
        int totalQty = 0;
        for (var ri in orderReturns.returnItems!) {
          totalQty += ri.quantity ?? 0;
        }
        itemRate = totalQty > 0 ? totalReturnAmount / totalQty : 0.0;
        itemMrp = itemRate;
      }
      final double itemTotal = itemQty * itemRate;
      if (showParticulars || showSl) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(showSl ? '${i + 1}. $returnItemName' : returnItemName,
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
      final countLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showReturnItemsCount',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Return Items:',
        arabic: 'عناصر المرتجع:',
        inlineBilingual: true,
      );
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
            label: _getModeLabel(
                displayConfig: displayConfig,
                key: 'showReturnTotalAmount',
                isEnglish: isEnglish,
                isBilingual: isBilingual,
                english: 'Return Total:',
                arabic: 'إجمالي المرتجع:'),
            value: returnRateTotal.toStringAsFixed(2),
            isBold: true,
            scale: 1.1,
            icon: currencyIcon,
            currencySymbol: currencySymbol));
      }
      if (showReturnNetAmt) {
        returnSummaryItems.add(StandardBoxedLineItem(
            label: _getModeLabel(
                displayConfig: displayConfig,
                key: 'showReturnNetAmount',
                isEnglish: isEnglish,
                isBilingual: isBilingual,
                english: 'Return Net Amount:',
                arabic: 'صافي مبلغ الإرجاع:'),
            value: returnRateTotal.toStringAsFixed(2),
            isBold: true,
            scale: 1.1,
            icon: currencyIcon,
            currencySymbol: currencySymbol));
      }
      rows.add(SpacingRow(_itemGap));
      rows.add(StandardBoxedTotalsRow(items: returnSummaryItems));
    }
  }

  void _buildFinalSummarySection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
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
      final int itemQty = returnItem.quantity ?? 0;
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
        int totalQty = 0;
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
          label: _getModeLabel(
              displayConfig: displayConfig,
              key: 'showFinalPurchase',
              isEnglish: isEnglish,
              isBilingual: isBilingual,
              english: 'ORDER TOTAL',
              arabic: 'إجمالي الطلب'),
          value: orderTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (showFinalReturn) {
      summaryItems.add(StandardBoxedLineItem(
          label: _getModeLabel(
              displayConfig: displayConfig,
              key: 'showFinalReturn',
              isEnglish: isEnglish,
              isBilingual: isBilingual,
              english: 'RETURN TOTAL',
              arabic: 'إجمالي المرتجع'),
          value: returnTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (showFinalNetAmount) {
      summaryItems.add(StandardBoxedLineItem(isSeparator: true));
      summaryItems.add(StandardBoxedLineItem(
          label: _getModeLabel(
              displayConfig: displayConfig,
              key: 'showFinalNetAmount',
              isEnglish: isEnglish,
              isBilingual: isBilingual,
              english: 'FINAL TOTAL  ',
              arabic: 'المبلغ النهائي'),
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
      if (isBilingual) {
        final arabicText = AmountHelper().convertNumberToWords(finalTotal,
            currency: currency, language: 'ar');
        final englishText = AmountHelper().convertNumberToWords(finalTotal,
            currency: currency, language: 'en');

        rows.add(TextRow('$arabicText فقط.', scale: 0.85, isBold: true));
        rows.add(TextRow('$englishText Only.',
            scale: 0.85,
            isBold: true,
            textDirectionOverride: TextDirection.ltr));
      } else {
        final language = isEnglish ? 'en' : 'ar';
        final amountText = AmountHelper().convertNumberToWords(finalTotal,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';
        rows.add(TextRow('$amountText$suffix', scale: 0.85, isBold: true));
      }
    }
    rows.add(SpacingRow(_itemGap));
  }
}
