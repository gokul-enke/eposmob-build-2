import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';

import 'receipt_layout.dart';
import 'receipt_layout_params.dart';
import 'receipt_configuration_contract.dart';
import 'receipt_pdf_builder.dart';
import 'receipt_sections.dart';
import 'common/return_metadata_rows.dart';
import 'common/layout_rows.dart';
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
class PremiumReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Label resolution is shared with the other receipt themes.  The active
  // mode is captured for the duration of a render so every section (including
  // returns and footer rows) uses the same normalized language semantics.
  ReceiptLanguageMode _activeLanguageMode = ReceiptLanguageMode.english;

  // Premium theme spacing constants
  static const double _sectionGap = 14.0;
  static const double _itemGap = 6.0;
  static const double _headerGap = 8.0;

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

      // Determine language direction from the normalized shared contract.
      _activeLanguageMode = params.receiptLanguageMode;
      final isEnglish = _activeLanguageMode.isEnglish;
      final isBilingual = _activeLanguageMode.isBilingual;
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
            part1Rows.add(ImageRow(logo, height: printWidth * 0.22));
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
      if (!params.isReturnOnly) {
        _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);
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
            sarSymbol, appSettings);
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
                message: 'print.development_print_saved'
                    .trParams({'path': savedFile.path}),
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
            '[PREMIUM] 112mm selected: using ${paperProfile.rasterWidthPx}px raster images; ESC/POS package profile is used only for feed/barcode/cut commands.');
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
        showScaffold(
            context: context, message: 'print.job_sent_successfully'.tr);
        // Note: Navigation is now handled by the caller
        // PrintPage has its own back button, auto-print doesn't need navigation
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR in Premium Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context,
            message: 'print.error_printing'.trParams({'error': e.toString()}));
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

  // ==================== HEADER SECTION (Modern & Clean) ====================

  void _buildHeaderSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    dynamic appSettings,
    bool isEnglish,
  ) {
    final billDocumentConfig = params.billDocumentConfig;

    final documentHeader = params.documentText(billDocumentConfig.header);
    final documentSubheader = params.documentText(billDocumentConfig.subheader);

    if (documentHeader.isNotEmpty) {
      rows.add(TextRow(documentHeader,
          isBold: true, scale: 1.1, verticalPadding: 3, verticalOffset: 1));
    }

    if (documentSubheader.isNotEmpty) {
      rows.add(TextRow(documentSubheader,
          isBold: true, scale: 0.95, verticalPadding: 2, verticalOffset: 0));
    }

    // Store Name - Large, centered, clean
    if (_isVisible(displayConfig, 'showStoreName')) {
      final storeNameLabel = params.labelFor(
        'showStoreName',
        englishFallback: params.storeName?.trim().isNotEmpty == true
            ? params.storeName!.trim()
            : 'STORE NAME',
        arabicFallback: params.storeName?.trim().isNotEmpty == true
            ? params.storeName!.trim()
            : 'اسم المتجر',
      );
      final storeName = storeNameLabel.isNotEmpty
          ? storeNameLabel
          : (params.storeName?.trim().isNotEmpty == true
              ? params.storeName!.trim()
              : 'STORE NAME');

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
    if (_isVisible(displayConfig, 'showDescription')) {
      final description = params.labelFor(
        'showDescription',
        englishFallback: '',
        arabicFallback: '',
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
      rows.add(FieldTextRow(params.storeFieldLine('showStoreAddress'),
          scale: 0.85, isBold: true));
    }

    // Invoice Title (Moved above Tax/Fssai Info)
    if (_isVisible(displayConfig, 'showInvoiceTitle')) {
      final invoiceTitle = params.invoiceTitleText;
      if (invoiceTitle.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(invoiceTitle.toUpperCase(), isBold: true, scale: 1.1));
        rows.add(SpacingRow(2));
      }
    }

    // Extra Heading 1 (e.g., CR NO)
    if (_isVisible(displayConfig, 'showExtraHeading1')) {
      final extraHeading1 = params.labelFor(
        'showExtraHeading1',
        englishFallback: '',
        arabicFallback: '',
      );
      if (extraHeading1.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(extraHeading1, scale: 0.9, isBold: true));
      }
    }

    // Extra Heading 2 (e.g., VAT NO)
    if (_isVisible(displayConfig, 'showExtraHeading2')) {
      final extraHeading2 = params.labelFor(
        'showExtraHeading2',
        englishFallback: '',
        arabicFallback: '',
      );
      if (extraHeading2.isNotEmpty) {
        rows.add(TextRow(extraHeading2, scale: 0.9, isBold: true));
      }
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (_isVisible(displayConfig, 'showFssaiInfo')) {
      final fssaiInfo = params.labelFor(
        'showFssaiInfo',
        englishFallback: '',
        arabicFallback: '',
      );
      if (fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.85, isBold: true));
      }
    }

    // Store VAT/CR: the option supplies label and visibility, the store's
    // ZATCA registration supplies the number.
    for (final key in const ['showVatNumber', 'showCRNumber']) {
      final taxLine = params.storeTaxText(key);
      if (taxLine.isNotEmpty) {
        rows.add(FieldTextRow(params.storeFieldLine(key),
            scale: 0.85, isBold: true));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Contact info
    final telephone = params.storeContactText('showTel');
    if (telephone.isNotEmpty) {
      rows.add(SpacingRow(5));
      rows.add(FieldTextRow(params.storeFieldLine('showTel'),
          scale: 0.9, isBold: true));
    }

    final email = params.storeContactText('showEmail');
    if (email.isNotEmpty) {
      rows.add(FieldTextRow(params.storeFieldLine('showEmail'),
          scale: 0.9, isBold: true));
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(ThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Invoice/Token Number
    final bool showInvoiceNumber =
        _isVisible(displayConfig, 'showInvoiceNumber');

    String? invoiceNumberText;
    if (showInvoiceNumber) {
      // Shared contract: document number_prefix + stable order-number component.
      invoiceNumberText = params.invoiceNumberText;
    }

    // Shared 'showTokenNumber' line: label, separator and token.
    final String? tokenText =
        params.tokenText.isNotEmpty ? params.tokenText : null;

    if (invoiceNumberText != null && tokenText != null) {
      final invoiceAlign = isEnglish ? TextAlign.left : TextAlign.right;
      final tokenAlign = isEnglish ? TextAlign.right : TextAlign.left;
      final invoiceCol = ReceiptTableColumn(invoiceNumberText,
          field: params.invoiceNumberLine,
          weight: 0.58,
          align: invoiceAlign,
          isBold: true,
          scale: 0.9);
      final tokenCol = ReceiptTableColumn(tokenText,
          field: params.tokenLine,
          weight: 0.38,
          align: tokenAlign,
          isBold: true,
          scale: 1.1);
      final spacerCol =
          ReceiptTableColumn('', weight: 0.04, align: TextAlign.center);

      // Configured bilingual token labels must wrap instead of losing their
      // second language or token value in a single-line cell.
      rows.add(MultiLineReceiptTableRow(isEnglish
          ? [invoiceCol, spacerCol, tokenCol]
          : [tokenCol, spacerCol, invoiceCol]));
    } else if (invoiceNumberText != null) {
      rows.add(
          FieldTextRow(params.invoiceNumberLine, scale: 0.9, isBold: true));
    } else if (tokenText != null) {
      rows.add(FieldTextRow(params.tokenLine, scale: 1.4, isBold: true));
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
    // The customer master switch and every child option are explicit.  A
    // missing option must not silently enable a field.
    if (!_isVisible(displayConfig, 'showCustomerNameAndPhone')) {
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

    final bool showCustomerName = _isVisible(displayConfig, 'showCustomerName');
    final bool showCustomerPhone =
        _isVisible(displayConfig, 'showCustomerPhone');
    // Quotations carry no payment; the shared summary names the method(s).
    final bool showPayment = _isVisible(displayConfig, paymentConfigKey) &&
        !params.isQuotation &&
        params.paymentMethodSummary.isNotEmpty;
    final bool showCustomerAddress =
        _isVisible(displayConfig, 'showCustomerAddress');
    final bool showComment = _isVisible(displayConfig, commentConfigKey);
    final bool showDeliveryMethod =
        _isVisible(displayConfig, 'showDeliveryMethod');
    final bool showDeliveryPhone =
        _isVisible(displayConfig, 'showDeliveryPhone');
    final bool showCustomerVatNumber =
        _isVisible(displayConfig, 'showCustomerVatNumber');
    final bool showCustomerCrNumber =
        _isVisible(displayConfig, 'showCustomerCrNumber');

    // Primary + alternate phone; both masked when 'showCustomerPhoneMasked'
    // is on. Empty when the phone is hidden or belongs to the walk-in customer.
    final String phoneText = params.customerPhoneLineText;

    final bool hasVisibleCustomerData = (showCustomerName &&
            params.customerName != null &&
            params.customerName!.isNotEmpty) ||
        (showCustomerPhone && phoneText.isNotEmpty) ||
        showPayment ||
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

    // Labels print in their own column, so a typed trailing colon is dropped
    // from each language line before the lines are joined.
    String customerSectionLabel(String key) => inlineBilingualLabel(
        withoutTrailingLabelColons(params.fieldLabel(key)));

    final customerLabel = customerSectionLabel('showCustomerName');
    final phoneLabel = customerSectionLabel('showCustomerPhone');
    final paymentLabel = customerSectionLabel(paymentConfigKey);
    final addressLabel = customerSectionLabel('showCustomerAddress');
    final commentLabel = customerSectionLabel(commentConfigKey);
    final deliveryLabel = customerSectionLabel('showDeliveryMethod');
    final deliveryPhoneLabel = customerSectionLabel('showDeliveryPhone');
    final customerVatLabel = customerSectionLabel('showCustomerVatNumber');
    final customerCrLabel = customerSectionLabel('showCustomerCrNumber');

    if (isEnglish) {
      // English: Label: Value format (left aligned for both)
      ReceiptTableRow customerInfoRow(String value, String label) {
        return ReceiptTableRow([
          ReceiptTableColumn(label,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(value,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]);
      }

      if (showCustomerName &&
          params.customerName != null &&
          params.customerName!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerName!, customerLabel));
      }

      if (showCustomerPhone && phoneText.isNotEmpty) {
        rows.add(customerInfoRow(phoneText, phoneLabel));
      }

      if (showPayment) {
        rows.add(customerInfoRow(params.paymentMethodSummary, paymentLabel));
      }

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerAddress!, addressLabel));
      }

      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(customerInfoRow(params.orderComment!, commentLabel));
      }

      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(customerInfoRow(params.deliveryMethod!, deliveryLabel));
      }
      if (showDeliveryPhone &&
          (params.deliveryPhone?.trim().isNotEmpty ?? false)) {
        rows.add(
            customerInfoRow(params.deliveryPhone!.trim(), deliveryPhoneLabel));
      }
      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerVatNumber!, customerVatLabel));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerCrNumber!, customerCrLabel));
      }
    } else {
      // Arabic: Label on right, Value on left (RTL reading flow). A bilingual
      // label carries two languages, so it gets the wider column.
      final valueWeight = params.isBilingual ? 0.45 : 0.65;
      final labelWeight = params.isBilingual ? 0.55 : 0.35;

      ReceiptTableRow customerInfoRow(String value, String label) {
        return ReceiptTableRow([
          ReceiptTableColumn(
            value,
            weight: valueWeight,
            align: TextAlign.left,
            scale: scale,
            textDirection:
                _hasArabic(value) ? TextDirection.rtl : TextDirection.ltr,
          ),
          ReceiptTableColumn(
            label,
            weight: labelWeight,
            align: TextAlign.right,
            isBold: true,
            scale: scale,
            textDirection: TextDirection.rtl,
          ),
        ]);
      }

      if (showCustomerName &&
          params.customerName != null &&
          params.customerName!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerName!, customerLabel));
      }

      if (showCustomerPhone && phoneText.isNotEmpty) {
        rows.add(customerInfoRow(phoneText, phoneLabel));
      }

      if (showPayment) {
        rows.add(customerInfoRow(params.paymentMethodSummary, paymentLabel));
      }

      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(customerInfoRow(params.orderComment!, commentLabel));
      }

      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(customerInfoRow(params.deliveryMethod!, deliveryLabel));
      }

      if (showDeliveryPhone &&
          (params.deliveryPhone?.trim().isNotEmpty ?? false)) {
        rows.add(
            customerInfoRow(params.deliveryPhone!.trim(), deliveryPhoneLabel));
      }

      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerVatNumber!, customerVatLabel));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerCrNumber!, customerCrLabel));
      }

      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(customerInfoRow(params.customerAddress!, addressLabel));
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
    final isBilingual = params.isBilingual;

    // Column headers: the shared per-key label every template prints.
    final String particularsLabel = params.fieldLabel('showParticulars');
    final String mrpLabel = params.fieldLabel('showMRP');
    final String qtyLabel = params.fieldLabel('showQty');
    final String rateLabel = params.fieldLabel('showRate');
    final String rateExcTaxLabel = params.fieldLabel('showRateExcTax');
    final String unitLabel = params.fieldLabel('showUnit');
    final String totalLabel = params.fieldLabel('showTotal');
    final String taxHeaderLabel = params.fieldLabel('showTaxHeader');
    final String slLabel = params.fieldLabel('showSLNumber');

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
          params,
          displayConfig,
          isEnglish,
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
    if (_isVisible(displayConfig, 'showItemsCount')) {
      final itemsCountLabel = inlineBilingualLabel(
          ReceiptConfigurationContract.withoutTrailingColon(
              params.fieldLabel('showItemsCount')));
      final int itemCount = params.cartItems.length;
      rows.add(FieldTextRow(
        ReceiptTextLine.field(itemsCountLabel, '$itemCount'),
        scale: 0.9,
        isBold: true,
      ));
      rows.add(SpacingRow(_itemGap));
    }

    if (_isVisible(displayConfig, 'showQuantityCount')) {
      final quantityCountLabel = inlineBilingualLabel(
          ReceiptConfigurationContract.withoutTrailingColon(
              params.fieldLabel('showQuantityCount')));
      rows.add(FieldTextRow(
        ReceiptTextLine.field(quantityCountLabel,
            ReceiptSections.formatQuantity(params.totalQuantity)),
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
    bool show(String key) => _isVisible(displayConfig, key);

    if (isEnglish) {
      if (show('showSLNumber')) {
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: tableWeights['showSLNumber'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showParticulars')) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: tableWeights['showParticulars'] ?? 0,
            align: TextAlign.left,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showMRP')) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showQty')) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRate')) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRateExcTax')) {
        headerCols.add(ReceiptTableColumn(rateExcTaxLabel,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showUnit')) {
        headerCols.add(ReceiptTableColumn(unitLabel,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showTaxHeader')) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.center,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showTotal')) {
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
      if (show('showTotal')) {
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: tableWeights['showTotal'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showTaxHeader')) {
        headerCols.add(ReceiptTableColumn(taxHeaderLabel,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRate')) {
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRateExcTax')) {
        headerCols.add(ReceiptTableColumn(rateExcTaxLabel,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showUnit')) {
        headerCols.add(ReceiptTableColumn(unitLabel,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showQty')) {
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showMRP')) {
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showParticulars')) {
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: tableWeights['showParticulars'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showSLNumber')) {
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
      rows.add(MultiLineReceiptTableRow(headerCols));
      rows.add(ThinDividerRow());
    }
  }

  void _buildCartItemRow(
    List<ReceiptRow> rows,
    dynamic item,
    int index,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    bool isBilingual,
    Map<String, double> tableWeights,
    double tableScale,
    double tableMinScale,
    double tableCellPadding,
  ) {
    // Shared name lines: [Arabic, English] on a bilingual document when the
    // product has an Arabic name, otherwise the one name for the language.
    final nameLines = displayConfig?['showParticulars']?.visible == true
        ? params.itemNameLines(item)
        : const <String>[];
    final String productNameArabic =
        nameLines.length > 1 ? nameLines.first : '';
    final String productName = nameLines.length > 1
        ? nameLines[1]
        : (nameLines.isEmpty ? '' : nameLines.first);
    String mrp = '';
    String quantity = '';
    String unitPrice = '';
    String unitPriceExTax = '';
    String unitName = '';
    String totalPrice = '';
    String itemTaxAmount = '';
    bool warrantyEnabled = false;

    if (params.isFromLocalStorage || item is Map) {
      mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      final double unitPriceValue = (double.tryParse(
              (item['unitPrice'] ?? item['unit_price'])?.toString() ?? '0') ??
          0.0);
      final double taxValue = (double.tryParse(
              (item['tax_amount'] ?? item['taxAmount'])?.toString() ?? '0') ??
          0.0);
      final double quantityValue =
          (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0);
      quantity = ReceiptSections.formatQuantity(quantityValue);
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
      mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      final double unitPriceValue =
          (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0);
      final double taxValue =
          (double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0);
      final double quantityValue =
          (double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0);
      quantity = ReceiptSections.formatQuantity(quantityValue);
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
    bool show(String key) => _isVisible(displayConfig, key);

    if (isEnglish) {
      // Product name row (English - single name)
      if (show('showParticulars') || show('showSLNumber')) {
        String itemText =
            show('showSLNumber') ? '$slNumber. $productName' : productName;
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
      if (show('showMRP')) {
        priceCols.add(ReceiptTableColumn(mrp,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.center,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showQty')) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.center,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRate')) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRateExcTax')) {
        priceCols.add(ReceiptTableColumn(unitPriceExTax,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showUnit')) {
        priceCols.add(ReceiptTableColumn(unitName,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.center,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showTaxHeader')) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showTotal')) {
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
      if (show('showParticulars') || show('showSLNumber')) {
        // Show Arabic name (line 1) and English name (line 2) when available
        String itemText = '';
        if (productNameArabic.isNotEmpty) {
          // Bilingual: Arabic on line 1, English on line 2
          if (show('showSLNumber')) {
            itemText = '$slNumber. $productNameArabic';
          } else {
            itemText = productNameArabic;
          }
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
          ]));

          // Add English name on second line
          String englishText =
              show('showSLNumber') ? '     $productName' : '  $productName';
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(englishText,
                weight: 1.0,
                align: TextAlign.left,
                textDirection: TextDirection.ltr),
          ]));
        } else {
          // Fallback to single name (English or Arabic)
          String itemText =
              show('showSLNumber') ? '$slNumber. $productName' : productName;
          final itemIsArabic = _hasArabic(itemText);
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemText,
                weight: 1.0,
                align: itemIsArabic ? TextAlign.right : TextAlign.left,
                textDirection:
                    itemIsArabic ? TextDirection.rtl : TextDirection.ltr),
          ]));
        }
      }
      // Price details row (RTL order)
      List<ReceiptTableColumn> priceCols = [];
      if (show('showTotal')) {
        priceCols.add(ReceiptTableColumn(totalPrice,
            weight: tableWeights['showTotal'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showTaxHeader')) {
        priceCols.add(ReceiptTableColumn(itemTaxAmount,
            weight: tableWeights['showTaxHeader'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRate')) {
        priceCols.add(ReceiptTableColumn(unitPrice,
            weight: tableWeights['showRate'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showRateExcTax')) {
        priceCols.add(ReceiptTableColumn(unitPriceExTax,
            weight: tableWeights['showRateExcTax'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showUnit')) {
        priceCols.add(ReceiptTableColumn(unitName,
            weight: tableWeights['showUnit'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showQty')) {
        priceCols.add(ReceiptTableColumn(quantity,
            weight: tableWeights['showQty'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      if (show('showMRP')) {
        priceCols.add(ReceiptTableColumn(mrp,
            weight: tableWeights['showMRP'] ?? 0,
            align: TextAlign.right,
            scale: tableScale,
            minScale: tableMinScale,
            horizontalPadding: tableCellPadding));
      }
      final itemDetailsWeight = _getItemDetailsWeight(tableWeights);
      if (itemDetailsWeight > 0) {
        priceCols.add(ReceiptTableColumn("", weight: itemDetailsWeight));
      }
      if (priceCols.any((column) => column.text.isNotEmpty)) {
        rows.add(ReceiptTableRow(priceCols));
      }
    }

    if (show('showWarranty') && warrantyEnabled) {
      final warrantyLabel = ReceiptConfigurationContract.label(
        options: displayConfig,
        key: 'showWarranty',
        mode: isBilingual
            ? ReceiptLanguageMode.bilingual
            : (isEnglish
                ? ReceiptLanguageMode.english
                : ReceiptLanguageMode.arabic),
        englishFallback: 'Warranty',
        arabicFallback: 'الضمان',
      );
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(
          warrantyLabel,
          weight: 1.0,
          align: isEnglish ? TextAlign.left : TextAlign.right,
          textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
        ),
      ]));
    }
  }

  Map<String, double> _buildNormalizedTableWeights(
    Map<String, DisplayOption>? displayConfig,
  ) {
    final bool showSlNumber = _isVisible(displayConfig, 'showSLNumber');
    final baseWeights = <String, double>{
      if (showSlNumber) 'showSLNumber': 0.08,
      if (_isVisible(displayConfig, 'showParticulars'))
        'showParticulars': showSlNumber ? 0.17 : 0.25,
      if (_isVisible(displayConfig, 'showMRP')) 'showMRP': 0.15,
      if (_isVisible(displayConfig, 'showQty')) 'showQty': 0.12,
      if (_isVisible(displayConfig, 'showRate')) 'showRate': 0.15,
      if (_isVisible(displayConfig, 'showRateExcTax')) 'showRateExcTax': 0.15,
      if (_isVisible(displayConfig, 'showUnit')) 'showUnit': 0.12,
      if (_isVisible(displayConfig, 'showTaxHeader')) 'showTaxHeader': 0.15,
      if (_isVisible(displayConfig, 'showTotal')) 'showTotal': 0.15,
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

    // Get currency from appSettings
    final String currency = appSettings?.currency ?? 'INR';
    final String? currencySymbol =
        currency.trim().toUpperCase() == 'INR' ? '\u20B9' : null;
    final ui.Image? currencyIcon = _currencyIcon(currency, sarSymbol);

    // Paper size aware scaling
    final bool is58mm = params.is58mm;

    // Shared amounts: the taxable subtotal never falls back to the
    // tax-inclusive grand total.
    final double saved = params.savedAmountValue;
    final double total = params.netAmountValue;
    final double discountAmountValue = params.discountAmountValue;
    final double taxAmount = params.totalTax;
    final double subtotal = params.subtotalExcTax;

    // Visibility settings
    final showSubTotal = params.isVisible('showSubTotal');
    final showMRPTotal = params.isVisible('showMRPTotal');
    final showDiscount = params.isVisible('showDiscount');
    final showTax = params.isVisible('showTax');
    final showNetAmount = params.isVisible('showNetAmount');

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
    debugPrint("  showSubTotal: $showSubTotal; showMRPTotal: $showMRPTotal");
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

    final taxLabelBase = _getLabel(displayConfig, 'showTax',
        resolvedLabels?.tax, isEnglish ? "VAT" : "الضريبة");
    final vatLabel = taxLabelBase;

    final grandTotalLabel = _getLabel(displayConfig, 'showNetAmount', null,
        isEnglish ? "GRAND TOTAL" : "المبلغ الاجمالي");

    // Prepare boxed items
    List<BoxedLineItem> boxedItems = [];

    // 1. Subtotal
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

    if (showMRPTotal) {
      boxedItems.add(BoxedLineItem(
        label: params.fieldLabel('showMRPTotal'),
        value: params.mrpTotalValue.toStringAsFixed(2),
        isBold: true,
        scale: 1.1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    // 2. Discounts
    if (showDiscount && discountAmountValue != 0) {
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
    final bool showPaymentBreaked = params.isVisible('showPaymentBreaked');

    // Shared rows (same as the standard layout): per-method amounts named by
    // their code, else the single method with the paid amount.
    final paymentRows = params.paymentBreakdownRows;
    if (params.paidAmount != null &&
        showPaymentBreaked &&
        paymentRows.isNotEmpty) {
      boxedItems.add(BoxedLineItem(isSeparator: true));
      for (final row in paymentRows) {
        boxedItems.add(BoxedLineItem(
          label: row.$1,
          value: row.$2.toStringAsFixed(2),
          isBold: true,
          scale: paymentRows.length == 1 ? 1.1 : 1,
          icon: currencyIcon,
          currencySymbol: currencySymbol,
        ));
      }
    }

    // Add the boxed row
    rows.add(BoxedTotalsRow(items: boxedItems));

    // Amount in Words
    if (params.isVisible('showAmountInWords')) {
      rows.add(SpacingRow(_itemGap));
      for (final line in params.amountInWordsLines(total, currency: currency)) {
        rows.add(TextRow(line, scale: is58mm ? 0.7 : 0.85, isBold: true));
      }
    }

    // You Saved
    if (params.isVisible('showSaved') && saved > 0) {
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
    if (!params.isVisible('showCustomerBalance')) {
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

    // Get labels from displayConfig (same on every paper size)
    String balanceLabel(String key) =>
        inlineBilingualLabel(ReceiptConfigurationContract.withoutTrailingColon(
            params.fieldLabel(key)));
    final prevBalanceLabel = balanceLabel('showCustomerPrevBalance');
    final paidAmountLabel = balanceLabel('showCustomerPaidAmount');
    final currentBalanceLabel = balanceLabel('showCustomerCurrentBalance');

    // Previous Balance
    if (params.isVisible('showCustomerPrevBalance') &&
        params.customerOldBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(prevBalanceLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

    // Paid Amount (this transaction)
    if (params.isVisible('showCustomerPaidAmount') &&
        params.paidAmount != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(paidAmountLabel,
            weight: 0.6, align: TextAlign.right, scale: scale),
        ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, scale: scale),
      ]));
    }

    // Current Balance
    if (params.isVisible('showCustomerCurrentBalance') &&
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

  void _buildBankSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
  ) {
    // Shared rows: 'showBankInfo' is the master switch; 'showBankName',
    // 'showAccountName', 'showAccountNumber', 'showIBAN' and 'showSwiftCode'
    // each gate their own field.
    if (!params.isVisible('showBankInfo')) return;
    final details = params.bankDetailRows;

    if (details.isEmpty) return;
    rows.add(SpacingRow(_itemGap));
    rows.add(TextRow(
      params.bankDetailsHeading,
      isBold: true,
      scale: 0.9,
    ));
    for (final detail in details) {
      rows.add(FieldTextRow(
          ReceiptTextLine.field(
              ReceiptConfigurationContract.withoutTrailingColon(detail.$1),
              detail.$2),
          scale: 0.8));
    }
  }

  void _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    BuildContext context,
  ) {
    rows.add(SpacingRow(_sectionGap));

    _buildBankSection(rows, params);

    // QR Code - Use ZATCA QR if credentials available, otherwise fallback to payment QR
    if (params.isVisible('showQRCode')) {
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

        qrMessage = params.labelFor(
          'showQRCode',
          englishFallback: 'ZATCA E-Invoice QR',
          arabicFallback: 'فاتورة الكترونية',
        );

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

        qrMessage = params.labelFor(
          'showQRCode',
          englishFallback: 'Scan to Pay',
          arabicFallback: 'امسح للدفع',
        );
      }

      // Display QR code if data is available
      if (qrData.isNotEmpty) {
        rows.add(TextRow(qrMessage, scale: 0.9));
        rows.add(SpacingRow(5));
        rows.add(QrRow(qrData, size: 220));
      }
    }

    // VAT footer is independent of QR generation.  A visible VAT footer must
    // still print when QR data is unavailable or disabled.
    if (params.isVisible('showVATFooter') &&
        params.zatcaVatNumber?.trim().isNotEmpty == true) {
      rows.add(SpacingRow(5));
      rows.add(FieldTextRow(params.vatFooterLine, scale: 0.8));
    }

    rows.add(SpacingRow(_headerGap));

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    // Date and Time - Clean format (with visibility check)
    if (params.isVisible('showDate')) {
      // Draw the date independently of its configured caption.
      final dateTimeText = params.orderDateTimeText;
      final dateLabel =
          _getLabel(displayConfig, 'showDate', resolvedLabels?.date, "");
      if (dateLabel.isNotEmpty) {
        rows.add(FieldTextRow(
            ReceiptTextLine.field(
                ReceiptConfigurationContract.withoutTrailingColon(dateLabel),
                dateTimeText),
            scale: 0.85));
      } else {
        rows.add(TextRow(dateTimeText, scale: 0.85));
      }
    }

    // Order Number Display (Footer only)
    if (params.isVisible('showOrderNumberInFooter')) {
      rows.add(SpacingRow(8));
      rows.add(ThinDividerRow());
      rows.add(SpacingRow(5));
      rows.add(FieldTextRow(params.orderNumberFooterLine,
          scale: 0.85, isBold: true));
    }

    rows.add(SpacingRow(_itemGap));

    // Terms & Conditions
    if (params.isVisible('showTermsConditions')) {
      final terms = params.termsText;
      if (terms.trim().isNotEmpty) {
        rows.add(TextRow(terms.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message - Elegant
    if (params.isVisible('showThankYouMessage')) {
      final message = params.thankYouText;
      if (message.trim().isNotEmpty) {
        rows.add(TextRow(message.trim(), isBold: true, scale: 0.95));
      }
    }

    rows.add(SpacingRow(_sectionGap));
  }

  // ==================== UTILITY METHODS ====================

  bool _isVisible(
    Map<String, DisplayOption>? displayConfig,
    String key,
  ) =>
      ReceiptConfigurationContract.isVisible(displayConfig, key);

  /// Resolve a configured label through the shared language contract.  The API
  /// stores Arabic in `value` and English in `default`; this keeps the modes
  /// independent and prevents Arabic values leaking into English output.
  String _getLabel(
    Map<String, DisplayOption>? displayConfig,
    String key,
    String? resolvedLabel,
    String defaultLabel,
  ) {
    // Callers pass the default of the document's language, so a neutral
    // default ("MRP", "#") is kept on Arabic and bilingual receipts too.
    final english = _activeLanguageMode.isEnglish;
    return ReceiptConfigurationContract.label(
      options: displayConfig,
      key: key,
      mode: _activeLanguageMode,
      englishFallback: english ? defaultLabel : '',
      arabicFallback: english ? '' : defaultLabel,
      resolvedArabic: resolvedLabel,
    );
  }

  bool _hasArabic(String value) => RegExp(r'[؀-ۿ]').hasMatch(value);

  /// The Saudi Riyal symbol image prints only for SAR amounts.
  ui.Image? _currencyIcon(String currency, ui.Image? sarSymbol) =>
      currency.trim().toUpperCase() == 'SAR' ? sarSymbol : null;

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    return PrintLogoLoader.loadUiLogo(url, tag: '[premium_receipt_layout]');
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

  // ==================== RETURN ITEMS SECTION ====================

  void _buildReturnSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    ui.Image? sarSymbol,
    dynamic appSettings,
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
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
    if (!hasCreditNoteConfig)
      rows.add(TextRow(params.returnsSectionHeading, isBold: true, scale: 1.1));
    rows.add(SpacingRow(_itemGap));

    appendReturnMetadataRows(rows, params, scale: scale, gap: _itemGap);

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
    final totalLabel = _getLabel(
        displayConfig,
        'showReturnTotal',
        retLabels?.text('grand_total_header') ?? resolvedLabels?.returnTotal,
        isEnglish ? 'TOTAL' : 'الإجمالي');

    final bool showSl = _isVisible(displayConfig, 'showReturnSLNumber');
    final bool showParticulars =
        _isVisible(displayConfig, 'showReturnParticulars');
    final bool showMrp = _isVisible(displayConfig, 'showReturnMRP');
    final unitPriceLabel = params.fieldLabel('showUnitPrice');
    final showUnitPrice = params.isVisible('showUnitPrice');
    final showHsn = params.isVisible('showHsnCode');
    final showTaxRate = params.isVisible('showTaxRateColumn');
    final showTaxAmount = params.isVisible('showTaxAmountColumn');
    final showTaxableValue = params.isVisible('showTaxableColumn');
    final showReturnSubtotal =
        params.isReturnOnly && params.isVisible('showSubTotal');
    final returnSubtotalLabel = params.labelFor('showSubTotal',
        englishFallback: 'Sub Total',
        arabicFallback: 'المجموع الفرعي',
        resolvedArabic: retLabels?.text('sub_total_header'),
        inlineBilingual: true);
    final taxAmountLabel = params.labelFor('showTaxAmountColumn',
        englishFallback: 'Tax Amount',
        arabicFallback: 'مبلغ الضريبة',
        resolvedArabic: retLabels?.text('tax_column'),
        inlineBilingual: true);
    final taxableValueLabel = params.labelFor('showTaxableColumn',
        englishFallback: 'Taxable Value',
        arabicFallback: 'القيمة الخاضعة للضريبة',
        resolvedArabic: retLabels?.text('taxable_value'),
        inlineBilingual: true);
    final hsnLabel = params.labelFor('showHsnCode',
        englishFallback: 'HSN',
        arabicFallback: 'رمز الصنف',
        resolvedArabic: retLabels?.text('hsn'),
        inlineBilingual: true);
    final taxRateLabel = params.labelFor('showTaxRateColumn',
        englishFallback: 'Tax Rate',
        arabicFallback: 'نسبة الضريبة',
        resolvedArabic: retLabels?.text('tax_rate_column'),
        inlineBilingual: true);

    final bool showQty = _isVisible(displayConfig, 'showReturnQty');
    final bool showRate = _isVisible(displayConfig, 'showReturnRate');
    final bool showTotal = _isVisible(displayConfig, 'showReturnTotal');

    final Map<String, double> baseWeights = {
      if (showSl) 'sl': 0.08,
      if (showParticulars) 'particulars': showSl ? 0.25 : 0.33,
      if (showMrp) 'mrp': 0.15,
      if (showHsn) 'hsn': 0.15,
      if (showTaxRate) 'taxRate': 0.15,
      if (showTaxAmount) 'taxAmount': 0.15,
      if (showTaxableValue) 'taxableValue': 0.15,
      if (showReturnSubtotal) 'returnSubtotal': 0.15,
      if (showUnitPrice) 'unitPrice': 0.15,
      if (showQty) 'qty': 0.12,
      if (showRate) 'rate': 0.15,
      if (showTotal) 'total': 0.15,
    };
    final double totalW = baseWeights.values.fold<double>(0, (s, w) => s + w);
    final Map<String, double> weights = totalW > 0
        ? {for (final e in baseWeights.entries) e.key: e.value / totalW}
        : baseWeights;

    if (!appendDenseReturnItemRows(rows, params, scale: scale, gap: _itemGap)) {
      if (showSl ||
          showParticulars ||
          showMrp ||
          showHsn ||
          showTaxRate ||
          showTaxAmount ||
          showTaxableValue ||
          showReturnSubtotal ||
          showUnitPrice ||
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
        if (showHsn)
          headerCols.add(ReceiptTableColumn(hsnLabel,
              weight: weights['hsn'] ?? 0,
              align: TextAlign.center,
              isBold: true,
              scale: scale));
        if (showTaxRate)
          headerCols.add(ReceiptTableColumn(taxRateLabel,
              weight: weights['taxRate'] ?? 0,
              align: TextAlign.center,
              isBold: true,
              scale: scale));
        if (showUnitPrice)
          headerCols.add(ReceiptTableColumn(unitPriceLabel,
              weight: weights['unitPrice'] ?? 0,
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
        for (final column in [
          (showTaxAmount, 'taxAmount', taxAmountLabel),
          (showTaxableValue, 'taxableValue', taxableValueLabel),
          (showReturnSubtotal, 'returnSubtotal', returnSubtotalLabel),
        ]) {
          if (column.$1) {
            headerCols.add(ReceiptTableColumn(column.$3,
                weight: weights[column.$2] ?? 0,
                align: TextAlign.right,
                isBold: true,
                scale: scale));
          }
        }
        rows.add(MultiLineReceiptTableRow(headerCols));
        rows.add(ThinDividerRow());
      }

      for (var i = 0; i < orderReturns.returnItems!.length; i++) {
        final returnItem = orderReturns.returnItems![i];
        final num itemQty = returnItem.quantity ?? 0;
        final (itemRate, itemMrp) = params.returnItemRate(returnItem);
        final double itemTotal = itemQty * itemRate;
        if (showParticulars || showSl) {
          // Shared name lines (variant attributes included).
          final displayName = params.itemNameLines(returnItem).join(' ');
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(
                ReceiptSections.returnItemHeading(
                    name: displayName,
                    number: i + 1,
                    showSerial: showSl,
                    showParticulars: showParticulars),
                weight: 1.0,
                align: TextAlign.left,
                scale: scale)
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
        if (showHsn)
          priceCols.add(ReceiptTableColumn(returnItem.hsnCode?.trim() ?? '',
              weight: weights['hsn'] ?? 0,
              align: TextAlign.right,
              scale: scale));
        if (showTaxRate)
          priceCols.add(ReceiptTableColumn(params.returnTaxRateText(returnItem),
              weight: weights['taxRate'] ?? 0,
              align: TextAlign.right,
              scale: scale));
        if (showUnitPrice)
          priceCols.add(ReceiptTableColumn(itemRate.toStringAsFixed(2),
              weight: weights['unitPrice'] ?? 0,
              align: TextAlign.right,
              scale: scale));
        if (showQty)
          priceCols.add(ReceiptTableColumn(
              ReceiptSections.formatQuantity(itemQty.toDouble()),
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
        for (final column in [
          (
            showTaxAmount,
            'taxAmount',
            params.returnItemMoneyText(returnItem.taxAmount)
          ),
          (
            showTaxableValue,
            'taxableValue',
            params.returnItemMoneyText(returnItem.taxableValue)
          ),
          (
            showReturnSubtotal,
            'returnSubtotal',
            params.returnItemMoneyText(returnItem.subTotal)
          ),
        ]) {
          if (column.$1) {
            priceCols.add(ReceiptTableColumn(column.$3,
                weight: weights[column.$2] ?? 0,
                align: TextAlign.right,
                scale: scale));
          }
        }
        if (priceCols.any((c) => c.text.isNotEmpty))
          rows.add(MultiLineReceiptTableRow(priceCols));
        if (i < orderReturns.returnItems!.length - 1)
          rows.add(ThinDividerRow());
      }
    }

    rows.add(SpacingRow(_itemGap));

    final returnCountRow = params.returnsSection?.countRow;
    if (returnCountRow != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(returnCountRow.$1,
            weight: 0.6, align: TextAlign.left, isBold: true, scale: scale),
        ReceiptTableColumn(returnCountRow.$2,
            weight: 0.4, align: TextAlign.right, isBold: true, scale: scale),
      ]));
    }

    final bool showReturnTotalAmt =
        _isVisible(displayConfig, 'showReturnTotalAmount');
    final bool showReturnNetAmt =
        _isVisible(displayConfig, 'showReturnNetAmount');
    final mrpTotalRow = params.returnMrpTotalRow;
    final allocationRows = params.returnAllocationTotalRows;
    if (showReturnTotalAmt ||
        showReturnNetAmt ||
        mrpTotalRow != null ||
        allocationRows.isNotEmpty) {
      final String currency = appSettings?.currency ?? 'INR';
      final String? currencySymbol =
          currency.trim().toUpperCase() == 'INR' ? '₹' : null;
      final ui.Image? currencyIcon = _currencyIcon(currency, sarSymbol);
      final double returnRateTotal = params.returnTotalValue;
      final List<BoxedLineItem> returnSummaryItems = [];
      if (mrpTotalRow != null) {
        returnSummaryItems.add(BoxedLineItem(
          label: mrpTotalRow.$1,
          value: mrpTotalRow.$2.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol,
        ));
      }
      for (final row in allocationRows) {
        returnSummaryItems.add(BoxedLineItem(
          label: row.$1,
          value: row.$2?.toStringAsFixed(2) ?? '',
          isBold: true,
          scale: 1.1,
          icon: row.$2 == null ? null : currencyIcon,
          currencySymbol: row.$2 == null ? null : currencySymbol,
        ));
      }
      if (showReturnTotalAmt) {
        returnSummaryItems.add(BoxedLineItem(
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
        returnSummaryItems.add(BoxedLineItem(
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
      rows.add(BoxedTotalsRow(items: returnSummaryItems));
    }
    appendReturnTaxSummaryRows(rows, params, scale: 0.85);
    final returnWords =
        params.returnsWordsLines(appSettings?.currency ?? 'INR');
    if (returnWords.isNotEmpty) {
      rows.add(SpacingRow(_itemGap));
      rows.add(TextRow(params.returnsSection!.wordsHeading,
          isBold: true, scale: 0.9));
      for (final line in returnWords) {
        rows.add(TextRow(line, isBold: false, scale: 0.85));
      }
    }
    appendReturnFooterRows(rows, params);
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
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty)
      return;

    final bool showFinalPurchase =
        _isVisible(displayConfig, 'showFinalPurchase');
    final bool showFinalReturn = _isVisible(displayConfig, 'showFinalReturn');
    final bool showFinalNetAmount =
        _isVisible(displayConfig, 'showFinalNetAmount');
    final bool showFinalAmountInWords =
        _isVisible(displayConfig, 'showFinalAmountInWords');
    if (!showFinalPurchase &&
        !showFinalReturn &&
        !showFinalNetAmount &&
        !showFinalAmountInWords) return;

    final String currency = appSettings?.currency ?? 'INR';
    final String? currencySymbol =
        currency.trim().toUpperCase() == 'INR' ? '₹' : null;
    final ui.Image? currencyIcon = _currencyIcon(currency, sarSymbol);

    final double returnTotal = params.returnTotalValue;

    final double orderTotal = params.netAmountValue;
    final double finalTotal = orderTotal - returnTotal;

    rows.add(SpacingRow(_sectionGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    List<BoxedLineItem> summaryItems = [];
    if (showFinalPurchase) {
      summaryItems.add(BoxedLineItem(
          label: _getLabel(displayConfig, 'showFinalPurchase', null,
              isEnglish ? 'ORDER TOTAL' : 'إجمالي الطلب'),
          value: orderTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (showFinalReturn) {
      summaryItems.add(BoxedLineItem(
          label: _getLabel(displayConfig, 'showFinalReturn', null,
              isEnglish ? 'RETURN TOTAL' : 'إجمالي المرتجع'),
          value: returnTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (showFinalNetAmount) {
      summaryItems.add(BoxedLineItem(isSeparator: true));
      summaryItems.add(BoxedLineItem(
          label: _getLabel(displayConfig, 'showFinalNetAmount', null,
              isEnglish ? 'FINAL TOTAL  ' : 'المبلغ النهائي'),
          value: finalTotal.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol));
    }
    if (summaryItems.isNotEmpty) rows.add(BoxedTotalsRow(items: summaryItems));

    if (showFinalAmountInWords) {
      rows.add(SpacingRow(_itemGap));
      final language = params.amountInWordsLanguage;
      final amountText = AmountHelper().convertNumberToWords(finalTotal,
          currency: currency, language: language);
      final suffix = language == 'ar' ? ' فقط.' : ' Only.';
      rows.add(TextRow('$amountText$suffix', scale: 0.85, isBold: true));
    }
    rows.add(SpacingRow(_itemGap));
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

  // Use measured text heights for Arabic ascenders/descenders and separators.
  StandardBoxedTotalsRow get _measuredRow => StandardBoxedTotalsRow(
        cornerRadius: cornerRadius,
        padding: padding,
        items: [
          for (final item in items)
            StandardBoxedLineItem(
              label: item.label,
              value: item.value,
              isBold: item.isBold,
              scale: item.scale,
              isSeparator: item.isSeparator,
              icon: item.icon,
              currencySymbol: item.currencySymbol,
            ),
        ],
      );

  @override
  double calculateHeight(
          double width, double fontSize, TextDirection direction) =>
      _measuredRow.calculateHeight(width, fontSize, direction);

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
          TextDirection direction) =>
      _measuredRow.render(canvas, y, width, fontSize, direction);
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
    String label = '',
    this.value = '',
    this.isBold = false,
    this.scale = 1.0,
    this.isSeparator = false,
    this.icon,
    this.currencySymbol,
  }) : label = inlineBilingualLabel(label);
}
