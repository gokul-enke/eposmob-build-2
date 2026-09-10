import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:math' as math;

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
import 'receipt_configuration_contract.dart';
import 'receipt_layout_params.dart';
import 'receipt_pdf_builder.dart';
import '../thermal/printer_utils.dart';
import '../thermal/debug_image_saver.dart';
import '../thermal/thermal_paper_profile.dart';
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
class Premium2BilingualReceiptLayout implements ReceiptLayout {
  static final RegExp _arabicRegex = RegExp(r'[؀-ۿ]');
  // Temporary local test switch until the backend exposes EN_AR. Keep null in
  // production; set to 'EN_AR' in a debug build to force bilingual rendering.
  static const String? _debugLanguageOverride = null;
  bool _hasArabic(String? s) => s != null && _arabicRegex.hasMatch(s);

  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Premium theme spacing constants
  static const double _sectionGap = 14.0;
  static const double _itemGap = 6.0;
  static const double _headerGap = 8.0;

  @override
  String get layoutId => 'premium2_bilingual';

  @override
  String get displayName => 'Premium 2 Bilingual';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== PREMIUM 2 BILINGUAL LAYOUT: THERMAL PRINTING ====");

    final context = params.context;
    final selectedPrinter = params.selectedPrinter;
    final billDocumentConfig = params.billDocumentConfig;

    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: ${params.selectedPaperSize}");

    debugPrint(
        "[PREMIUM][LOGO] Config: showLogo=${billDocumentConfig.showLogo}, logo='${billDocumentConfig.logo}', layout=$layoutId, order=${params.orderNumber}");

    try {
      debugPrint("Connecting to printer...");
      await _printerUtils.connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully.");

      debugPrint("Rendering premium receipt images...");
      final rendered = await _renderReceiptImages(params);
      final imagePart1 = rendered.part1;
      final imagePart2 = rendered.part2;

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
                message: 'Development print saved to ${savedFile.path}',
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
      final ThermalPaperProfile paperProfile = params.thermalPaperProfile;
      if (paperProfile.is112mm) {
        debugPrint(
            '[PREMIUM2] 112mm selected: using ${paperProfile.rasterWidthPx}px raster images; ESC/POS package profile is used only for feed/barcode/cut commands.');
      }
      final generator = paperProfile.createGenerator(profile);
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
      rethrow;
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
    return buildContractReceiptPdf(params);
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    await printThermal(params);
  }

  /// Renders the same bitmap used by thermal printing without connecting to a
  /// printer. Printer Settings uses this for an exact, renderer-backed preview.
  Future<Uint8List> renderPreviewPng(ReceiptLayoutParams params) async {
    final rendered = await _renderReceiptImages(params);
    final width = math.max(rendered.part1.width, rendered.part2.width);
    final combined = img.Image(
      width: width,
      height: rendered.part1.height + rendered.part2.height,
      numChannels: 4,
    );
    img.fill(combined, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      combined,
      rendered.part1,
      dstX: (width - rendered.part1.width) ~/ 2,
      blend: img.BlendMode.direct,
    );
    img.compositeImage(
      combined,
      rendered.part2,
      dstX: (width - rendered.part2.width) ~/ 2,
      dstY: rendered.part1.height,
      blend: img.BlendMode.direct,
    );
    return Uint8List.fromList(img.encodePng(combined));
  }

  Future<_Premium2RenderedImages> _renderReceiptImages(
      ReceiptLayoutParams params) async {
    final context = params.context;
    final billDocumentConfig = params.billDocumentConfig;
    final displayConfig = params.displayConfig;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final paymentGatewaysProvider =
        Provider.of<PaymentGatewaysProvider>(context, listen: false);
    final isEnglish = _isEnglishContent(params);
    final isLtrLayout = _isLtrLayout(params);
    final textDirection = isLtrLayout ? TextDirection.ltr : TextDirection.rtl;
    final printWidth = params.printWidth;
    final baseFontSize = params.baseFontSize;
    final part1Rows = <ReceiptRow>[];
    final part2Rows = <ReceiptRow>[];
    final hasVisibleReceiptContent =
        displayConfig?.values.any((option) => option.visible == true) ?? false;

    final currencyCode =
        (appSettings?.currency.toString() ?? '').trim().toUpperCase();
    final useTextCurrencySymbol = currencyCode == 'INR';
    ui.Image? sarSymbol;
    if (!useTextCurrencySymbol) {
      try {
        sarSymbol =
            await _loadAssetImage('assets/images/saudi_riyal_symbol.png');
      } catch (error) {
        debugPrint('[PREMIUM] Error loading SAR symbol: $error');
      }
    }

    ui.Image? deliveryIcon;
    if (billDocumentConfig.showLogo == 1) {
      try {
        ui.Image? logo;
        if (billDocumentConfig.logo != null &&
            billDocumentConfig.logo.toString().isNotEmpty) {
          logo = await _fetchNetworkUiImage(billDocumentConfig.logo.toString());
        }
        if (logo != null) {
          part1Rows.add(ImageRow(logo, height: printWidth * 0.22));
          part1Rows.add(SpacingRow(_headerGap));
        }
      } catch (error) {
        debugPrint('[PREMIUM] Error loading logo: $error');
      }
    }
    if (billDocumentConfig.showIcon == 1 &&
        billDocumentConfig.icon != null &&
        billDocumentConfig.icon.toString().trim().isNotEmpty) {
      deliveryIcon =
          await _fetchNetworkUiImage(billDocumentConfig.icon.toString());
    }

    if (hasVisibleReceiptContent) {
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings,
          isEnglish, isLtrLayout);
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish,
          isLtrLayout, deliveryIcon);
      if (!params.isReturnOnly) {
        _buildCartItemsSection(
            part1Rows, params, displayConfig, isEnglish, isLtrLayout);
        _buildTotalsSection(part1Rows, params, displayConfig, isEnglish,
            sarSymbol, appSettings);
        _buildBankSection(
            part1Rows, params, displayConfig, isEnglish, isLtrLayout);
      }
      if (params.orderReturns?.returnItems?.isNotEmpty == true) {
        _buildReturnSection(part1Rows, params, displayConfig, isEnglish,
            isLtrLayout, sarSymbol, appSettings);
        if (!params.isReturnOnly) {
          _buildFinalSummarySection(part1Rows, params, displayConfig, isEnglish,
              sarSymbol, appSettings);
        }
      }
      _buildFooterSection(
          part2Rows, params, displayConfig, isEnglish, paymentGatewaysProvider);
    }

    if (part1Rows.isEmpty) part1Rows.add(SpacingRow(1));
    if (part2Rows.isEmpty) part2Rows.add(SpacingRow(1));

    final part1 = await ArabicPrinterHelper.renderReceiptToImage(
      rows: part1Rows,
      width: printWidth,
      fontSize: baseFontSize,
      textDirection: textDirection,
    );
    final part2 = await ArabicPrinterHelper.renderReceiptToImage(
      rows: part2Rows,
      width: printWidth,
      fontSize: baseFontSize,
      textDirection: textDirection,
    );
    return _Premium2RenderedImages(part1: part1, part2: part2);
  }

  // ==================== HEADER SECTION (Modern & Clean) ====================

  void _buildHeaderSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    dynamic appSettings,
    bool isEnglish,
    bool isLtrLayout,
  ) {
    final billDocumentConfig = params.billDocumentConfig;
    final bool isBilingual = _isBilingualContent(params);

    final documentHeader = _documentTextForMode(
      billDocumentConfig.header,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
    );
    final documentSubheader = _documentTextForMode(
      billDocumentConfig.subheader,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
    );

    if (documentHeader.isNotEmpty) {
      rows.add(TextRow(documentHeader,
          isBold: true, scale: 1.1, verticalPadding: 3, verticalOffset: 1));
    }

    if (documentSubheader.isNotEmpty) {
      rows.add(TextRow(documentSubheader,
          isBold: true, scale: 0.95, verticalPadding: 2, verticalOffset: 0));
    }

    for (final headingKey in const ['showExtraHeading1', 'showExtraHeading2']) {
      if (displayConfig?[headingKey]?.visible != true) continue;
      final heading = _getModeLabel(
        displayConfig: displayConfig,
        key: headingKey,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );
      if (heading.isNotEmpty) {
        rows.add(
            TextRow(heading, isBold: true, scale: 0.9, verticalPadding: 2));
      }
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
      double storeNameScale = 1.6;
      final longestStoreNameLine = storeName.split('\n').fold<int>(
          0, (length, line) => line.length > length ? line.length : length);
      if (longestStoreNameLine > 20) {
        storeNameScale = 1.3;
      } else if (longestStoreNameLine > 14) {
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
      final description = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDescription',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );
      if (description.isNotEmpty) {
        rows.add(SpacingRow(2));
        rows.add(TextRow(description.trim(),
            scale: 1.0, isBold: true, verticalPadding: 4, verticalOffset: 1));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // The option supplies visibility/label; the active store supplies value.
    final storeAddress = params.storeAddressText();
    if (storeAddress.isNotEmpty) {
      rows.add(TextRow(storeAddress, scale: 0.85, isBold: true));
    }

    // Invoice Title (Moved above Tax/Fssai Info)
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showInvoiceTitle',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: appSettings?.printTitle ?? 'INVOICE',
        arabic: 'فاتورة',
      );
      debugPrint(
          "[Premium2BilingualReceiptLayout] order=${params.orderNumber}, customerType=${params.customerType ?? 'null'}, hasCustomerKyc=${(params.customerVatNumber?.trim().isNotEmpty ?? false) || (params.customerCrNumber?.trim().isNotEmpty ?? false)}, printedInvoiceTitle=$invoiceTitle");
      rows.add(SpacingRow(5));
      rows.add(TextRow(invoiceTitle.toUpperCase(), isBold: true, scale: 1.1));
      rows.add(SpacingRow(2));
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showFssaiInfo',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'FSSAI / Tax Information',
        arabic: 'معلومات FSSAI / الضريبة',
      );
      if (fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.85, isBold: true));
      }
    }

    if (displayConfig?['showVatNumber']?.visible == true) {
      final configuredVat = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showVatNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );
      final vatNumber = params.zatcaVatNumber?.trim() ?? '';
      if (configuredVat.isNotEmpty) {
        rows.add(TextRow(configuredVat, scale: 0.85, isBold: true));
      } else if (vatNumber.isNotEmpty) {
        final label = isBilingual
            ? _getInlineBilingualText(
                arabic: 'الرقم الضريبي', english: 'VAT Number')
            : (isEnglish ? 'VAT Number' : 'الرقم الضريبي');
        rows.add(TextRow('$label: $vatNumber', scale: 0.85, isBold: true));
      }
    }

    if (displayConfig?['showCRNumber']?.visible == true) {
      final configuredCr = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCRNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );
      final crNumber = params.zatcaCrNumber?.trim() ?? '';
      if (configuredCr.isNotEmpty) {
        rows.add(TextRow(configuredCr, scale: 0.85, isBold: true));
      } else if (crNumber.isNotEmpty) {
        final label = isBilingual
            ? _getInlineBilingualText(
                arabic: 'السجل التجاري', english: 'CR Number')
            : (isEnglish ? 'CR Number' : 'السجل التجاري');
        rows.add(TextRow('$label: $crNumber', scale: 0.85, isBold: true));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final configuredPhone = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTel',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );
      final phone = params.storePhone?.isNotEmpty == true
          ? params.storePhone!
          : (appSettings?.customerCarePhone ?? '');
      if (configuredPhone.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(configuredPhone, scale: 1.15, isBold: true));
      } else if (phone.isNotEmpty) {
        final label = isBilingual
            ? _getInlineBilingualText(arabic: 'رقم الهاتف', english: 'Phone')
            : (isEnglish ? 'Phone' : 'رقم الهاتف');
        rows.add(SpacingRow(5));
        rows.add(TextRow('$label: $phone', scale: 1.15, isBold: true));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final configuredEmail = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showEmail',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
      );
      final emailVal = params.storeEmail?.isNotEmpty == true
          ? params.storeEmail!
          : (appSettings?.customerCareEmail ?? '');
      if (configuredEmail.isNotEmpty) {
        rows.add(TextRow(configuredEmail, scale: 0.9, isBold: true));
      } else if (emailVal.isNotEmpty) {
        final label = isBilingual
            ? _getInlineBilingualText(
                arabic: 'البريد الإلكتروني', english: 'Email')
            : (isEnglish ? 'Email' : 'البريد الإلكتروني');
        rows.add(TextRow('$label: $emailVal', scale: 0.9, isBold: true));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(ThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Invoice/Token Number - hide header invoice when footer invoice number is enabled
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

      // Prefer the language-specific option label. The document-level prefix
      // remains the fallback for older configurations that expose only
      // `number_prefix`.
      final documentNumberPrefix = _documentTextForMode(
        params.billDocumentConfig.numberPrefix,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
      );
      final String invoicePrefix = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showInvoiceNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english:
            documentNumberPrefix.isNotEmpty ? documentNumberPrefix : 'INV-',
        arabic: documentNumberPrefix.isNotEmpty
            ? documentNumberPrefix
            : 'رقم الفاتورة:',
        inlineBilingual: true,
      );

      invoiceNumberText = invoicePrefix.isEmpty
          ? strippedNumber
          : _appendValueToModeLabel(
              invoicePrefix,
              strippedNumber,
              isBilingual,
            );
    }

    String? tokenText;
    if (showTokenNumber) {
      final tokenPrefix = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTokenNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Token Number',
        arabic: 'رقم الرمز',
      );
      tokenText = tokenPrefix.isNotEmpty
          ? _appendValueToModeLabel(
              tokenPrefix, params.tokenNumber!, isBilingual)
          : params.tokenNumber!;
    }

    if (invoiceNumberText != null && tokenText != null) {
      if (isBilingual) {
        // Two bilingual labels cannot remain readable in narrow side-by-side
        // columns. Stack them and give each the full receipt width.
        rows.add(TextRow(invoiceNumberText,
            align: TextAlign.center, isBold: true, scale: 1.0));
        rows.add(TextRow(tokenText,
            align: TextAlign.center, isBold: true, scale: 0.9));
      } else {
        final invoiceAlign = isLtrLayout ? TextAlign.left : TextAlign.right;
        final tokenAlign = isLtrLayout ? TextAlign.right : TextAlign.left;
        final invoiceCol = ReceiptTableColumn(invoiceNumberText,
            weight: 0.58, align: invoiceAlign, isBold: true, scale: 1.1);
        final tokenCol = ReceiptTableColumn(tokenText,
            weight: 0.38, align: tokenAlign, isBold: true, scale: 1.1);
        final spacerCol =
            ReceiptTableColumn('', weight: 0.04, align: TextAlign.center);

        rows.add(ReceiptTableRow(isLtrLayout
            ? [invoiceCol, spacerCol, tokenCol]
            : [tokenCol, spacerCol, invoiceCol]));
      }
    } else if (invoiceNumberText != null) {
      rows.add(TextRow(invoiceNumberText, scale: 1.3, isBold: true));
    } else if (tokenText != null) {
      rows.add(TextRow(tokenText, scale: 1.4, isBold: true));
    }

    // Date belongs to the invoice metadata, before customer and item details.
    if (displayConfig?['showDate']?.visible == true) {
      final formattedDate = params.isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
          : DateHelper.formatISODate(params.orderDate);
      final formattedTime = params.isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
          : DateHelper.formatISOTimeOnlyToIST(params.orderDate);
      final dateLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDate',
        resolvedArabic: billDocumentConfig.resolvedLabels?.date,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Date',
        arabic: 'التاريخ',
        inlineBilingual: true,
      );
      rows.add(TextRow(
        dateLabel.isEmpty
            ? '$formattedDate  $formattedTime'
            : _appendValueToModeLabel(
                dateLabel,
                '$formattedDate  $formattedTime',
                isBilingual,
              ),
        scale: 0.85,
        align: isLtrLayout ? TextAlign.left : TextAlign.right,
      ));
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
    bool isLtrLayout,
    ui.Image? deliveryIcon,
  ) {
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
    final bool isBilingual = _isBilingualContent(params);

    final bool showCustomerMaster =
        displayConfig?['showCustomerNameAndPhone']?.visible == true;
    final bool showCustomerName = showCustomerMaster &&
        displayConfig?['showCustomerName']?.visible == true;
    final bool showCustomerPhone = showCustomerMaster &&
        displayConfig?['showCustomerPhone']?.visible == true;
    final bool showPayment = displayConfig?[paymentConfigKey]?.visible == true;
    final bool showCustomerAddress =
        displayConfig?['showCustomerAddress']?.visible == true;
    final bool showComment = displayConfig?[commentConfigKey]?.visible == true;
    final bool showDeliveryMethod =
        displayConfig?['showDeliveryMethod']?.visible == true;
    final bool showDeliveryPhone =
        displayConfig?['showDeliveryPhone']?.visible == true;
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
            params.customerCrNumber!.isNotEmpty) ||
        (showDeliveryPhone &&
            (params.deliveryPhone?.trim().isNotEmpty ?? false));

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
    final deliveryPhoneLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showDeliveryPhone',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Delivery Phone:',
      arabic: 'هاتف التوصيل:',
      inlineBilingual: true,
    );

    final customerSectionTitle = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerNameAndPhone',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: '',
      arabic: '',
    );

    if (customerSectionTitle.isNotEmpty) {
      rows.add(TextRow(
        customerSectionTitle,
        isBold: true,
        scale: scale,
        align: isLtrLayout ? TextAlign.left : TextAlign.right,
      ));
    }

    if (deliveryIcon != null && showDeliveryMethod) {
      rows.add(ImageRow(deliveryIcon,
          height: params.printWidth * 0.10, align: TextAlign.center));
    }

    if (isLtrLayout) {
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

      if (showDeliveryPhone &&
          (params.deliveryPhone?.trim().isNotEmpty ?? false)) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(deliveryPhoneLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.deliveryPhone!.trim(),
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
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
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
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
        ]));
      }

      if (showPayment &&
          params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(paymentLabel,
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
        ]));
      }

      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(commentLabel,
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
        ]));
      }

      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.deliveryMethod!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(deliveryLabel,
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
        ]));
      }

      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerVatNumber!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(customerVatLabel,
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
        ]));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerCrNumber!,
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(customerCrLabel,
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
        ]));
      }

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(TextRow(
          _appendValueToModeLabel(
              addressLabel, ': ${params.customerAddress!}', isBilingual),
          scale: 0.9,
          align: TextAlign.right,
        ));
      }

      if (showDeliveryPhone &&
          (params.deliveryPhone?.trim().isNotEmpty ?? false)) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.deliveryPhone!.trim(),
              weight: 0.65, align: TextAlign.left, scale: scale),
          ReceiptTableColumn(deliveryPhoneLabel,
              weight: 0.35,
              align: TextAlign.right,
              isBold: true,
              scale: scale,
              maxLines: isBilingual ? 2 : 1),
        ]));
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
    bool isLtrLayout,
  ) {
    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool isBilingual = _isBilingualContent(params);

    // Extract labels with fallbacks
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
      arabic: '#',
    );
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
        isLtrLayout,
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

    if (params.isReturnOnly) {
      return;
    }

    // Build cart items
    for (var i = 0; i < params.cartItems.length; i++) {
      _buildCartItemRow(
          rows,
          params.cartItems[i],
          i,
          params.isFromLocalStorage,
          displayConfig,
          isEnglish,
          isLtrLayout,
          isBilingual,
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
      final itemsCountLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showItemsCount',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Items',
        arabic: 'أغراض',
        inlineBilingual: true,
      );
      final int itemCount = params.cartItems.length;
      rows.add(TextRow(
        _appendValueToModeLabel(itemsCountLabel, ': $itemCount', isBilingual),
        scale: 0.9,
        isBold: true,
      ));
      rows.add(SpacingRow(_itemGap));
    }

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
      final totalQuantity = params.totalQuantity;
      final formattedQuantity = totalQuantity % 1 == 0
          ? totalQuantity.toInt().toString()
          : totalQuantity.toStringAsFixed(2);
      rows.add(TextRow(
        _appendValueToModeLabel(
            quantityCountLabel, ': $formattedQuantity', isBilingual),
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
    bool isLtrLayout,
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
    String fitHeader(String label) {
      if (tableWeights.length < 7) return label;
      return label
          .split('\n')
          .expand((line) => line
              .trim()
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty))
          .join('\n');
    }

    if (isLtrLayout) {
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(slLabel),
            weight: tableWeights['showSLNumber'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(particularsLabel),
            weight: tableWeights['showParticulars'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(mrpLabel),
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(qtyLabel),
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(rateLabel),
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(rateExcTaxLabel),
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(unitLabel),
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(taxHeaderLabel),
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(totalLabel),
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
        headerCols.add(ReceiptTableColumn(fitHeader(totalLabel),
            weight: tableWeights['showTotal'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(taxHeaderLabel),
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(unitLabel),
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(rateExcTaxLabel),
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showRate']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(rateLabel),
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showQty']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(qtyLabel),
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(mrpLabel),
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(particularsLabel),
            weight: tableWeights['showParticulars'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (displayConfig?['showSLNumber']?.visible == true) {
        headerCols.add(ReceiptTableColumn(fitHeader(slLabel),
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
    bool isLtrLayout,
    bool isBilingual,
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
    bool warrantyEnabled = false;

    if (isFromLocalStorage || item is Map) {
      final dynamic rawNames = item['names'];
      final names = rawNames is Map ? rawNames : const <String, dynamic>{};
      final itemNameEnglish =
          (names['en'] ?? item['productName'] ?? item['product_name'] ?? '')
              .toString();
      final itemNameArabic = (names['ar'] ?? '').toString();
      if (isBilingual && itemNameArabic.isNotEmpty) {
        productNameArabic = itemNameArabic;
        productName = itemNameEnglish;
      } else if (!isEnglish && itemNameArabic.isNotEmpty) {
        productName = itemNameArabic;
      } else {
        productName = itemNameEnglish;
      }
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
      unitName = getPrintUnit(item);
      totalPrice = (double.tryParse(
                  (item['totalPrice'] ?? item['total_price'])?.toString() ??
                      '0') ??
              0.0)
          .toStringAsFixed(2);
      itemTaxAmount = taxValue.toStringAsFixed(2);
      warrantyEnabled = item['warrantyEnabled'] == true ||
          item['warranty_enabled'] == true ||
          item['warrantyEnabled']?.toString() == '1' ||
          item['warranty_enabled']?.toString() == '1';
    } else {
      final itemNameEnglish = item.names?.en ?? item.productName ?? '';
      final itemNameArabic = item.names?.ar ?? '';
      if (isBilingual && itemNameArabic.isNotEmpty) {
        // Bilingual mode renders Arabic first and English second.
        productNameArabic = itemNameArabic;
        productName = itemNameEnglish;
      } else if (!isEnglish && itemNameArabic.isNotEmpty) {
        // Arabic mode must remain Arabic-only.
        productName = itemNameArabic;
        productNameArabic = '';
      } else {
        // English mode, or a product without a translated Arabic name.
        productName = itemNameEnglish;
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
      unitName = getPrintUnit(item);
      totalPrice = (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      itemTaxAmount = taxValue.toStringAsFixed(2);
      warrantyEnabled = item.warrantyEnabled == true;
    }

    String slNumber = (index + 1).toString();

    if (isLtrLayout) {
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
          // Fallback to single name (English or Arabic). Some clients only
          // populate the English name field but store Arabic text in it, so
          // detect the script instead of assuming the field content is English.
          final bool nameIsArabic = _hasArabic(productName);
          String itemText = displayConfig?['showSLNumber']?.visible == true
              ? '$slNumber. $productName'
              : productName;
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText,
                weight: 1.0,
                align: nameIsArabic ? TextAlign.right : TextAlign.left,
                textDirection:
                    nameIsArabic ? TextDirection.rtl : TextDirection.ltr),
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
      if (displayConfig?['showUnit']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitName,
            weight: tableWeights['showUnit'] ?? 0,
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
      if (displayConfig?['showRate']?.visible == true) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: tableWeights['showRate'] ?? 0,
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

    if (displayConfig?['showWarranty']?.visible == true && warrantyEnabled) {
      final warrantyLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showWarranty',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Warranty',
        arabic: 'الضمان',
      );
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(
          warrantyLabel,
          weight: 1.0,
          align: isLtrLayout ? TextAlign.left : TextAlign.right,
          textDirection: isLtrLayout ? TextDirection.ltr : TextDirection.rtl,
        ),
      ]));
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
    final bool isDualLanguage = _isBilingualContent(params);

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

    final totalMrp = total + saved;

    // Every total has its own admin switch. Missing options must stay hidden;
    // older code merged Sub Total and MRP Total and therefore printed the
    // wrong label beside the ex-tax subtotal.
    final showSubTotal = displayConfig?['showSubTotal']?.visible == true;
    final showMRPTotal = displayConfig?['showMRPTotal']?.visible == true;
    final showDiscount = displayConfig?['showDiscount']?.visible == true;
    final showSaved = displayConfig?['showSaved']?.visible == true;
    final showTax = displayConfig?['showTax']?.visible == true;
    final showNetAmount = displayConfig?['showNetAmount']?.visible == true;

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
        "  showSubTotal: $showSubTotal (API: ${displayConfig?['showSubTotal']?.visible})");
    debugPrint(
        "  showMRPTotal: $showMRPTotal (API: ${displayConfig?['showMRPTotal']?.visible})");
    debugPrint(
        "  showDiscount: $showDiscount (API: ${displayConfig?['showDiscount']?.visible})");
    debugPrint(
        "  showTax: $showTax (API: ${displayConfig?['showTax']?.visible})");
    debugPrint(
        "  showNetAmount: $showNetAmount (API: ${displayConfig?['showNetAmount']?.visible})");
    debugPrint("=======================================");

    // EXTRA: dump all displayConfig keys and their visible/value for diagnosing missing subtotal
    debugPrint("===== FULL DISPLAY CONFIG DUMP =====");
    if (displayConfig == null) {
      debugPrint("  displayConfig is NULL");
    } else {
      displayConfig.forEach((key, opt) {
        debugPrint("  [$key] visible=${opt.visible} value=${opt.value}");
      });
    }
    debugPrint("  params.netExcTax: ${params.netExcTax}");
    debugPrint("  subtotal (resolved): $subtotal");
    debugPrint("  totalMrp (net + saved): $totalMrp");
    debugPrint("=====================================");

    // Labels
    final subtotalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showSubTotal',
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'SUBTOTAL (EXC TAX)',
      arabic: 'المجموع الفرعي دون الضريبة',
    );

    final mrpTotalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showMRPTotal',
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'MRP TOTAL',
      arabic: 'إجمالي سعر التجزئة',
    );

    final discountLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showDiscount',
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'DISCOUNTS',
      arabic: 'الخصم',
    );
    final discountLabel = discountLabelBase;

    final taxLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showTax',
      resolvedArabic: resolvedLabels?.tax,
      resolvedEnglish: resolvedLabels?.taxDefault,
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'VAT',
      arabic: 'ضريبة القيمة المضافة',
    );
    final vatLabel = taxLabelBase;

    final grandTotalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showNetAmount',
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'GRAND TOTAL',
      arabic: 'المبلغ الاجمالي',
    );

    final savedLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showSaved',
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'YOU SAVED',
      arabic: 'لقد وفرت',
    );

    final cashLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCash',
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'Cash',
      arabic: 'نقدي',
      inlineBilingual: true,
    );
    // Prepare boxed items
    List<BoxedLineItem> boxedItems = [];

    // 1. Ex-tax subtotal
    if (showSubTotal) {
      boxedItems.add(BoxedLineItem(
        label: subtotalLabel,
        value: subtotal.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 2. MRP total
    if (showMRPTotal) {
      boxedItems.add(BoxedLineItem(
        label: mrpTotalLabel,
        value: totalMrp.toStringAsFixed(2),
        isBold: true,
        scale: 1.0,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 3. Discounts. Visible means visible even when the value is zero.
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

    // 4. Savings
    if (showSaved) {
      boxedItems.add(BoxedLineItem(
        label: savedLabel,
        value: saved.toStringAsFixed(2),
        isBold: true,
        scale: 1.0,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 5. VAT
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

    // 6. Grand Total (Bold)
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

    // 7. Payment details
    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible == true;

    if (params.paidAmount != null && showPaymentBreaked) {
      boxedItems.add(BoxedLineItem(isSeparator: true));

      final paymentBreakdownTitle = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showPaymentBreaked',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: '',
        arabic: '',
      );
      if (paymentBreakdownTitle.isNotEmpty) {
        boxedItems.add(BoxedLineItem(
          label: paymentBreakdownTitle,
          value: '',
          isBold: true,
          scale: 0.95,
        ));
      }

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
                  ? _getInlineBilingualText(arabic: 'نقدي', english: 'Cash')
                  : (isEnglish ? "Cash" : "نقدي");
            } else if (method == 'CARD') {
              label = isDualLanguage
                  ? _getInlineBilingualText(arabic: 'بطاقة', english: 'Card')
                  : (isEnglish ? "Card" : "بطاقة");
            } else if (method == 'UPI') {
              label = "UPI";
            }

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
                if (method == 'CASH') {
                  label = isDualLanguage
                      ? _getInlineBilingualText(arabic: 'نقدي', english: 'Cash')
                      : (isEnglish ? "Cash" : "نقدي");
                } else if (method == 'CARD') {
                  label = isDualLanguage
                      ? _getInlineBilingualText(
                          arabic: 'بطاقة', english: 'Card')
                      : (isEnglish ? "Card" : "بطاقة");
                } else if (method == 'UPI') {
                  label = "UPI";
                }

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

    // Never draw an empty border when every amount control is disabled.
    if (boxedItems.isNotEmpty) {
      rows.add(BoxedTotalsRow(items: boxedItems));
    }

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(_itemGap));

      final amountInWordsTitle = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showAmountInWords',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: '',
        arabic: '',
      );
      if (amountInWordsTitle.isNotEmpty) {
        rows.add(TextRow(
          amountInWordsTitle,
          scale: is58mm ? 0.7 : 0.85,
          isBold: true,
        ));
      }

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
        final language = _amountWordsLanguageCode(params);
        final amountText = AmountHelper().convertNumberToWords(total,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';

        rows.add(TextRow('$amountText$suffix',
            scale: is58mm ? 0.7 : 0.85, isBold: true));
      }
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
    if (displayConfig?['showCustomerBalance']?.visible != true) {
      return;
    }

    // Hide balance information for default/walk-in customers
    if (params.isDefaultCustomer) {
      return;
    }

    final bool isBilingual = _isBilingualContent(params);

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

    final balanceSectionTitle = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerBalance',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: '',
      arabic: '',
    );
    if (balanceSectionTitle.isNotEmpty) {
      rows.add(TextRow(
        balanceSectionTitle,
        isBold: true,
        scale: scale,
      ));
    }

    // Get labels from displayConfig - shorter for 58mm
    final prevBalanceLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerPrevBalance',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Previous Balance',
      arabic: 'الرصيد السابق',
      inlineBilingual: true,
    );
    final prevBalanceLabel = prevBalanceLabelBase;

    final paidAmountLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerPaidAmount',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Paid Amount',
      arabic: 'المبلغ المدفوع',
      inlineBilingual: true,
    );
    final paidAmountLabel = paidAmountLabelBase;

    final currentBalanceLabelBase = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showCustomerCurrentBalance',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'Current Balance',
      arabic: 'الرصيد الحالي',
      inlineBilingual: true,
    );
    final currentBalanceLabel = currentBalanceLabelBase;

    // Previous Balance
    if (displayConfig?['showCustomerPrevBalance']?.visible == true &&
        params.customerOldBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(prevBalanceLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

    // Paid Amount (this transaction)
    if (displayConfig?['showCustomerPaidAmount']?.visible == true &&
        params.paidAmount != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(paidAmountLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

    // Current Balance
    if (displayConfig?['showCustomerCurrentBalance']?.visible == true &&
        params.customerCurrentBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(currentBalanceLabel,
            weight: 0.6, align: TextAlign.right, isBold: true, scale: scale),
        ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, isBold: true, scale: scale),
      ]));
    }
  }

  void _buildBankSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isLtrLayout,
  ) {
    if (displayConfig?['showBankInfo']?.visible != true) return;

    final bank = params.primaryBank;
    final account = params.primaryBankAccount;
    if (bank == null && account == null) return;

    final isBilingual = _isBilingualContent(params);
    final details = <({String label, String value})>[];

    void addDetail(
      String key,
      String? value, {
      required String english,
      required String arabic,
    }) {
      if (displayConfig?[key]?.visible != true) return;
      final cleanValue = value?.trim() ?? '';
      if (cleanValue.isEmpty) return;
      details.add((
        label: _getModeLabel(
          displayConfig: displayConfig,
          key: key,
          isEnglish: isEnglish,
          isBilingual: isBilingual,
          english: english,
          arabic: arabic,
        ),
        value: cleanValue,
      ));
    }

    addDetail('showBankName', bank?.bankName,
        english: 'Bank Name', arabic: 'اسم البنك');
    addDetail('showAccountName', account?.accountHolderName,
        english: 'Account Name', arabic: 'اسم الحساب');
    addDetail('showAccountNumber', account?.accountNumber,
        english: 'Account Number', arabic: 'رقم الحساب');
    addDetail('showIBAN', account?.iban,
        english: 'IBAN', arabic: 'رقم الآيبان');
    addDetail('showSwiftCode', account?.swiftCode,
        english: 'SWIFT', arabic: 'رمز سويفت');

    if (details.isEmpty) return;

    final title = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showBankInfo',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'BANK DETAILS',
      arabic: 'تفاصيل الحساب البنكي',
    );

    rows.add(SpacingRow(_sectionGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
    rows.add(TextRow(title, isBold: true, scale: 0.95));
    rows.add(SpacingRow(3));

    for (final detail in details) {
      final columns = isLtrLayout
          ? [
              ReceiptTableColumn(detail.label,
                  weight: 0.42,
                  align: TextAlign.left,
                  isBold: true,
                  maxLines: isBilingual ? 2 : 1),
              ReceiptTableColumn(detail.value,
                  weight: 0.58,
                  align: TextAlign.left,
                  textDirection: TextDirection.ltr,
                  maxLines: 2),
            ]
          : [
              ReceiptTableColumn(detail.value,
                  weight: 0.58,
                  align: TextAlign.left,
                  textDirection: TextDirection.ltr,
                  maxLines: 2),
              ReceiptTableColumn(detail.label,
                  weight: 0.42,
                  align: TextAlign.right,
                  isBold: true,
                  maxLines: isBilingual ? 2 : 1),
            ];
      rows.add(ReceiptTableRow(columns));
    }
  }

  // ==================== RETURN ITEMS SECTION ====================

  void _buildReturnSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isLtrLayout,
    ui.Image? sarSymbol,
    dynamic appSettings,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return;
    }

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;
    final bool isBilingual = _isBilingualContent(params);

    final retDc = params.returnBillDisplayConfig;
    final retLabels = params.returnBillResolvedLabels;
    final hasCreditNoteConfig = retLabels?.creditNoteNumber != null ||
        retLabels?.creditNoteDate != null;

    rows.add(SpacingRow(_sectionGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
    if (!hasCreditNoteConfig) {
      rows.add(TextRow(
        isBilingual
            ? _getBilingualText(
                arabic: params.returnsSectionHeadingArabic,
                english: params.returnsSectionHeading)
            : (isEnglish
                ? params.returnsSectionHeading
                : params.returnsSectionHeadingArabic),
        isBold: true,
        scale: 1.1,
      ));
    }
    rows.add(SpacingRow(_itemGap));

    // — Credit Note Details section —
    if (hasCreditNoteConfig) {
      final detailsHeading = isBilingual
          ? _getBilingualText(
              arabic: (retDc?['showCreditNoteOrder']?.value as String?)
                          ?.isNotEmpty ==
                      true
                  ? retDc!['showCreditNoteOrder']!.value as String
                  : 'تفاصيل إشعار الائتمان',
              english: (retDc?['showCreditNoteOrder']?.value as String?)
                          ?.isNotEmpty ==
                      true
                  ? retDc!['showCreditNoteOrder']!.value as String
                  : 'CREDIT NOTE DETAILS')
          : (isEnglish
              ? (retLabels?.detailsHeading?.isNotEmpty == true
                  ? retLabels!.detailsHeading!
                  : 'CREDIT NOTE DETAILS')
              : 'تفاصيل إشعار الائتمان');
      rows.add(TextRow(detailsHeading, isBold: true, scale: scale));
      rows.add(SpacingRow(_itemGap));
      if (retLabels?.creditNoteNumber != null) {
        final cnLabelText = retLabels?.creditNoteNumber?.isNotEmpty == true
            ? retLabels!.creditNoteNumber!
            : 'Credit Note No:';
        final cnLabel = isBilingual
            ? _getBilingualText(
                arabic: 'رقم إشعار الائتمان:', english: cnLabelText)
            : (isEnglish ? cnLabelText : 'رقم إشعار الائتمان:');
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(cnLabel,
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.orderNumber,
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      if (retLabels?.creditNoteDate != null) {
        final dateLabelText = retLabels?.creditNoteDate?.isNotEmpty == true
            ? retLabels!.creditNoteDate!
            : 'Credit Note Date:';
        final dateLabel = isBilingual
            ? _getBilingualText(
                arabic: 'تاريخ إشعار الائتمان:', english: dateLabelText)
            : (isEnglish ? dateLabelText : 'تاريخ إشعار الائتمان:');
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(dateLabel,
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.orderDate,
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      rows.add(SpacingRow(_itemGap));
    }

    // — Customer Details section —
    if (params.customerName != null && params.customerName!.trim().isNotEmpty) {
      final custHeading = isBilingual
          ? _getBilingualText(
              arabic: retLabels?.customerHeading ?? 'تفاصيل العميل',
              english: retLabels?.customerHeading ?? 'CUSTOMER DETAILS')
          : (isEnglish
              ? (retLabels?.customerHeading ?? 'CUSTOMER DETAILS')
              : (retLabels?.customerHeading ?? 'تفاصيل العميل'));
      rows.add(TextRow(custHeading, isBold: true, scale: scale));
      rows.add(SpacingRow(_itemGap));
      final custNameLabel = isBilingual
          ? _getBilingualText(arabic: 'اسم العميل:', english: 'Customer Name:')
          : (isEnglish ? 'Customer Name:' : 'اسم العميل:');
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(custNameLabel,
            weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
        ReceiptTableColumn(params.customerName!,
            weight: 0.55, align: TextAlign.left, scale: scale),
      ]));
      if (params.customerPhone != null &&
          params.customerPhone!.trim().isNotEmpty) {
        final phoneLabel = isBilingual
            ? _getBilingualText(arabic: 'الهاتف:', english: 'Phone:')
            : (isEnglish ? 'Phone:' : 'الهاتف:');
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(phoneLabel,
              weight: 0.45, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.customerPhone!,
              weight: 0.55, align: TextAlign.left, scale: scale),
        ]));
      }
      if (params.customerAddress != null &&
          params.customerAddress!.trim().isNotEmpty) {
        final addrLabel = isBilingual
            ? _getBilingualText(
                arabic: 'عنوان الفاتورة:', english: 'Billing Address:')
            : (isEnglish ? 'Billing Address:' : 'عنوان الفاتورة:');
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(addrLabel,
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

    // Extract column labels
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

    // Build normalized column weights
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

    // Table header
    if (showSl ||
        showParticulars ||
        showMrp ||
        showQty ||
        showRate ||
        showTotal) {
      List<ReceiptTableColumn> headerCols = [];
      if (isLtrLayout && showSl) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: weights['sl'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: scale));
      }
      if (isLtrLayout && showParticulars) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: weights['particulars'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: scale));
      }
      if (isLtrLayout && showMrp) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: weights['mrp'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: scale));
      }
      if (isLtrLayout && showQty) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: weights['qty'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: scale));
      }
      if (isLtrLayout && showRate) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: weights['rate'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: scale));
      }
      if (isLtrLayout && showTotal) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: weights['total'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: scale));
      }
      if (!isLtrLayout) {
        if (showTotal) {
          headerCols.add(ReceiptTableColumn(totalLabel,
              weight: weights['total'] ?? 0,
              align: TextAlign.right,
              isBold: true,
              scale: scale));
        }
        if (showRate) {
          headerCols.add(ReceiptTableColumn(rateLabel,
              weight: weights['rate'] ?? 0,
              align: TextAlign.right,
              isBold: true,
              scale: scale));
        }
        if (showQty) {
          headerCols.add(ReceiptTableColumn(qtyLabel,
              weight: weights['qty'] ?? 0,
              align: TextAlign.right,
              isBold: true,
              scale: scale));
        }
        if (showMrp) {
          headerCols.add(ReceiptTableColumn(mrpLabel,
              weight: weights['mrp'] ?? 0,
              align: TextAlign.right,
              isBold: true,
              scale: scale));
        }
        if (showParticulars) {
          headerCols.add(ReceiptTableColumn(particularsLabel,
              weight: weights['particulars'] ?? 0,
              align: TextAlign.right,
              isBold: true,
              scale: scale));
        }
        if (showSl) {
          headerCols.add(ReceiptTableColumn(slLabel,
              weight: weights['sl'] ?? 0,
              align: TextAlign.right,
              isBold: true,
              scale: scale));
        }
      }
      rows.add(ReceiptTableRow(headerCols));
      rows.add(ThinDividerRow());
    }

    // Return items
    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final num itemQty = returnItem.quantity ?? 0;
      final String productName = returnItem.productName ?? '';

      double itemMrp = 0.0;
      double itemRate = 0.0;

      for (var cartItem in params.cartItems) {
        String cartName = '';
        double cartRate = 0.0;
        double cartMrp = 0.0;

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

      // Fallback: average rate from returnTotalAmount
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
      final String slNumber = '${i + 1}';

      // Product name row
      if (showParticulars || showSl) {
        final String nameText =
            showSl ? '$slNumber. $productName' : productName;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(nameText,
              weight: 1.0,
              align: isLtrLayout ? TextAlign.left : TextAlign.right,
              scale: scale,
              textDirection:
                  _hasArabic(nameText) ? TextDirection.rtl : TextDirection.ltr),
        ]));
      }

      // Price details row
      final double detailsWeight =
          (weights['sl'] ?? 0) + (weights['particulars'] ?? 0);
      List<ReceiptTableColumn> priceCols = [];
      if (isLtrLayout && detailsWeight > 0) {
        priceCols.add(ReceiptTableColumn('', weight: detailsWeight));
      }
      if (isLtrLayout && showMrp) {
        priceCols.add(ReceiptTableColumn(itemMrp.toStringAsFixed(2),
            weight: weights['mrp'] ?? 0,
            align: TextAlign.center,
            scale: scale));
      }
      if (isLtrLayout && showQty) {
        priceCols.add(ReceiptTableColumn(itemQty.toString(),
            weight: weights['qty'] ?? 0,
            align: TextAlign.center,
            scale: scale));
      }
      if (isLtrLayout && showRate) {
        priceCols.add(ReceiptTableColumn(itemRate.toStringAsFixed(2),
            weight: weights['rate'] ?? 0,
            align: TextAlign.right,
            scale: scale));
      }
      if (isLtrLayout && showTotal) {
        priceCols.add(ReceiptTableColumn(itemTotal.toStringAsFixed(2),
            weight: weights['total'] ?? 0,
            align: TextAlign.right,
            scale: scale));
      }
      if (!isLtrLayout) {
        if (showTotal) {
          priceCols.add(ReceiptTableColumn(itemTotal.toStringAsFixed(2),
              weight: weights['total'] ?? 0,
              align: TextAlign.right,
              scale: scale));
        }
        if (showRate) {
          priceCols.add(ReceiptTableColumn(itemRate.toStringAsFixed(2),
              weight: weights['rate'] ?? 0,
              align: TextAlign.right,
              scale: scale));
        }
        if (showQty) {
          priceCols.add(ReceiptTableColumn(itemQty.toString(),
              weight: weights['qty'] ?? 0,
              align: TextAlign.right,
              scale: scale));
        }
        if (showMrp) {
          priceCols.add(ReceiptTableColumn(itemMrp.toStringAsFixed(2),
              weight: weights['mrp'] ?? 0,
              align: TextAlign.right,
              scale: scale));
        }
        if (detailsWeight > 0) {
          priceCols.add(ReceiptTableColumn('', weight: detailsWeight));
        }
      }
      if (priceCols.any((c) => c.text.isNotEmpty)) {
        rows.add(ReceiptTableRow(priceCols));
      }

      if (i < orderReturns.returnItems!.length - 1) {
        rows.add(ThinDividerRow());
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Return items count
    if (displayConfig?['showReturnItemsCount']?.visible == true) {
      final bool useCreditNoteItemsCount =
          retLabels?.creditNoteItemsCount != null;
      final countLabel = useCreditNoteItemsCount
          ? (isBilingual
              ? _getInlineBilingualText(
                  arabic: 'عناصر إشعار الائتمان:',
                  english: 'Credit Note Items:')
              : (isEnglish ? 'Credit Note Items:' : 'عناصر إشعار الائتمان:'))
          : (isBilingual
              ? _getInlineBilingualText(
                  arabic: 'عناصر المرتجع:', english: 'Return Items:')
              : (isEnglish ? 'Return Items:' : 'عناصر المرتجع:'));
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(countLabel,
            weight: 0.6,
            align: isLtrLayout ? TextAlign.left : TextAlign.right,
            isBold: true,
            scale: scale),
        ReceiptTableColumn(orderReturns.returnItems!.length.toString(),
            weight: 0.4, align: TextAlign.right, isBold: true, scale: scale),
      ]));
    }

    // Return summary box — showReturnTotalAmount and showReturnNetAmount are
    // separate toggles so each gets its own line.
    final bool showReturnTotalAmt =
        displayConfig?['showReturnTotalAmount']?.visible == true;
    final bool showReturnNetAmt =
        displayConfig?['showReturnNetAmount']?.visible == true;

    if (showReturnTotalAmt || showReturnNetAmt) {
      final String currency = appSettings?.currency ?? 'INR';
      final String? currencySymbol =
          currency.trim().toUpperCase() == 'INR' ? '₹' : null;
      final ui.Image? currencyIcon = currencySymbol == null ? sarSymbol : null;

      // Both totals are rate-based (what the customer actually paid for the
      // returned items). returnTotalAmount from the API is already rate-based.
      // showReturnTotalAmount = gross total of return items at selling rate
      // showReturnNetAmount   = net refund amount (same source, different label)
      final double returnRateTotal =
          double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;

      final List<BoxedLineItem> returnSummaryItems = [];

      if (showReturnTotalAmt) {
        final bool useCreditNoteTotalAmount =
            retLabels?.creditNoteTotalAmount != null;
        final label = useCreditNoteTotalAmount
            ? _getModeLabel(
                displayConfig: displayConfig,
                key: 'showReturnTotalAmount',
                isEnglish: isEnglish,
                isBilingual: isBilingual,
                english: 'Credit Note Total:',
                arabic: 'إجمالي إشعار الائتمان:',
                inlineBilingual: true,
              )
            : _getModeLabel(
                displayConfig: displayConfig,
                key: 'showReturnTotalAmount',
                isEnglish: isEnglish,
                isBilingual: isBilingual,
                english: 'Return Total:',
                arabic: 'إجمالي المرتجع:',
                inlineBilingual: true,
              );
        returnSummaryItems.add(BoxedLineItem(
          label: label,
          value: returnRateTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol,
        ));
      }

      if (showReturnNetAmt) {
        final bool useCreditNoteRefund = retLabels?.creditNoteRefund != null;
        final label = useCreditNoteRefund
            ? _getModeLabel(
                displayConfig: displayConfig,
                key: 'showReturnNetAmount',
                isEnglish: isEnglish,
                isBilingual: isBilingual,
                english: 'Credit Note Refund:',
                arabic: 'استرداد إشعار الائتمان:',
                inlineBilingual: true,
              )
            : _getModeLabel(
                displayConfig: displayConfig,
                key: 'showReturnNetAmount',
                isEnglish: isEnglish,
                isBilingual: isBilingual,
                english: 'Return Net Amount:',
                arabic: 'صافي مبلغ الإرجاع:',
                inlineBilingual: true,
              );
        returnSummaryItems.add(BoxedLineItem(
          label: label,
          value: returnRateTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol,
        ));
      }

      rows.add(SpacingRow(_itemGap));
      rows.add(BoxedTotalsRow(items: returnSummaryItems));

      if (hasCreditNoteConfig) {
        final arabicText = AmountHelper().convertNumberToWords(returnRateTotal,
            currency: currency, language: 'ar');
        final englishText = AmountHelper().convertNumberToWords(returnRateTotal,
            currency: currency, language: 'en');
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow('Amount in Words:', isBold: true, scale: 0.9));
        rows.add(TextRow(englishText, isBold: false, scale: 0.85));
        rows.add(TextRow(arabicText, isBold: false, scale: 0.85));
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
    dynamic appSettings,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return;
    }

    final bool showFinalPurchase =
        displayConfig?['showFinalPurchase']?.visible == true;
    final bool showFinalReturn =
        displayConfig?['showFinalReturn']?.visible == true;
    final bool showFinalNetAmount =
        displayConfig?['showFinalNetAmount']?.visible == true;
    final bool showFinalAmountInWords =
        displayConfig?['showFinalAmountInWords']?.visible == true;
    final bool isBilingual = _isBilingualContent(params);

    if (!showFinalPurchase && !showFinalReturn && !showFinalNetAmount) return;

    final String currency = appSettings?.currency ?? 'INR';
    final String? currencySymbol =
        currency.trim().toUpperCase() == 'INR' ? '₹' : null;
    final ui.Image? currencyIcon = currencySymbol == null ? sarSymbol : null;

    // Calculate return total from cart item rates
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

    final purchaseLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showFinalPurchase',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'ORDER TOTAL',
      arabic: 'إجمالي الطلب',
      inlineBilingual: true,
    );
    final returnLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showFinalReturn',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'RETURN TOTAL',
      arabic: 'إجمالي المرتجع',
      inlineBilingual: true,
    );
    final finalLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showFinalNetAmount',
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'FINAL TOTAL',
      arabic: 'المبلغ النهائي',
      inlineBilingual: true,
    );

    rows.add(SpacingRow(_sectionGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    List<BoxedLineItem> summaryItems = [];
    if (showFinalPurchase) {
      summaryItems.add(BoxedLineItem(
        label: purchaseLabel,
        value: orderTotal.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }
    if (showFinalReturn) {
      summaryItems.add(BoxedLineItem(
        label: returnLabel,
        value: returnTotal.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }
    if (showFinalNetAmount) {
      summaryItems.add(BoxedLineItem(isSeparator: true));
      summaryItems.add(BoxedLineItem(
        label: finalLabel,
        value: finalTotal.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    if (summaryItems.isNotEmpty) {
      rows.add(BoxedTotalsRow(items: summaryItems));
    }

    // Amount in words for final total
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
        final language = _amountWordsLanguageCode(params);
        final amountText = AmountHelper().convertNumberToWords(finalTotal,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';
        rows.add(TextRow('$amountText$suffix', scale: 0.85, isBold: true));
      }
    }

    rows.add(SpacingRow(_itemGap));
  }

  // ==================== FOOTER SECTION ====================

  void _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    PaymentGatewaysProvider paymentGatewaysProvider,
  ) {
    final bool isBilingual = _isBilingualContent(params);
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

        qrMessage = _getModeLabel(
          displayConfig: displayConfig,
          key: 'showQRCode',
          isEnglish: isEnglish,
          isBilingual: isBilingual,
          english: 'ZATCA E-Invoice QR',
          arabic: 'فاتورة إلكترونية',
        );

        debugPrint('[PremiumLayout] ZATCA QR generated: ${qrData.isNotEmpty}');
      } else {
        debugPrint('[PremiumLayout] No ZATCA credentials, using payment QR');

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

        qrMessage = _getModeLabel(
          displayConfig: displayConfig,
          key: 'showQRCode',
          isEnglish: isEnglish,
          isBilingual: isBilingual,
          english: 'Scan to Pay',
          arabic: 'امسح للدفع',
        );
      }

      // Display QR code if data is available
      if (qrData.isNotEmpty) {
        rows.add(TextRow(qrMessage, scale: 0.9));
        rows.add(SpacingRow(5));
        rows.add(QrRow(qrData, size: 220));
      }
    }

    // VAT footer is independent of QR visibility and payment/ZATCA QR data.
    final vatNumber = params.zatcaVatNumber?.trim() ?? '';
    if (displayConfig?['showVATFooter']?.visible == true &&
        vatNumber.isNotEmpty) {
      rows.add(SpacingRow(5));
      final vatLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showVATFooter',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'VAT',
        arabic: 'معلومات ضريبية',
        inlineBilingual: true,
      );
      rows.add(TextRow(
        _appendValueToModeLabel(vatLabel, vatNumber, isBilingual),
        scale: 0.8,
      ));
    }

    rows.add(SpacingRow(_headerGap));

    // Order Number Display (Prioritize Footer if both are active)
    final bool showFooterInvoice =
        displayConfig?['showOrderNumberInFooter']?.visible == true;

    if (showFooterInvoice) {
      // Extract number sequence (e.g., "1149" from "INV-1149")
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      // Determine prefix and style based on which setting is active
      String prefixKey =
          showFooterInvoice ? 'showOrderNumberInFooter' : 'showInvoiceNumber';
      if (showFooterInvoice &&
          displayConfig?['showOrderNumberInFooter']?.value == null) {
        // Fallback to general prefix if footer value is null
        prefixKey = 'showInvoiceNumber';
      }

      final documentNumberPrefix = _documentTextForMode(
        params.billDocumentConfig.numberPrefix,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
      );
      final String invoicePrefix = _getModeLabel(
        displayConfig: displayConfig,
        key: prefixKey,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english:
            documentNumberPrefix.isNotEmpty ? documentNumberPrefix : 'INV NO:',
        arabic: 'رقم الفاتورة:',
        inlineBilingual: true,
      );
      final invoiceText = _appendValueToModeLabel(
        invoicePrefix,
        strippedNumber,
        isBilingual,
      );

      rows.add(SpacingRow(3));
      if (showFooterInvoice) {
        rows.add(SpacingRow(5));
        rows.add(ThinDividerRow());
        rows.add(SpacingRow(5));
        rows.add(TextRow(invoiceText, scale: 0.85, isBold: true));
      } else {
        rows.add(TextRow(invoiceText, scale: 0.85));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      final documentTerms = _documentTextForMode(
        params.billDocumentConfig.terms,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
      );
      final terms = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTermsConditions',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: documentTerms,
        arabic: documentTerms,
      );
      if (terms.trim().isNotEmpty) {
        rows.add(TextRow(terms.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message - Elegant
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final fallbackMessage = _documentTextForMode(
        params.billDocumentConfig.footer,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
      );
      final message = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showThankYouMessage',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: fallbackMessage.isNotEmpty
            ? fallbackMessage
            : 'Thank You for Your Visit!',
        arabic:
            fallbackMessage.isNotEmpty ? fallbackMessage : 'شكراً لزيارتكم!',
      );
      rows.add(TextRow(
        message,
        isBold: true,
        scale: isBilingual ? 0.8 : 0.95,
      ));
    }

    final documentFooter = _documentTextForMode(
      params.billDocumentConfig.footer,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
    );
    if (documentFooter.isNotEmpty) {
      rows.add(SpacingRow(_itemGap));
      rows.add(TextRow(documentFooter, isBold: true, scale: 0.8));
    }

    rows.add(SpacingRow(_sectionGap));
  }

  // ==================== UTILITY METHODS ====================

  String _documentTextForMode(
    String? text, {
    required bool isEnglish,
    required bool isBilingual,
  }) {
    final mode = isBilingual
        ? ReceiptLanguageMode.bilingual
        : isEnglish
            ? ReceiptLanguageMode.english
            : ReceiptLanguageMode.arabic;
    return ReceiptConfigurationContract.documentText(text, mode);
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
    final mode = isBilingual
        ? ReceiptLanguageMode.bilingual
        : isEnglish
            ? ReceiptLanguageMode.english
            : ReceiptLanguageMode.arabic;
    return ReceiptConfigurationContract.label(
      options: displayConfig,
      key: key,
      mode: mode,
      resolvedArabic: resolvedArabic,
      resolvedEnglish: resolvedEnglish,
      englishFallback: english,
      arabicFallback: arabic,
      inlineBilingual: inlineBilingual,
    );
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

  String _normalizedDocumentLanguage(ReceiptLayoutParams params) {
    final raw = (((kDebugMode ? _debugLanguageOverride : null) ??
            params.billDocumentConfig.language ??
            '')
        .trim()
        .toUpperCase());
    return ReceiptConfigurationContract.languageMode(raw).code.toUpperCase();
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

  String _amountWordsLanguageCode(ReceiptLayoutParams params) {
    return _isEnglishContent(params) ? 'en' : 'ar';
  }

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    return PrintLogoLoader.loadUiLogo(url,
        tag: '[premium2_bilingual_receipt_layout]');
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
class _Premium2RenderedImages {
  final img.Image part1;
  final img.Image part2;

  const _Premium2RenderedImages({required this.part1, required this.part2});
}

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
        h += _itemHeight(item, width, fontSize, textDirection);
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
        final contentWidth = math.max(1.0, width - (padding * 2));
        final valueColumnWidth = contentWidth * 0.32;
        final labelColumnWidth = contentWidth * 0.62;
        final prefixWidth = _prefixWidth(item, itemFontSize);
        final valueMaxWidth =
            (valueColumnWidth - prefixWidth).clamp(1.0, width).toDouble();
        final labelPainters = _createLabelPainters(
          item.label,
          labelColumnWidth,
          itemFontSize,
          item.isBold,
          textDirection,
        );
        final valuePainter = _createTextPainter(
          item.value,
          valueMaxWidth,
          itemFontSize,
          item.isBold,
          TextAlign.left,
          TextDirection.ltr,
        );
        final labelHeight = _paintersHeight(labelPainters);
        final rowHeight = math.max(labelHeight, valuePainter.height) + 8;

        // Draw Icon if present
        double valueOffsetX = padding;
        if (item.icon != null) {
          final double iconSize = itemFontSize * 0.75;
          final src = Rect.fromLTWH(
              0, 0, item.icon!.width.toDouble(), item.icon!.height.toDouble());
          final dst = Rect.fromLTWH(padding,
              currentY + (rowHeight - 8 - iconSize) / 2, iconSize, iconSize);
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
                fontFamily: ArabicPrinterHelper.fontFamily,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          symbolPainter.paint(
            canvas,
            Offset(valueOffsetX,
                currentY + (rowHeight - 8 - symbolPainter.height) / 2),
          );
          valueOffsetX += symbolPainter.width + 4;
        }

        // Value on Left (after icon)
        valuePainter.paint(
          canvas,
          Offset(
            valueOffsetX,
            currentY + (rowHeight - 8 - valuePainter.height) / 2,
          ),
        );

        // Labels on the right. Paint explicit Arabic/English lines separately
        // so each language always receives its own measured baseline.
        double labelY = currentY;
        for (final painter in labelPainters) {
          painter.paint(
            canvas,
            Offset(width - padding - painter.width, labelY),
          );
          labelY += painter.height + 2;
        }

        currentY += rowHeight;
      }
    }
  }

  double _itemHeight(
    BoxedLineItem item,
    double width,
    double fontSize,
    TextDirection textDirection,
  ) {
    final itemFontSize = fontSize * item.scale;
    final contentWidth = math.max(1.0, width - (padding * 2));
    final valueColumnWidth = contentWidth * 0.32;
    final labelColumnWidth = contentWidth * 0.62;
    final prefixWidth = _prefixWidth(item, itemFontSize);
    final valueMaxWidth =
        (valueColumnWidth - prefixWidth).clamp(1.0, width).toDouble();
    final labelPainters = _createLabelPainters(
      item.label,
      labelColumnWidth,
      itemFontSize,
      item.isBold,
      textDirection,
    );
    final valuePainter = _createTextPainter(
      item.value,
      valueMaxWidth,
      itemFontSize,
      item.isBold,
      TextAlign.left,
      TextDirection.ltr,
    );
    return math.max(_paintersHeight(labelPainters), valuePainter.height) + 8;
  }

  List<TextPainter> _createLabelPainters(
    String text,
    double maxWidth,
    double fontSize,
    bool isBold,
    TextDirection textDirection,
  ) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final effectiveLines = lines.isEmpty ? <String>[''] : lines;
    final labelFontSize =
        effectiveLines.length > 1 ? fontSize * 0.82 : fontSize;

    return effectiveLines
        .map((line) => _createTextPainter(
              line,
              maxWidth,
              labelFontSize,
              isBold,
              TextAlign.right,
              textDirection,
            ))
        .toList();
  }

  double _paintersHeight(List<TextPainter> painters) {
    if (painters.isEmpty) return 0;
    return painters.fold<double>(
            0, (height, painter) => height + painter.height) +
        ((painters.length - 1) * 2);
  }

  double _prefixWidth(BoxedLineItem item, double fontSize) {
    if (item.icon != null) return (fontSize * 0.75) + 4;
    final symbol = item.currencySymbol;
    if (symbol == null || symbol.isEmpty) return 0;
    final painter = _createTextPainter(
      symbol,
      double.infinity,
      fontSize,
      item.isBold,
      TextAlign.left,
      TextDirection.ltr,
    );
    return painter.width + 4;
  }

  TextPainter _createTextPainter(
    String text,
    double maxWidth,
    double fontSize,
    bool isBold,
    TextAlign align,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: align,
    );
    painter.layout(maxWidth: maxWidth);
    return painter;
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
