import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';

class ThermalPrinter {
  final BuildContext context;
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Font configuration - default fallback (will be overridden by user preference)
  static const PosFontType defaultFontType = PosFontType.fontB;

  // Text size variables for consistent sizing
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  ThermalPrinter(this.context);

  // Load font type from SharedPreferences
  Future<PosFontType> _loadFontType() async {
    final prefs = await SharedPreferences.getInstance();
    final fontStyle =
        prefs.getString('default_font_style') ?? 'Font B (Default)';
    return fontStyle.contains('Font A') ? PosFontType.fontA : PosFontType.fontB;
  }

  Future<void> printReceipt({
    required BluetoothPrinter selectedPrinter,
    required List<dynamic> cartItems,
    required String formattedTotal,
    required String? savedTotal,
    required String orderDate,
    required String orderNumber,
    required bool isFromLocalStorage,
    required String selectedPaperSize,
    required DocumentConfig? billDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
  }) async {
    debugPrint("===== THERMAL PRINTING DEBUG =====");

    // Ensure billDocumentConfig is loaded before printing
    if (billDocumentConfig == null) {
      debugPrint("ERROR: Bill document configuration not loaded yet.");
      if (context.mounted) {
        // showScaffoldError(
        //   context: context,
        //   message: "Document configurations not loaded. Please wait.",
        // );
      }
      return;
    }

    debugPrint("Printing receipt with thermal printer:");
    debugPrint(
        "Printer: ${selectedPrinter.deviceName} (${selectedPrinter.typePrinter})");
    debugPrint("Paper size: $selectedPaperSize");

    // Use the loaded display configuration
    final displayConfig = billDocumentConfig.displayConfiguration?.options;
    _debugPrintTemplateSettings(displayConfig);

    try {
      // Load the selected font type from preferences
      final selectedFontType = await _loadFontType();
      debugPrint(
          "Using font type: ${selectedFontType == PosFontType.fontA ? 'Font A' : 'Font B'}");

      // Connect to the printer
      debugPrint("Connecting to printer...");
      await _printerUtils.connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully");

      // Generate receipt
      final profile = await CapabilityProfile.load();

      // Select appropriate paper size based on selection
      PaperSize paperSize;
      if (selectedPaperSize == '80mm') {
        paperSize = PaperSize.mm80;
        debugPrint("Using 80mm paper size configuration");
      } else if (selectedPaperSize == '58mm') {
        paperSize = PaperSize.mm58;
        debugPrint("Using 58mm paper size configuration");
      } else {
        // Default to 80mm for any other value
        paperSize = PaperSize.mm80;
        debugPrint("Using default 80mm paper size configuration");
      }

      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // Pass the display config, document config, and selected font type to helper functions
      bytes += _buildHeader(generator, displayConfig, billDocumentConfig,
          orderDate, orderNumber, selectedFontType);
      bytes += _buildCartItems(
          generator,
          cartItems,
          displayConfig,
          isFromLocalStorage,
          selectedPaperSize,
          billDocumentConfig,
          selectedFontType);
      bytes += _buildTotalAmount(
          generator,
          displayConfig,
          formattedTotal,
          savedTotal,
          cartItems.length,
          billDocumentConfig,
          cartItems,
          isFromLocalStorage,
          selectedFontType);

      // QR Code
      if (displayConfig?['showQRCode']?.visible == true) {
        debugPrint("QR Code is enabled in display config");
        // Access link from PaymentGatewaysProvider
        final paymentGatewaysProvider =
            Provider.of<PaymentGatewaysProvider>(context, listen: false);
        debugPrint(
            "Payment gateways available: ${paymentGatewaysProvider.paymentGateways.length}");

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

        debugPrint("Manual payment gateway found:");
        debugPrint("- ID: ${manualPaymentGateway.id}");
        debugPrint("- Name: '${manualPaymentGateway.name}'");
        debugPrint("- Code: '${manualPaymentGateway.code}'");
        debugPrint("- Link: '${manualPaymentGateway.link}'");

        bytes += _buildQRCode(generator, manualPaymentGateway.link,
            formattedTotal, orderNumber, displayConfig, selectedFontType);
      } else {
        debugPrint("Skipping QR code, disabled in settings");
        debugPrint(
            "Display config showQRCode visible: ${displayConfig?['showQRCode']?.visible}");
      }

      // Date and Time (moved to bottom, just above barcode)
      bytes += _buildDateTimeRow(generator, orderDate, selectedFontType);

      // Order ID Barcode (just before Terms & Conditions)
      bytes += _buildOrderBarcode(
          generator, orderNumber, selectedPaperSize, selectedFontType);

      // Terms & Conditions
      if (displayConfig?['showTermsConditions']?.visible == true) {
        bytes += _buildTermsConditions(generator, displayConfig,
            billDocumentConfig, selectedPaperSize, selectedFontType);
      } else {
        debugPrint("Skipping Terms & Conditions, disabled in settings");
      }

      // Thank You Message (moved to end after Terms & Conditions)
      if (displayConfig?['showThankYouMessage']?.visible == true) {
        bytes +=
            _buildThankYouMessage(generator, displayConfig, selectedFontType);
      }

      // Cut the receipt
      bytes += generator.cut();

      debugPrint("Receipt generated, sending to printer...");
      // Print receipt
      await _printerUtils.sendPrintJob(selectedPrinter, bytes);
      debugPrint("Print job sent successfully");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 90;
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

  List<int> _buildHeader(
      Generator generator,
      Map<String, DisplayOption>? displayConfig,
      DocumentConfig? docConfig,
      String orderDate,
      String orderNumber,
      PosFontType fontType) {
    List<int> bytes = [];

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    // Store Name
    if (displayConfig?['showStoreName']?.visible == true) {
      final storeName = displayConfig?['showStoreName']?.value as String? ??
          docConfig?.header ??
          'STORE NAME';
      bytes += generator.row([
        PosColumn(
          text: storeName.isNotEmpty ? storeName : 'STORE NAME',
          width: 12,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeBig),
        ),
      ]);
    }

    // Description (subheader from DocumentConfig or value from displayConfig)
    if (displayConfig?['showDescription']?.visible == true) {
      final description = displayConfig?['showDescription']?.value as String? ??
          docConfig?.subheader ??
          '';
      bytes += generator.row([
        PosColumn(
          text: description.isNotEmpty ? description : '',
          width: 12,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: true,
            height: textSizeMedium,
          ),
        ),
      ]);
    }

    // Store Address - Only show if data is available
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final storeAddress = displayConfig?['showStoreAddress']?.value as String?;
      if (storeAddress != null && storeAddress.isNotEmpty) {
        bytes += generator.row([
          PosColumn(
            text: storeAddress,
            width: 12,
            styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall,
            ),
          ),
        ]);
      }
    }

    // Fssai Info - Only show if data is available
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
      if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
        bytes += generator.row([
          PosColumn(
            text: fssaiInfo,
            width: 12,
            styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall,
            ),
          ),
        ]);
      }
    }

    // Telephone
    if (displayConfig?['showTel']?.visible == true) {
      final telephone = displayConfig?['showTel']?.value as String? ??
          appSettings?.customerCarePhone ??
          '';
      if (telephone.isNotEmpty) {
        bytes += generator.text('TEL: $telephone',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.center,
                bold: true,
                height: textSizeSmall));
      }
    }

    // Email
    if (displayConfig?['showEmail']?.visible == true) {
      final email = displayConfig?['showEmail']?.value as String? ??
          appSettings?.customerCareEmail ??
          '';
      if (email.isNotEmpty) {
        bytes += generator.text('Email: $email',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.center,
                bold: true,
                height: textSizeSmall));
      }
    }

    // Invoice Title (from DocumentConfig header or displayConfig value)
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle =
          displayConfig?['showInvoiceTitle']?.value as String? ??
              docConfig?.header ??
              appSettings?.printTitle ??
              'INVOICE';
      bytes += generator.text(
          invoiceTitle.isNotEmpty ? invoiceTitle : 'INVOICE',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeMedium));
    }

    // Invoice Number
    if (displayConfig?['showInvoiceNumber']?.visible == true) {
      // Use the numberPrefix from docConfig if available, otherwise just use orderNumber
      final invoiceNumberText =
          docConfig?.numberPrefix != null && docConfig!.numberPrefix!.isNotEmpty
              ? '${docConfig.numberPrefix}$orderNumber'
              : 'INV No: $orderNumber';

      bytes += generator.text(invoiceNumberText,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall));
    }

    // Date Header - Moved to separate _buildDateTimeRow method

    return bytes;
  }

  List<int> _buildCartItems(
      Generator generator,
      List<dynamic> cartItems,
      Map<String, DisplayOption>? displayConfig,
      bool isFromLocalStorage,
      String selectedPaperSize,
      DocumentConfig? billDocumentConfig,
      PosFontType fontType) {
    List<int> bytes = [];

    // Determine if we're using 58mm paper for font size adjustment
    bool is58mm = selectedPaperSize == '58mm';

    // Add table headers with fixed widths
    List<PosColumn> headerColumns = [];

    if (displayConfig?['showSLNumber']?.visible == true) {
      final slLabel =
          (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSLNumber']!.value as String
              : 'SL#';
      headerColumns.add(PosColumn(
          text: slLabel,
          width: 1,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
    }

    if (displayConfig?['showParticulars']?.visible == true) {
      final label =
          (displayConfig?['showParticulars']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showParticulars']!.value as String
              : 'PARTICULARS';
      // Fixed width for header title
      int particularsWidth = 3;
      if (displayConfig?['showSLNumber']?.visible != true) {
        particularsWidth += 1; // Add SL width if SL is not visible
      }

      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: particularsWidth,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
    }

    if (displayConfig?['showMRP']?.visible == true) {
      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : 'MRP';
      headerColumns.add(PosColumn(
          text: mrpLabel.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
    }

    if (displayConfig?['showQty']?.visible == true) {
      final label =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : 'QTY';
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
    }

    if (displayConfig?['showRate']?.visible == true) {
      final label =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : 'RATE';
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
    }

    if (displayConfig?['showTotal']?.visible == true) {
      final label =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : 'TOTAL';
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
    }

    if (headerColumns.isNotEmpty) {
      bytes += generator.row(headerColumns);
      bytes += generator.hr();
    }

    // Process each cart item
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
        unitPrice = (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
        totalPrice =
            (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
                .toStringAsFixed(2);
      }

      String slNumber = (i + 1).toString();

      // First row: SL# + Product Name
      List<PosColumn> productNameRow = [];

      if (displayConfig?['showSLNumber']?.visible == true) {
        productNameRow.add(PosColumn(
            text: '$slNumber',
            width: 1,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }

      if (displayConfig?['showParticulars']?.visible == true) {
        // Product name takes full width: 11 (when SL visible) or 12 (when SL hidden)
        int productNameWidth =
            displayConfig?['showSLNumber']?.visible == true ? 11 : 12;

        // Calculate character limit for product name based on actual paper width
        // For thermal printers: 58mm ≈ 32 chars, 80mm ≈ 48 chars
        int maxCharsPerLine;
        if (is58mm) {
          maxCharsPerLine = displayConfig?['showSLNumber']?.visible == true
              ? 28
              : 32; // Reserve space for SL number
        } else {
          maxCharsPerLine = displayConfig?['showSLNumber']?.visible == true
              ? 44
              : 48; // Reserve space for SL number
        }

        if (productName.length <= maxCharsPerLine) {
          // Try using generator.text() instead of generator.row() to prevent centering
          if (displayConfig?['showSLNumber']?.visible == true) {
            // Show SL number first, then product name on same line
            bytes += generator.text('$slNumber  $productName',
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.left,
                    bold: true,
                    height: is58mm ? textSizeSmall : textSizeSmall));
          } else {
            // Just product name
            bytes += generator.text(productName,
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.left,
                    bold: true,
                    height: is58mm ? textSizeSmall : textSizeSmall));
          }
        } else {
          // Product name needs multiple lines - split properly using generator.text()
          String remainingName = productName;
          bool isFirstLine = true;

          while (remainingName.isNotEmpty) {
            String currentLine;

            if (remainingName.length <= maxCharsPerLine) {
              currentLine = remainingName;
              remainingName = '';
            } else {
              // Find a good break point (prefer breaking at spaces)
              int breakPoint = maxCharsPerLine;

              for (int i = maxCharsPerLine - 1;
                  i >= maxCharsPerLine - 10 && i >= 0;
                  i--) {
                if (i < remainingName.length && remainingName[i] == ' ') {
                  breakPoint = i;
                  break;
                }
              }

              currentLine = remainingName.substring(0, breakPoint).trim();
              remainingName = remainingName.substring(breakPoint).trim();
            }

            // Use generator.text() for multi-line names too
            if (isFirstLine &&
                displayConfig?['showSLNumber']?.visible == true) {
              // First line with SL number
              bytes += generator.text('$slNumber  $currentLine',
                  styles: PosStyles(
                      fontType: fontType,
                      align: PosAlign.left,
                      bold: true,
                      height: is58mm ? textSizeSmall : textSizeSmall));
            } else {
              // Continuation lines or when SL not visible
              String lineText =
                  (displayConfig?['showSLNumber']?.visible == true &&
                          !isFirstLine)
                      ? '   $currentLine' // Add spacing for SL alignment
                      : currentLine;
              bytes += generator.text(lineText,
                  styles: PosStyles(
                      fontType: fontType,
                      align: PosAlign.left,
                      bold: true,
                      height: is58mm ? textSizeSmall : textSizeSmall));
            }
            isFirstLine = false;
          }
        }
      } else if (displayConfig?['showSLNumber']?.visible == true) {
        // Only SL number, no product name - fill the row to width 12
        productNameRow.add(PosColumn(
            text: '$slNumber',
            width: 1,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: is58mm ? textSizeSmall : textSizeSmall)));
        productNameRow.add(PosColumn(
            text: '',
            width: 11,
            styles: PosStyles(
                fontType: fontType, align: PosAlign.left, bold: true)));
        bytes += generator.row(productNameRow);
      }

      // Second row: Price details
      List<PosColumn> priceDetailsRow = [];

      // Add empty space for SL column (width 1)
      if (displayConfig?['showSLNumber']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: '',
            width: 1,
            styles: PosStyles(fontType: fontType, align: PosAlign.left)));
      }

      // Add price columns with the old working widths (like your old code)
      if (displayConfig?['showMRP']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: mrp,
            width: 3, // Back to 3 like your old working code
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: quantity,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: unitPrice,
            width: 3, // Back to 3 like your old working code
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: totalPrice,
            width: 3, // Back to 3 like your old working code
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }

      if (priceDetailsRow.isNotEmpty) {
        bytes += generator.row(priceDetailsRow);
      }
    }

    bytes += generator.hr();
    return bytes;
  }

  List<int> _buildTotalAmount(
      Generator generator,
      Map<String, DisplayOption>? displayConfig,
      String formattedTotal,
      String? savedTotal,
      int itemCount,
      DocumentConfig? billDocumentConfig,
      List<dynamic> cartItems,
      bool isFromLocalStorage,
      PosFontType fontType) {
    List<int> bytes = [];

    double saved = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(formattedTotal) ?? 0.0;
    double totalMrp = saved + total;

    // Calculate total quantity from all cart items
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

    // Create vertical division layout
    // Collect all left side and right side items first
    List<Map<String, String>> leftSideItems = [];
    List<Map<String, String>> rightSideItems = [];

    // Left side items
    if (displayConfig?['showItemsCount']?.visible == true) {
      leftSideItems.add({
        'label': 'Items',
        'value': itemCount.toString(),
        'textSize': 'small',
        'bold': 'false'
      });
    }

    leftSideItems.add({
      'label': 'Total Qty',
      'value': totalQuantity % 1 == 0
          ? totalQuantity.toInt().toString()
          : totalQuantity.toStringAsFixed(2),
      'textSize': 'small',
      'bold': 'false'
    });

    // Right side items
    if (displayConfig?['showMRPTotal']?.visible == true) {
      rightSideItems.add({
        'label': 'Total MRP',
        'value': totalMrp.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'false'
      });
    }

    if (displayConfig?['showSaved']?.visible == true) {
      rightSideItems.add({
        'label': 'You Saved',
        'value': saved.toStringAsFixed(2),
        'textSize': 'medium',
        'bold': 'false'
      });
    } else if (displayConfig?['showDiscount']?.visible == true) {
      rightSideItems.add({
        'label': 'Discount',
        'value': saved.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'false'
      });
    }

    if (displayConfig?['showNetAmount']?.visible == true) {
      rightSideItems.add({
        'label': 'Net Total',
        'value': total.toStringAsFixed(2),
        'textSize': 'medium',
        'bold': 'true'
      });
    }

    // Generate rows with vertical division (5-1-6 columns: left section, gap, right section)
    int maxRows = leftSideItems.length > rightSideItems.length
        ? leftSideItems.length
        : rightSideItems.length;

    for (int i = 0; i < maxRows; i++) {
      List<PosColumn> columns = [];

      // Left side (first 5 columns: 2 for label + 3 for value)
      if (i < leftSideItems.length) {
        final leftItem = leftSideItems[i];
        PosTextSize textSize = leftItem['textSize'] == 'big'
            ? textSizeBig
            : leftItem['textSize'] == 'medium'
                ? textSizeMedium
                : textSizeSmall;
        bool isBold = leftItem['bold'] == 'true';

        columns.add(PosColumn(
            text: leftItem['label']!,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: isBold,
                height: textSize)));
        columns.add(PosColumn(
            text: leftItem['value']!,
            width: 3,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSize)));
      } else {
        // Empty left side
        columns.add(PosColumn(
            text: '', width: 2, styles: PosStyles(fontType: fontType)));
        columns.add(PosColumn(
            text: '', width: 3, styles: PosStyles(fontType: fontType)));
      }

      // Gap column (1 column for spacing)
      columns.add(
          PosColumn(text: '', width: 1, styles: PosStyles(fontType: fontType)));

      // Right side (last 6 columns: 3 for label + 3 for value)
      if (i < rightSideItems.length) {
        final rightItem = rightSideItems[i];
        PosTextSize textSize = rightItem['textSize'] == 'big'
            ? textSizeBig
            : rightItem['textSize'] == 'medium'
                ? textSizeMedium
                : textSizeSmall;
        bool isBold = rightItem['bold'] == 'true';

        columns.add(PosColumn(
            text: rightItem['label']!,
            width: 3,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: isBold,
                height: textSize)));
        columns.add(PosColumn(
            text: rightItem['value']!,
            width: 3,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSize)));
      } else {
        // Empty right side
        columns.add(PosColumn(
            text: '', width: 3, styles: PosStyles(fontType: fontType)));
        columns.add(PosColumn(
            text: '', width: 3, styles: PosStyles(fontType: fontType)));
      }

      bytes += generator.row(columns);
    }

    // Add a separator line if any totals were shown
    if ((displayConfig?['showItemsCount']?.visible == true) ||
        (displayConfig?['showMRPTotal']?.visible == true) ||
        (displayConfig?['showSaved']?.visible == true) ||
        (displayConfig?['showDiscount']?.visible == true) ||
        (displayConfig?['showNetAmount']?.visible == true)) {
      bytes += generator.hr();
    }

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      bytes += generator.text(
          '${AmountHelper().convertNumberToWords(total)} Only.',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall));
    }

    return bytes;
  }

  List<int> _buildThankYouMessage(Generator generator,
      Map<String, DisplayOption>? displayConfig, PosFontType fontType) {
    List<int> bytes = [];

    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final message = displayConfig?['showThankYouMessage']?.value as String? ??
          'Thank You... Visit Again';
      bytes += generator.text(
          message.isNotEmpty ? message : 'Thank You... Visit Again',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeMedium));
    }

    return bytes;
  }

  List<int> _buildQRCode(
      Generator generator,
      String qrCodeLinkTemplate,
      String formattedTotal,
      String orderNumber,
      Map<String, DisplayOption>? displayConfig,
      PosFontType fontType) {
    if (displayConfig?['showQRCode']?.visible != true) {
      debugPrint("QR Code disabled in settings, skipping");
      return [];
    }

    debugPrint("===== QR CODE DEBUG =====");
    debugPrint("QR Code enabled in settings");
    debugPrint("Link template: '$qrCodeLinkTemplate'");
    debugPrint("Formatted total: '$formattedTotal'");
    debugPrint("Order number: '$orderNumber'");

    List<int> bytes = [];

    String qrData;

    // Check if the link template is empty or contains placeholders
    if (qrCodeLinkTemplate.isEmpty) {
      debugPrint(
          "WARNING: QR code link template is empty, skipping QR code generation");
      return [];
    } else if (qrCodeLinkTemplate.contains('{formattedTotal}') ||
        qrCodeLinkTemplate.contains('{orderNumber}')) {
      // Replace placeholders in the template string
      qrData = qrCodeLinkTemplate
          .replaceAll('{formattedTotal}', formattedTotal)
          .replaceAll('{orderNumber}', orderNumber);
      debugPrint("Using template with placeholders: '$qrData'");
    } else {
      // Use the link as-is, or create a UPI payment URL if it looks like a UPI ID
      if (qrCodeLinkTemplate.contains('@')) {
        // Looks like a UPI ID, create full UPI payment URL
        qrData =
            'upi://pay?pa=$qrCodeLinkTemplate&am=$formattedTotal&tn=$orderNumber&cu=INR&ds=EPOS&t=c&st=1&se=1&sd=1';
        debugPrint("Created UPI payment URL: '$qrData'");
      } else {
        // Use the link as-is
        qrData = qrCodeLinkTemplate;
        debugPrint("Using link as-is: '$qrData'");
      }
    }

    try {
      bytes += generator.qrcode(
        qrData,
        size: QRSize.size4,
        align: PosAlign.center,
      );
      debugPrint("QR code generated successfully");
    } catch (e) {
      debugPrint("ERROR generating QR code: $e");
      debugPrint("QR data that failed: '$qrData'");
      return [];
    }

    bytes += generator.emptyLines(1);

    final qrCodeMessage = displayConfig?['showQRCode']?.value as String? ??
        'Scan this QR code to Pay';
    bytes += generator.text(
        qrCodeMessage.isNotEmpty ? qrCodeMessage : 'Scan this QR code to Pay',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: true,
            height: textSizeSmall));
    debugPrint("==========================");
    return bytes;
  }

  List<int> _buildDateTimeRow(
      Generator generator, String orderDate, PosFontType fontType) {
    List<int> bytes = [];

    // Add top divider line
    // bytes += generator.hr();

    // Add date and time row with smaller text size
    bytes += generator.row([
      PosColumn(
          text: DateHelper.formatISODate(orderDate),
          width: 6,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: textSizeSmall,
              width: textSizeSmall)),
      PosColumn(
          text: DateHelper.formatISODateToIST(orderDate),
          width: 6,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: textSizeSmall,
              width: textSizeSmall)),
    ]);

    // Add bottom divider line
    // bytes += generator.hr();

    return bytes;
  }

  List<int> _buildOrderBarcode(Generator generator, String orderNumber,
      String selectedPaperSize, PosFontType fontType) {
    List<int> bytes = [];

    debugPrint(
        "Generating Order ID barcode: $orderNumber for $selectedPaperSize paper");

    // Adjust barcode size based on paper width
    bool is58mm = selectedPaperSize == '58mm';
    int barcodeHeight = is58mm ? 20 : 30; // Smaller height for 58mm

    try {
      // Use CODE39 which supports: '0'–'9', A–Z, SP, $, %, *, +, -, ., /
      // Keep the hyphen as CODE39 supports it
      String cleanOrderNumber =
          orderNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
      if (cleanOrderNumber.isNotEmpty) {
        List<String> code39Data = cleanOrderNumber.split("");
        bytes += generator.barcode(
          Barcode.code39(code39Data),
          height: barcodeHeight,
          width: 1,
          textPos: BarcodeText.none,
          align: PosAlign.center,
        );
        debugPrint(
            "Generated CODE39 barcode with data: $cleanOrderNumber (height: $barcodeHeight)");
      } else {
        debugPrint("No valid characters for barcode, displaying as text");
      }
    } catch (e) {
      debugPrint(
          "Error generating CODE39 barcode: $e, displaying as text fallback");

      // Final fallback: Just display the order number as text
      bytes += generator.text(orderNumber,
          styles: PosStyles(
              fontType: fontType, align: PosAlign.center, bold: true));
    }

    return bytes;
  }

  List<int> _buildTermsConditions(
      Generator generator,
      Map<String, DisplayOption>? displayConfig,
      DocumentConfig? billDocumentConfig,
      String selectedPaperSize,
      PosFontType fontType) {
    if (displayConfig?['showTermsConditions']?.visible != true) {
      debugPrint("Terms & Conditions disabled in settings, skipping");
      return [];
    }

    // Get terms from displayConfig value first, then fallback to billDocumentConfig
    String? terms = displayConfig?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      // Fallback to billDocumentConfig terms
      terms = billDocumentConfig?.terms;
    }

    if (terms == null || terms.trim().isEmpty) {
      debugPrint("No Terms & Conditions data available from API, skipping");
      return [];
    }

    debugPrint(
        "Generating Terms & Conditions (enabled in settings with data): $terms");

    List<int> bytes = [];

    // Add separator line before terms
    bytes += generator.hr();

    // Determine character limit based on paper size
    int maxCharsPerLine = selectedPaperSize == '58mm'
        ? 38
        : 52; // More optimal for each paper size

    // Use the terms from displayConfig or DocumentConfig
    List<String> termsList = terms.split('\n');
    for (var term in termsList) {
      if (term.trim().isNotEmpty) {
        String termText = term.trim();

        // Let the printer handle wrapping automatically if text is not too long
        if (termText.length <= maxCharsPerLine) {
          // Short text - let printer handle it naturally
          bytes += generator.text(termText,
              styles: PosStyles(
                  fontType: fontType,
                  align: PosAlign.left,
                  bold: false,
                  height: textSizeSmall));
        } else {
          // Long text - manual word wrapping to prevent awkward breaks
          List<String> words = termText.split(' ');
          String currentLine = '';

          for (String word in words) {
            String testLine = currentLine.isEmpty ? word : '$currentLine $word';
            if (testLine.length <= maxCharsPerLine) {
              currentLine = testLine;
            } else {
              // Current line is full, print it and start new line
              if (currentLine.isNotEmpty) {
                bytes += generator.text(currentLine,
                    styles: PosStyles(
                        fontType: fontType,
                        align: PosAlign.left,
                        bold: false,
                        height: textSizeSmall));
              }
              currentLine = word;
            }
          }

          // Print the last line if not empty
          if (currentLine.isNotEmpty) {
            bytes += generator.text(currentLine,
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.left,
                    bold: false,
                    height: textSizeSmall));
          }
        }
      }
    }

    // Add separator line after terms
    bytes += generator.hr();
    return bytes;
  }

  void _debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    if (displayConfig == null) {
      debugPrint("ERROR: Display configuration is null!");
      return;
    }

    debugPrint("Current display settings (from Bill config):");
    displayConfig.forEach((key, value) {
      debugPrint("- $key: visible=${value.visible}, value=${value.value}");
    });
  }
}
