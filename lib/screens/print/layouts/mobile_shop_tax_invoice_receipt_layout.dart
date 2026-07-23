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
import 'receipt_layout_params.dart';
import '../thermal/printer_utils.dart';
import '../thermal/debug_image_saver.dart';
import '../logo_loader.dart';

/// Mobile shop bilingual tax invoice thermal layout.
///
/// This layout features:
/// - Generous whitespace between sections
/// - Thin solid line dividers
/// - Clean, centered header with balanced typography
/// - Bilingual support (English/Arabic) like the reference
/// - Streamlined totals section with clear hierarchy
/// - Minimal, elegant footer
class MobileShopTaxInvoiceReceiptLayout implements ReceiptLayout {
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
  String get layoutId => 'mobile_shop_tax_invoice';

  @override
  String get displayName => 'Mobile Shop Tax Invoice';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== MOBILE SHOP TAX INVOICE LAYOUT: THERMAL PRINTING ====");

    final context = params.context;
    final selectedPrinter = params.selectedPrinter;
    final billDocumentConfig = params.billDocumentConfig;
    final displayConfig = params.displayConfig;

    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: ${params.selectedPaperSize}");

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;
    debugPrint(
        "[PREMIUM][LOGO] Config: showLogo=${billDocumentConfig.showLogo}, logo='${billDocumentConfig.logo}', layout=$layoutId, order=${params.orderNumber}");

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

      // ========== LOAD CURRENCY SYMBOL ==========
      final String currencyCode =
          (appSettings?.currency.toString() ?? '').trim().toUpperCase();
      final bool useTextCurrencySymbol = currencyCode == 'INR';
      ui.Image? sarSymbol;
      if (!useTextCurrencySymbol) {
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
      } else {
        debugPrint("[PREMIUM] Using INR text currency symbol for totals");
      }

      // ========== LOGO SECTION ==========
      if (billDocumentConfig.showLogo == 1) {
        try {
          debugPrint(
              "[PREMIUM][LOGO] Logo section enabled. Attempting logo load...");
          ui.Image? logo;
          if (billDocumentConfig.logo != null &&
              billDocumentConfig.logo.toString().isNotEmpty) {
            debugPrint(
                "[PREMIUM][LOGO] Raw logo value: '${billDocumentConfig.logo}'");
            logo =
                await _fetchNetworkUiImage(billDocumentConfig.logo.toString());
          } else {
            debugPrint(
                "[PREMIUM][LOGO] Logo path is empty/null in billDocumentConfig.");
          }

          if (logo != null) {
            debugPrint("[PREMIUM] Logo loaded: ${logo.width}x${logo.height}");
            part1Rows.add(ImageRow(logo, height: printWidth * 0.22));
            part1Rows.add(SpacingRow(_headerGap));
            debugPrint(
                "[PREMIUM][LOGO] Logo row added to receipt with width=${(printWidth * 0.6).toStringAsFixed(1)}");
          } else {
            debugPrint(
                "[PREMIUM][LOGO] Logo image is null after fetch; row not added.");
          }
        } catch (e) {
          debugPrint("[PREMIUM] Error loading logo: $e");
        }
      } else {
        debugPrint(
            "[PREMIUM][LOGO] Logo section skipped because showLogo != 1.");
      }

      // ========== HEADER SECTION (Modern & Clean) ==========
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings,
          isEnglish, isLtrLayout);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(
          part1Rows, params, displayConfig, isEnglish, isLtrLayout);

      // ========== CART ITEMS SECTION ==========
      if (!params.isReturnOnly) {
        _buildCartItemsSection(
            part1Rows, params, displayConfig, isEnglish, isLtrLayout);
      }

      // ========== TOTALS SECTION (Bilingual Style) ==========
      if (!params.isReturnOnly) {
        _buildTotalsSection(part1Rows, params, displayConfig, isEnglish,
            sarSymbol, appSettings);
      }

      // ========== RETURN ITEMS SECTION ==========
      if (params.orderReturns != null &&
          params.orderReturns!.returnItems != null &&
          params.orderReturns!.returnItems!.isNotEmpty) {
        _buildReturnSection(part1Rows, params, displayConfig, isEnglish,
            isLtrLayout, sarSymbol, appSettings);
        if (!params.isReturnOnly) {
          _buildFinalSummarySection(part1Rows, params, displayConfig, isEnglish,
              sarSymbol, appSettings);
        }
      }

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
        "[MobileShopTaxInvoiceReceiptLayout] buildPdf - delegating to StandardPrinter");
    return pw.Document();
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    await printThermal(params);
  }

  // ==================== HEADER SECTION ====================

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

    final documentHeader = (billDocumentConfig.header ?? '').trim();
    final documentSubheader = (billDocumentConfig.subheader ?? '').trim();

    // Optional free-form header/subheader from document config (often Arabic legal name).
    if (documentHeader.isNotEmpty) {
      rows.add(TextRow(documentHeader,
          isBold: true, scale: 1.0, verticalPadding: 2, verticalOffset: 1));
    }

    if (documentSubheader.isNotEmpty) {
      rows.add(TextRow(documentSubheader,
          isBold: true, scale: 0.95, verticalPadding: 2, verticalOffset: 0));
    }

    // Store Name — reference shows Arabic then English, centered.
    if (displayConfig?['showStoreName']?.visible == true) {
      final fallbackStoreName = params.storeName?.isNotEmpty == true
          ? params.storeName!
          : 'STORE NAME';
      final option = displayConfig?['showStoreName'];
      final configuredArabic =
          option?.value is String ? (option!.value as String).trim() : '';
      final configuredEnglish = option?.defaultValue?.trim() ?? '';

      String storeName;
      if (isBilingual) {
        final arabic = configuredArabic.isNotEmpty
            ? configuredArabic
            : fallbackStoreName;
        final english = configuredEnglish.isNotEmpty
            ? configuredEnglish
            : fallbackStoreName;
        storeName = _getBilingualText(
            arabic: arabic, english: english, englishFirst: false);
      } else {
        storeName = _getModeLabel(
          displayConfig: displayConfig,
          key: 'showStoreName',
          isEnglish: isEnglish,
          isBilingual: false,
          english: fallbackStoreName,
          arabic: fallbackStoreName,
        );
      }

      double storeNameScale = 1.35;
      final longestStoreNameLine = storeName.split('\n').fold<int>(
          0, (length, line) => line.length > length ? line.length : length);
      if (longestStoreNameLine > 28) {
        storeNameScale = 1.05;
      } else if (longestStoreNameLine > 18) {
        storeNameScale = 1.2;
      }

      rows.add(TextRow(storeName,
          isBold: true,
          scale: storeNameScale,
          verticalPadding: 3,
          verticalOffset: 1));
    }

    if (displayConfig?['showDescription']?.visible == true) {
      final description = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDescription',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
        inlineBilingual: true,
      );
      if (description.isNotEmpty) {
        rows.add(TextRow(description.trim(),
            scale: 0.9, isBold: true, verticalPadding: 2));
      }
    }

    if (displayConfig?['showTel']?.visible == true) {
      final label = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTel',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Phone',
        arabic: 'رقم الهاتف',
        inlineBilingual: true,
      );
      final phone = params.storePhone?.isNotEmpty == true
          ? params.storePhone!
          : (appSettings?.customerCarePhone ?? '');
      if (phone.isNotEmpty) {
        rows.add(TextRow(
          _appendValueToModeLabel(label, ' : $phone', isBilingual),
          scale: 0.9,
          isBold: true,
        ));
      }
    }

    if (displayConfig?['showStoreAddress']?.visible == true) {
      final configuredAddress =
          displayConfig?['showStoreAddress']?.value?.toString().trim() ?? '';
      final address = configuredAddress.isNotEmpty
          ? configuredAddress
          : (params.storeLocation ?? '').trim();
      if (address.isNotEmpty) {
        rows.add(TextRow(address, scale: 0.85, isBold: false));
      }
    }

    // Tax number — prefer ZATCA VAT / configured VAT footer text.
    if (displayConfig?['showVATFooter']?.visible == true &&
        params.zatcaVatNumber != null &&
        params.zatcaVatNumber!.isNotEmpty) {
      final vatLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showVATFooter',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Tax Number',
        arabic: 'الرقم الضريبي',
        inlineBilingual: true,
      );
      rows.add(TextRow(
        _appendValueToModeLabel(
            vatLabel, ' : ${params.zatcaVatNumber!}', isBilingual),
        scale: 0.85,
      ));
    }

    // CR / commercial registration style line from FSSAI/tax info slot.
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showFssaiInfo',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: '',
        arabic: '',
        inlineBilingual: true,
      );
      if (fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.85, isBold: false));
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
        inlineBilingual: true,
      );
      final emailVal = params.storeEmail?.isNotEmpty == true
          ? params.storeEmail!
          : (appSettings?.customerCareEmail ?? '');
      if (emailVal.isNotEmpty) {
        rows.add(TextRow(
          _appendValueToModeLabel(label, ' : $emailVal', isBilingual),
          scale: 0.85,
        ));
      }
    }

    // Invoice title — reference: TAX INVOICE then Arabic on next line.
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final option = displayConfig?['showInvoiceTitle'];
      final configuredArabic =
          option?.value is String ? (option!.value as String).trim() : '';
      final configuredEnglish = option?.defaultValue?.trim() ?? '';
      final englishTitle = configuredEnglish.isNotEmpty
          ? configuredEnglish
          : (appSettings?.printTitle ?? 'TAX INVOICE');
      final arabicTitle =
          configuredArabic.isNotEmpty ? configuredArabic : 'فاتورة ضريبية';

      rows.add(SpacingRow(6));
      if (isBilingual) {
        rows.add(TextRow(englishTitle.toUpperCase(),
            isBold: true, scale: 1.15, align: TextAlign.center));
        rows.add(TextRow(arabicTitle,
            isBold: true, scale: 1.1, align: TextAlign.center));
      } else {
        final title = isEnglish ? englishTitle : arabicTitle;
        rows.add(TextRow(title.toUpperCase(), isBold: true, scale: 1.15));
      }
      debugPrint(
          "[MobileShopTaxInvoiceReceiptLayout] order=${params.orderNumber}, printedInvoiceTitle=$englishTitle / $arabicTitle");
    }

    rows.add(SpacingRow(_headerGap));
  }

  // ==================== BILL META + CUSTOMER SECTION ====================

  void _buildCustomerSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isLtrLayout,
  ) {
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 0.95;
    final bool isBilingual = _isBilingualContent(params);

    void addMetaLine(String label, String value, {bool isBold = false}) {
      final trimmedValue = value.trim();
      if (trimmedValue.isEmpty) return;
      rows.add(TextRow(
        '$label : $trimmedValue',
        align: TextAlign.left,
        scale: scale,
        isBold: isBold,
        textDirectionOverride: TextDirection.ltr,
      ));
    }

    String resolveCoreMetaLabel({
      required String key,
      required String english,
      required String arabic,
    }) {
      final option = displayConfig?[key];
      final configuredArabic =
          option?.value is String ? (option!.value as String).trim() : '';
      final configuredEnglish = option?.defaultValue?.trim() ?? '';

      if (configuredArabic.isEmpty && configuredEnglish.isEmpty) {
        return '$english / $arabic';
      }

      return _getModeLabel(
        displayConfig: displayConfig,
        key: key,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: english,
        arabic: arabic,
        inlineBilingual: true,
      );
    }

    // Bill No. / رقم الفاتورة : #####
    final bool showInvoiceNumber =
        displayConfig?['showInvoiceNumber']?.visible != false;
    if (showInvoiceNumber) {
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;
      final billLabel = resolveCoreMetaLabel(
        key: 'showTokenNumber',
        english: 'Bill No.',
        arabic: 'رقم الفاتورة',
      );
      addMetaLine(billLabel, strippedNumber, isBold: true);
    }

    // Date / تاريخ :
    if (displayConfig?['showDate']?.visible != false) {
      String formattedDate = params.isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
          : DateHelper.formatISODate(params.orderDate);
      String formattedTime = params.isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
          : DateHelper.formatISOTimeOnlyToIST(params.orderDate);
      final dateLabel = resolveCoreMetaLabel(
        key: 'showDate',
        english: 'Date',
        arabic: 'تاريخ',
      );
      addMetaLine(dateLabel, '$formattedDate $formattedTime');
    }

    // Customer / العميل :
    final bool showCustomerBlock =
        displayConfig?['showCustomerNameAndPhone']?.visible != false;
    final bool showCustomerName =
        showCustomerBlock && displayConfig?['showCustomerName']?.visible != false;
    if (showCustomerName &&
        params.customerName != null &&
        params.customerName!.isNotEmpty) {
      final customerLabel = resolveCoreMetaLabel(
        key: 'showCustomerName',
        english: 'Customer',
        arabic: 'العميل',
      );
      addMetaLine(customerLabel, params.customerName!);
    }

    // Optional extra customer fields (same data logic, quieter than reference core).
    final String paymentConfigKey =
        displayConfig?.containsKey('showPaymentMethod') == true
            ? 'showPaymentMethod'
            : 'showPayment';
    final String commentConfigKey =
        displayConfig?.containsKey('showOrderComment') == true
            ? 'showOrderComment'
            : 'showComment';
    final bool showCustomerPhone =
        showCustomerBlock &&
            displayConfig?['showCustomerPhone']?.visible != false;
    final bool showPayment = displayConfig?[paymentConfigKey]?.visible == true;
    final bool showCustomerAddress =
        displayConfig?['showCustomerAddress']?.visible == true;
    final bool showComment = displayConfig?[commentConfigKey]?.visible == true;
    final bool showDeliveryMethod =
        displayConfig?['showDeliveryMethod']?.visible == true;
    final bool showCustomerVatNumber =
        displayConfig?['showCustomerVatNumber']?.visible == true;
    final bool showCustomerCrNumber =
        displayConfig?['showCustomerCrNumber']?.visible == true;
    final bool showTokenNumber =
        displayConfig?['showTokenNumber']?.visible == true &&
            params.tokenNumber != null &&
            params.tokenNumber!.isNotEmpty;

    if (showTokenNumber) {
      final tokenLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTokenNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Token',
        arabic: 'الرمز',
        inlineBilingual: true,
      );
      addMetaLine(tokenLabel, params.tokenNumber!);
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
      final phoneLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerPhone',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Phone',
        arabic: 'الهاتف',
        inlineBilingual: true,
      );
      addMetaLine(phoneLabel, phoneText);
    }

    if (showPayment &&
        params.paymentMethod != null &&
        params.paymentMethod!.isNotEmpty) {
      final paymentLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: paymentConfigKey,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Payment',
        arabic: 'الدفع',
        inlineBilingual: true,
      );
      addMetaLine(paymentLabel, params.paymentMethod!);
    }

    if (showCustomerAddress &&
        params.customerAddress != null &&
        params.customerAddress!.isNotEmpty) {
      final addressLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerAddress',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Address',
        arabic: 'العنوان',
        inlineBilingual: true,
      );
      addMetaLine(addressLabel, params.customerAddress!);
    }

    if (showComment &&
        params.orderComment != null &&
        params.orderComment!.isNotEmpty) {
      final commentLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: commentConfigKey,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Comment',
        arabic: 'تعليق',
        inlineBilingual: true,
      );
      addMetaLine(commentLabel, params.orderComment!);
    }

    if (showDeliveryMethod &&
        params.deliveryMethod != null &&
        params.deliveryMethod!.isNotEmpty) {
      final deliveryLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDeliveryMethod',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Delivery',
        arabic: 'التوصيل',
        inlineBilingual: true,
      );
      addMetaLine(deliveryLabel, params.deliveryMethod!);
    }

    if (showCustomerVatNumber &&
        params.customerVatNumber != null &&
        params.customerVatNumber!.isNotEmpty) {
      final customerVatLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerVatNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Customer VAT',
        arabic: 'الرقم الضريبي للعميل',
        inlineBilingual: true,
      );
      addMetaLine(customerVatLabel, params.customerVatNumber!);
    }

    if (showCustomerCrNumber &&
        params.customerCrNumber != null &&
        params.customerCrNumber!.isNotEmpty) {
      final customerCrLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerCrNumber',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: 'Customer CR',
        arabic: 'السجل التجاري للعميل',
        inlineBilingual: true,
      );
      addMetaLine(customerCrLabel, params.customerCrNumber!);
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(DottedDividerRow());
    rows.add(SpacingRow(4));
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

    // Extract labels with fallbacks — reference: SN, DESCRIPTION, VAT, QTY, PRICE, AMOUNT
    final String particularsLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showParticulars',
      resolvedArabic: resolvedLabels?.particulars,
      resolvedEnglish: resolvedLabels?.particularsDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'DESCRIPTION',
      arabic: 'اسم الصنف',
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
      english: 'QTY',
      arabic: 'كمية',
    );
    final String rateLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showRate',
      resolvedArabic: resolvedLabels?.rate,
      resolvedEnglish: resolvedLabels?.rateDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'PRICE',
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
      english: 'AMOUNT',
      arabic: 'القيمة',
    );
    final String taxHeaderLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showTaxHeader',
      resolvedArabic: resolvedLabels?.tax,
      resolvedEnglish: resolvedLabels?.taxDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'VAT',
      arabic: 'ضريبة',
    );
    final String slLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showSLNumber',
      resolvedArabic: resolvedLabels?.slNumber,
      resolvedEnglish: resolvedLabels?.slNumberDefault,
      isEnglish: isEnglish,
      isBilingual: isBilingual,
      english: 'SN',
      arabic: 'ر.م',
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
        rows.add(DottedDividerRow());
      }
    }

    rows.add(SpacingRow(4));
    rows.add(DottedDividerRow());
    rows.add(SpacingRow(_itemGap));

    // Item/qty counts are rendered in totals to match the reference receipt.
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

    if (isLtrLayout) {
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
      // Reference order: VAT before QTY/PRICE/AMOUNT
      if (displayConfig?['showTaxHeader']?.visible == true) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: tableWeights['showTaxHeader'] ?? 0,
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
      rows.add(DottedDividerRow());
      rows.add(ReceiptTableRow(headerCols));
      rows.add(DottedDividerRow());
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
    String productNameArabic = '';
    String productCode = '';
    String mrp = '';
    String quantity = '';
    String unitPrice = '';
    String unitPriceExTax = '';
    String unitName = '';
    String totalPrice = '';
    String itemTaxAmount = '';

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
      productCode = (item['barcode'] ??
              item['sku'] ??
              item['product_code'] ??
              item['productCode'] ??
              item['product_id'] ??
              item['productId'] ??
              '')
          .toString();
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
    } else {
      final itemNameEnglish = item.names?.en ?? item.productName ?? '';
      final itemNameArabic = item.names?.ar ?? '';
      if (isBilingual && itemNameArabic.isNotEmpty) {
        productNameArabic = itemNameArabic;
        productName = itemNameEnglish;
      } else if (!isEnglish && itemNameArabic.isNotEmpty) {
        productName = itemNameArabic;
        productNameArabic = '';
      } else {
        productName = itemNameEnglish;
        productNameArabic = '';
      }

      try {
        productCode = (item.barcode ?? item.sku ?? item.productId ?? '')
            .toString();
      } catch (_) {
        productCode = (item.productId ?? '').toString();
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
    }

    final String slNumber = (index + 1).toString();

    ReceiptTableColumn col(
      String text, {
      required String key,
      TextAlign align = TextAlign.center,
      TextDirection? textDirection,
    }) {
      return ReceiptTableColumn(
        text,
        weight: tableWeights[key] ?? 0,
        align: align,
        scale: tableScale,
        minScale: tableMinScale,
        horizontalPadding: tableCellPadding,
        textDirection: textDirection,
      );
    }

    List<ReceiptTableColumn> buildLtrRow({
      String sl = '',
      String name = '',
      String tax = '',
      String qty = '',
      String rate = '',
      String rateEx = '',
      String unit = '',
      String mrpValue = '',
      String total = '',
      TextDirection? nameDirection,
    }) {
      final cols = <ReceiptTableColumn>[];
      if (displayConfig?['showSLNumber']?.visible == true) {
        cols.add(col(sl, key: 'showSLNumber', align: TextAlign.left));
      }
      if (displayConfig?['showParticulars']?.visible == true) {
        cols.add(col(name,
            key: 'showParticulars',
            align: TextAlign.left,
            textDirection: nameDirection));
      }
      if (displayConfig?['showMRP']?.visible == true) {
        cols.add(col(mrpValue, key: 'showMRP'));
      }
      if (displayConfig?['showTaxHeader']?.visible == true) {
        cols.add(col(tax, key: 'showTaxHeader', align: TextAlign.right));
      }
      if (displayConfig?['showQty']?.visible == true) {
        cols.add(col(qty, key: 'showQty'));
      }
      if (displayConfig?['showRate']?.visible == true) {
        cols.add(col(rate, key: 'showRate', align: TextAlign.right));
      }
      if (displayConfig?['showRateExcTax']?.visible == true) {
        cols.add(col(rateEx, key: 'showRateExcTax', align: TextAlign.right));
      }
      if (displayConfig?['showUnit']?.visible == true) {
        cols.add(col(unit, key: 'showUnit'));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        cols.add(col(total, key: 'showTotal', align: TextAlign.right));
      }
      return cols;
    }

    if (isLtrLayout) {
      // Line 1: SN | English name | QTY | PRICE
      final primaryCols = buildLtrRow(
        sl: displayConfig?['showSLNumber']?.visible == true ? slNumber : '',
        name: productName,
        qty: quantity,
        rate: unitPrice,
        nameDirection: TextDirection.ltr,
      );
      if (primaryCols.any((c) => c.text.isNotEmpty)) {
        rows.add(ReceiptTableRow(primaryCols));
      }

      // Line 2: Arabic product name under description
      if (isBilingual && productNameArabic.isNotEmpty) {
        final arabicCols = buildLtrRow(
          name: productNameArabic,
          nameDirection: TextDirection.rtl,
        );
        rows.add(ReceiptTableRow(arabicCols));
      }

      // Line 3: product code under description, VAT amount, line total
      final detailCols = buildLtrRow(
        name: productCode,
        tax: itemTaxAmount,
        total: totalPrice,
        mrpValue: displayConfig?['showMRP']?.visible == true ? mrp : '',
        rateEx: displayConfig?['showRateExcTax']?.visible == true
            ? unitPriceExTax
            : '',
        unit: displayConfig?['showUnit']?.visible == true ? unitName : '',
        nameDirection: TextDirection.ltr,
      );
      if (detailCols.any((c) => c.text.isNotEmpty)) {
        rows.add(ReceiptTableRow(detailCols));
      }
      return;
    }

    // Arabic-only RTL fallback (same data, mirrored columns)
    if (displayConfig?['showParticulars']?.visible == true ||
        displayConfig?['showSLNumber']?.visible == true) {
      if (productNameArabic.isNotEmpty) {
        final itemText = displayConfig?['showSLNumber']?.visible == true
            ? '$slNumber. $productNameArabic'
            : productNameArabic;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
        ]));
        if (productName.isNotEmpty) {
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(productName,
                weight: 1.0,
                align: TextAlign.left,
                textDirection: TextDirection.ltr),
          ]));
        }
      } else {
        final bool nameIsArabic = _hasArabic(productName);
        final itemText = displayConfig?['showSLNumber']?.visible == true
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

    final priceCols = <ReceiptTableColumn>[];
    if (displayConfig?['showTotal']?.visible == true) {
      priceCols.add(col(totalPrice, key: 'showTotal', align: TextAlign.right));
    }
    if (displayConfig?['showTaxHeader']?.visible == true) {
      priceCols
          .add(col(itemTaxAmount, key: 'showTaxHeader', align: TextAlign.right));
    }
    if (displayConfig?['showRate']?.visible == true) {
      priceCols.add(col(unitPrice, key: 'showRate', align: TextAlign.right));
    }
    if (displayConfig?['showRateExcTax']?.visible == true) {
      priceCols
          .add(col(unitPriceExTax, key: 'showRateExcTax', align: TextAlign.right));
    }
    if (displayConfig?['showUnit']?.visible == true) {
      priceCols.add(col(unitName, key: 'showUnit', align: TextAlign.right));
    }
    if (displayConfig?['showQty']?.visible == true) {
      priceCols.add(col(quantity, key: 'showQty', align: TextAlign.right));
    }
    if (displayConfig?['showMRP']?.visible == true) {
      priceCols.add(col(mrp, key: 'showMRP', align: TextAlign.right));
    }
    final itemDetailsWeight = _getItemDetailsWeight(tableWeights);
    if (itemDetailsWeight > 0) {
      priceCols.add(ReceiptTableColumn(
          productCode.isNotEmpty ? productCode : '',
          weight: itemDetailsWeight,
          align: TextAlign.right));
    }
    if (priceCols.any((column) => column.text.isNotEmpty)) {
      rows.add(ReceiptTableRow(priceCols));
    }
  }

  Map<String, double> _buildNormalizedTableWeights(
    Map<String, DisplayOption>? displayConfig,
  ) {
    final bool showSlNumber = displayConfig?['showSLNumber']?.visible == true;
    final baseWeights = <String, double>{
      if (showSlNumber) 'showSLNumber': 0.07,
      if (displayConfig?['showParticulars']?.visible == true)
        'showParticulars': showSlNumber ? 0.30 : 0.36,
      if (displayConfig?['showMRP']?.visible == true) 'showMRP': 0.12,
      if (displayConfig?['showTaxHeader']?.visible == true)
        'showTaxHeader': 0.12,
      if (displayConfig?['showQty']?.visible == true) 'showQty': 0.10,
      if (displayConfig?['showRate']?.visible == true) 'showRate': 0.14,
      if (displayConfig?['showRateExcTax']?.visible == true)
        'showRateExcTax': 0.14,
      if (displayConfig?['showUnit']?.visible == true) 'showUnit': 0.10,
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

  // ==================== TOTALS SECTION (Reference unboxed style) ====================

  void _buildTotalsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    ui.Image? sarSymbol,
    dynamic appSettings,
  ) {
    rows.add(SpacingRow(2));

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool isDualLanguage = _isBilingualContent(params);

    final String currency = appSettings?.currency ?? 'INR';
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 0.95;

    double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;
    double total =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double taxAmount = params.totalTax;

    double taxableAmount;
    if (params.netExcTax != null) {
      taxableAmount =
          double.tryParse(params.netExcTax!) ?? (total - taxAmount);
    } else {
      // Prefer exclusive-of-tax base when tax is known.
      taxableAmount = taxAmount > 0 ? (total - taxAmount) : total;
    }
    if (taxableAmount < 0) taxableAmount = 0;

    final showItemsCount = displayConfig?['showItemsCount']?.visible ??
        displayConfig?['showQuantityCount']?.visible ??
        true;
    final showGross = displayConfig?['showSubTotal']?.visible ??
        displayConfig?['showMRPTotal']?.visible ??
        true;
    final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
    final showTax = displayConfig?['showTax']?.visible ?? true;
    final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;
    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible ?? true;

    void addTotalLine(String label, String value,
        {bool isBold = false, double lineScale = 1.0}) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(label,
            weight: 0.72,
            align: TextAlign.left,
            isBold: isBold,
            scale: scale * lineScale,
            textDirection: TextDirection.ltr),
        ReceiptTableColumn(value,
            weight: 0.28,
            align: TextAlign.right,
            isBold: isBold,
            scale: scale * lineScale,
            textDirection: TextDirection.ltr),
      ]));
    }

    // NO. OF ITEMS / عدد العناصر
    if (showItemsCount) {
      final itemsCountLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showItemsCount',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'NO. OF ITEMS',
        arabic: 'عدد العناصر',
        inlineBilingual: true,
      );
      addTotalLine(itemsCountLabel, params.totalQuantity.toStringAsFixed(2));
    }

    // GROSS AMOUNT / المبلغ الإجمالي  (taxable / ex-tax base)
    if (showGross) {
      final grossLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showMRPTotal',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'GROSS AMOUNT',
        arabic: 'المبلغ الإجمالي',
        inlineBilingual: true,
      );
      addTotalLine(grossLabel, taxableAmount.toStringAsFixed(2));
    }

    // DISCOUNT / خصم
    if (showDiscount) {
      final discountLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showDiscount',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'DISCOUNT',
        arabic: 'خصم',
        inlineBilingual: true,
      );
      addTotalLine(discountLabel, discountAmountValue.toStringAsFixed(2));
    }

    // TOTAL TAXABLE AMOUNT
    if (showGross) {
      final taxableLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showSubTotal',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'TOTAL TAXABLE AMOUNT',
        arabic: 'إجمالي المبلغ الخاضع للضريبة',
        inlineBilingual: true,
      );
      final afterDiscount =
          (taxableAmount - discountAmountValue).clamp(0.0, double.infinity);
      addTotalLine(taxableLabel, afterDiscount.toStringAsFixed(2));
    }

    // TOTAL VAT
    if (showTax) {
      final vatLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTax',
        resolvedArabic: resolvedLabels?.tax,
        resolvedEnglish: resolvedLabels?.taxDefault,
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'TOTAL VAT',
        arabic: 'مجموع الضريبة',
        inlineBilingual: true,
      );
      addTotalLine(vatLabel, taxAmount.toStringAsFixed(2));
    }

    // NET AMOUNT (bold)
    if (showNetAmount) {
      final netLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showNetAmount',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'NET AMOUNT',
        arabic: 'المجموع الصافي',
        inlineBilingual: true,
      );
      addTotalLine(netLabel, total.toStringAsFixed(2),
          isBold: true, lineScale: 1.05);
    }

    // Settlements / المستوطنات + payment breakdown
    final settlementsLabel = _getModeLabel(
      displayConfig: displayConfig,
      key: 'showPaymentBreaked',
      isEnglish: isEnglish,
      isBilingual: isDualLanguage,
      english: 'Settlements',
      arabic: 'المستوطنات',
      inlineBilingual: true,
    );

    if (params.paidAmount != null && showPaymentBreaked) {
      bool wroteSettlement = false;

      if (params.paymentBreakdown != null &&
          params.paymentBreakdown!.isNotEmpty) {
        params.paymentBreakdown!.forEach((method, amount) {
          final amt = double.tryParse(amount.toString()) ?? 0.0;
          if (amt <= 0) return;
          String label = method;
          if (method == 'CASH') {
            label = isDualLanguage
                ? _getInlineBilingualText(arabic: 'نقدي', english: 'Cash')
                : (isEnglish ? 'Cash' : 'نقدي');
          } else if (method == 'CARD') {
            label = isDualLanguage
                ? _getInlineBilingualText(arabic: 'بطاقة', english: 'Card')
                : (isEnglish ? 'Card' : 'بطاقة');
          } else if (method == 'UPI') {
            label = 'UPI';
          }
          if (!wroteSettlement) {
            addTotalLine(settlementsLabel, '');
            wroteSettlement = true;
          }
          addTotalLine(label, amt.toStringAsFixed(2));
        });
      } else if (params.paymentMethod != null &&
          params.paymentMethod!.startsWith('{')) {
        try {
          final Map<String, dynamic> paymentData =
              json.decode(params.paymentMethod!);
          if (paymentData['isMultiPayment'] == true) {
            final Map<String, dynamic> amounts = paymentData['amounts'];
            amounts.forEach((method, amount) {
              final amt = double.tryParse(amount.toString()) ?? 0.0;
              if (amt <= 0) return;
              String label = method;
              if (method == 'CASH') {
                label = isDualLanguage
                    ? _getInlineBilingualText(arabic: 'نقدي', english: 'Cash')
                    : (isEnglish ? 'Cash' : 'نقدي');
              } else if (method == 'CARD') {
                label = isDualLanguage
                    ? _getInlineBilingualText(arabic: 'بطاقة', english: 'Card')
                    : (isEnglish ? 'Card' : 'بطاقة');
              }
              if (!wroteSettlement) {
                addTotalLine(settlementsLabel, '');
                wroteSettlement = true;
              }
              addTotalLine(label, amt.toStringAsFixed(2));
            });
          }
        } catch (e) {
          debugPrint("Error parsing multi-payment: $e");
        }
      }

      if (!wroteSettlement) {
        addTotalLine(settlementsLabel, params.paidAmount!.toStringAsFixed(2));
      }
    } else {
      addTotalLine(settlementsLabel, '');
    }

    // BALANCE (bold) — prefer current customer balance, else net - paid
    if (displayConfig?['showCustomerBalance']?.visible != false ||
        params.paidAmount != null) {
      final balanceLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showCustomerCurrentBalance',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'BALANCE',
        arabic: 'توازن',
        inlineBilingual: true,
      );
      double balanceValue = 0.0;
      if (params.customerCurrentBalance != null && !params.isDefaultCustomer) {
        balanceValue = params.customerCurrentBalance!;
      } else if (params.paidAmount != null) {
        balanceValue = total - params.paidAmount!;
      }
      addTotalLine(balanceLabel, balanceValue.toStringAsFixed(2),
          isBold: true, lineScale: 1.05);
    }

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
        final language = _amountWordsLanguageCode(params);
        final amountText = AmountHelper().convertNumberToWords(total,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';

        rows.add(TextRow('$amountText$suffix',
            scale: is58mm ? 0.7 : 0.85, isBold: true));
      }
    }

    // You Saved
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      final savedLabel = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showSaved',
        isEnglish: isEnglish,
        isBilingual: isDualLanguage,
        english: 'You Saved:',
        arabic: 'لقد وفرت:',
        inlineBilingual: true,
      );
      rows.add(SpacingRow(5));
      rows.add(TextRow(
        _appendValueToModeLabel(
            savedLabel, saved.toStringAsFixed(2), isDualLanguage),
        isBold: true,
        scale: 0.9,
      ));
    }

    // Optional detailed balance block (previous / paid / current) when enabled.
    final showDetailedBalance =
        displayConfig?['showCustomerPrevBalance']?.visible == true ||
            displayConfig?['showCustomerPaidAmount']?.visible == true;
    if (showDetailedBalance) {
      _buildCustomerBalance(rows, params, displayConfig, isEnglish);
    }
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

    rows.add(SpacingRow(_sectionGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
    rows.add(TextRow(
      isBilingual
          ? _getBilingualText(arabic: 'المرتجعات', english: 'RETURNS')
          : (isEnglish ? 'RETURNS' : 'المرتجعات'),
      isBold: true,
      scale: 1.1,
    ));
    rows.add(SpacingRow(_itemGap));

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
      final int itemQty = returnItem.quantity ?? 0;
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
        int totalQty = 0;
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
      final countLabel = isBilingual
          ? _getInlineBilingualText(
              arabic: 'عناصر المرتجع:', english: 'Return Items:')
          : (isEnglish ? 'Return Items:' : 'عناصر المرتجع:');
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
        final label = _getModeLabel(
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
        final label = _getModeLabel(
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
        displayConfig?['showFinalPurchase']?.visible != false;
    final bool showFinalReturn =
        displayConfig?['showFinalReturn']?.visible != false;
    final bool showFinalNetAmount =
        displayConfig?['showFinalNetAmount']?.visible != false;
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
    BuildContext context,
  ) {
    final bool isBilingual = _isBilingualContent(params);
    rows.add(SpacingRow(_sectionGap));

    // QR Code — reference shows a large centered QR with no caption above it.
    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';

      if (params.hasZatcaCredentials) {
        final zatcaHelper = ZatcaQrHelper();
        qrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate,
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );
      } else {
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
      }

      if (qrData.isNotEmpty) {
        rows.add(QrRow(qrData, size: 220, shrinkFactor: 0.95));
      }
    }

    rows.add(SpacingRow(_headerGap));

    // Order Number Display (footer) — optional, not on the reference receipt.
    final bool showFooterInvoice =
        displayConfig?['showOrderNumberInFooter']?.visible == true;

    if (showFooterInvoice) {
      final regex = RegExp(r'[1-9]\d*');
      final match = regex.firstMatch(params.orderNumber);
      final strippedNumber =
          match != null ? match.group(0)! : params.orderNumber;

      String prefixKey = 'showOrderNumberInFooter';
      if (displayConfig?['showOrderNumberInFooter']?.value == null) {
        prefixKey = 'showInvoiceNumber';
      }

      final String invoicePrefix = _getModeLabel(
        displayConfig: displayConfig,
        key: prefixKey,
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: params.billDocumentConfig.numberPrefix ?? 'INV NO:',
        arabic: 'رقم الفاتورة:',
        inlineBilingual: true,
      );
      final invoiceText = _appendValueToModeLabel(
        invoicePrefix,
        strippedNumber,
        isBilingual,
      );

      rows.add(SpacingRow(5));
      rows.add(DottedDividerRow());
      rows.add(SpacingRow(5));
      rows.add(TextRow(invoiceText, scale: 0.85, isBold: true));
    }

    rows.add(SpacingRow(_itemGap));

    if (displayConfig?['showTermsConditions']?.visible == true) {
      final terms = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showTermsConditions',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: params.billDocumentConfig.terms ?? '',
        arabic: params.billDocumentConfig.terms ?? '',
      );
      if (terms.trim().isNotEmpty) {
        rows.add(TextRow(terms.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank you — reference: THANK YOU. VISIT AGAIN
    if (displayConfig?['showThankYouMessage']?.visible != false) {
      final fallbackMessage = params.billDocumentConfig.footer?.trim();
      final message = _getModeLabel(
        displayConfig: displayConfig,
        key: 'showThankYouMessage',
        isEnglish: isEnglish,
        isBilingual: isBilingual,
        english: fallbackMessage?.isNotEmpty == true
            ? fallbackMessage!
            : 'THANK YOU. VISIT AGAIN',
        arabic: fallbackMessage?.isNotEmpty == true
            ? fallbackMessage!
            : 'شكراً لزيارتكم',
        inlineBilingual: false,
      );
      rows.add(TextRow(
        message,
        isBold: true,
        scale: 0.95,
        align: TextAlign.center,
      ));
    }

    rows.add(SpacingRow(_sectionGap));
  }

  // ==================== UTILITY METHODS ====================

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

  /// Reference receipt uses English-first inline labels: `Bill No. / رقم الفاتورة`.
  String _getInlineBilingualText(
      {required String arabic, required String english}) {
    final arabicText = arabic.trim();
    final englishText = english.trim();
    if (arabicText.isEmpty) return englishText;
    if (englishText.isEmpty) return arabicText;
    if (arabicText.toLowerCase() == englishText.toLowerCase()) {
      return englishText;
    }
    return '$englishText / $arabicText';
  }

  /// Stacked bilingual text. [englishFirst] matches table headers / titles
  /// (`TAX INVOICE` above `فاتورة ضريبية`). Store header uses Arabic first.
  String _getBilingualText({
    required String arabic,
    required String english,
    bool englishFirst = true,
  }) {
    final arabicText = arabic.trim();
    final englishText = english.trim();
    if (arabicText.isEmpty) return englishText;
    if (englishText.isEmpty) return arabicText;
    if (arabicText.toLowerCase() == englishText.toLowerCase()) {
      return englishText;
    }
    return englishFirst
        ? '$englishText\n$arabicText'
        : '$arabicText\n$englishText';
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
    if (raw == 'EN_AR' ||
        raw == 'EN/AR' ||
        raw == 'AR/EN' ||
        raw == 'BILINGUAL') {
      return 'EN_AR';
    }
    if (raw == 'AR' || raw == 'ARABIC') return 'AR';
    if (raw == 'EN' || raw == 'ENGLISH') return 'EN';
    // Preserve the existing Arabic fallback for old/missing configurations.
    return 'AR';
  }

  bool _isEnglishContent(ReceiptLayoutParams params) {
    return _normalizedDocumentLanguage(params) == 'EN';
  }

  bool _isBilingualContent(ReceiptLayoutParams params) {
    return _normalizedDocumentLanguage(params) == 'EN_AR';
  }

  /// EN_AR follows the reference receipt: LTR column flow with bilingual labels.
  bool _isLtrLayout(ReceiptLayoutParams params) {
    final lang = _normalizedDocumentLanguage(params);
    return lang == 'EN' || lang == 'EN_AR';
  }

  String _amountWordsLanguageCode(ReceiptLayoutParams params) {
    return _isEnglishContent(params) ? 'en' : 'ar';
  }

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    return PrintLogoLoader.loadUiLogo(url,
        tag: '[mobile_shop_tax_invoice_receipt_layout]');
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
          "[MobileShopTaxInvoiceReceiptLayout] Error loading asset image: $e");
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
