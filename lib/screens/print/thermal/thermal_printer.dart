/// Thermal Printing Module
///
/// This module provides thermal receipt printing functionality with support for:
/// - Text-based printing (standard receipts)
/// - Image-based printing (for Arabic/multilingual support)
library thermal_printer;

import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:image/image.dart' as img;

// Import modular components
import 'font_config.dart';
import 'printer_utils.dart';
import 'sections/sections.dart';

// Re-export components for external use
export 'font_config.dart';
export 'printer_utils.dart';
export 'sections/sections.dart';

/// Main class for thermal receipt printing
/// Uses modular section builders for better maintainability
class ThermalPrinter {
  final BuildContext context;
  final ThermalPrinterUtils _printerUtils;
  final PrinterManager printerManager;

  // Section builders
  late final HeaderSectionBuilder _headerBuilder;
  late final CustomerSectionBuilder _customerBuilder;
  late final CartItemsSectionBuilder _cartItemsBuilder;
  late TotalsSection _totalsBuilder;
  late final ReturnsSectionBuilder _returnsBuilder;
  late final TotalSummarySectionBuilder _totalSummaryBuilder;
  late final BalanceSectionBuilder _balanceBuilder;
  late final QrCodeSectionBuilder _qrCodeBuilder;
  late final BarcodeSectionBuilder _barcodeBuilder;
  late final FooterSectionBuilder _footerBuilder;

  ThermalPrinter(this.context)
      : _printerUtils = ThermalPrinterUtils(),
        printerManager = PrinterManager.instance {
    _headerBuilder = HeaderSectionBuilder(context);
    _customerBuilder = CustomerSectionBuilder(utils: _printerUtils);
    _cartItemsBuilder = CartItemsSectionBuilder(utils: _printerUtils);
    _totalsBuilder = TotalsSectionBuilder();
    _returnsBuilder = ReturnsSectionBuilder(utils: _printerUtils);
    _totalSummaryBuilder = TotalSummarySectionBuilder();
    _balanceBuilder = BalanceSectionBuilder();
    _qrCodeBuilder = QrCodeSectionBuilder();
    _barcodeBuilder = BarcodeSectionBuilder();
    _footerBuilder = FooterSectionBuilder();
  }

  // Expose static font config methods for backward compatibility
  static PosTextSize getHeaderSize(bool is58mm) =>
      ThermalFontConfig.getHeaderSize(is58mm);
  static PosTextSize getTotalSize(bool is58mm) =>
      ThermalFontConfig.getTotalSize(is58mm);
  static PosTextSize getSubtitleSize(bool is58mm) =>
      ThermalFontConfig.getSubtitleSize(is58mm);
  static PosTextSize getBodySize(bool is58mm) =>
      ThermalFontConfig.getBodySize(is58mm);
  static PosTextSize getSmallSize(bool is58mm) =>
      ThermalFontConfig.getSmallSize(is58mm);

  // Static constants for backward compatibility
  static const PosFontType defaultFontType = ThermalFontConfig.defaultFontType;
  static const PosTextSize textSizeTitle = ThermalFontConfig.textSizeTitle;
  static const PosTextSize textSizeBig = ThermalFontConfig.textSizeBig;
  static const PosTextSize textSizeMedium = ThermalFontConfig.textSizeMedium;
  static const PosTextSize textSizeSmall = ThermalFontConfig.textSizeSmall;

  /// Main text-based printing method
  Future<void> printReceipt({
    required BluetoothPrinter selectedPrinter,
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    OrderReturns? orderReturns,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double? paidAmount,
  }) async {
    debugPrint("===== THERMAL PRINTING DEBUG =====");

    if (billDocumentConfig == null) {
      debugPrint("ERROR: Bill document configuration not loaded yet.");
      return;
    }

    debugPrint(
        "Printer: ${selectedPrinter.deviceName} (${selectedPrinter.typePrinter})");
    debugPrint("Paper size: $selectedPaperSize");

    final displayConfig = billDocumentConfig.displayConfiguration?.options;
    _printerUtils.debugPrintTemplateSettings(displayConfig);

    // Template selection
    if (billDocumentConfig.language == 'ar' ||
        billDocumentConfig.language == 'bilingual') {
      _totalsBuilder = BilingualTotalsBuilder();
    } else {
      _totalsBuilder = TotalsSectionBuilder();
    }

    try {
      final selectedFontType = await _printerUtils.loadFontType();
      debugPrint(
          "Using font type: ${selectedFontType == PosFontType.fontA ? 'Font A' : 'Font B'}");

      debugPrint("Connecting to printer...");
      await _printerUtils.connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully");

      final profile = await CapabilityProfile.load();

      PaperSize paperSize;
      if (selectedPaperSize == '80mm') {
        paperSize = PaperSize.mm80;
      } else if (selectedPaperSize == '58mm') {
        paperSize = PaperSize.mm58;
      } else {
        paperSize = PaperSize.mm80;
      }

      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // Build receipt using section builders
      debugPrint("Building header...");
      bytes += _headerBuilder.build(generator, displayConfig,
          billDocumentConfig, orderDate, orderNumber, selectedFontType);

      if (customerName != null ||
          customerPhone != null ||
          customerEmail != null) {
        debugPrint("Building customer details...");
        bytes += _customerBuilder.build(generator, customerName, customerPhone,
            customerEmail, customerAddress, selectedFontType);
      }

      debugPrint("Building cart items...");
      bytes += _cartItemsBuilder.build(
          generator,
          cartItems,
          displayConfig,
          isFromLocalStorage,
          selectedPaperSize,
          billDocumentConfig,
          selectedFontType);

      debugPrint("Building total amount...");
      // Calculate total tax
      double totalTax = 0.0;
      for (var item in cartItems) {
        if (isFromLocalStorage) {
          totalTax +=
              double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
        } else {
          totalTax += double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
        }
      }

      final totalsBytes = _totalsBuilder.build(
        generator,
        displayConfig,
        formattedTotal,
        savedTotal,
        discountAmount,
        cartItems.length,
        billDocumentConfig,
        cartItems,
        isFromLocalStorage,
        selectedFontType,
        paperSize,
        customerOldBalance,
        customerCurrentBalance,
        totalTax,
      );
      bytes += totalsBytes;
      // Order Returns section
      if (orderReturns != null &&
          orderReturns.returnItems != null &&
          orderReturns.returnItems!.isNotEmpty) {
        debugPrint("Building order returns section...");
        bytes += _returnsBuilder.build(
          generator,
          orderReturns,
          cartItems,
          isFromLocalStorage,
          selectedPaperSize,
          selectedFontType,
          displayConfig,
          billDocumentConfig,
        );

        debugPrint("Building total summary section...");
        bytes += _totalSummaryBuilder.build(
          generator,
          formattedTotal,
          orderReturns,
          cartItems,
          isFromLocalStorage,
          selectedFontType,
          displayConfig,
        );
      } else {
        // Amount in words when no returns
        if (displayConfig?['showAmountInWords']?.visible == true) {
          debugPrint("Building amount in words...");
          bytes += _balanceBuilder.buildAmountInWords(
            generator,
            double.parse(formattedTotal),
            selectedFontType,
          );
        }

        // Customer balance
        if (customerOldBalance != null ||
            customerCurrentBalance != null ||
            paidAmount != null) {
          bytes += _balanceBuilder.buildCustomerBalance(
            generator,
            customerOldBalance,
            customerCurrentBalance,
            paidAmount,
            selectedFontType,
          );
        }
      }

      // QR Code
      if (displayConfig?['showQRCode']?.visible == true) {
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

        debugPrint("Building QR code...");
        bytes += _qrCodeBuilder.build(generator, manualPaymentGateway.link,
            formattedTotal, orderNumber, displayConfig, selectedFontType);
      }

      // Date/time and barcode
      debugPrint("Building date/time row...");
      bytes += _barcodeBuilder.buildDateTimeRow(
          generator, orderDate, selectedFontType, isFromLocalStorage);

      debugPrint("Building order barcode...");
      bytes += _barcodeBuilder.buildOrderBarcode(
          generator, orderNumber, selectedPaperSize, selectedFontType);

      // Terms & Conditions
      if (displayConfig?['showTermsConditions']?.visible == true) {
        debugPrint("Building terms & conditions...");
        bytes += _footerBuilder.buildTermsConditions(generator, displayConfig,
            billDocumentConfig, selectedPaperSize, selectedFontType);
      }

      // Thank You Message
      if (displayConfig?['showThankYouMessage']?.visible == true) {
        debugPrint("Building thank you message...");
        bytes += _footerBuilder.buildThankYouMessage(
            generator, displayConfig, selectedFontType);
      }

      // Open cash drawer and cut
      bytes += generator.drawer();
      bytes += generator.cut();

      debugPrint("Sending to printer...");
      await printerManager.send(
          type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e) {
      debugPrint("ERROR printing receipt: ${e.toString()}");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error printing: ${e.toString()}",
        );
      }
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("==========================");
    }
  }

  /// Image-based printing method for Arabic/English support.
  /// Uses the same parameters as printReceipt() but renders the receipt as images.
  Future<void> printReceiptAsImage({
    required BluetoothPrinter selectedPrinter,
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    OrderReturns? orderReturns,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double? paidAmount,
  }) async {
    debugPrint("===== IMAGE-BASED THERMAL PRINTING ====");

    if (billDocumentConfig == null) {
      debugPrint("ERROR: Bill document configuration not loaded yet.");
      return;
    }

    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: $selectedPaperSize");

    final displayConfig = billDocumentConfig.displayConfiguration?.options;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    try {
      debugPrint("Connecting to printer...");
      await _printerUtils.connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully.");

      // Determine language direction
      // Use language from config if available, fallback to current app locale
      final configLanguage = billDocumentConfig.language;
      final isEnglish = configLanguage != null
          ? configLanguage == 'en'
          : LocalizationService.locale.languageCode == 'en';

      final textDirection = isEnglish ? TextDirection.ltr : TextDirection.rtl;
      debugPrint(
          "Language: ${isEnglish ? 'English' : 'Arabic'} (Source: ${configLanguage != null ? 'Config' : 'App Locale'}) ($textDirection)");

      // Setup print parameters
      final double printWidth = selectedPaperSize == '58mm' ? 384.0 : 576.0;
      // Dynamic font size: larger for 80mm to maintain proportional appearance
      final double baseFontSize = selectedPaperSize == '80mm' ? 28.0 : 20.0;

      // Build receipt rows
      List<ReceiptRow> part1Rows = [];
      List<ReceiptRow> part2Rows = [];

      // ========== PART 1: Header, Customer, Items, Totals ==========

      // --- HEADER SECTION ---
      // Store Name
      if (displayConfig?['showStoreName']?.visible == true) {
        final storeName = displayConfig?['showStoreName']?.value as String? ??
            billDocumentConfig.header ??
            'STORE NAME';
        part1Rows.add(TextRow(storeName.isNotEmpty ? storeName : 'STORE NAME',
            isBold: true, scale: 2.0));
      }

      // Description/Subheader
      if (displayConfig?['showDescription']?.visible == true) {
        final description =
            displayConfig?['showDescription']?.value as String? ??
                billDocumentConfig.subheader ??
                '';
        if (description.isNotEmpty) {
          part1Rows.add(TextRow(description, scale: 0.9));
        }
      }

      // Store Address
      if (displayConfig?['showStoreAddress']?.visible == true) {
        final storeAddress =
            displayConfig?['showStoreAddress']?.value as String?;
        if (storeAddress != null && storeAddress.isNotEmpty) {
          part1Rows.add(TextRow(storeAddress, scale: 0.9));
        }
      }

      // FSSAI Info
      if (displayConfig?['showFssaiInfo']?.visible == true) {
        final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
        if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
          part1Rows.add(TextRow(fssaiInfo, scale: 0.9));
        }
      }

      // Telephone
      if (displayConfig?['showTel']?.visible == true) {
        final telephone = displayConfig?['showTel']?.value as String? ??
            appSettings?.customerCarePhone ??
            '';
        if (telephone.isNotEmpty) {
          part1Rows.add(TextRow('TEL: $telephone', scale: 0.8));
        }
      }

      // Email
      if (displayConfig?['showEmail']?.visible == true) {
        final email = displayConfig?['showEmail']?.value as String? ??
            appSettings?.customerCareEmail ??
            '';
        if (email.isNotEmpty) {
          part1Rows.add(TextRow('Email: $email', scale: 0.8));
        }
      }

      part1Rows.add(SpacingRow(10));

      // Invoice Title
      if (displayConfig?['showInvoiceTitle']?.visible == true) {
        final invoiceTitle =
            displayConfig?['showInvoiceTitle']?.value as String? ??
                billDocumentConfig.header ??
                appSettings?.printTitle ??
                'INVOICE';
        part1Rows.add(TextRow(
            invoiceTitle.isNotEmpty ? invoiceTitle : 'INVOICE',
            isBold: true,
            scale: 1.2));
      }

      // Invoice Number
      if (displayConfig?['showInvoiceNumber']?.visible == true) {
        final invoiceNumberText = billDocumentConfig.numberPrefix != null &&
                billDocumentConfig.numberPrefix!.isNotEmpty
            ? '${billDocumentConfig.numberPrefix}$orderNumber'
            : 'INV No: $orderNumber';
        part1Rows.add(TextRow(invoiceNumberText, isBold: true));
      }

      part1Rows.add(DividerRow());

      // --- CUSTOMER DETAILS SECTION ---
      if (customerName != null || customerPhone != null) {
        if (isEnglish) {
          // English: Label: Value format
          if (customerName != null && customerName.isNotEmpty) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn("Customer:",
                  weight: 0.35, align: TextAlign.left, isBold: true),
              ReceiptTableColumn(customerName,
                  weight: 0.65, align: TextAlign.left),
            ]));
          }
          if (customerPhone != null && customerPhone.isNotEmpty) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn("Phone:",
                  weight: 0.35, align: TextAlign.left, isBold: true),
              ReceiptTableColumn(
                  StringHelper.maskStringShowLast4(customerPhone),
                  weight: 0.65,
                  align: TextAlign.left),
            ]));
          }
        } else {
          // Arabic: Value :Label format (RTL)
          if (customerName != null && customerName.isNotEmpty) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn(customerName,
                  weight: 0.65, align: TextAlign.right),
              ReceiptTableColumn("العميل:",
                  weight: 0.35, align: TextAlign.left, isBold: true),
            ]));
          }
          if (customerPhone != null && customerPhone.isNotEmpty) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn(
                  StringHelper.maskStringShowLast4(customerPhone),
                  weight: 0.65,
                  align: TextAlign.right),
              ReceiptTableColumn("الهاتف:",
                  weight: 0.35, align: TextAlign.left, isBold: true),
            ]));
          }
        }
        if (customerAddress != null && customerAddress.isNotEmpty) {
          part1Rows.add(TextRow(customerAddress, scale: 0.9));
        }
        part1Rows.add(DividerRow());
      }

      // --- CART ITEMS SECTION ---
      // Get dynamic labels from resolved_labels or display_configuration, with fallbacks
      final resolvedLabels = billDocumentConfig.resolvedLabels;

      // Extract labels with fallbacks (API value -> resolved_labels -> default)
      final String particularsLabel =
          (displayConfig?['showParticulars']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showParticulars']!.value as String
              : (resolvedLabels?.particulars?.isNotEmpty == true
                  ? resolvedLabels!.particulars!
                  : (isEnglish ? "Item" : "الصنف"));

      final String mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : (resolvedLabels?.mrp?.isNotEmpty == true
                  ? resolvedLabels!.mrp!
                  : "MRP");

      final String qtyLabel =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : (resolvedLabels?.qty?.isNotEmpty == true
                  ? resolvedLabels!.qty!
                  : (isEnglish ? "Qty" : "الكمية"));

      final String rateLabel =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : (resolvedLabels?.rate?.isNotEmpty == true
                  ? resolvedLabels!.rate!
                  : (isEnglish ? "Rate" : "السعر"));

      final String totalLabel =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : (resolvedLabels?.total?.isNotEmpty == true
                  ? resolvedLabels!.total!
                  : (isEnglish ? "Total" : "الإجمالي"));

      // Table Header
      if (isEnglish) {
        List<ReceiptTableColumn> headerCols = [];
        if (displayConfig?['showParticulars']?.visible == true) {
          headerCols.add(ReceiptTableColumn(particularsLabel,
              weight: 0.40, align: TextAlign.left, isBold: true));
        }
        if (displayConfig?['showMRP']?.visible == true) {
          headerCols.add(ReceiptTableColumn(mrpLabel,
              weight: 0.15, align: TextAlign.center, isBold: true));
        }
        if (displayConfig?['showQty']?.visible == true) {
          headerCols.add(ReceiptTableColumn(qtyLabel,
              weight: 0.10, align: TextAlign.center, isBold: true));
        }
        if (displayConfig?['showRate']?.visible == true) {
          headerCols.add(ReceiptTableColumn(rateLabel,
              weight: 0.15, align: TextAlign.right, isBold: true));
        }
        if (displayConfig?['showTotal']?.visible == true) {
          headerCols.add(ReceiptTableColumn(totalLabel,
              weight: 0.20, align: TextAlign.right, isBold: true));
        }
        if (headerCols.isNotEmpty) {
          part1Rows.add(ReceiptTableRow(headerCols));
          part1Rows.add(DividerRow());
        }
      } else {
        // Arabic header (RTL - columns in visual left-to-right order)
        List<ReceiptTableColumn> headerCols = [];
        if (displayConfig?['showTotal']?.visible == true) {
          headerCols.add(ReceiptTableColumn(totalLabel,
              weight: 0.2, align: TextAlign.right, isBold: true));
        }
        if (displayConfig?['showRate']?.visible == true) {
          headerCols.add(ReceiptTableColumn(rateLabel,
              weight: 0.2, align: TextAlign.right, isBold: true));
        }
        if (displayConfig?['showQty']?.visible == true) {
          headerCols.add(ReceiptTableColumn(qtyLabel,
              weight: 0.15, align: TextAlign.right, isBold: true));
        }
        if (displayConfig?['showMRP']?.visible == true) {
          headerCols.add(ReceiptTableColumn(mrpLabel,
              weight: 0.15, align: TextAlign.right, isBold: true));
        }
        if (displayConfig?['showParticulars']?.visible == true) {
          headerCols.add(ReceiptTableColumn(particularsLabel,
              weight: 0.3, align: TextAlign.right, isBold: true));
        }
        if (headerCols.isNotEmpty) {
          part1Rows.add(ReceiptTableRow(headerCols));
          part1Rows.add(DividerRow());
        }
      }

      // Cart Items
      for (var i = 0; i < cartItems.length; i++) {
        var item = cartItems[i];
        String productName = '';
        String mrp = '';
        String quantity = '';
        String unitPrice = '';
        String totalPrice = '';

        if (isFromLocalStorage) {
          productName = item['productName'] ?? '';
          mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
          quantity = item['quantity'] ?? '0';
          unitPrice =
              (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0)
                  .toStringAsFixed(2);
          totalPrice =
              (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
                  .toStringAsFixed(2);
        } else {
          productName = item.productName ?? '';
          mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
          quantity = item.quantity?.toString() ?? '0';
          unitPrice =
              (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
                  .toStringAsFixed(2);
          totalPrice =
              (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
                  .toStringAsFixed(2);
        }

        String slNumber = (i + 1).toString();

        if (isEnglish) {
          // Product name row
          if (displayConfig?['showParticulars']?.visible == true ||
              displayConfig?['showSLNumber']?.visible == true) {
            String itemText = displayConfig?['showSLNumber']?.visible == true
                ? '$slNumber. $productName'
                : productName;
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.left),
            ]));
          }
          // Price details row
          List<ReceiptTableColumn> priceCols = [];
          priceCols.add(
              ReceiptTableColumn("", weight: 0.40)); // Empty for item column
          if (displayConfig?['showMRP']?.visible == true) {
            priceCols.add(
                ReceiptTableColumn(mrp, weight: 0.15, align: TextAlign.center));
          }
          if (displayConfig?['showQty']?.visible == true) {
            priceCols.add(ReceiptTableColumn(quantity,
                weight: 0.10, align: TextAlign.center));
          }
          if (displayConfig?['showRate']?.visible == true) {
            priceCols.add(ReceiptTableColumn(unitPrice,
                weight: 0.15, align: TextAlign.right));
          }
          if (displayConfig?['showTotal']?.visible == true) {
            priceCols.add(ReceiptTableColumn(totalPrice,
                weight: 0.20, align: TextAlign.right));
          }
          if (priceCols.length > 1) {
            part1Rows.add(ReceiptTableRow(priceCols));
          }
        } else {
          // Arabic: RTL layout
          if (displayConfig?['showParticulars']?.visible == true ||
              displayConfig?['showSLNumber']?.visible == true) {
            String itemText = displayConfig?['showSLNumber']?.visible == true
                ? '$slNumber. $productName'
                : productName;
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn(itemText, weight: 1.0, align: TextAlign.right),
            ]));
          }
          // Price details row (RTL order)
          List<ReceiptTableColumn> priceCols = [];
          if (displayConfig?['showTotal']?.visible == true) {
            priceCols.add(ReceiptTableColumn(totalPrice,
                weight: 0.2, align: TextAlign.right));
          }
          if (displayConfig?['showRate']?.visible == true) {
            priceCols.add(ReceiptTableColumn(unitPrice,
                weight: 0.2, align: TextAlign.right));
          }
          if (displayConfig?['showQty']?.visible == true) {
            priceCols.add(ReceiptTableColumn(quantity,
                weight: 0.15, align: TextAlign.right));
          }
          if (displayConfig?['showMRP']?.visible == true) {
            priceCols.add(
                ReceiptTableColumn(mrp, weight: 0.15, align: TextAlign.right));
          }
          priceCols.add(
              ReceiptTableColumn("", weight: 0.3)); // Empty for item column
          if (priceCols.length > 1) {
            part1Rows.add(ReceiptTableRow(priceCols));
          }
        }
      }

      part1Rows.add(SpacingRow(5));
      part1Rows.add(DividerRow());

      // --- TOTALS SECTION ---
      double saved = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
      double total = double.tryParse(formattedTotal) ?? 0.0;
      double discountAmountValue =
          double.tryParse(discountAmount ?? '0.0') ?? 0.0;
      double totalMrp = saved + total;

      // Calculate total quantity
      double totalQuantity = 0.0;
      for (var item in cartItems) {
        if (isFromLocalStorage) {
          totalQuantity +=
              double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
        } else {
          totalQuantity +=
              double.tryParse(item.quantity?.toString() ?? '0') ?? 0.0;
        }
      }

      if (isEnglish) {
        // Summary rows (English) - use dynamic labels from API
        final String itemsCountLabel =
            (displayConfig?['showItemsCount']?.value as String?)?.isNotEmpty ==
                    true
                ? displayConfig!['showItemsCount']!.value as String
                : "Items:";
        final String discountLabel =
            (displayConfig?['showDiscount']?.value as String?)?.isNotEmpty ==
                    true
                ? displayConfig!['showDiscount']!.value as String
                : "Discount:";
        final String mrpTotalLabel =
            (displayConfig?['showMRPTotal']?.value as String?)?.isNotEmpty ==
                    true
                ? displayConfig!['showMRPTotal']!.value as String
                : "Total MRP:";
        final String netAmountLabel =
            (displayConfig?['showNetAmount']?.value as String?)?.isNotEmpty ==
                    true
                ? displayConfig!['showNetAmount']!.value as String
                : "Net Total:";

        if (displayConfig?['showItemsCount']?.visible == true) {
          part1Rows.add(ReceiptTableRow([
            ReceiptTableColumn(itemsCountLabel,
                weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn(cartItems.length.toString(),
                weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn(" ", weight: 0.05),
            ReceiptTableColumn(discountLabel,
                weight: 0.25, align: TextAlign.right),
            ReceiptTableColumn(discountAmountValue.toStringAsFixed(2),
                weight: 0.20, align: TextAlign.right),
          ]));
        }

        // Total Qty label - use Qty label from table header
        final String totalQtyLabel = "$qtyLabel Total:";
        part1Rows.add(ReceiptTableRow([
          ReceiptTableColumn(totalQtyLabel,
              weight: 0.25, align: TextAlign.left),
          ReceiptTableColumn(
              totalQuantity % 1 == 0
                  ? totalQuantity.toInt().toString()
                  : totalQuantity.toStringAsFixed(2),
              weight: 0.25,
              align: TextAlign.left),
          ReceiptTableColumn(" ", weight: 0.50),
        ]));

        if (displayConfig?['showMRPTotal']?.visible == true) {
          part1Rows.add(ReceiptTableRow([
            ReceiptTableColumn(mrpTotalLabel,
                weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn(totalMrp.toStringAsFixed(2),
                weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn(" ", weight: 0.50),
          ]));
        }

        part1Rows.add(SpacingRow(5));

        // Net Total
        if (displayConfig?['showNetAmount']?.visible == true) {
          part1Rows.add(ReceiptTableRow([
            ReceiptTableColumn(netAmountLabel,
                weight: 0.5, align: TextAlign.center, isBold: true),
            ReceiptTableColumn(total.toStringAsFixed(2),
                weight: 0.5, align: TextAlign.center, isBold: true),
          ]));
        }
      } else {
        // SUMMARY ROWS - Bilingual Design (Image-based)
        double totalDiscountAmount = discountAmountValue;
        double subtotal = total + totalDiscountAmount;

        // 1. Subtotal
        part1Rows.add(ReceiptTableRow([
          ReceiptTableColumn(subtotal.toStringAsFixed(2),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn("SUBTOTAL المجموع",
              weight: 0.65, align: TextAlign.right),
        ]));

        // 2. Discounts
        if (totalDiscountAmount > 0) {
          final discountLabel =
              (displayConfig?['showDiscount']?.value as String?)?.isNotEmpty ==
                      true
                  ? displayConfig!['showDiscount']!.value as String
                  : "DISCOUNTS الخصم";

          part1Rows.add(ReceiptTableRow([
            ReceiptTableColumn(totalDiscountAmount.toStringAsFixed(2),
                weight: 0.35, align: TextAlign.left),
            ReceiptTableColumn(discountLabel,
                weight: 0.65, align: TextAlign.right),
          ]));
        }

        // 3. Tax / VAT
        // Try to get dynamic label from config, otherwise fallback to bilingual design
        final taxLabel =
            (displayConfig?['showTax']?.value as String?)?.isNotEmpty == true
                ? displayConfig!['showTax']!.value as String
                : (billDocumentConfig.resolvedLabels?.tax?.isNotEmpty == true
                    ? billDocumentConfig.resolvedLabels!.tax!
                    : "Tax");

        double taxAmount = 0.0;
        for (var item in cartItems) {
          if (isFromLocalStorage) {
            taxAmount +=
                double.tryParse(item['tax_amount']?.toString() ?? '0') ?? 0.0;
          } else {
            taxAmount +=
                double.tryParse(item.taxAmount?.toString() ?? '0') ?? 0.0;
          }
        }

        part1Rows.add(ReceiptTableRow([
          ReceiptTableColumn(taxAmount.toStringAsFixed(2),
              weight: 0.35, align: TextAlign.left),
          ReceiptTableColumn(taxLabel, weight: 0.65, align: TextAlign.right),
        ]));

        part1Rows.add(SpacingRow(5));

        // 4. Net Total (Grand Total)
        if (displayConfig?['showNetAmount']?.visible == true) {
          final netTotalLabel =
              (displayConfig?['showNetAmount']?.value as String?)?.isNotEmpty ==
                      true
                  ? displayConfig!['showNetAmount']!.value as String
                  : "GRAND TOTAL المبلغ الاجمالي";

          part1Rows.add(ReceiptTableRow([
            ReceiptTableColumn(total.toStringAsFixed(2),
                weight: 0.35, align: TextAlign.left, isBold: true),
            ReceiptTableColumn(netTotalLabel,
                weight: 0.65, align: TextAlign.right, isBold: true),
          ]));
        }
      }

      // You Saved
      if (displayConfig?['showSaved']?.visible == true && saved > 0) {
        part1Rows.add(SpacingRow(5));
        part1Rows.add(TextRow(
          isEnglish
              ? "You Saved: ${saved.toStringAsFixed(2)}"
              : "لقد وفرت: ${saved.toStringAsFixed(2)} ريال",
          isBold: true,
          scale: 0.9,
        ));
      }

      part1Rows.add(DividerRow());

      // Amount in Words
      if (displayConfig?['showAmountInWords']?.visible == true) {
        final amountInWords =
            '${AmountHelper().convertNumberToWords(total)} Only.';
        part1Rows.add(TextRow(amountInWords, scale: 0.9, isBold: true));
        part1Rows.add(DividerRow());
      }

      // Customer Balance
      if (customerOldBalance != null ||
          customerCurrentBalance != null ||
          paidAmount != null) {
        if (isEnglish) {
          if (customerOldBalance != null) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn("Old Balance:",
                  weight: 0.5, align: TextAlign.left),
              ReceiptTableColumn(customerOldBalance.toStringAsFixed(2),
                  weight: 0.5, align: TextAlign.right),
            ]));
          }
          if (paidAmount != null) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn("Paid Amount:",
                  weight: 0.5, align: TextAlign.left),
              ReceiptTableColumn(paidAmount.toStringAsFixed(2),
                  weight: 0.5, align: TextAlign.right),
            ]));
          }
          if (customerCurrentBalance != null) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn("Current Balance:",
                  weight: 0.5, align: TextAlign.left, isBold: true),
              ReceiptTableColumn(customerCurrentBalance.toStringAsFixed(2),
                  weight: 0.5, align: TextAlign.right, isBold: true),
            ]));
          }
        } else {
          // Arabic balance display
          if (customerOldBalance != null) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn(customerOldBalance.toStringAsFixed(2),
                  weight: 0.3, align: TextAlign.right),
              ReceiptTableColumn("الرصيد السابق:",
                  weight: 0.3, align: TextAlign.left),
              ReceiptTableColumn(" ", weight: 0.4),
            ]));
          }
          if (paidAmount != null) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn(paidAmount.toStringAsFixed(2),
                  weight: 0.3, align: TextAlign.right),
              ReceiptTableColumn("المدفوع:",
                  weight: 0.3, align: TextAlign.left),
              ReceiptTableColumn(" ", weight: 0.4),
            ]));
          }
          if (customerCurrentBalance != null) {
            part1Rows.add(ReceiptTableRow([
              ReceiptTableColumn(customerCurrentBalance.toStringAsFixed(2),
                  weight: 0.3, align: TextAlign.right, isBold: true),
              ReceiptTableColumn("الرصيد الحالي:",
                  weight: 0.3, align: TextAlign.left, isBold: true),
              ReceiptTableColumn(" ", weight: 0.4),
            ]));
          }
        }
        part1Rows.add(SpacingRow(10));
      }

      // ========== PART 2: Footer (QR, Date, Terms, Thank You) ==========

      part2Rows.add(SpacingRow(10));

      // QR Code
      if (displayConfig?['showQRCode']?.visible == true) {
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

        String qrData = manualPaymentGateway.link;
        if (qrData.isNotEmpty) {
          if (qrData.contains('{formattedTotal}') ||
              qrData.contains('{orderNumber}')) {
            qrData = qrData
                .replaceAll('{formattedTotal}', formattedTotal)
                .replaceAll('{orderNumber}', orderNumber);
          } else if (qrData.contains('@')) {
            qrData =
                'upi://pay?pa=$qrData&am=$formattedTotal&tn=$orderNumber&cu=INR';
          }

          final qrMessage =
              displayConfig?['showQRCode']?.value as String? ?? 'Scan to Pay';
          part2Rows.add(TextRow(isEnglish ? qrMessage : "امسح الرمز للدفع",
              isBold: true, scale: 0.9));
          part2Rows.add(QrRow(qrData, size: 200));
        }
      }

      part2Rows.add(SpacingRow(15));

      // Date and Time
      String formattedDate = isFromLocalStorage
          ? DateHelper.formatToISODateOnlyFromISO(orderDate)
          : DateHelper.formatISODate(orderDate);
      String formattedTime = isFromLocalStorage
          ? DateHelper.formatToISOTimeOnlyFromISO(orderDate)
          : DateHelper.formatISOTimeOnlyToIST(orderDate);

      if (isEnglish) {
        part2Rows.add(ReceiptTableRow([
          ReceiptTableColumn("Date:", weight: 0.4, align: TextAlign.left),
          ReceiptTableColumn("$formattedDate $formattedTime",
              weight: 0.6, align: TextAlign.right),
        ]));
      } else {
        // Arabic: Label on Right, Value on Left
        part2Rows.add(ReceiptTableRow([
          ReceiptTableColumn("$formattedDate $formattedTime",
              weight: 0.6, align: TextAlign.left),
          ReceiptTableColumn("التاريخ:", weight: 0.4, align: TextAlign.right),
        ]));
      }

      part2Rows.add(SpacingRow(5));

      // Invoice number for barcode reference
      part2Rows.add(TextRow('#$orderNumber', scale: 0.8));

      part2Rows.add(SpacingRow(5));

      // Terms & Conditions
      if (displayConfig?['showTermsConditions']?.visible == true) {
        String? terms = displayConfig?['showTermsConditions']?.value as String?;
        if (terms == null || terms.trim().isEmpty) {
          terms = billDocumentConfig.terms;
        }
        if (terms != null && terms.trim().isNotEmpty) {
          part2Rows.add(TextRow(terms.trim(), scale: 0.8));
        }
      }

      part2Rows.add(SpacingRow(5));

      // Thank You Message
      if (displayConfig?['showThankYouMessage']?.visible == true) {
        final message =
            displayConfig?['showThankYouMessage']?.value as String? ??
                'Thank You... Visit Again';
        part2Rows.add(TextRow(
          isEnglish
              ? (message.isNotEmpty ? message : 'Thank You... Visit Again')
              : "شكراً لزيارتكم! نأمل رؤيتكم قريباً",
          isBold: true,
        ));
      }

      part2Rows.add(SpacingRow(20));

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

      // ========== GENERATE ESC/POS BYTES ==========
      debugPrint("Generating ESC/POS bytes...");
      final profile = await CapabilityProfile.load();
      final generator = Generator(
          selectedPaperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80,
          profile);
      List<int> bytes = [];

      // Print images
      bytes += generator.image(imagePart1);
      bytes += generator.image(imagePart2);

      // Print native barcode (works well natively)
      String cleanOrderNumber =
          orderNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
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
      await printerManager.send(
          type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully.");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR in Image-Based Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: "Error printing: ${e.toString()}");
      }
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("===== END IMAGE-BASED PRINTING =====");
    }
  }
}
