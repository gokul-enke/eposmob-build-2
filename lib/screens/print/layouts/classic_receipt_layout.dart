import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
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

/// Classic receipt layout - the original/default design.
///
/// This layout maintains the current receipt design with:
/// - Centered header with logo, store name, description
/// - Invoice information below header
/// - Customer details section
/// - Items table with configurable columns
/// - Totals section (supports bilingual for Arabic)
/// - QR code for payment
/// - Barcode and footer
class ClassicReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  @override
  String get layoutId => 'classic';

  @override
  String get displayName => 'Classic';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== CLASSIC LAYOUT: IMAGE-BASED THERMAL PRINTING ====");

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
      final textDirection = isEnglish ? TextDirection.ltr : TextDirection.rtl;
      debugPrint(
          "Language: ${isEnglish ? 'English' : 'Arabic'} ($textDirection)");

      // Setup print parameters
      final double printWidth = params.printWidth;
      final double baseFontSize = params.baseFontSize;

      // Build receipt rows
      List<ReceiptRow> part1Rows = [];
      List<ReceiptRow> part2Rows = [];

      // Add Logo at the top if enabled
      if (billDocumentConfig.showLogo == 1) {
        debugPrint("[LOGO_DEBUG] showLogo == 1, attempting to load logo");
        try {
          ui.Image? logo;
          if (billDocumentConfig.logo != null &&
              billDocumentConfig.logo.toString().isNotEmpty) {
            logo =
                await _fetchNetworkUiImage(billDocumentConfig.logo.toString());
          }

          if (logo != null) {
            debugPrint(
                "[LOGO_DEBUG] Logo loaded successfully: ${logo.width}x${logo.height}");
            part1Rows.add(ImageRow(logo, height: printWidth * 0.22));
            part1Rows.add(SpacingRow(6));
          }
        } catch (e) {
          debugPrint("[LOGO_DEBUG] Error loading logo: $e");
        }
      }

      // ========== HEADER SECTION ==========
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish);

      // ========== CART ITEMS SECTION ==========
      if (!params.isReturnOnly) {
        _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);
      }

      // ========== TOTALS SECTION ==========
      if (!params.isReturnOnly) {
        _buildTotalsSection(
            part1Rows, params, displayConfig, isEnglish, appSettings);
      }

      // ========== RETURN ITEMS SECTION ==========
      if (params.orderReturns != null &&
          params.orderReturns!.returnItems != null &&
          params.orderReturns!.returnItems!.isNotEmpty) {
        _buildReturnSection(
            part1Rows, params, displayConfig, isEnglish, appSettings);
        if (!params.isReturnOnly) {
          _buildFinalSummarySection(
              part1Rows, params, displayConfig, isEnglish, appSettings);
        }
      }

      // ========== FOOTER SECTION (Part 2) ==========
      _buildFooterSection(part2Rows, params, displayConfig, isEnglish, context);

      // ========== RENDER IMAGES ==========
      debugPrint("Rendering receipt images...");

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

      // Print images
      bytes += generator.image(imagePart1);
      bytes += generator.image(imagePart2);

      // Print native barcode
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

      // Feed and Cut
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
      debugPrint("ERROR in Classic Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: "Error printing: ${e.toString()}");
      }
      rethrow;
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("===== END CLASSIC LAYOUT PRINTING =====");
    }
  }

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) async {
    // For now, return an empty document - PDF logic will be migrated separately
    // The StandardPrinter will continue to handle PDF generation
    // until we fully migrate the PDF logic here
    debugPrint(
        "[ClassicReceiptLayout] buildPdf called - delegating to StandardPrinter");
    return pw.Document();
  }

  // ==================== PRIVATE HELPER METHODS ====================

  void _buildHeaderSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    dynamic appSettings,
  ) {
    final billDocumentConfig = params.billDocumentConfig;
    final isEnglish = params.isEnglish;

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

    // Store Name - priority: document config value > logged-in store name > default
    if (displayConfig?['showStoreName']?.visible == true) {
      final storeName = _getDisplayValue(
        displayConfig?['showStoreName']?.value,
        params.storeName,
        'STORE NAME',
      );

      double storeNameScale = 1.6;
      if (storeName.length > 20) {
        storeNameScale = 1.3;
      } else if (storeName.length > 14) {
        storeNameScale = 1.5;
      }

      rows.add(TextRow(storeName.isNotEmpty ? storeName.trim() : 'STORE NAME',
          isBold: true,
          scale: storeNameScale,
          verticalPadding: 4,
          verticalOffset: 1));
    }

    // Description - use displayConfig value only
    if (displayConfig?['showDescription']?.visible == true) {
      final description = _getDisplayValue(
        displayConfig?['showDescription']?.value,
        null,
        '',
      );
      if (description.isNotEmpty) {
        rows.add(TextRow(description, isBold: true, scale: 1.1));
      }
    }

    // Store Address
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final label = displayConfig?['showStoreAddress']?.value as String? ?? '';
      final address = params.storeLocation ?? '';
      if (address.isNotEmpty) {
        final storeAddress = label.isNotEmpty ? '$label: $address' : address;
        rows.add(TextRow(storeAddress, scale: 0.9, isBold: true));
      }
    }

    // FSSAI Info
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
      if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.9, isBold: true));
      }
    }

    // Extra Heading 1 (e.g., CR NO)
    if (displayConfig?['showExtraHeading1']?.visible == true) {
      final extraHeading1 =
          displayConfig?['showExtraHeading1']?.value as String?;
      if (extraHeading1 != null && extraHeading1.isNotEmpty) {
        rows.add(TextRow(extraHeading1, scale: 0.9, isBold: true));
      }
    }

    // Extra Heading 2 (e.g., VAT NO)
    if (displayConfig?['showExtraHeading2']?.visible == true) {
      final extraHeading2 =
          displayConfig?['showExtraHeading2']?.value as String?;
      if (extraHeading2 != null && extraHeading2.isNotEmpty) {
        rows.add(TextRow(extraHeading2, scale: 0.9, isBold: true));
      }
    }

    // Telephone
    if (displayConfig?['showTel']?.visible == true) {
      final label = displayConfig?['showTel']?.value as String? ?? '';
      final phone = params.storePhone?.isNotEmpty == true
          ? params.storePhone!
          : (appSettings?.customerCarePhone ?? '');
      if (phone.isNotEmpty) {
        final telephone = label.isNotEmpty ? '$label: $phone' : phone;
        rows.add(TextRow(telephone, scale: 0.8, isBold: true));
      }
    }

    // Email
    if (displayConfig?['showEmail']?.visible == true) {
      final label = displayConfig?['showEmail']?.value as String? ?? '';
      final emailVal = params.storeEmail?.isNotEmpty == true
          ? params.storeEmail!
          : (appSettings?.customerCareEmail ?? '');
      if (emailVal.isNotEmpty) {
        final email = label.isNotEmpty ? '$label: $emailVal' : emailVal;
        rows.add(TextRow(email, scale: 0.8, isBold: true));
      }
    }

    rows.add(SpacingRow(6));

    // Invoice Title - use displayConfig value, then appSettings.printTitle, then default
    // Invoice title is controlled by display config, separate from document header/subheader.
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle = _getDisplayValue(
        displayConfig?['showInvoiceTitle']?.value,
        appSettings?.printTitle,
        isEnglish ? 'INVOICE' : 'فاتورة',
      );
      rows.add(TextRow(invoiceTitle.isNotEmpty ? invoiceTitle : 'INVOICE',
          isBold: true, scale: 1.2));
    }

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
      final invoiceAlign = isEnglish ? TextAlign.left : TextAlign.right;
      final tokenAlign = isEnglish ? TextAlign.right : TextAlign.left;
      final invoiceCol = ReceiptTableColumn(invoiceNumberText,
          weight: 0.58, align: invoiceAlign, isBold: true);
      final tokenCol = ReceiptTableColumn(tokenText,
          weight: 0.38, align: tokenAlign, isBold: true, scale: 1.1);
      final spacerCol =
          ReceiptTableColumn('', weight: 0.04, align: TextAlign.center);

      rows.add(ReceiptTableRow(isEnglish
          ? [invoiceCol, spacerCol, tokenCol]
          : [tokenCol, spacerCol, invoiceCol]));
    } else if (invoiceNumberText != null) {
      rows.add(TextRow(invoiceNumberText, isBold: true));
    } else if (tokenText != null) {
      rows.add(TextRow(tokenText, scale: 1.4, isBold: true));
    }

    rows.add(DividerRow());
  }

  void _buildCustomerSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    // Check if customer section should be shown at all
    final showCustomerSection =
        displayConfig?['showCustomerNameAndPhone']?.visible ?? true;
    if (!showCustomerSection) {
      return;
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

    // Get customer section labels from displayConfig or use defaults
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
      // English: Label: Value format
      if (showCustomerName &&
          params.customerName != null &&
          params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left),
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
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(phoneText, weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (showPayment &&
          params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(addressLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerAddress!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(deliveryLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.deliveryMethod!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerVatLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerVatNumber!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(customerCrLabel,
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerCrNumber!,
              weight: 0.65, align: TextAlign.left),
        ]));
      }
    } else {
      // Arabic: Label on right, Value on left (RTL reading flow)
      if (showCustomerName &&
          params.customerName != null &&
          params.customerName!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerName!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(customerLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
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
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(phoneLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (showPayment &&
          params.paymentMethod != null &&
          params.paymentMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paymentMethod!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(paymentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (showComment &&
          params.orderComment != null &&
          params.orderComment!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.orderComment!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(commentLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (showDeliveryMethod &&
          params.deliveryMethod != null &&
          params.deliveryMethod!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.deliveryMethod!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(deliveryLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (showCustomerVatNumber &&
          params.customerVatNumber != null &&
          params.customerVatNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerVatNumber!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(customerVatLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (showCustomerCrNumber &&
          params.customerCrNumber != null &&
          params.customerCrNumber!.isNotEmpty) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerCrNumber!,
              weight: 0.65, align: TextAlign.left),
          ReceiptTableColumn(customerCrLabel,
              weight: 0.35, align: TextAlign.right, isBold: true),
        ]));
      }
      if (showCustomerAddress &&
          params.customerAddress != null &&
          params.customerAddress!.isNotEmpty) {
        rows.add(TextRow(params.customerAddress!, scale: 0.9));
      }
      rows.add(DividerRow());
    }
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
        rows.add(DividerRow());
      }
    }

    rows.add(SpacingRow(5));

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
      rows.add(SpacingRow(5));
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
      rows.add(SpacingRow(5));
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
      rows.add(DividerRow());
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
      unitName = getPrintUnit(item);
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
      unitName = getPrintUnit(item);
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

  void _buildTotalsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    dynamic appSettings,
  ) {
    // Get currency from appSettings
    final String currency = appSettings?.currency ?? 'INR';
    final String currencyPrefix =
        currency.trim().toUpperCase() == 'INR' ? '\u20B9' : currency.trim();
    String money(num amount) => currencyPrefix.isEmpty
        ? amount.toStringAsFixed(2)
        : '$currencyPrefix ${amount.toStringAsFixed(2)}';
    final bool isDualLanguage =
        (params.billDocumentConfig.language ?? '').toLowerCase() == 'ar';

    double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;
    double total =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double totalMrp = saved + total;
    double totalQuantity = params.totalQuantity;
    double taxAmount = params.totalTax;

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final qtyLabel = _getLabel(displayConfig, 'showQty', resolvedLabels?.qty,
        isEnglish ? "Qty" : "الكمية");

    if (isEnglish) {
      // Summary rows (English)
      final itemsCountLabel =
          _getLabel(displayConfig, 'showItemsCount', null, "Items:");
      final discountLabel =
          _getLabel(displayConfig, 'showDiscount', null, "Discount:");
      final mrpTotalLabel =
          _getLabel(displayConfig, 'showMRPTotal', null, "Total MRP:");
      final netAmountLabel =
          _getLabel(displayConfig, 'showNetAmount', null, "Net Total:");
      final taxLabel =
          _getLabel(displayConfig, 'showTax', resolvedLabels?.tax, "Tax :");
      final quantityCountLabel = _getLabel(
          displayConfig, 'showQuantityCount', null, "$qtyLabel Total:");

      // Check visibility settings
      final showItemsCount = displayConfig?['showItemsCount']?.visible ?? true;
      final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
      final showQuantityCount =
          displayConfig?['showQuantityCount']?.visible ?? true;
      final showTax = displayConfig?['showTax']?.visible ?? true;
      final showMRPTotal = displayConfig?['showSubTotal']?.visible ??
          displayConfig?['showMRPTotal']?.visible ??
          true;
      final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

      // Items count and Discount row
      if (showItemsCount || (showDiscount && discountAmountValue != 0)) {
        List<ReceiptTableColumn> summaryRow = [];

        if (showItemsCount) {
          summaryRow.add(ReceiptTableColumn(itemsCountLabel,
              weight: 0.25, align: TextAlign.left));
          summaryRow.add(ReceiptTableColumn(params.cartItems.length.toString(),
              weight: 0.25, align: TextAlign.left));
        } else {
          summaryRow.add(ReceiptTableColumn("", weight: 0.50));
        }

        summaryRow.add(ReceiptTableColumn(" ", weight: 0.05));

        if (showDiscount && discountAmountValue != 0) {
          summaryRow.add(ReceiptTableColumn(discountLabel,
              weight: 0.25, align: TextAlign.right));
          summaryRow.add(ReceiptTableColumn(money(discountAmountValue),
              weight: 0.20, align: TextAlign.right));
        } else {
          summaryRow.add(ReceiptTableColumn("", weight: 0.45));
        }

        rows.add(ReceiptTableRow(summaryRow));
      }

      // Total Qty and Tax row
      if (showQuantityCount || showTax) {
        List<ReceiptTableColumn> qtyTaxRow = [];

        if (showQuantityCount) {
          qtyTaxRow.add(ReceiptTableColumn(quantityCountLabel,
              weight: 0.25, align: TextAlign.left));
          qtyTaxRow.add(ReceiptTableColumn(
              totalQuantity % 1 == 0
                  ? totalQuantity.toInt().toString()
                  : totalQuantity.toStringAsFixed(2),
              weight: 0.25,
              align: TextAlign.left));
        } else {
          qtyTaxRow.add(ReceiptTableColumn("", weight: 0.50));
        }

        qtyTaxRow.add(ReceiptTableColumn(" ", weight: 0.05));

        if (showTax) {
          qtyTaxRow.add(ReceiptTableColumn(taxLabel,
              weight: 0.25, align: TextAlign.right));
          qtyTaxRow.add(ReceiptTableColumn(money(taxAmount),
              weight: 0.20, align: TextAlign.right));
        } else {
          qtyTaxRow.add(ReceiptTableColumn("", weight: 0.45));
        }

        rows.add(ReceiptTableRow(qtyTaxRow));
      }

      if (showMRPTotal) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(mrpTotalLabel,
              weight: 0.25, align: TextAlign.left),
          ReceiptTableColumn(money(totalMrp),
              weight: 0.25, align: TextAlign.left),
          ReceiptTableColumn(" ", weight: 0.50),
        ]));
      }

      rows.add(SpacingRow(5));

      // Net Total
      if (showNetAmount) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(netAmountLabel,
              weight: 0.5, align: TextAlign.center, isBold: true),
          ReceiptTableColumn(money(total),
              weight: 0.5, align: TextAlign.center, isBold: true),
        ]));
      }
    } else {
      // Arabic/Bilingual totals
      double totalDiscountAmount = discountAmountValue;

      // Calculate subtotal
      double subtotal;
      if (params.netExcTax != null) {
        subtotal =
            double.tryParse(params.netExcTax!) ?? (total + totalDiscountAmount);
      } else {
        subtotal = total + totalDiscountAmount;
      }

      final subtotalLabel =
          _getLabel(displayConfig, 'showSubTotal', null, "SUBTOTAL المجموع");
      final discountLabel =
          _getLabel(displayConfig, 'showDiscount', null, "DISCOUNTS الخصم");
      final taxLabelArabic = _getLabel(
          displayConfig, 'showTax', resolvedLabels?.tax, "TAX الضريبة");
      final netTotalLabel = _getLabel(
          displayConfig, 'showNetAmount', null, "GRAND TOTAL المبلغ الاجمالي");

      // Check visibility settings
      final showMRPTotal = displayConfig?['showSubTotal']?.visible ??
          displayConfig?['showMRPTotal']?.visible ??
          true;
      final showDiscount = displayConfig?['showDiscount']?.visible ?? true;
      final showTax = displayConfig?['showTax']?.visible ?? true;
      final showNetAmount = displayConfig?['showNetAmount']?.visible ?? true;

      // Subtotal
      if (showMRPTotal) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(money(subtotal),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn(subtotalLabel,
              weight: 0.65, align: TextAlign.right),
        ]));
      }

      // Discounts
      if (showDiscount && totalDiscountAmount != 0) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(money(totalDiscountAmount),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn(discountLabel,
              weight: 0.65, align: TextAlign.right),
        ]));
      }

      // Tax
      if (showTax) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(money(taxAmount),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn(taxLabelArabic,
              weight: 0.65, align: TextAlign.right),
        ]));
      }

      rows.add(SpacingRow(5));

      // Net Total
      if (showNetAmount) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(money(total),
              weight: 0.35, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(netTotalLabel,
              weight: 0.65, align: TextAlign.right, isBold: true),
        ]));
      }
    }

    // Payment Breakthrough (Multi-payment / JSON payload / single payment)
    final bool showPaymentBreaked =
        displayConfig?['showPaymentBreaked']?.visible ?? true;
    if (params.paidAmount != null && showPaymentBreaked) {
      void addPaymentRow(String label, double amt) {
        if (isEnglish) {
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(label, weight: 0.5, align: TextAlign.left),
            ReceiptTableColumn(money(amt), weight: 0.5, align: TextAlign.right),
          ]));
        } else {
          rows.add(ReceiptTableRow([
            ReceiptTableColumn(money(amt), weight: 0.5, align: TextAlign.left),
            ReceiptTableColumn(label, weight: 0.5, align: TextAlign.right),
          ]));
        }
      }

      String paymentLabelFor(String method) {
        if (method == 'CASH') return isEnglish ? "Cash" : "نقدي";
        if (method == 'CARD') return isEnglish ? "Card" : "بطاقة";
        if (method == 'UPI') return "UPI";
        return method;
      }

      bool isMultiPayment = false;

      // Preferred: structured payment breakdown map
      if (params.paymentBreakdown != null &&
          params.paymentBreakdown!.isNotEmpty) {
        isMultiPayment = true;
        rows.add(SpacingRow(5));
        params.paymentBreakdown!.forEach((method, amount) {
          double amt = double.tryParse(amount.toString()) ?? 0.0;
          if (amt > 0) {
            addPaymentRow(paymentLabelFor(method), amt);
          }
        });
      }
      // Fallback: paymentMethod carrying a JSON multi-payment payload
      else if (params.paymentMethod != null &&
          params.paymentMethod!.startsWith('{')) {
        try {
          final Map<String, dynamic> paymentData =
              json.decode(params.paymentMethod!);
          if (paymentData['isMultiPayment'] == true) {
            isMultiPayment = true;
            final Map<String, dynamic> amounts = paymentData['amounts'];
            rows.add(SpacingRow(5));
            amounts.forEach((method, amount) {
              double amt = double.tryParse(amount.toString()) ?? 0.0;
              if (amt > 0) {
                addPaymentRow(paymentLabelFor(method), amt);
              }
            });
          }
        } catch (e) {
          debugPrint("Error parsing multi-payment: $e");
        }
      }

      // Single payment fallback
      if (!isMultiPayment) {
        String label = isEnglish ? "Cash" : "نقدي";
        if (params.paymentMethod != null &&
            params.paymentMethod!.isNotEmpty &&
            params.paymentMethod != 'CASH') {
          label = params.paymentMethod!;
        }
        rows.add(SpacingRow(5));
        addPaymentRow(label, params.paidAmount!);
      }
    }

    // You Saved
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      final savedLabel = _getLabel(displayConfig, 'showSaved', null,
          isEnglish ? "You Saved:" : "لقد وفرت:");
      rows.add(SpacingRow(5));
      rows.add(TextRow(
        "$savedLabel ${money(saved)}",
        isBold: true,
        scale: 0.9,
      ));
    }

    rows.add(DividerRow());

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(5));

      if (isDualLanguage) {
        final arabicText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'ar');
        final englishText = AmountHelper()
            .convertNumberToWords(total, currency: currency, language: 'en');

        rows.add(TextRow('$arabicText فقط.', scale: 0.9, isBold: true));
        rows.add(TextRow('$englishText Only.',
            scale: 0.9,
            isBold: true,
            textDirectionOverride: TextDirection.ltr));
      } else {
        final language =
            (params.billDocumentConfig.language ?? 'en').toLowerCase();
        final amountText = AmountHelper().convertNumberToWords(total,
            currency: currency, language: language);
        final suffix = language == 'ar' ? ' فقط.' : ' Only.';
        rows.add(TextRow('$amountText$suffix', scale: 0.9, isBold: true));
      }
      rows.add(DividerRow());
    }

    // Customer Balance
    _buildCustomerBalance(rows, params, displayConfig, isEnglish);
  }

  void _buildCustomerBalance(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    // Check if customer balance section should be shown at all
    final showCustomerBalance =
        displayConfig?['showCustomerBalance']?.visible ?? true;
    if (!showCustomerBalance) {
      return;
    }

    // Hide balance information for default/walk-in customers
    if (params.isDefaultCustomer) {
      return;
    }

    if (params.customerOldBalance == null &&
        params.customerCurrentBalance == null &&
        params.paidAmount == null) {
      return;
    }

    // Check visibility for each balance field
    final showPrevBalance =
        displayConfig?['showCustomerPrevBalance']?.visible ?? true;
    final showPaidAmount =
        displayConfig?['showCustomerPaidAmount']?.visible ?? true;
    final showCurrentBalance =
        displayConfig?['showCustomerCurrentBalance']?.visible ?? true;

    // Get labels from displayConfig
    final prevBalanceLabel = _getLabel(displayConfig, 'showCustomerPrevBalance',
        null, isEnglish ? "Old Balanceance:" : "الرصيد السابق:");
    final paidAmountLabel = _getLabel(displayConfig, 'showCustomerPaidAmount',
        null, isEnglish ? "Paid Amount:" : "المدفوع:");
    final currentBalanceLabel = _getLabel(
        displayConfig,
        'showCustomerCurrentBalance',
        null,
        isEnglish ? "Current Balance:" : "الرصيد الحالي:");

    bool hasVisibleRows = false;

    if (isEnglish) {
      if (showPrevBalance && params.customerOldBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(prevBalanceLabel,
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showPaidAmount && params.paidAmount != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(paidAmountLabel,
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showCurrentBalance && params.customerCurrentBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(currentBalanceLabel,
              weight: 0.5, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.right, isBold: true),
        ]));
      }
    } else {
      // Arabic balance display
      if (showPrevBalance && params.customerOldBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(prevBalanceLabel,
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showPaidAmount && params.paidAmount != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.left),
          ReceiptTableColumn(paidAmountLabel,
              weight: 0.5, align: TextAlign.right),
        ]));
      }
      if (showCurrentBalance && params.customerCurrentBalance != null) {
        hasVisibleRows = true;
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
              weight: 0.5, align: TextAlign.left, isBold: true),
          ReceiptTableColumn(currentBalanceLabel,
              weight: 0.5, align: TextAlign.right, isBold: true),
        ]));
      }
    }

    if (hasVisibleRows) {
      rows.add(SpacingRow(10));
    }
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    // For now, use image-based printing for all cases
    // Native ESC/POS text mode can be implemented later for faster printing
    await printThermal(params);
  }

  void _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    BuildContext context,
  ) {
    rows.add(SpacingRow(10));

    // QR Code - ZATCA QR takes priority if credentials are available
    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';
      String qrMessage = '';

      // Check if ZATCA credentials are available
      if (params.hasZatcaCredentials) {
        // Generate ZATCA Phase 1 compliant QR code
        final zatcaHelper = ZatcaQrHelper();
        final zatcaQrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate, // Pass true UTC ISO string
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );

        if (zatcaQrData.isNotEmpty) {
          qrData = zatcaQrData;
          qrMessage = displayConfig?['showQRCode']?.value as String? ??
              (isEnglish ? 'Tax Invoice QR' : 'رمز الفاتورة الضريبية');
        }
      }

      // Fallback to payment gateway QR if no ZATCA credentials
      if (qrData.isEmpty) {
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
        rows.add(TextRow(qrMessage, isBold: true, scale: 0.9));
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

    rows.add(SpacingRow(15));

    // Date and Time - check visibility
    final showDate = displayConfig?['showDate']?.visible ?? true;
    if (showDate) {
      String formattedDate = params.isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
          : DateHelper.formatISODate(params.orderDate);
      String formattedTime = params.isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
          : DateHelper.formatISOTimeOnlyToIST(params.orderDate);

      final resolvedLabels = params.billDocumentConfig.resolvedLabels;
      final dateLabel = _getLabel(displayConfig, 'showDate',
          resolvedLabels?.date, isEnglish ? "Date:" : "التاريخ:");

      if (isEnglish) {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(dateLabel, weight: 0.4, align: TextAlign.left),
          ReceiptTableColumn("$formattedDate $formattedTime",
              weight: 0.6, align: TextAlign.right),
        ]));
      } else {
        rows.add(ReceiptTableRow([
          ReceiptTableColumn("$formattedDate $formattedTime",
              weight: 0.6, align: TextAlign.left),
          ReceiptTableColumn(dateLabel, weight: 0.4, align: TextAlign.right),
        ]));
      }

      rows.add(SpacingRow(5));
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

      rows.add(SpacingRow(5));
      if (showFooterInvoice) {
        rows.add(DividerRow());
        rows.add(SpacingRow(5));
        rows.add(TextRow('$invoicePrefix $strippedNumber',
            scale: 0.85, isBold: true));
      } else {
        rows.add(TextRow('$invoicePrefix $strippedNumber', scale: 0.85));
      }
    }

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      String? terms = displayConfig?['showTermsConditions']?.value as String?;
      if (terms == null || terms.trim().isEmpty) {
        terms = params.billDocumentConfig.terms;
      }
      if (terms != null && terms.trim().isNotEmpty) {
        rows.add(TextRow(terms.trim(), scale: 0.8));
      }
    }

    rows.add(SpacingRow(5));

    // Thank You Message
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final String defaultThankYou =
          isEnglish ? 'Thank You... Visit Again' : 'شكراً لزيارتكم!';
      final message = (displayConfig?['showThankYouMessage']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showThankYouMessage']!.value as String
          : (params.billDocumentConfig.footer?.isNotEmpty == true
              ? params.billDocumentConfig.footer!
              : defaultThankYou);
      rows.add(TextRow(message, isBold: true));
    }

    rows.add(SpacingRow(20));
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
    return PrintLogoLoader.loadUiLogo(url, tag: '[classic_receipt_layout]');
  }

  // ==================== RETURN ITEMS SECTION ====================

  void _buildReturnSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    dynamic appSettings,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty)
      return;

    final resolvedLabels = params.billDocumentConfig.resolvedLabels;
    final bool is58mm = params.is58mm;
    final double scale = is58mm ? 0.85 : 1.0;

    rows.add(SpacingRow(14.0));
    rows.add(DividerRow());
    rows.add(SpacingRow(6.0));
    rows.add(TextRow('RETURNS', isBold: true, scale: 1.1));
    rows.add(SpacingRow(6.0));

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
      rows.add(DividerRow());
    }

    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final int itemQty = returnItem.quantity ?? 0;
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
      if (i < orderReturns.returnItems!.length - 1) rows.add(DividerRow());
    }

    rows.add(SpacingRow(6.0));

    if (displayConfig?['showReturnItemsCount']?.visible == true) {
      final countLabel = isEnglish ? 'Return Items:' : 'عناصر المرتجع:';
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
    final double returnRateTotal =
        double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;

    if (showReturnTotalAmt) {
      final label = _getLabel(displayConfig, 'showReturnTotalAmount', null,
          isEnglish ? 'Return Total:' : 'إجمالي المرتجع:');
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(label,
            weight: 0.6, align: TextAlign.left, isBold: true, scale: scale),
        ReceiptTableColumn(returnRateTotal.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, isBold: true, scale: scale),
      ]));
    }
    if (showReturnNetAmt) {
      final label = _getLabel(displayConfig, 'showReturnNetAmount', null,
          isEnglish ? 'Return Net Amount:' : 'صافي مبلغ الإرجاع:');
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(label,
            weight: 0.6, align: TextAlign.left, isBold: true, scale: scale),
        ReceiptTableColumn(returnRateTotal.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, isBold: true, scale: scale),
      ]));
    }
  }

  // ==================== FINAL SUMMARY SECTION (after returns) ====================

  void _buildFinalSummarySection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    dynamic appSettings,
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

    final String currency = appSettings?.currency ?? 'INR';

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

    rows.add(SpacingRow(14.0));
    rows.add(DividerRow());
    rows.add(SpacingRow(6.0));

    if (showFinalPurchase) {
      final label = _getLabel(displayConfig, 'showFinalPurchase', null,
          isEnglish ? 'ORDER TOTAL' : 'إجمالي الطلب');
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(label,
            weight: 0.6, align: TextAlign.left, isBold: true),
        ReceiptTableColumn(orderTotal.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, isBold: true),
      ]));
    }
    if (showFinalReturn) {
      final label = _getLabel(displayConfig, 'showFinalReturn', null,
          isEnglish ? 'RETURN TOTAL' : 'إجمالي المرتجع');
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(label,
            weight: 0.6, align: TextAlign.left, isBold: true),
        ReceiptTableColumn(returnTotal.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, isBold: true),
      ]));
    }
    if (showFinalNetAmount) {
      rows.add(DividerRow());
      final label = _getLabel(displayConfig, 'showFinalNetAmount', null,
          isEnglish ? 'FINAL TOTAL' : 'المبلغ النهائي');
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(label,
            weight: 0.6, align: TextAlign.left, isBold: true, scale: 1.1),
        ReceiptTableColumn(finalTotal.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.right, isBold: true, scale: 1.1),
      ]));
    }

    if (showFinalAmountInWords) {
      rows.add(SpacingRow(6.0));
      final language =
          (params.billDocumentConfig.language ?? 'en').toLowerCase();
      final amountText = AmountHelper().convertNumberToWords(finalTotal,
          currency: currency, language: language);
      final suffix = language == 'ar' ? ' فقط.' : ' Only.';
      rows.add(TextRow('$amountText$suffix', scale: 0.85, isBold: true));
    }
    rows.add(SpacingRow(6.0));
  }
}
