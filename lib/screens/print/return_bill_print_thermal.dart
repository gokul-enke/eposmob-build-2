import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';

class ReturnBillThermalPrinter {
  final BuildContext context;
  var printerManager = PrinterManager.instance;

  // Font configuration - default fallback (will be overridden by user preference)
  static const PosFontType defaultFontType = PosFontType.fontB;

  // Text size variables for consistent sizing (same as sales print)
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  ReturnBillThermalPrinter(this.context);

  String _sanitizeTextForThermalPrinter(String text) {
    return text
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll(''', "'")
        .replaceAll(''', "'")
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  // Load font type from SharedPreferences
  Future<PosFontType> _loadFontType() async {
    final prefs = await SharedPreferences.getInstance();
    final fontStyle =
        prefs.getString('default_font_style') ?? 'Font B (Default)';
    return fontStyle.contains('Font A') ? PosFontType.fontA : PosFontType.fontB;
  }

  Future<void> printReturnBill({
    required BluetoothPrinter selectedPrinter,
    required List<OrderReturnItem> returnItems,
    required String returnTotalAmount,
    required String orderDate,
    required String orderNumber,
    required String selectedPaperSize,
    required DocumentConfig? returnBillDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerBalance,
  }) async {
    debugPrint("===== RETURN BILL THERMAL PRINTING DEBUG =====");

    // Ensure returnBillDocumentConfig is loaded before printing
    if (returnBillDocumentConfig == null) {
      debugPrint("ERROR: Return Bill document configuration not loaded yet.");
      return;
    }

    debugPrint("Printing return bill with thermal printer:");
    debugPrint(
        "Printer: ${selectedPrinter.deviceName} (${selectedPrinter.typePrinter})");
    debugPrint("Paper size: $selectedPaperSize");

    // Use the loaded display configuration
    final displayConfig =
        returnBillDocumentConfig.displayConfiguration?.options;
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

      // Select appropriate paper size
      PaperSize paperSize;
      if (selectedPaperSize == '80mm') {
        paperSize = PaperSize.mm80;
        debugPrint("Using 80mm paper size configuration");
      } else if (selectedPaperSize == '58mm') {
        paperSize = PaperSize.mm58;
        debugPrint("Using 58mm paper size configuration");
      } else {
        paperSize = PaperSize.mm80;
        debugPrint("Using default 80mm paper size configuration");
      }

      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      debugPrint("Starting to build return bill sections...");

      // Build header
      debugPrint("Building header...");
      bytes += _buildHeader(generator, displayConfig, returnBillDocumentConfig,
          orderDate, orderNumber, selectedFontType);
      debugPrint("Header built successfully");

      // Build customer details if available
      if (customerName != null ||
          customerPhone != null ||
          customerEmail != null) {
        debugPrint("Building customer details...");
        bytes += _buildCustomerDetails(
            generator,
            customerName,
            customerPhone,
            customerEmail,
            customerAddress,
            customerBalance,
            selectedFontType,
            displayConfig);
        debugPrint("Customer details built successfully");
      }

      // Build return items table
      debugPrint("Building return items...");
      bytes += _buildReturnItems(generator, returnItems, displayConfig,
          selectedPaperSize, returnBillDocumentConfig, selectedFontType);
      debugPrint("Return items built successfully");

      // Build total amount
      debugPrint("Building total amount...");
      bytes += _buildTotalAmount(generator, displayConfig, returnTotalAmount,
          returnItems.length, returnBillDocumentConfig, selectedFontType);
      debugPrint("Total amount built successfully");

      // QR Code
      if (displayConfig?['showQRCode']?.visible == true) {
        debugPrint("Building QR code...");
        // Check for ZATCA credentials first
        final prefs = await SharedPreferences.getInstance();
        final zatcaVatNumber = prefs.getString('zatca_vat_number');
        final zatcaCompanyName = prefs.getString('zatca_company_name');
        final bool hasZatcaCredentials = zatcaVatNumber != null &&
            zatcaVatNumber.isNotEmpty &&
            zatcaCompanyName != null &&
            zatcaCompanyName.isNotEmpty;

        if (hasZatcaCredentials) {
          debugPrint(
              '[ReturnBillThermal] ZATCA credentials found, generating ZATCA QR');
          final zatcaHelper = ZatcaQrHelper();
          final totalAmount = double.tryParse(returnTotalAmount) ?? 0.0;
          final qrData = zatcaHelper.generateQrForInvoice(
            sellerName: zatcaCompanyName,
            vatNumber: zatcaVatNumber,
            invoiceDate: orderDate, // Pass true UTC ISO string
            totalAmount: totalAmount,
            vatAmount: 0.0, // Return bills typically have 0 VAT added
          );
          if (qrData.isNotEmpty) {
            bytes += _buildQRCode(generator, qrData, returnTotalAmount,
                orderNumber, displayConfig, selectedFontType);
          }
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
          bytes += _buildQRCode(generator, manualPaymentGateway.link,
              returnTotalAmount, orderNumber, displayConfig, selectedFontType);
        }
        debugPrint("QR code built successfully");
      }

      // Date and Time
      debugPrint("Building date/time row...");
      bytes += _buildDateTimeRow(generator, orderDate, selectedFontType);
      debugPrint("Date/time row built successfully");

      // Order ID Barcode
      debugPrint("Building order barcode...");
      bytes += _buildOrderBarcode(
          generator, orderNumber, selectedPaperSize, selectedFontType);
      debugPrint("Order barcode built successfully");

      // Terms & Conditions
      if (displayConfig?['showTermsConditions']?.visible == true) {
        debugPrint("Building terms & conditions...");
        bytes += _buildTermsConditions(generator, displayConfig,
            returnBillDocumentConfig, selectedPaperSize, selectedFontType);
        debugPrint("Terms & conditions built successfully");
      }

      // Thank You Message
      if (displayConfig?['showThankYouMessage']?.visible == true) {
        debugPrint("Building thank you message...");
        bytes +=
            _buildThankYouMessage(generator, displayConfig, selectedFontType);
        debugPrint("Thank you message built successfully");
      }

      // Cut the receipt
      bytes += generator.cut();

      debugPrint("Return bill generated, sending to printer...");
      // Print receipt
      await printerManager.send(
          type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully");

      if (context.mounted) {
        showScaffold(
            context: context, message: "Return Bill printed successfully");
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("ERROR printing return bill: ${e.toString()}");
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

  Future<void> _connectToPrinter(BluetoothPrinter printer) async {
    await printerManager.connect(
      type: printer.typePrinter,
      model: UsbPrinterInput(
        name: printer.deviceName,
        productId: printer.productId,
        vendorId: printer.vendorId,
      ),
    );
  }

  Future<void> _disconnectPrinter(BluetoothPrinter printer) async {
    await printerManager.disconnect(type: printer.typePrinter);
  }

  void _debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    debugPrint("===== RETURN BILL TEMPLATE SETTINGS =====");
    if (displayConfig != null) {
      displayConfig.forEach((key, value) {
        debugPrint("$key: visible=${value.visible}, value=${value.value}");
      });
    } else {
      debugPrint("Display config is null");
    }
    debugPrint("=====================================");
  }

  List<int> _buildHeader(
    Generator generator,
    Map<String, DisplayOption>? displayConfig,
    DocumentConfig? returnBillDocumentConfig,
    String orderDate,
    String orderNumber,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    // Store Name - Use generator.row() like sale bill
    if (displayConfig?['showStoreName']?.visible == true) {
      final storeName = displayConfig?['showStoreName']?.value as String? ??
          returnBillDocumentConfig?.header ??
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
          returnBillDocumentConfig?.subheader ??
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
              returnBillDocumentConfig?.header ??
              appSettings?.printTitle ??
              'RETURN BILL';
      bytes +=
          generator.text(invoiceTitle.isNotEmpty ? invoiceTitle : 'RETURN BILL',
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
      // Use the numberPrefix from returnBillDocumentConfig if available, otherwise just use orderNumber
      final invoiceNumberText =
          returnBillDocumentConfig?.numberPrefix != null &&
                  returnBillDocumentConfig!.numberPrefix!.isNotEmpty
              ? '${returnBillDocumentConfig.numberPrefix}$orderNumber'
              : 'Bill No: $orderNumber';

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

  List<int> _buildCustomerDetails(
    Generator generator,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerBalance,
    PosFontType fontType,
    Map<String, DisplayOption>? displayConfig,
  ) {
    List<int> bytes = [];

    if (displayConfig?['showCustomerNameAndPhone']?.visible == true) {
      if (customerName != null && customerName.isNotEmpty) {
        bytes += generator.text(
          'Customer: ${_sanitizeTextForThermalPrinter(customerName)}',
          styles: PosStyles(fontType: fontType, align: PosAlign.left),
        );
      }

      if (customerPhone != null && customerPhone.isNotEmpty) {
        bytes += generator.text(
          'Phone: ${StringHelper.maskStringShowLast4(customerPhone)}',
          styles: PosStyles(fontType: fontType, align: PosAlign.left),
        );
      }
    }

    if (customerBalance != null &&
        customerBalance.isNotEmpty &&
        displayConfig?['showCustomerBalance']?.visible == true) {
      bytes += generator.text(
        'Balance: $customerBalance',
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.left,
          bold: true,
        ),
      );
    }

    bytes += generator.hr();
    return bytes;
  }

  List<int> _buildReturnItems(
    Generator generator,
    List<OrderReturnItem> returnItems,
    Map<String, DisplayOption>? displayConfig,
    String selectedPaperSize,
    DocumentConfig? returnBillDocumentConfig,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    debugPrint("===== BUILD RETURN ITEMS DEBUG =====");
    debugPrint("Return items count: ${returnItems.length}");
    debugPrint("Selected paper size: $selectedPaperSize");

    // Determine if we're using 58mm paper for font size adjustment
    bool is58mm = selectedPaperSize == '58mm';

    // Build dynamic header for return table
    List<PosColumn> headerColumns = [];
    int totalHeaderWidth = 0;

    debugPrint("Building header columns...");

    if (displayConfig?['showReturnSLNumber']?.visible == true) {
      final label = (displayConfig?['showReturnSLNumber']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnSLNumber']!.value as String
          : (returnBillDocumentConfig
                      ?.resolvedLabels?.returnSlNumber?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnSlNumber!
              : 'SL#');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
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

    if (displayConfig?['showReturnParticulars']?.visible == true) {
      final label = (displayConfig?['showReturnParticulars']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnParticulars']!.value as String
          : (returnBillDocumentConfig
                      ?.resolvedLabels?.returnParticulars?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnParticulars!
              : 'PARTICULARS');
      int particularsWidth = 5;
      if (displayConfig?['showReturnSLNumber']?.visible != true) {
        particularsWidth += 1;
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

    if (displayConfig?['showReturnQty']?.visible == true) {
      final label = (displayConfig?['showReturnQty']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnQty']!.value as String
          : (returnBillDocumentConfig?.resolvedLabels?.returnQty?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnQty!
              : 'QTY');
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: textSizeSmall)));
    }

    if (displayConfig?['showReturnRate']?.visible == true) {
      final label = (displayConfig?['showReturnRate']?.value as String?)
                  ?.isNotEmpty ==
              true
          ? displayConfig!['showReturnRate']!.value as String
          : (returnBillDocumentConfig?.resolvedLabels?.returnRate?.isNotEmpty ==
                  true
              ? returnBillDocumentConfig!.resolvedLabels!.returnRate!
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

    if (displayConfig?['showReturnTotal']?.visible == true) {
      final label =
          (displayConfig?['showReturnTotal']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showReturnTotal']!.value as String
              : (returnBillDocumentConfig
                          ?.resolvedLabels?.returnTotal?.isNotEmpty ==
                      true
                  ? returnBillDocumentConfig!.resolvedLabels!.returnTotal!
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

    // Print each return item using 11+1 column layout like sale bill
    for (var i = 0; i < returnItems.length; i++) {
      final returnItem = returnItems[i];
      debugPrint("Processing return item $i...");

      String productName = returnItem.productName ?? 'Unknown';
      String quantity = '${returnItem.quantity ?? 0}';
      String slNumber = (i + 1).toString();

      debugPrint("Item $i: $productName, Qty: $quantity");

      // Product Name Row using 11+1 column layout (same as sale bill)
      if (displayConfig?['showReturnParticulars']?.visible == true ||
          displayConfig?['showReturnSLNumber']?.visible == true) {
        debugPrint("Building product name row...");
        // Calculate character limit based on 48-character printer width
        int maxCharsPerLine = 40; // Half of 48 characters for the first column

        // Build the left column text (SL + Product Name)
        String leftColumnText = '';
        if (displayConfig?['showReturnSLNumber']?.visible == true &&
            displayConfig?['showReturnParticulars']?.visible == true) {
          // Both SL and product name
          leftColumnText =
              '$slNumber ${_sanitizeTextForThermalPrinter(productName)}';
        } else if (displayConfig?['showReturnSLNumber']?.visible == true) {
          // Only SL number
          leftColumnText = slNumber;
        } else {
          // Only product name
          leftColumnText = _sanitizeTextForThermalPrinter(productName);
        }

        debugPrint(
            "Left column text: '$leftColumnText' (length: ${leftColumnText.length})");

        if (leftColumnText.length <= maxCharsPerLine) {
          // Text fits in one line - use the 11+1 column layout
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
                text: '', // Empty space like in sale bill
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

              for (int j = maxCharsPerLine - 1;
                  j >= maxCharsPerLine - 10 && j >= 0;
                  j--) {
                if (j < remainingText.length && remainingText[j] == ' ') {
                  breakPoint = j;
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

      // Second row: Price details (Qty, Rate, Total) - Note: OrderReturnItem doesn't have rate/total
      debugPrint("Building price details row...");
      List<PosColumn> priceDetailsRow = [];

      // Add empty space for product name area
      priceDetailsRow.add(PosColumn(
          text: '',
          width: 6,
          styles: PosStyles(fontType: fontType, align: PosAlign.left)));

      if (displayConfig?['showReturnQty']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: quantity,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }

      // Note: OrderReturnItem model doesn't have rate/total fields
      // Showing placeholders
      if (displayConfig?['showReturnRate']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: '-',
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }
      if (displayConfig?['showReturnTotal']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: '-',
            width: 2,
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
    String returnTotalAmount,
    int itemsCount,
    DocumentConfig? returnBillDocumentConfig,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    // Return Total Amount
    if (displayConfig?['showReturnTotalAmount']?.visible == true) {
      bytes += generator.row([
        PosColumn(
          text: 'RETURN TOTAL:',
          width: 6,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: textSizeMedium,
            width: textSizeMedium,
          ),
        ),
        PosColumn(
          text: returnTotalAmount,
          width: 6,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: textSizeMedium,
            width: textSizeMedium,
          ),
        ),
      ]);
    }

    bytes += generator.hr();

    // Amount in words
    if (displayConfig?['showReturnAmountInWords']?.visible == true) {
      final amountDouble = double.tryParse(returnTotalAmount) ?? 0.0;
      bytes += _buildAmountInWords(generator, amountDouble, fontType);
    }

    // Items count
    if (displayConfig?['showReturnItemsCount']?.visible == true) {
      bytes += generator.text(
        'Total Items: $itemsCount',
        styles: PosStyles(
          fontType: fontType,
          align: PosAlign.center,
          bold: true,
          height: textSizeSmall,
        ),
      );
    }

    bytes += generator.emptyLines(1);
    return bytes;
  }

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

    // Wrap long amount in words text (same as sale bill)
    int maxCharsPerLine = 48;
    if (amountInWords.length <= maxCharsPerLine) {
      bytes += generator.text(
        _sanitizeTextForThermalPrinter(amountInWords),
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
          _sanitizeTextForThermalPrinter(currentLine),
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

  List<int> _buildQRCode(
    Generator generator,
    String qrCodeLinkTemplate,
    String returnTotalAmount,
    String orderNumber,
    Map<String, DisplayOption>? displayConfig,
    PosFontType fontType,
  ) {
    if (displayConfig?['showQRCode']?.visible != true) {
      debugPrint("QR Code disabled in settings, skipping");
      return [];
    }

    debugPrint("===== QR CODE DEBUG =====");
    debugPrint("QR Code enabled in settings");
    debugPrint("Link template: '$qrCodeLinkTemplate'");
    debugPrint("Return total amount: '$returnTotalAmount'");
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
          .replaceAll('{formattedTotal}', returnTotalAmount)
          .replaceAll('{orderNumber}', orderNumber);
      debugPrint("Using template with placeholders: '$qrData'");
    } else {
      // Use the link as-is, or create a UPI payment URL if it looks like a UPI ID
      if (qrCodeLinkTemplate.contains('@')) {
        // Looks like a UPI ID, create full UPI payment URL
        qrData =
            'upi://pay?pa=$qrCodeLinkTemplate&am=$returnTotalAmount&tn=$orderNumber&cu=INR&ds=EPOS&t=c&st=1&se=1&sd=1';
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

  List<int> _buildDateTimeRow(
    Generator generator,
    String orderDate,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    debugPrint("===== BUILD DATE TIME ROW DEBUG =====");
    debugPrint("Order date: $orderDate");

    // Use appropriate date formatting
    String formattedDate = DateHelper.formatISODate(orderDate);
    String formattedTime = DateHelper.formatISODateToIST(orderDate);

    debugPrint("Creating date/time row with 6+6 column layout");

    List<PosColumn> dateTimeColumns = [
      PosColumn(
          text: formattedDate,
          width: 6,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: textSizeSmall,
              width: textSizeSmall)),
      PosColumn(
          text: formattedTime,
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

    debugPrint("===== END BUILD DATE TIME ROW DEBUG =====");
    return bytes;
  }

  List<int> _buildOrderBarcode(
    Generator generator,
    String orderNumber,
    String selectedPaperSize,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    debugPrint(
        "Generating Order ID barcode: $orderNumber for $selectedPaperSize paper");

    // Adjust barcode size based on paper width
    bool is58mm = selectedPaperSize == '58mm';
    int barcodeHeight = is58mm ? 40 : 30; // Bigger height for 58mm

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
    DocumentConfig? returnBillDocumentConfig,
    String selectedPaperSize,
    PosFontType fontType,
  ) {
    if (displayConfig?['showTermsConditions']?.visible != true) {
      debugPrint("Terms & Conditions disabled in settings, skipping");
      return [];
    }

    // Get terms from displayConfig value first, then fallback to returnBillDocumentConfig
    String? terms = displayConfig?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      // Fallback to returnBillDocumentConfig terms
      terms = returnBillDocumentConfig?.terms;
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
                text: _sanitizeTextForThermalPrinter(termText),
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
                  text: _sanitizeTextForThermalPrinter(currentLine),
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

    bytes += generator.emptyLines(1);
    return bytes;
  }

  List<int> _buildThankYouMessage(
    Generator generator,
    Map<String, DisplayOption>? displayConfig,
    PosFontType fontType,
  ) {
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
}
