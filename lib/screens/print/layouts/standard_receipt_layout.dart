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
import 'receipt_configuration_contract.dart';
import 'receipt_layout_params.dart';
import 'receipt_pdf_builder.dart';
import 'receipt_sections.dart';
import 'common/return_metadata_rows.dart';
import 'common/layout_rows.dart';
import '../thermal/printer_utils.dart';
import '../thermal/debug_image_saver.dart';
import '../thermal/thermal_paper_profile.dart';
import '../logo_loader.dart';

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
  ReceiptLanguageMode _languageMode = ReceiptLanguageMode.english;

  // Standard theme spacing constants
  static const double _sectionGap = 14.0;
  static const double _itemGap = 6.0;
  static const double _headerGap = 8.0;

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
    _languageMode = params.receiptLanguageMode;

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
            '[STANDARD] 112mm selected: using ${paperProfile.rasterWidthPx}px raster images; ESC/POS package profile is used only for feed/barcode/cut commands.');
      }
      final generator = paperProfile.createGenerator(profile);
      List<int> bytes = [];

      bytes += generator.image(imagePart1);
      bytes += generator.image(imagePart2);

      // Native barcode
      String cleanOrderNumber = params.printableOrderNumberComponent
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
      if (cleanOrderNumber.isNotEmpty) {
        try {
          List<String> code39Data = cleanOrderNumber.split("");
          bytes += generator.barcode(
            Barcode.code39(code39Data),
            width: params.is58mm ? 1 : 2,
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
      debugPrint("ERROR in Standard Layout Print: $e");
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
      debugPrint("===== END STANDARD LAYOUT PRINTING =====");
    }
  }

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) async {
    debugPrint(
        "[StandardReceiptLayout] buildPdf - delegating to StandardPrinter");
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
    if (displayConfig?['showStoreName']?.visible == true) {
      // Shared registry: typed text, else the active store's name.
      final storeNameText = params.fieldLabel('showStoreName');

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
          verticalPadding: 4,
          verticalOffset: 1));
    }

    // Description/Subheader - Arabic subtitle style
    if (displayConfig?['showDescription']?.visible == true) {
      final descriptionText = params.fieldLabel('showDescription');

      if (descriptionText.isNotEmpty) {
        rows.add(SpacingRow(2));
        rows.add(TextRow(descriptionText.trim(),
            scale: 1.0, isBold: true, verticalPadding: 4, verticalOffset: 1));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // The option supplies visibility/label; the active store supplies value.
    final addressText = params.storeAddressText();
    if (addressText.isNotEmpty) {
      rows.add(TextRow(addressText, scale: 0.85, isBold: true));
    }

    // Invoice Title (Moved above Tax/Fssai Info)
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitleText = params.invoiceTitleText;

      if (invoiceTitleText.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(
            TextRow(invoiceTitleText.toUpperCase(), isBold: true, scale: 1.1));
        rows.add(SpacingRow(2));
      }
    }

    // Extra Heading 1
    if (displayConfig?['showExtraHeading1']?.visible == true) {
      final extraHeading1Text = params.labelFor(
        'showExtraHeading1',
        englishFallback: '',
        arabicFallback: '',
      );

      if (extraHeading1Text.isNotEmpty) {
        rows.add(SpacingRow(2));
        rows.add(TextRow(extraHeading1Text, scale: 0.95, isBold: true));
      }
    }

    // Extra Heading 2
    if (displayConfig?['showExtraHeading2']?.visible == true) {
      final extraHeading2Text = params.labelFor(
        'showExtraHeading2',
        englishFallback: '',
        arabicFallback: '',
      );

      if (extraHeading2Text.isNotEmpty) {
        rows.add(SpacingRow(2));
        rows.add(TextRow(extraHeading2Text, scale: 0.95, isBold: true));
      }
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfoText = params.labelFor(
        'showFssaiInfo',
        englishFallback: '',
        arabicFallback: '',
      );

      if (fssaiInfoText.isNotEmpty) {
        rows.add(TextRow(fssaiInfoText, scale: 0.85, isBold: true));
      }
    }

    // Store tax registration details
    final storeVatText = params.storeTaxText('showVatNumber');
    if (storeVatText.isNotEmpty) {
      rows.add(TextRow(storeVatText, scale: 0.85));
    }

    final storeCrText = params.storeTaxText('showCRNumber');
    if (storeCrText.isNotEmpty) {
      rows.add(TextRow(storeCrText, scale: 0.85));
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final telephoneText =
          params.storeContactText('showTel', inlineBilingual: false);
      if (telephoneText.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(telephoneText, scale: 0.9, isBold: true));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final emailText =
          params.storeContactText('showEmail', inlineBilingual: false);
      if (emailText.isNotEmpty) {
        rows.add(TextRow(emailText, scale: 0.9, isBold: true));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(StandardThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Invoice/Token Number
    final bool showInvoiceNumber =
        displayConfig?['showInvoiceNumber']?.visible == true;
    final bool showTokenNumber =
        params.isVisible('showTokenNumber') && params.tokenText.isNotEmpty;

    String? invoiceNumberText;
    if (showInvoiceNumber) {
      // Shared contract: number_prefix + printable order-number component
      // ("ORD-000430" -> "430"; stable offline references stay whole).
      invoiceNumberText = params.invoiceNumberText;
    }

    String? tokenText;
    if (showTokenNumber) {
      // Shared contract: `<label>: 286`; symbol prefixes stay attached.
      tokenText = params.tokenText;
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

    // Date and Time - moved to top section
    if (params.isVisible('showDate')) {
      final dateLabel = inlineBilingualLabel(
          withoutTrailingLabelColons(params.fieldLabel('showDate')));
      // Isolate the date/time as LTR so an RTL receipt does not reorder it to
      // "AM 09:40 23-09-2026".
      final dateTimeText = '\u2066${params.orderDateTimeText}\u2069';
      rows.add(SpacingRow(3));
      if (dateLabel.isNotEmpty) {
        rows.add(TextRow("$dateLabel: $dateTimeText", scale: 0.85));
      } else {
        rows.add(TextRow(dateTimeText, scale: 0.85));
      }
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
    if (!params.isVisible('showCustomerNameAndPhone')) {
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

    final bool showCustomerName = params.isVisible('showCustomerName');
    final bool showCustomerPhone = params.isVisible('showCustomerPhone');
    // Quotations carry no payment; the shared summary is empty when unpaid.
    final bool showPayment = !params.isQuotation &&
        params.isVisible(paymentConfigKey) &&
        params.paymentMethodSummary.isNotEmpty;
    // Shared phone line: primary + alternate, both masked when
    // 'showCustomerPhoneMasked' is on.
    final String phoneText = params.customerPhoneLineText;
    final bool showCustomerAddress = params.isVisible('showCustomerAddress');
    final bool showComment = params.isVisible(commentConfigKey);
    final bool showDeliveryMethod = params.isVisible('showDeliveryMethod');
    final bool showDeliveryPhone = params.isVisible('showDeliveryPhone');
    final bool showCustomerVatNumber =
        displayConfig?['showCustomerVatNumber']?.visible == true;
    final bool showCustomerCrNumber =
        displayConfig?['showCustomerCrNumber']?.visible == true;

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
        (showDeliveryPhone &&
            params.deliveryPhone != null &&
            params.deliveryPhone!.isNotEmpty) ||
        (showCustomerVatNumber &&
            params.customerVatNumber != null &&
            params.customerVatNumber!.isNotEmpty) ||
        (showCustomerCrNumber &&
            params.customerCrNumber != null &&
            params.customerCrNumber!.isNotEmpty);

    if (!hasVisibleCustomerData) {
      return;
    }

    String customerSectionLabel(String label) {
      final labelWithoutColons = withoutTrailingLabelColons(label);
      return params.isBilingual
          ? inlineBilingualLabel(labelWithoutColons)
          : labelWithoutColons;
    }

    final customerLabel = customerSectionLabel(_getLabel(displayConfig,
        'showCustomerName', null, isEnglish ? "Customer:" : "العميل:"));
    final phoneLabel = customerSectionLabel(_getLabel(displayConfig,
        'showCustomerPhone', null, isEnglish ? "Phone:" : "الهاتف:"));
    final paymentLabel = customerSectionLabel(_getLabel(displayConfig,
        paymentConfigKey, null, isEnglish ? "Payment:" : "الدفع:"));
    final addressLabel = customerSectionLabel(_getLabel(displayConfig,
        'showCustomerAddress', null, isEnglish ? "Address:" : "العنوان:"));
    final commentLabel = customerSectionLabel(_getLabel(displayConfig,
        commentConfigKey, null, isEnglish ? "Comment:" : "تعليق:"));
    final deliveryLabel = customerSectionLabel(_getLabel(displayConfig,
        'showDeliveryMethod', null, isEnglish ? "Delivery:" : "التوصيل:"));
    final deliveryPhoneLabel = customerSectionLabel(params.labelFor(
      'showDeliveryPhone',
      englishFallback: 'Delivery Phone:',
      arabicFallback: 'هاتف التوصيل:',
    ));
    final customerVatLabel = customerSectionLabel(_getLabel(
        displayConfig,
        'showCustomerVatNumber',
        null,
        isEnglish ? "Customer VAT:" : "الرقم الضريبي للعميل:"));
    final customerCrLabel = customerSectionLabel(_getLabel(
        displayConfig,
        'showCustomerCrNumber',
        null,
        isEnglish ? "Customer CR:" : "السجل التجاري للعميل:"));

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

      if (showCustomerPhone && phoneText.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(phoneLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(phoneText,
              weight: 0.65, align: TextAlign.left, scale: scale),
        ]));
      }

      if (showPayment) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.paymentMethodSummary,
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
      if (showDeliveryPhone &&
          params.deliveryPhone != null &&
          params.deliveryPhone!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(deliveryPhoneLabel,
              weight: 0.35, align: TextAlign.left, isBold: true, scale: scale),
          ReceiptTableColumn(params.deliveryPhone!,
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
          params.deliveryPhone != null &&
          params.deliveryPhone!.isNotEmpty) {
        rows.add(customerInfoRow(params.deliveryPhone!, deliveryPhoneLabel));
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
    final bool isDualLanguage = params.isBilingual;

    // Shared item-header text (same as the A4/A5 PDFs): the typed label for
    // this language, else the built-in text of this language; a bilingual
    // header is the Arabic line plus the English line only when typed.
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
        params.itemNameLines(params.cartItems[i]),
      );
      if (params.isVisible('showWarranty') &&
          _itemWarrantyEnabled(
              params.cartItems[i], params.isFromLocalStorage)) {
        rows.add(TextRow(
          params.labelFor(
            'showWarranty',
            englishFallback: 'Warranty',
            arabicFallback: 'الضمان',
          ),
          scale: 0.8,
          isBold: true,
        ));
      }
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
      rows.add(MultiLineReceiptTableRow(headerCols));
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
    List<String> nameLines,
  ) {
    // Shared item name (variant attributes included): Arabic above English
    // when the document prints two lines.
    final String productNameArabic = nameLines.length > 1 ? nameLines[0] : '';
    final String productName = nameLines.isEmpty ? '' : nameLines.last;
    String mrp = '';
    String quantity = '';
    String unitPrice = '';
    String unitPriceExTax = '';
    String unitName = '';
    String totalPrice = '';
    String itemTaxAmount = '';

    if (isFromLocalStorage || item is Map) {
      mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      quantity = ReceiptSections.formatQuantity(
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0);
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
      mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2);
      quantity = ReceiptSections.formatQuantity(
          double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0);
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
    final String? currencySymbol = currency.trim().toUpperCase() == 'INR'
        ? '\u20B9'
        : _currencyCodeText(currency, sarSymbol);
    final ui.Image? currencyIcon = _currencyIcon(currency, sarSymbol);

    // Paper size aware scaling
    final bool is58mm = params.is58mm;

    double total =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double taxAmount = params.totalTax;

    // Taxable amount shared by every template: the API net excluding tax,
    // else the item lines' totals minus their tax.
    final double subtotal = params.subtotalExcTax;

    // Visibility settings
    final showSubTotal = params.isVisible('showSubTotal');
    final showMRPTotal = params.isVisible('showMRPTotal');
    final showDiscount = params.isVisible('showDiscount');
    final showTax = params.isVisible('showTax');
    final showNetAmount = params.isVisible('showNetAmount');

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
        "  showSubTotal: $showSubTotal; showMRPTotal: $showMRPTotal");
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

    // Prepare boxed items
    List<StandardBoxedLineItem> boxedItems = [];

    // 1. Subtotal
    if (showSubTotal) {
      boxedItems.add(StandardBoxedLineItem(
        label: subtotalLabel,
        value: subtotal.toStringAsFixed(2),
        isBold: true,
        scale: 1,
        icon: currencyIcon,
        currencySymbol: currencySymbol,
      ));
    }

    if (showMRPTotal) {
      boxedItems.add(StandardBoxedLineItem(
        label: params.fieldLabel('showMRPTotal'),
        value: params.mrpTotalValue.toStringAsFixed(2),
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
    // Only show if paidAmount is provided (not null) and showPaymentBreaked is true or missing (default true)
    final bool showPaymentBreaked = params.isVisible('showPaymentBreaked');

    // Shared rows: per-method amounts (breakdown map or multi-payment JSON),
    // else the single method with the paid amount, named in the document
    // language (`showCash` label for cash).
    final paymentRows = params.paymentBreakdownRows;
    if (params.paidAmount != null &&
        showPaymentBreaked &&
        paymentRows.isNotEmpty) {
      boxedItems.add(StandardBoxedLineItem(isSeparator: true));
      for (final row in paymentRows) {
        boxedItems.add(StandardBoxedLineItem(
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
    rows.add(StandardBoxedTotalsRow(items: boxedItems));

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(_itemGap));
      for (final line in params.amountInWordsLines(total, currency: currency)) {
        rows.add(TextRow(line, scale: is58mm ? 0.7 : 0.85, isBold: true));
      }
    }

    // Items Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      final itemsCountText = ReceiptConfigurationContract.withoutTrailingColon(
          params.fieldLabel('showItemsCount', inlineBilingual: true));

      if (itemsCountText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow('$itemsCountText: ${params.cartItems.length}',
            scale: is58mm ? 0.75 : 0.85, isBold: true));
      }
    }

    if (displayConfig?['showQuantityCount']?.visible == true) {
      final quantityCountText =
          ReceiptConfigurationContract.withoutTrailingColon(
              params.fieldLabel('showQuantityCount', inlineBilingual: true));

      if (quantityCountText.isNotEmpty) {
        rows.add(SpacingRow(_itemGap));
        rows.add(TextRow(
            '$quantityCountText: ${ReceiptSections.formatQuantity(params.totalQuantity)}',
            scale: is58mm ? 0.75 : 0.85,
            isBold: true));
      }
    }

    // You Saved
    // Shared label: empty unless 'showSaved' is on and something was saved.
    final savedLabel = params.savedLabel;
    if (savedLabel.isNotEmpty) {
      rows.add(SpacingRow(5));
      rows.add(TextRow(
        "$savedLabel: ${params.savedAmountValue.toStringAsFixed(2)}",
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
    rows.add(StandardThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    final prevBalanceLabel = inlineBilingualLabel(_getLabel(
        displayConfig,
        'showCustomerPrevBalance',
        null,
        isEnglish ? "Previous Balance" : "الرصيد السابق"));

    final paidAmountLabel = inlineBilingualLabel(_getLabel(
        displayConfig,
        'showCustomerPaidAmount',
        null,
        isEnglish ? "Paid Amount" : "المبلغ المدفوع"));

    final currentBalanceLabel = inlineBilingualLabel(_getLabel(
        displayConfig,
        'showCustomerCurrentBalance',
        null,
        isEnglish ? "Current Balance" : "الرصيد الحالي"));

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
    if (!params.isVisible('showBankInfo')) return;

    // Shared rows: one per enabled field ('showBankName', 'showAccountName',
    // 'showAccountNumber', 'showIBAN', 'showSwiftCode') that has a value.
    final details = params.bankDetailRows;

    if (details.isEmpty) return;
    rows.add(SpacingRow(_itemGap));
    rows.add(TextRow(
      params.bankDetailsHeading,
      isBold: true,
      scale: 0.9,
    ));
    for (final detail in details) {
      rows.add(TextRow('${detail.$1}: ${detail.$2}', scale: 0.8));
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
    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';
      final qrMessage = params.qrCaption;

      // Check if ZATCA credentials are available for Saudi Arabia e-invoicing
      if (params.hasZatcaCredentials) {
        debugPrint(
            '[StandardLayout] ZATCA credentials found, generating ZATCA QR');

        debugPrint(
            '[StandardLayout] Raw params.orderDate (UTC): ${params.orderDate}');
        // Generate ZATCA Phase 1 compliant QR code
        final zatcaHelper = ZatcaQrHelper();
        debugPrint(
            '[StandardLayout] Passing UTC ISO date directly to ZATCA helper: ${params.orderDate}');
        qrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate, // Pass true UTC ISO string
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );

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
                'upi://pay?pa=$qrData&am=${params.netAmountValue.toStringAsFixed(2)}&tn=${params.orderNumber}&cu=INR';
          }
        }
      }

      // Display QR code if data is available
      if (qrData.isNotEmpty) {
        rows.add(TextRow(qrMessage, scale: 0.9));
        rows.add(SpacingRow(5));
        rows.add(QrRow(qrData, size: 220));
      }
    }

    // VAT footer is independent of QR generation.
    // Shared 'showVATFooter' line; empty when hidden or without a VAT number.
    final vatFooterText = params.vatFooterText;
    if (vatFooterText.isNotEmpty) {
      rows.add(SpacingRow(5));
      rows.add(TextRow(vatFooterText, scale: 0.8));
    }

    rows.add(SpacingRow(_headerGap));

    // Order Number Display (Footer only)
    final bool showFooterInvoice =
        displayConfig?['showOrderNumberInFooter']?.visible == true;

    if (showFooterInvoice) {
      // Shared "<showOrderNumberInFooter label> 1149" line.
      rows.add(SpacingRow(3));
      rows.add(SpacingRow(5));
      rows.add(StandardThinDividerRow());
      rows.add(SpacingRow(5));
      rows.add(
          TextRow(params.orderNumberFooterText, scale: 0.85, isBold: true));
    }

    rows.add(SpacingRow(_itemGap));

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      final termsText = params.termsText;

      if (termsText.isNotEmpty) {
        rows.add(TextRow(termsText.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message - Elegant
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final messageText = params.thankYouText;

      if (messageText.isNotEmpty) {
        rows.add(TextRow(messageText, isBold: true, scale: 0.95));
      }
    }

    rows.add(SpacingRow(_sectionGap));
  }

  // ==================== UTILITY METHODS ====================

  bool _itemWarrantyEnabled(dynamic item, bool isFromLocalStorage) {
    if (isFromLocalStorage || item is Map) {
      return item['warranty_enabled'] == true ||
          item['warrantyEnabled'] == true ||
          item['warranty_enabled']?.toString() == '1' ||
          item['warrantyEnabled']?.toString() == '1';
    }
    try {
      return item.warrantyEnabled == true;
    } catch (_) {
      return false;
    }
  }

  /// Label with priority: typed text for this language > resolvedLabel >
  /// [defaultLabel]. Callers pass the default of the document's language
  /// (`isEnglish ? English : Arabic`), so a neutral default such as "MRP" or
  /// "#" is kept on Arabic and bilingual receipts too.
  String _getLabel(
    Map<String, DisplayOption>? displayConfig,
    String key,
    String? resolvedLabel,
    String defaultLabel,
  ) {
    final english = _languageMode.isEnglish;
    return ReceiptConfigurationContract.label(
      options: displayConfig,
      key: key,
      mode: _languageMode,
      englishFallback: english ? defaultLabel : '',
      arabicFallback: english ? '' : defaultLabel,
      resolvedArabic: resolvedLabel,
    );
  }

  bool _hasArabic(String value) => RegExp(r'[؀-ۿ]').hasMatch(value);

  /// The riyal symbol image belongs to SAR only.
  ui.Image? _currencyIcon(String currency, ui.Image? sarSymbol) =>
      currency.trim().toUpperCase() == 'SAR' ? sarSymbol : null;

  /// Currency mark printed as text when no symbol image applies: the
  /// currency code (e.g. `AED`), or `SAR` when the riyal image is missing.
  String? _currencyCodeText(String currency, ui.Image? sarSymbol) {
    if (_currencyIcon(currency, sarSymbol) != null) return null;
    final code = currency.trim().toUpperCase();
    return code.isEmpty ? null : code;
  }

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    return PrintLogoLoader.loadUiLogo(url, tag: '[standard_receipt_layout]');
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
    final totalLabel = _getLabel(displayConfig, 'showReturnTotal',
        retLabels?.text('grand_total_header') ?? resolvedLabels?.returnTotal, isEnglish ? 'TOTAL' : 'الإجمالي');

    final bool showSl = displayConfig?['showReturnSLNumber']?.visible == true;
    final bool showParticulars =
        displayConfig?['showReturnParticulars']?.visible == true;
    final bool showMrp = displayConfig?['showReturnMRP']?.visible == true;
    final unitPriceLabel = params.fieldLabel('showUnitPrice');
    final showUnitPrice = params.isVisible('showUnitPrice');
    final showHsn = params.isVisible('showHsnCode');
    final showTaxRate = params.isVisible('showTaxRateColumn');
    final hsnLabel = params.labelFor('showHsnCode', englishFallback: 'HSN',
        arabicFallback: 'رمز الصنف', resolvedArabic: retLabels?.text('hsn'), inlineBilingual: true);
    final taxRateLabel = params.labelFor('showTaxRateColumn', englishFallback: 'Tax Rate',
        arabicFallback: 'نسبة الضريبة', resolvedArabic: retLabels?.text('tax_rate_column'), inlineBilingual: true);

    final bool showQty = displayConfig?['showReturnQty']?.visible == true;
    final bool showRate = displayConfig?['showReturnRate']?.visible == true;
    final bool showTotal = displayConfig?['showReturnTotal']?.visible == true;

    final Map<String, double> baseWeights = {
      if (showSl) 'sl': 0.08,
      if (showParticulars) 'particulars': showSl ? 0.25 : 0.33,
      if (showMrp) 'mrp': 0.15,
      if (showHsn) 'hsn': 0.15,
      if (showTaxRate) 'taxRate': 0.15,
      if (showUnitPrice) 'unitPrice': 0.15,
      if (showQty) 'qty': 0.12,
      if (showRate) 'rate': 0.15,
      if (showTotal) 'total': 0.15,
    };
    final double totalW = baseWeights.values.fold<double>(0, (s, w) => s + w);
    final Map<String, double> weights = totalW > 0
        ? {for (final e in baseWeights.entries) e.key: e.value / totalW}
        : baseWeights;

    // Arabic / bilingual receipts mirror the table (columns right-to-left,
    // right-aligned) exactly like the cart table.
    final TextAlign startAlign = isEnglish ? TextAlign.left : TextAlign.right;
    TextAlign cellAlign(TextAlign englishAlign) =>
        isEnglish ? englishAlign : TextAlign.right;

    if (showSl ||
        showParticulars ||
        showMrp ||
        showHsn ||
        showTaxRate ||
        showUnitPrice ||
        showQty ||
        showRate ||
        showTotal) {
      List<ReceiptTableColumn> headerCols = [];
      if (showSl)
        headerCols.add(ReceiptTableColumn(slLabel,
            weight: weights['sl'] ?? 0,
            align: startAlign,
            isBold: true,
            scale: scale));
      if (showParticulars)
        headerCols.add(ReceiptTableColumn(particularsLabel,
            weight: weights['particulars'] ?? 0,
            align: startAlign,
            isBold: true,
            scale: scale));
      if (showMrp)
        headerCols.add(ReceiptTableColumn(mrpLabel,
            weight: weights['mrp'] ?? 0,
            align: cellAlign(TextAlign.center),
            isBold: true,
            scale: scale));
      if (showHsn)
        headerCols.add(ReceiptTableColumn(hsnLabel,
            weight: weights['hsn'] ?? 0,
            align: cellAlign(TextAlign.center),
            isBold: true,
            scale: scale));
      if (showTaxRate)
        headerCols.add(ReceiptTableColumn(taxRateLabel,
            weight: weights['taxRate'] ?? 0,
            align: cellAlign(TextAlign.center),
            isBold: true,
            scale: scale));
      if (showUnitPrice)
        headerCols.add(ReceiptTableColumn(unitPriceLabel,
            weight: weights['unitPrice'] ?? 0,
            align: cellAlign(TextAlign.center),
            isBold: true,
            scale: scale));
      if (showQty)
        headerCols.add(ReceiptTableColumn(qtyLabel,
            weight: weights['qty'] ?? 0,
            align: cellAlign(TextAlign.center),
            isBold: true,
            scale: scale));
      if (showRate)
        headerCols.add(ReceiptTableColumn(rateLabel,
            weight: weights['rate'] ?? 0,
            align: cellAlign(TextAlign.center),
            isBold: true,
            scale: scale));
      if (showTotal)
        headerCols.add(ReceiptTableColumn(totalLabel,
            weight: weights['total'] ?? 0,
            align: TextAlign.right,
            isBold: true,
            scale: scale));
      final orderedHeaderCols =
          isEnglish ? headerCols : headerCols.reversed.toList();
      rows.add(MultiLineReceiptTableRow(orderedHeaderCols));
      rows.add(StandardThinDividerRow());
    }

    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final double itemQty = (returnItem.quantity ?? 0).toDouble();
      // Shared rate lookup: matching cart line, else the return average.
      final (itemRate, itemMrp) = params.returnItemRate(returnItem);
      var productName = returnItem.productName ?? '';
      final attributes = returnItem.formattedVariantAttributes;
      if (attributes.isNotEmpty && !productName.contains('($attributes)')) {
        productName = '$productName ($attributes)';
      }
      final double itemTotal = itemQty * itemRate;
      if (showParticulars || showSl) {
        final itemText = ReceiptSections.returnItemHeading(
            name: productName, number: i + 1,
            showSerial: showSl, showParticulars: showParticulars);
        final itemIsArabic = _hasArabic(itemText);
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(itemText,
              weight: 1.0,
              align: startAlign,
              textDirection:
                  itemIsArabic ? TextDirection.rtl : TextDirection.ltr,
              scale: scale)
        ]));
      }
      final double dw = (weights['sl'] ?? 0) + (weights['particulars'] ?? 0);
      List<ReceiptTableColumn> priceCols = [];
      if (dw > 0) priceCols.add(ReceiptTableColumn('', weight: dw));
      if (showMrp)
        priceCols.add(ReceiptTableColumn(itemMrp.toStringAsFixed(2),
            weight: weights['mrp'] ?? 0,
            align: cellAlign(TextAlign.center),
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
            ReceiptSections.formatQuantity(itemQty),
            weight: weights['qty'] ?? 0,
            align: cellAlign(TextAlign.center),
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
        rows.add(MultiLineReceiptTableRow(
            isEnglish ? priceCols : priceCols.reversed.toList()));
      if (i < orderReturns.returnItems!.length - 1)
        rows.add(StandardThinDividerRow());
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
        displayConfig?['showReturnTotalAmount']?.visible == true;
    final bool showReturnNetAmt =
        displayConfig?['showReturnNetAmount']?.visible == true;
    final mrpTotalRow = params.returnMrpTotalRow;
    if (showReturnTotalAmt || showReturnNetAmt || mrpTotalRow != null) {
      final String? currencySymbol = currency.trim().toUpperCase() == 'INR'
          ? '₹'
          : _currencyCodeText(currency, sarSymbol);
      final ui.Image? currencyIcon = _currencyIcon(currency, sarSymbol);
      final double returnRateTotal = params.returnTotalValue;
      final List<StandardBoxedLineItem> returnSummaryItems = [];
      if (mrpTotalRow != null) {
        returnSummaryItems.add(StandardBoxedLineItem(
          label: mrpTotalRow.$1,
          value: mrpTotalRow.$2.toStringAsFixed(2),
          isBold: true,
          scale: 1.1,
          icon: currencyIcon,
          currencySymbol: currencySymbol,
        ));
      }
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
    }
    final returnWords = params.returnsWordsLines(currency);
    if (returnWords.isNotEmpty) {
      rows.add(SpacingRow(_itemGap));
      rows.add(TextRow(params.returnsSection!.wordsHeading,
          isBold: true, scale: 0.9));
      for (final line in returnWords) {
        rows.add(TextRow(line, isBold: false, scale: 0.85));
      }
    }
    appendReturnSignatoryRows(rows, params);
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

    final bool showFinalPurchase = params.isVisible('showFinalPurchase');
    final bool showFinalReturn = params.isVisible('showFinalReturn');
    final bool showFinalNetAmount = params.isVisible('showFinalNetAmount');
    final bool showFinalAmountInWords =
        displayConfig?['showFinalAmountInWords']?.visible == true;
    if (!showFinalPurchase && !showFinalReturn && !showFinalNetAmount &&
        !showFinalAmountInWords) return;

    final String? currencySymbol = currency.trim().toUpperCase() == 'INR'
        ? '₹'
        : _currencyCodeText(currency, sarSymbol);
    final ui.Image? currencyIcon = _currencyIcon(currency, sarSymbol);

    final double returnTotal = params.returnTotalValue;

    final double orderTotal = params.netAmountValue;
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
      final language = params.amountInWordsLanguage;
      final amountText = AmountHelper().convertNumberToWords(finalTotal,
          currency: currency, language: language);
      final suffix = language == 'ar' ? ' فقط.' : ' Only.';
      rows.add(TextRow('$amountText$suffix', scale: 0.85, isBold: true));
    }
    rows.add(SpacingRow(_itemGap));
  }
}

/// Thin solid line divider for Standard theme
