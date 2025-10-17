import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/order_details.dart';

class ThermalPrinter {
  final BuildContext context;
  var printerManager = PrinterManager.instance;

  // Font configuration - default fallback (will be overridden by user preference)
  static const PosFontType defaultFontType = PosFontType.fontB;

  // Text size variables for consistent sizing
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  ThermalPrinter(this.context);

  String _sanitizeTextForThermalPrinter(String text) {
    return text
        // Replace em dash with regular hyphen
        .replaceAll('–', '-')
        .replaceAll('—', '-') // en dash as well
        // Replace other problematic Unicode characters
        .replaceAll('“', '"') // smart quotes to regular quotes
        .replaceAll('”', '"')
        .replaceAll('‘', "'") // smart apostrophes
        .replaceAll('’', "'")
        .replaceAll('…', '...') // ellipsis
        // Remove any remaining non-printable characters except basic punctuation
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  // Removed _maskPhone - now using StringHelper.maskStringShowLast4

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
      await _connectToPrinter(selectedPrinter);
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

      debugPrint("Starting to build receipt sections...");

      // Pass the display config, document config, and selected font type to helper functions
      debugPrint("Building header...");
      bytes += _buildHeader(generator, displayConfig, billDocumentConfig,
          orderDate, orderNumber, selectedFontType);
      debugPrint("Header built successfully");

      // Build customer details if available
      if (customerName != null ||
          customerPhone != null ||
          customerEmail != null) {
        debugPrint("Building customer details...");
        bytes += _buildCustomerDetails(generator, customerName, customerPhone,
            customerEmail, customerAddress, selectedFontType);
        debugPrint("Customer details built successfully");
      }

      debugPrint("Building cart items...");
      bytes += _buildCartItems(
          generator,
          cartItems,
          displayConfig,
          isFromLocalStorage,
          selectedPaperSize,
          billDocumentConfig,
          selectedFontType);
      debugPrint("Cart items built successfully");

      debugPrint("Building total amount...");
      bytes += _buildTotalAmount(
          generator,
          displayConfig,
          formattedTotal,
          savedTotal,
          discountAmount,
          cartItems.length,
          billDocumentConfig,
          cartItems,
          isFromLocalStorage,
          selectedFontType);
      debugPrint("Total amount built successfully");

      // Add Order Returns section if orderReturns is not null and has items
      if (orderReturns != null &&
          orderReturns.returnItems != null &&
          orderReturns.returnItems!.isNotEmpty) {
        debugPrint("Building order returns section...");
        bytes += _buildOrderReturnsSection(
          generator,
          orderReturns,
          cartItems,
          isFromLocalStorage,
          selectedPaperSize,
          selectedFontType,
          displayConfig,
        );
        debugPrint("Order returns section built successfully");
      }

      // Add Total Summary section ONLY when there are returns
      if (orderReturns != null &&
          orderReturns.returnItems != null &&
          orderReturns.returnItems!.isNotEmpty) {
        debugPrint("Building total summary section...");
        bytes += _buildTotalSummarySection(
          generator,
          formattedTotal,
          orderReturns,
          cartItems,
          isFromLocalStorage,
          selectedFontType,
          displayConfig,
        );
        debugPrint("Total summary section built successfully");
      } else {
        // Add Amount in words under order summary when there are no returns
        // Use 'showAmountInWords' for regular bills (no returns)
        if (displayConfig?['showAmountInWords']?.visible == true) {
          debugPrint("Building amount in words (no returns scenario)...");
          bytes += _buildAmountInWords(
            generator,
            double.parse(formattedTotal),
            selectedFontType,
          );
          debugPrint("Amount in words built successfully");
        }
      }

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

        debugPrint("Building QR code...");
        bytes += _buildQRCode(generator, manualPaymentGateway.link,
            formattedTotal, orderNumber, displayConfig, selectedFontType);
        debugPrint("QR code built successfully");
      } else {
        debugPrint("Skipping QR code, disabled in settings");
        debugPrint(
            "Display config showQRCode visible: ${displayConfig?['showQRCode']?.visible}");
      }

      // Date and Time (moved to bottom, just above barcode)
      debugPrint("Building date/time row...");
      bytes += _buildDateTimeRow(generator, orderDate, selectedFontType);
      debugPrint("Date/time row built successfully");

      // Order ID Barcode (just before Terms & Conditions)
      debugPrint("Building order barcode...");
      bytes += _buildOrderBarcode(
          generator, orderNumber, selectedPaperSize, selectedFontType);
      debugPrint("Order barcode built successfully");

      // Terms & Conditions
      if (displayConfig?['showTermsConditions']?.visible == true) {
        debugPrint("Building terms & conditions...");
        bytes += _buildTermsConditions(generator, displayConfig,
            billDocumentConfig, selectedPaperSize, selectedFontType);
        debugPrint("Terms & conditions built successfully");
      } else {
        debugPrint("Skipping Terms & Conditions, disabled in settings");
      }

      // Thank You Message (moved to end after Terms & Conditions)
      if (displayConfig?['showThankYouMessage']?.visible == true) {
        debugPrint("Building thank you message...");
        bytes +=
            _buildThankYouMessage(generator, displayConfig, selectedFontType);
        debugPrint("Thank you message built successfully");
      }

      // Cut the receipt
      bytes += generator.cut();

      debugPrint("Receipt generated, sending to printer...");
      // Print receipt
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
      await _disconnectPrinter(selectedPrinter);
      debugPrint("==========================");
    }
  }

  // Add this new method to build the order returns section
  List<int> _buildOrderReturnsSection(
    Generator generator,
    OrderReturns orderReturns,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    String selectedPaperSize,
    PosFontType fontType,
    Map<String, DisplayOption>? displayConfig,
  ) {
    List<int> bytes = [];

    debugPrint("===== BUILD ORDER RETURNS SECTION =====");
    debugPrint("Return items count: ${orderReturns.returnItems!.length}");

    // Add spacing before return section
    bytes += generator.emptyLines(2);

    // Returns heading
    bytes += generator.text(
      'RETURNS',
      styles: PosStyles(
        fontType: fontType,
        align: PosAlign.center,
        bold: true,
        height: textSizeSmall,
        width: textSizeSmall,
      ),
    );

    bytes += generator.emptyLines(1);

    // Create headers for the return table using Sales Return Bill configuration
    // Priority: displayConfig value > resolved_labels > default
    String slNumberLabel = (displayConfig?['showReturnSLNumber']?.value as String?)?.isNotEmpty == true
        ? displayConfig!['showReturnSLNumber']!.value as String
        : (displayConfig?['showReturnSLNumber']?.visible == true 
            ? 'Sl#' 
            : 'Sl#');
    
    String particularsLabel = (displayConfig?['showReturnParticulars']?.value as String?)?.isNotEmpty == true
        ? displayConfig!['showReturnParticulars']!.value as String
        : (displayConfig?['showReturnParticulars']?.visible == true 
            ? 'DESCRIPTION' 
            : 'DESCRIPTION');
    
    String mrpLabel = (displayConfig?['showReturnMRP']?.value as String?)?.isNotEmpty == true
        ? displayConfig!['showReturnMRP']!.value as String
        : (displayConfig?['showReturnMRP']?.visible == true 
            ? 'MRP' 
            : 'MRP');
    
    String qtyLabel = (displayConfig?['showReturnQty']?.value as String?)?.isNotEmpty == true
        ? displayConfig!['showReturnQty']!.value as String
        : (displayConfig?['showReturnQty']?.visible == true 
            ? 'QTY' 
            : 'QTY');
    
    String amountLabel = (displayConfig?['showReturnTotal']?.value as String?)?.isNotEmpty == true
        ? displayConfig!['showReturnTotal']!.value as String
        : (displayConfig?['showReturnTotal']?.visible == true 
            ? 'AMOUNT' 
            : 'AMOUNT');

    List<PosColumn> headerColumns = [
      PosColumn(
        text: slNumberLabel,
        width: 1,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: particularsLabel,
        width: 4,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: mrpLabel,
        width: 2,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: qtyLabel,
        width: 2,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: amountLabel,
        width: 3,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
    ];

    bytes += generator.row(headerColumns);
    bytes += generator.hr();

    // Calculate individual item rates and amounts by matching with original cart items
    double calculatedReturnTotal = 0.0;

    for (var i = 0; i < orderReturns.returnItems!.length; i++) {
      final returnItem = orderReturns.returnItems![i];
      final itemQuantity = returnItem.quantity ?? 0;

      // Try to find matching original cart item by product name
      double itemMrp = 0.0;
      double itemRate = 0.0;
      double itemAmount = 0.0;

      // Look for matching item in cartItems
      for (var cartItem in cartItems) {
        String cartItemProductName = '';
        double cartItemUnitPrice = 0.0;

        if (isFromLocalStorage) {
          cartItemProductName = cartItem['productName'] ?? '';
          cartItemUnitPrice =
              double.tryParse(cartItem['unitPrice']?.toString() ?? '0') ?? 0.0;
        } else {
          // Handle different object types
          if (cartItem is Map<String, dynamic>) {
            cartItemProductName = cartItem['product_name']?.toString() ??
                cartItem['productName']?.toString() ??
                '';
            cartItemUnitPrice = double.tryParse(
                    cartItem['unit_price']?.toString() ??
                        cartItem['unitPrice']?.toString() ??
                        '0') ??
                0.0;
          } else {
            try {
              cartItemProductName = cartItem.productName?.toString() ?? '';
              cartItemUnitPrice =
                  double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
            } catch (e) {
              cartItemProductName = '';
              cartItemUnitPrice = 0.0;
            }
          }
        }

        // If product names match, use the original unit price and MRP
        if (cartItemProductName == returnItem.productName) {
          itemRate = cartItemUnitPrice;
          
          // Fetch MRP from cartItem
          if (isFromLocalStorage) {
            itemMrp = double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
          } else {
            if (cartItem is Map<String, dynamic>) {
              itemMrp = double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
            } else {
              try {
                itemMrp = double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0;
              } catch (e) {
                itemMrp = 0.0;
              }
            }
          }
          
          itemAmount = itemQuantity * itemRate;
          calculatedReturnTotal += itemAmount;
          break;
        }
      }

      // If no match found, fall back to average rate calculation
      if (itemRate == 0.0 && itemAmount == 0.0) {
        final totalReturnAmount =
            double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;

        int totalQuantity = 0;
        for (var item in orderReturns.returnItems!) {
          totalQuantity += item.quantity ?? 0;
        }

        final averageRate =
            totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
        itemAmount = itemQuantity * averageRate;
        calculatedReturnTotal += itemAmount;
        itemRate = averageRate;
      }

      // Build return item row
      List<PosColumn> returnItemColumns = [
        PosColumn(
          text: (i + 1).toString(),
          width: 1,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: false,
            height: textSizeSmall,
          ),
        ),
        PosColumn(
          text: _sanitizeTextForThermalPrinter(returnItem.productName ?? ''),
          width: 4,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: false,
            height: textSizeSmall,
          ),
        ),
        PosColumn(
          text: itemMrp.toStringAsFixed(2),
          width: 2,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: false,
            height: textSizeSmall,
          ),
        ),
        PosColumn(
          text: itemQuantity.toString(),
          width: 2,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: false,
            height: textSizeSmall,
          ),
        ),
        PosColumn(
          text: itemAmount.toStringAsFixed(2),
          width: 3,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: false,
            height: textSizeSmall,
          ),
        ),
      ];

      bytes += generator.row(returnItemColumns);
    }

    bytes += generator.hr();
    bytes += generator.emptyLines(1);

    // Return Summary heading removed per request

    // Return summary details
    List<PosColumn> returnSummaryColumns1 = [
      PosColumn(
        text: 'Total Items:',
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: orderReturns.returnItems!.length.toString(),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
    ];

    List<PosColumn> returnSummaryColumns2 = [
      PosColumn(
        text: 'Total MRP:',
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: calculatedReturnTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
    ];

    bytes += generator.row(returnSummaryColumns1);
    bytes += generator.row(returnSummaryColumns2);
    bytes += generator.hr();

    List<PosColumn> returnNetTotalColumns = [
      PosColumn(
        text: 'Net Total:',
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: calculatedReturnTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
    ];

    bytes += generator.row(returnNetTotalColumns);
    bytes += generator.emptyLines(2);

    debugPrint("===== END BUILD ORDER RETURNS SECTION =====");
    return bytes;
  }

  // Add this new method to build the total summary section
  List<int> _buildTotalSummarySection(
    Generator generator,
    String formattedTotal,
    OrderReturns orderReturns,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    PosFontType fontType,
    Map<String, DisplayOption>? displayConfig,
  ) {
    List<int> bytes = [];

    debugPrint("===== BUILD TOTAL SUMMARY SECTION =====");

    // Parse the order total
    double orderTotal = double.tryParse(formattedTotal) ?? 0.0;

    // Calculate return total
    double returnTotal = 0.0;
    if (orderReturns.returnItems != null &&
        orderReturns.returnItems!.isNotEmpty) {
      for (var i = 0; i < orderReturns.returnItems!.length; i++) {
        final returnItem = orderReturns.returnItems![i];
        final itemQuantity = returnItem.quantity ?? 0;

        // Try to find matching original cart item by product name
        double itemRate = 0.0;

        for (var cartItem in cartItems) {
          String cartItemProductName = '';
          double cartItemUnitPrice = 0.0;

          if (isFromLocalStorage) {
            cartItemProductName = cartItem['productName'] ?? '';
            cartItemUnitPrice =
                double.tryParse(cartItem['unitPrice']?.toString() ?? '0') ??
                    0.0;
          } else {
            if (cartItem is Map<String, dynamic>) {
              cartItemProductName = cartItem['product_name']?.toString() ??
                  cartItem['productName']?.toString() ??
                  '';
              cartItemUnitPrice = double.tryParse(
                      cartItem['unit_price']?.toString() ??
                          cartItem['unitPrice']?.toString() ??
                          '0') ??
                  0.0;
            } else {
              try {
                cartItemProductName = cartItem.productName?.toString() ?? '';
                cartItemUnitPrice =
                    double.tryParse(cartItem.unitPrice?.toString() ?? '0') ??
                        0.0;
              } catch (e) {
                cartItemProductName = '';
                cartItemUnitPrice = 0.0;
              }
            }
          }

          if (cartItemProductName == returnItem.productName) {
            itemRate = cartItemUnitPrice;
            returnTotal += itemQuantity * itemRate;
            break;
          }
        }

        // If no match found, use average rate calculation
        if (itemRate == 0.0 && orderReturns.returnTotalAmount != null) {
          final totalReturnAmount =
              double.tryParse(orderReturns.returnTotalAmount ?? '0.00') ?? 0.0;

          int totalQuantity = 0;
          for (var item in orderReturns.returnItems!) {
            totalQuantity += item.quantity ?? 0;
          }

          final averageRate =
              totalQuantity > 0 ? totalReturnAmount / totalQuantity : 0.0;
          returnTotal += itemQuantity * averageRate;
        }
      }
    }

    // Calculate final total (order total - return total)
    double finalTotal = orderTotal - returnTotal;

    bytes += generator.emptyLines(1);
    // TOTAL SUMMARY heading removed per request
    // bytes += generator.text(
    //   'TOTAL SUMMARY',
    //   styles: PosStyles(
    //     fontType: fontType,
    //     align: PosAlign.center,
    //     bold: true,
    //     height: textSizeMedium,
    //     width: textSizeMedium,
    //   ),
    // );

    bytes += generator.emptyLines(1);

    // Use Sales Return Bill configuration labels
    String purchaseLabel = (displayConfig?['showFinalPurchase']?.value as String?) ?? 'Order Total:';
    String returnLabel = (displayConfig?['showFinalReturn']?.value as String?) ?? 'Return Total:';
    String finalTotalLabel = (displayConfig?['showFinalNetAmount']?.value as String?) ?? 'Final Total:';

    // Order Total (Purchase)
    List<PosColumn> orderTotalColumns = [
      PosColumn(
        text: purchaseLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: orderTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
    ];

    bytes += generator.row(orderTotalColumns);

    // Return Total
    List<PosColumn> returnTotalColumns = [
      PosColumn(
        text: returnLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: returnTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
    ];

    bytes += generator.row(returnTotalColumns);
    bytes += generator.hr();

    // Final Total
    List<PosColumn> finalTotalColumns = [
      PosColumn(
        text: finalTotalLabel,
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeSmall,
        ),
      ),
      PosColumn(
        text: finalTotal.toStringAsFixed(2),
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeSmall,
        ),
      ),
    ];

    bytes += generator.row(finalTotalColumns);

    // Amount in words for final total (when there are returns)
    // Use 'showFinalAmountInWords' for Sales Return Bill configuration
    if (displayConfig?['showFinalAmountInWords']?.visible == true) {
      debugPrint("Building final amount in words (returns scenario)...");
      bytes += _buildAmountInWords(generator, finalTotal, fontType);
    }

    bytes += generator.emptyLines(1);

    debugPrint("===== END BUILD TOTAL SUMMARY SECTION =====");
    return bytes;
  }

  // Helper method for amount in words
  List<int> _buildAmountInWords(
    Generator generator,
    double amount,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    bytes += generator.emptyLines(1);
    bytes += generator.text(
      'Amount in words:',
      styles: PosStyles(
        fontType: fontType,
        align: PosAlign.left,
        bold: true,
        height: textSizeSmall,
      ),
    );

    String amountInWords =
        '${AmountHelper().convertNumberToWords(amount)} Only.';

    // Wrap long amount in words text
    int maxCharsPerLine = 48;
    if (amountInWords.length <= maxCharsPerLine) {
      bytes += generator.text(
        amountInWords,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: false,
          height: textSizeSmall,
        ),
      );
    } else {
      String remainingText = amountInWords;
      while (remainingText.isNotEmpty) {
        String currentLine;
        if (remainingText.length <= maxCharsPerLine) {
          currentLine = remainingText;
          remainingText = '';
        } else {
          int breakPoint = maxCharsPerLine;
          for (int i = maxCharsPerLine - 1;
              i >= maxCharsPerLine - 10 && i >= 0;
              i--) {
            if (i < remainingText.length && remainingText[i] == ' ') {
              breakPoint = i;
              break;
            }
          }
          currentLine = remainingText.substring(0, breakPoint).trim();
          remainingText = remainingText.substring(breakPoint).trim();
        }
        bytes += generator.text(
          currentLine,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: false,
            height: textSizeSmall,
          ),
        );
      }
    }

    return bytes;
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
              width: textSizeMedium,
              height: textSizeMedium),
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
            bold: false,
            height: textSizeSmall,
            width: textSizeSmall,
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
              bold: false,
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
              bold: false,
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
                bold: false,
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
                bold: false,
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
      bytes +=
          generator.text(invoiceTitle.isNotEmpty ? invoiceTitle : 'INVOICE',
              styles: PosStyles(
                fontType: fontType,
                align: PosAlign.center,
                bold: true,
                height: textSizeSmall,
                width: textSizeSmall,
              ));
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
              height: textSizeSmall,
              width: textSizeSmall));

      bytes += generator.emptyLines(1);
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

    debugPrint("===== BUILD CART ITEMS DEBUG =====");
    debugPrint("Cart items count: ${cartItems.length}");
    debugPrint("Selected paper size: $selectedPaperSize");
    debugPrint("Is from local storage: $isFromLocalStorage");

    // Determine if we're using 58mm paper for font size adjustment
    bool is58mm = selectedPaperSize == '58mm';

    // Add table headers with fixed widths
    List<PosColumn> headerColumns = [];
    int totalHeaderWidth = 0;

    debugPrint("Building header columns...");

    if (displayConfig?['showSLNumber']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final slLabel =
          (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSLNumber']!.value as String
              : (billDocumentConfig?.resolvedLabels?.slNumber?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.slNumber!
                  : 'SL#');
      headerColumns.add(PosColumn(
          text: slLabel,
          width: 1,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
      totalHeaderWidth += 1;
      debugPrint(
          "Added SL column with width 1, total width: $totalHeaderWidth");
    }

    if (displayConfig?['showParticulars']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showParticulars']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showParticulars']!.value as String
              : (billDocumentConfig?.resolvedLabels?.particulars?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.particulars!
                  : 'PARTICULARS');
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
      totalHeaderWidth += particularsWidth;
      debugPrint(
          "Added PARTICULARS column with width $particularsWidth, total width: $totalHeaderWidth");
    }

    if (displayConfig?['showMRP']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : (billDocumentConfig?.resolvedLabels?.mrp?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.mrp!
                  : 'MRP');
      headerColumns.add(PosColumn(
          text: mrpLabel.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
      totalHeaderWidth += 2;
      debugPrint(
          "Added MRP column with width 2, total width: $totalHeaderWidth");
    }

    if (displayConfig?['showQty']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : (billDocumentConfig?.resolvedLabels?.qty?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.qty!
                  : 'QTY');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
      totalHeaderWidth += 2;
      debugPrint(
          "Added QTY column with width 2, total width: $totalHeaderWidth");
    }

    if (displayConfig?['showRate']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : (billDocumentConfig?.resolvedLabels?.rate?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.rate!
                  : 'RATE');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
      totalHeaderWidth += 2;
      debugPrint(
          "Added RATE column with width 2, total width: $totalHeaderWidth");
    }

    if (displayConfig?['showTotal']?.visible == true) {
      // Use displayConfig value first, then fallback to resolved_labels, then default
      final label =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : (billDocumentConfig?.resolvedLabels?.total?.isNotEmpty == true
                  ? billDocumentConfig!.resolvedLabels!.total!
                  : 'TOTAL');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
      totalHeaderWidth += 2;
      debugPrint(
          "Added TOTAL column with width 2, total width: $totalHeaderWidth");
    }

    debugPrint("Final header total width: $totalHeaderWidth");
    if (totalHeaderWidth != 12) {
      debugPrint(
          "ERROR: Header columns width ($totalHeaderWidth) is not equal to 12!");
    }

    if (headerColumns.isNotEmpty) {
      debugPrint("Adding header row with ${headerColumns.length} columns");
      bytes += generator.row(headerColumns);
      bytes += generator.hr();
    }

    // Process each cart item
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];
      debugPrint("Processing cart item $i...");

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
      debugPrint(
          "Item $i: $productName, MRP: $mrp, Qty: $quantity, Rate: $unitPrice, Total: $totalPrice");

      // Product Name Row using date/time row approach (SL + Product Name in one column, empty space in second column)
      if (displayConfig?['showParticulars']?.visible == true ||
          displayConfig?['showSLNumber']?.visible == true) {
        debugPrint("Building product name row...");
        // Calculate character limit based on 48-character printer width
        // Using 6+6 column split like date/time row
        int maxCharsPerLine = 40; // Half of 48 characters for the first column

        // Build the left column text (SL + Product Name)
        String leftColumnText = '';
        if (displayConfig?['showSLNumber']?.visible == true &&
            displayConfig?['showParticulars']?.visible == true) {
          // Both SL and product name
          leftColumnText =
              '$slNumber ${_sanitizeTextForThermalPrinter(productName)}';
        } else if (displayConfig?['showSLNumber']?.visible == true) {
          // Only SL number
          leftColumnText = slNumber;
        } else {
          // Only product name
          leftColumnText = _sanitizeTextForThermalPrinter(productName);
        }

        debugPrint(
            "Left column text: '$leftColumnText' (length: ${leftColumnText.length})");

        if (leftColumnText.length <= maxCharsPerLine) {
          // Text fits in one line - use the date/time row approach
          debugPrint("Text fits in one line, using 11+1 column layout");
          List<PosColumn> productRow = [
            PosColumn(
                text: leftColumnText,
                width: 11,
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.left,
                    bold: false,
                    height: is58mm ? textSizeSmall : textSizeSmall)),
            PosColumn(
                text: '', // Empty space like in date/time row
                width: 1,
                styles: PosStyles(
                    fontType: fontType,
                    align: PosAlign.right,
                    bold: false,
                    height: is58mm ? textSizeSmall : textSizeSmall)),
          ];
          debugPrint("Product row total width: ${11 + 1}");
          bytes += generator.row(productRow);
        } else {
          // Text needs wrapping - split into multiple lines
          debugPrint("Text needs wrapping, splitting into multiple lines");
          String remainingText = leftColumnText;

          while (remainingText.isNotEmpty) {
            String currentLine;

            if (remainingText.length <= maxCharsPerLine) {
              currentLine = remainingText;
              remainingText = '';
            } else {
              // Find a good break point (prefer breaking at spaces)
              int breakPoint = maxCharsPerLine;

              for (int i = maxCharsPerLine - 1;
                  i >= maxCharsPerLine - 10 && i >= 0;
                  i--) {
                if (i < remainingText.length && remainingText[i] == ' ') {
                  breakPoint = i;
                  break;
                }
              }

              currentLine = remainingText.substring(0, breakPoint).trim();
              remainingText = remainingText.substring(breakPoint).trim();
            }

            debugPrint("Wrapped line: '$currentLine'");
            List<PosColumn> wrappedRow = [
              PosColumn(
                  text: currentLine,
                  width: 11,
                  styles: PosStyles(
                      fontType: fontType,
                      align: PosAlign.left,
                      bold: false,
                      height: is58mm ? textSizeSmall : textSizeSmall)),
              PosColumn(
                  text: '', // Empty space
                  width: 1,
                  styles: PosStyles(
                      fontType: fontType,
                      align: PosAlign.right,
                      bold: false,
                      height: is58mm ? textSizeSmall : textSizeSmall)),
            ];
            debugPrint("Wrapped row total width: ${11 + 1}");
            bytes += generator.row(wrappedRow);
          }
        }
      }

      // Second row: Price details
      debugPrint("Building price details row...");
      List<PosColumn> priceDetailsRow = [];
      int priceRowWidth = 0;

      // Add empty space for SL column (width 1)
      // if (displayConfig?['showSLNumber']?.visible == true) {
      priceDetailsRow.add(PosColumn(
          text: '',
          width: 4,
          styles: PosStyles(fontType: fontType, align: PosAlign.left)));
      priceRowWidth += 4;
      debugPrint(
          "Added empty space column with width 4, total width: $priceRowWidth");
      // }

      // Add price columns with the old working widths (like your old code)
      if (displayConfig?['showMRP']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: mrp,
            width: 2, // Back to 3 like your old working code
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
        priceRowWidth += 2;
        debugPrint(
            "Added MRP column with width 2, total width: $priceRowWidth");
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
        priceRowWidth += 2;
        debugPrint(
            "Added QTY column with width 2, total width: $priceRowWidth");
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: unitPrice,
            width: 2, // Back to 3 like your old working code
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
        priceRowWidth += 2;
        debugPrint(
            "Added RATE column with width 2, total width: $priceRowWidth");
      }
      if (displayConfig?['showTotal']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: totalPrice,
            width: 2, // Back to 3 like your old working code
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
        priceRowWidth += 2;
        debugPrint(
            "Added TOTAL column with width 2, total width: $priceRowWidth");
      }

      debugPrint("Final price row total width: $priceRowWidth");
      if (priceRowWidth != 12) {
        debugPrint(
            "ERROR: Price row columns width ($priceRowWidth) is not equal to 12!");
      }

      if (priceDetailsRow.isNotEmpty) {
        debugPrint(
            "Adding price details row with ${priceDetailsRow.length} columns");
        bytes += generator.row(priceDetailsRow);
      }
    }

    bytes += generator.hr();
    debugPrint("===== END BUILD CART ITEMS DEBUG =====");
    return bytes;
  }

  List<int> _buildTotalAmount(
      Generator generator,
      Map<String, DisplayOption>? displayConfig,
      String formattedTotal,
      String? savedTotal,
      String? discountAmount,
      int itemCount,
      DocumentConfig? billDocumentConfig,
      List<dynamic> cartItems,
      bool isFromLocalStorage,
      PosFontType fontType) {
    List<int> bytes = [];

    debugPrint("===== BUILD TOTAL AMOUNT DEBUG =====");
    debugPrint("Formatted total: $formattedTotal");
    debugPrint("Saved total: $savedTotal");
    debugPrint("Discount amount: $discountAmount");
    debugPrint("Item count: $itemCount");

    double saved = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(formattedTotal) ?? 0.0;
    double discountAmountValue =
        double.tryParse(discountAmount ?? '0.0') ?? 0.0;
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

    debugPrint(
        "Calculated values - Saved: $saved, Total: $total, Total MRP: $totalMrp, Total Qty: $totalQuantity");

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
        'bold': 'false',
        'fontStyle': 'normal',
        'fontType': 'fontA' // Default font type
      });
      debugPrint("Added left side item: Items = $itemCount");
    }

    leftSideItems.add({
      'label': 'Total Qty',
      'value': totalQuantity % 1 == 0
          ? totalQuantity.toInt().toString()
          : totalQuantity.toStringAsFixed(2),
      'textSize': 'small',
      'bold': 'false',
      'fontStyle': 'normal',
      'fontType': 'fontA' // Default font type
    });
    debugPrint(
        "Added left side item: Total Qty = ${totalQuantity % 1 == 0 ? totalQuantity.toInt().toString() : totalQuantity.toStringAsFixed(2)}");

    // Right side items
    if (displayConfig?['showMRPTotal']?.visible == true) {
      rightSideItems.add({
        'label': 'Total MRP',
        'value': totalMrp.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'false',
        'fontStyle': 'normal',
        'fontType': 'fontA' // Different font type for MRP
      });
      debugPrint(
          "Added right side item: Total MRP = ${totalMrp.toStringAsFixed(2)}");
    }

    if (displayConfig?['showDiscount']?.visible == true) {
      rightSideItems.add({
        'label': 'Discount',
        'value': discountAmountValue.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'false',
        'fontStyle': 'normal',
        'fontType': 'fontA' // Default font type
      });
      debugPrint(
          "Added right side item: Discount = ${discountAmountValue.toStringAsFixed(2)}");
    }

    if (displayConfig?['showNetAmount']?.visible == true) {
      rightSideItems.add({
        'label': 'Net Total',
        'value': total.toStringAsFixed(2),
        'textSize': 'small',
        'bold': 'true',
        'fontType': 'fontA' // Different font type for Net Total
      });
      debugPrint(
          "Added right side item: Net Total = ${total.toStringAsFixed(2)}");
    }

    debugPrint("Left side items count: ${leftSideItems.length}");
    debugPrint("Right side items count: ${rightSideItems.length}");

    // Generate rows with vertical division (5-1-6 columns: left section, gap, right section)
    int maxRows = leftSideItems.length > rightSideItems.length
        ? leftSideItems.length
        : rightSideItems.length;

    debugPrint("Will generate $maxRows rows");

    for (int i = 0; i < maxRows; i++) {
      debugPrint("Generating row $i...");
      List<PosColumn> columns = [];
      int rowWidth = 0;

      // Left side (first 5 columns: 2 for label + 3 for value)
      if (i < leftSideItems.length) {
        final leftItem = leftSideItems[i];
        PosTextSize textSize = leftItem['textSize'] == 'big'
            ? textSizeBig
            : leftItem['textSize'] == 'medium'
                ? textSizeMedium
                : textSizeSmall;
        bool isBold = leftItem['bold'] == 'true';
        // Get custom font type if specified, otherwise use the default
        PosFontType itemFontType = leftItem['fontType'] == 'fontA'
            ? PosFontType.fontA
            : PosFontType.fontB;

        // Combine label and value with a colon
        String labelText = '${leftItem['label']!}: ';

        columns.add(PosColumn(
            text: labelText,
            width: 3,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.left,
                bold: isBold,
                height: textSize)));
        rowWidth += 3;
        debugPrint(
            "Added left label column with width 3, row width: $rowWidth");

        columns.add(PosColumn(
            text: leftItem['value']!,
            width: 1,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.right,
                bold: true,
                height: textSize)));
        rowWidth += 1;
        debugPrint(
            "Added left value column with width 1, row width: $rowWidth");
      } else {
        // Empty left side
        columns.add(PosColumn(
            text: '', width: 2, styles: PosStyles(fontType: fontType)));
        rowWidth += 2;
        debugPrint(
            "Added empty left column with width 2, row width: $rowWidth");

        columns.add(PosColumn(
            text: '', width: 2, styles: PosStyles(fontType: fontType)));
        rowWidth += 2;
        debugPrint(
            "Added empty left column with width 2, row width: $rowWidth");
      }

      // Gap column (1 column for spacing)
      columns.add(
          PosColumn(text: '', width: 2, styles: PosStyles(fontType: fontType)));
      rowWidth += 2;
      debugPrint("Added gap column with width 2, row width: $rowWidth");

      // Right side (last 6 columns: 3 for label + 3 for value)
      if (i < rightSideItems.length) {
        final rightItem = rightSideItems[i];
        PosTextSize textSize = rightItem['textSize'] == 'big'
            ? textSizeBig
            : rightItem['textSize'] == 'medium'
                ? textSizeMedium
                : textSizeSmall;
        bool isBold = rightItem['bold'] == 'true';
        // Get custom font type if specified, otherwise use the default
        PosFontType itemFontType = rightItem['fontType'] == 'fontA'
            ? PosFontType.fontA
            : PosFontType.fontB;

        // Combine label and value with a colon
        String labelText = '${rightItem['label']!}: ';

        columns.add(PosColumn(
            text: labelText,
            width: 3,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.left,
                bold: isBold,
                height: textSize,
                width: textSize)));
        rowWidth += 3;
        debugPrint(
            "Added right label column with width 3, row width: $rowWidth");

        columns.add(PosColumn(
            text: rightItem['value']!,
            width: 3,
            styles: PosStyles(
                fontType: itemFontType,
                align: PosAlign.right,
                bold: isBold,
                height: textSize,
                width: textSize)));
        rowWidth += 3;
        debugPrint(
            "Added right value column with width 3, row width: $rowWidth");
      } else {
        // Empty right side
        columns.add(PosColumn(
            text: '', width: 3, styles: PosStyles(fontType: fontType)));
        rowWidth += 3;
        debugPrint(
            "Added empty right column with width 3, row width: $rowWidth");

        columns.add(PosColumn(
            text: '', width: 3, styles: PosStyles(fontType: fontType)));
        rowWidth += 3;
        debugPrint(
            "Added empty right column with width 3, row width: $rowWidth");
      }

      debugPrint("Row $i final width: $rowWidth");
      if (rowWidth != 12) {
        debugPrint(
            "ERROR: Row $i columns width ($rowWidth) is not equal to 12!");
      }

      bytes += generator.row(columns);
    }

    bytes += generator.emptyLines(1);

    //Amount in Words
    if (displayConfig?['showSaved']?.visible == true && saved > 0) {
      bytes += generator.text('You Saved: ${saved.toStringAsFixed(2)}',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall,
              width: textSizeSmall));
    }

    // Add a separator line if any totals were shown
    if ((displayConfig?['showItemsCount']?.visible == true) ||
        (displayConfig?['showMRPTotal']?.visible == true) ||
        (displayConfig?['showSaved']?.visible == true && saved > 0) ||
        (displayConfig?['showDiscount']?.visible == true) ||
        (displayConfig?['showNetAmount']?.visible == true)) {
      bytes += generator.hr();
    }

    // Amount in Words
    // if (displayConfig?['showAmountInWords']?.visible == true) {
    //   bytes += generator.text(
    //       '${AmountHelper().convertNumberToWords(total)} Only.',
    //       styles: PosStyles(
    //           fontType: fontType,
    //           align: PosAlign.center,
    //           bold: true,
    //           height: textSizeSmall));
    // }

    debugPrint("===== END BUILD TOTAL AMOUNT DEBUG =====");
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
              height: textSizeSmall,
              width: textSizeSmall));
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
        size: QRSize.Size4,
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

  double _calculateCartTotal(List<dynamic> cartItems, bool isFromLocalStorage) {
    double total = 0.0;

    for (var item in cartItems) {
      double itemTotal = 0.0;

      if (isFromLocalStorage) {
        itemTotal =
            double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0;
      } else {
        if (item is Map<String, dynamic>) {
          itemTotal = double.tryParse(item['total_price']?.toString() ??
                  item['totalPrice']?.toString() ??
                  '0') ??
              0.0;
        } else {
          try {
            itemTotal =
                double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0;
          } catch (e) {
            debugPrint('Error accessing item totalPrice: $e');
            itemTotal = 0.0;
          }
        }
      }

      total += itemTotal;
    }

    return total;
  }

  // Helper method to build cart total row after items table
  List<int> _buildCartTotalRow(
    Generator generator,
    List<dynamic> cartItems,
    bool isFromLocalStorage,
    PosFontType fontType,
  ) {
    List<int> bytes = [];
    final cartTotal = _calculateCartTotal(cartItems, isFromLocalStorage);

    bytes += generator.row([
      PosColumn(
        text: 'TOTAL:',
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
          height: textSizeMedium,
        ),
      ),
      PosColumn(
        text: 'Rs. ${cartTotal.toStringAsFixed(2)}',
        width: 6,
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.right,
          bold: true,
          height: textSizeMedium,
        ),
      ),
    ]);

    return bytes;
  }

  List<int> _buildDateTimeRow(
      Generator generator, String orderDate, PosFontType fontType) {
    List<int> bytes = [];

    debugPrint("===== BUILD DATE TIME ROW DEBUG =====");
    debugPrint("Order date: $orderDate");

    // Add top divider line
    // bytes += generator.hr();

    // Add date and time row with smaller text size
    debugPrint("Creating date/time row with 6+6 column layout");
    List<PosColumn> dateTimeColumns = [
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
    ];

    int dateTimeRowWidth = 6 + 6;
    debugPrint("Date/time row total width: $dateTimeRowWidth");
    if (dateTimeRowWidth != 12) {
      debugPrint(
          "ERROR: Date/time row columns width ($dateTimeRowWidth) is not equal to 12!");
    }

    bytes += generator.row(dateTimeColumns);

    // Add bottom divider line
    // bytes += generator.hr();

    debugPrint("===== END BUILD DATE TIME ROW DEBUG =====");
    return bytes;
  }

  List<int> _buildOrderBarcode(Generator generator, String orderNumber,
      String selectedPaperSize, PosFontType fontType) {
    List<int> bytes = [];

    debugPrint(
        "Generating Order ID barcode: $orderNumber for $selectedPaperSize paper");

    // Adjust barcode size based on paper width
    bool is58mm = selectedPaperSize == '58mm';
    int barcodeHeight =
        is58mm ? 40 : 30; // Bigger height for 58mm (increased from 20 to 40)

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

    // Use the terms from displayConfig or DocumentConfig
    List<String> termsList = terms.split('\n');

    for (var term in termsList) {
      if (term.trim().isNotEmpty) {
        String termText = term.trim();

        // Calculate character limit based on 48-character printer width
        int maxCharsPerLine =
            48; // Based on your printer's actual character width

        if (termText.length <= maxCharsPerLine) {
          // Text fits in one line
          bytes += generator.row([
            PosColumn(
                text: termText,
                width: 12,
                styles: const PosStyles(
                    fontType:
                        PosFontType.fontB, // Use the passed fontType parameter
                    align: PosAlign.left,
                    bold: false,
                    height: textSizeSmall,
                    width: textSizeSmall)),
          ]);
        } else {
          // Text needs to be wrapped to multiple lines
          String remainingText = termText;

          while (remainingText.isNotEmpty) {
            String currentLine;

            if (remainingText.length <= maxCharsPerLine) {
              currentLine = remainingText;
              remainingText = '';
            } else {
              // Find a good break point (prefer breaking at spaces)
              int breakPoint = maxCharsPerLine;

              for (int i = maxCharsPerLine - 1;
                  i >= maxCharsPerLine - 10 && i >= 0;
                  i--) {
                if (i < remainingText.length && remainingText[i] == ' ') {
                  breakPoint = i;
                  break;
                }
              }

              currentLine = remainingText.substring(0, breakPoint).trim();
              remainingText = remainingText.substring(breakPoint).trim();
            }

            bytes += generator.row([
              PosColumn(
                  text: currentLine,
                  width: 12,
                  styles: const PosStyles(
                      fontType: PosFontType
                          .fontB, // Use the passed fontType parameter
                      align: PosAlign.left,
                      bold: false,
                      height: textSizeSmall,
                      width: textSizeSmall)),
            ]);
          }
        }
      }
    }

    // Add separator line after terms
    bytes += generator.hr();
    return bytes;
  }

  Future<void> _connectToPrinter(BluetoothPrinter selectedPrinter) async {
    if (selectedPrinter.typePrinter == PrinterType.usb) {
      await printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: selectedPrinter.deviceName ?? 'Unknown',
          productId: selectedPrinter.productId,
          vendorId: selectedPrinter.vendorId,
        ),
      );
    } else if (selectedPrinter.typePrinter == PrinterType.bluetooth) {
      if (selectedPrinter.address == null) {
        throw Exception('Bluetooth printer address is null');
      }
      await printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: selectedPrinter.deviceName ?? 'Unknown',
          address: selectedPrinter.address!,
          isBle: false,
        ),
      );
    }
  }

  Future<void> _disconnectPrinter(BluetoothPrinter selectedPrinter) async {
    try {
      await printerManager.disconnect(type: selectedPrinter.typePrinter);
    } catch (e) {
      // Handle disconnection error
    }
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

  // Customer Details Section for Thermal Receipt
  List<int> _buildCustomerDetails(
    Generator generator,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    // Add separator line
    bytes += generator.hr();

    // Customer Details Title
    // bytes += generator.text(
    //   'CUSTOMER DETAILS',
    //   styles: PosStyles(
    //     fontType: fontType,
    //     align: PosAlign.center,
    //     bold: true,
    //     height: textSizeMedium,
    //     width: textSizeMedium,
    //   ),
    // );

    // Customer Name + Phone on a single line without labels when both are present
    if ((customerName != null && customerName.isNotEmpty) &&
        (customerPhone != null && customerPhone.isNotEmpty)) {
      final combined = _sanitizeTextForThermalPrinter(
          '$customerName - ${StringHelper.maskStringShowLast4(customerPhone)}');
      bytes += generator.text(
        combined,
        styles: PosStyles(
          fontType: fontType,
          height: textSizeSmall,
          width: textSizeSmall,
        ),
      );
    } else {
      // Otherwise show whichever exists, without labels
      if (customerName != null && customerName.isNotEmpty) {
        bytes += generator.text(
          _sanitizeTextForThermalPrinter(customerName),
          styles: PosStyles(
            fontType: fontType,
            height: textSizeSmall,
            width: textSizeSmall,
          ),
        );
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        bytes += generator.text(
          _sanitizeTextForThermalPrinter(
              StringHelper.maskStringShowLast4(customerPhone)),
          styles: PosStyles(
            fontType: fontType,
            height: textSizeSmall,
            width: textSizeSmall,
          ),
        );
      }
    }

    // Customer Email
    // if (customerEmail != null && customerEmail.isNotEmpty) {
    //   bytes += generator.text(
    //     'Email: $customerEmail',
    //     styles: PosStyles(
    //       fontType: fontType,
    //       height: textSizeSmall,
    //       width: textSizeSmall,
    //     ),
    //   );
    // }

    // Customer Address without label
    if (customerAddress != null && customerAddress.isNotEmpty) {
      bytes += generator.text(
        _sanitizeTextForThermalPrinter(customerAddress),
        styles: PosStyles(
          fontType: fontType,
          height: textSizeSmall,
          width: textSizeSmall,
        ),
      );
    }

    // Add separator line
    bytes += generator.hr();

    return bytes;
  }
}
