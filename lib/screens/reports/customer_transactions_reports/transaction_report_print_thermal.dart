import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
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

class TransactionReportThermalPrinter {
  final BuildContext context;
  var printerManager = PrinterManager.instance;

  // Font configuration - default fallback (will be overridden by user preference)
  static const PosFontType defaultFontType = PosFontType.fontB;

  // Text size variables for consistent sizing
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  TransactionReportThermalPrinter(this.context);

  // Load font type from SharedPreferences
  Future<PosFontType> _loadFontType() async {
    final prefs = await SharedPreferences.getInstance();
    final fontStyle =
        prefs.getString('default_font_style') ?? 'Font B (Default)';
    return fontStyle.contains('Font A') ? PosFontType.fontA : PosFontType.fontB;
  }

  Future<void> printTransactionReport({
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
    String? fromDate,
    String? toDate,
  }) async {
    debugPrint("===== THERMAL PRINTER DEBUG INFO =====");
    debugPrint("Customer data received:");
    debugPrint("  Name: $customerName");
    debugPrint("  Phone: $customerPhone");
    debugPrint("  Email: $customerEmail");
    debugPrint("  Address: $customerAddress");
    debugPrint("===== END THERMAL PRINTER DEBUG INFO =====");

    debugPrint("===== TRANSACTION REPORT THERMAL PRINTING DEBUG =====");

    // Ensure billDocumentConfig is loaded before printing
    if (billDocumentConfig == null) {
      debugPrint("ERROR: Bill document configuration not loaded yet.");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Document configurations not loaded. Please wait.",
        );
      }
      return;
    }

    debugPrint("Printing transaction report with thermal printer:");
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

      debugPrint("Starting to build transaction report sections...");

      // Pass the display config, document config, and selected font type to helper functions
      debugPrint("Building header...");
      bytes += _buildHeader(generator, displayConfig, billDocumentConfig,
          orderDate, orderNumber, selectedFontType);
      debugPrint("Header built successfully");

      // Build customer details if available
      if (customerName != null ||
          customerPhone != null ||
          customerEmail != null ||
          customerAddress != null ||
          fromDate != null ||
          toDate != null) {
        debugPrint("Building customer details...");
        bytes += _buildCustomerDetails(generator, customerName, customerPhone,
            customerEmail, customerAddress, fromDate, toDate, selectedFontType);
        debugPrint("Customer details built successfully");
      }

      debugPrint("Building transaction report items...");
      bytes += _buildTransactionReportItems(
          generator,
          cartItems,
          displayConfig,
          isFromLocalStorage,
          selectedPaperSize,
          billDocumentConfig,
          selectedFontType);
      debugPrint("Transaction report items built successfully");

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

      // Date and Time (moved to bottom, just above barcode)
      debugPrint("Building date/time row...");
      bytes += _buildDateTimeRow(generator, orderDate, selectedFontType);
      debugPrint("Date/time row built successfully");

      // Order ID Barcode (just before Terms & Conditions) - REMOVED AS PER USER REQUEST
      // debugPrint("Building order barcode...");
      // bytes += _buildOrderBarcode(
      //     generator, orderNumber, selectedPaperSize, selectedFontType);
      // debugPrint("Order barcode built successfully");

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

      debugPrint("Transaction report generated, sending to printer...");
      // Print receipt
      await printerManager.send(
          type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 65; // Back to transaction report
      }
    } catch (e) {
      debugPrint("ERROR printing transaction report: ${e.toString()}");
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

    // Store Name - Always show "EPosenke"
    bytes += generator.text('EPosenke',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: true,
            width: textSizeMedium,
            height: textSizeMedium));

    // Description - Always show "Customer Transaction Report"
    bytes += generator.text('Customer Transaction Report',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: false,
            height: textSizeSmall));

    bytes += generator.emptyLines(1);

    return bytes;
  }

  List<int> _buildTransactionReportItems(
      Generator generator,
      List<dynamic> cartItems,
      Map<String, DisplayOption>? displayConfig,
      bool isFromLocalStorage,
      String selectedPaperSize,
      DocumentConfig? billDocumentConfig,
      PosFontType fontType) {
    List<int> bytes = [];

    debugPrint("===== BUILD TRANSACTION REPORT ITEMS DEBUG =====");
    debugPrint("Cart items count: ${cartItems.length}");
    debugPrint("Selected paper size: $selectedPaperSize");
    debugPrint("Is from local storage: $isFromLocalStorage");

    // Determine if we're using 58mm paper for font size adjustment
    bool is58mm = selectedPaperSize == '58mm';

    // Add table headers with fixed widths
    List<PosColumn> headerColumns = [];
    int totalHeaderWidth = 0;

    debugPrint("Building header columns...");

    // Add Sl.No column
    headerColumns.add(PosColumn(
        text: 'Sl.No',
        width: 1,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 1;
    debugPrint("Added SL column with width 1, total width: $totalHeaderWidth");

    // Add Order Number column
    headerColumns.add(PosColumn(
        text: 'Order Number',
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint(
        "Added Order Number column with width 2, total width: $totalHeaderWidth");

    // Add Transaction Type column
    headerColumns.add(PosColumn(
        text: 'Transaction Type',
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint(
        "Added Transaction Type column with width 2, total width: $totalHeaderWidth");

    // Add Type column
    headerColumns.add(PosColumn(
        text: 'Type',
        width: 1,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 1;
    debugPrint(
        "Added Type column with width 1, total width: $totalHeaderWidth");

    // Add Amount column
    headerColumns.add(PosColumn(
        text: 'Amount',
        width: 1,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 1;
    debugPrint(
        "Added Amount column with width 1, total width: $totalHeaderWidth");

    // Add Tax column
    headerColumns.add(PosColumn(
        text: 'Tax',
        width: 1,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 1;
    debugPrint("Added Tax column with width 1, total width: $totalHeaderWidth");

    // Add Status column
    headerColumns.add(PosColumn(
        text: 'Status',
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint(
        "Added Status column with width 2, total width: $totalHeaderWidth");

    // Add Date column
    headerColumns.add(PosColumn(
        text: 'Date',
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint(
        "Added Date column with width 2, total width: $totalHeaderWidth");

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

      String orderNumber = '';
      String transactionType = '';
      String type = '';
      String amount = '';
      String tax = '10'; // Default tax value as shown in example
      String status = '';
      String date = '';

      if (isFromLocalStorage) {
        // Handle local storage data
        orderNumber = item['orderNumber'] ?? 'N/A';
        transactionType = item['transactionType'] ?? 'N/A';
        type = item['type'] ?? 'N/A';
        amount = item['amount'] ?? '0.00';
        status = item['status'] ?? 'N/A';
        date = item['date'] ?? 'N/A';
      } else {
        // Handle different object types - check if it's a Map or an object
        if (item is Map<String, dynamic>) {
          // Handle Map case (from API responses or converted data)
          orderNumber = item['order_id']?.toString() ??
              item['orderId']?.toString() ??
              item['orderNumber']?.toString() ??
              'N/A';
          transactionType = item['transaction_type']?.toString() ??
              item['transactionType']?.toString() ??
              'N/A';
          type = item['type']?.toString() ?? 'N/A';
          amount = item['amount']?.toString() ?? '0.00';
          status = item['status']?.toString() ?? 'N/A';
          date = item['date']?.toString() ?? 'N/A';
        } else {
          // Handle object case (ListTransaction or similar)
          try {
            orderNumber = item.orderNumber?.toString() ??
                item.orderId?.toString() ??
                'N/A';
            transactionType = item.transactionType?.toString() ?? 'N/A';
            type = item.type?.toString() ?? 'N/A';
            amount = item.amount?.toString() ?? '0.00';
            status = item.status?.toString() ?? 'N/A';
            date = item.date?.toString() ?? 'N/A';
          } catch (e) {
            debugPrint('Error accessing cart item properties: $e');
            debugPrint('Item type: ${item.runtimeType}');
            debugPrint('Item: $item');
            // Fallback to safe defaults
            orderNumber = 'N/A';
            transactionType = 'N/A';
            type = 'N/A';
            amount = '0.00';
            
            status = 'N/A';
            date = 'N/A';
          }
        }
      }

      String slNumber = (i + 1).toString();
      debugPrint(
          "Item $i: Order: $orderNumber, Type: $transactionType, Amount: $amount, Status: $status, Date: $date");

      // Create row with all transaction details
      List<PosColumn> itemRow = [
        PosColumn(
            text: slNumber,
            width: 1,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: orderNumber,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: transactionType,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: type,
            width: 1,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: amount,
            width: 1,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: tax,
            width: 1,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: status,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: date,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
      ];

      int itemRowWidth = 1 + 2 + 2 + 1 + 1 + 1 + 2 + 2;
      debugPrint("Item row total width: $itemRowWidth");
      if (itemRowWidth != 12) {
        debugPrint(
            "ERROR: Item row columns width ($itemRowWidth) is not equal to 12!");
      }

      bytes += generator.row(itemRow);
    }

    bytes += generator.hr();
    debugPrint("===== END BUILD TRANSACTION REPORT ITEMS DEBUG =====");
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

    // Calculate totals
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var item in cartItems) {
      double amount = 0.0;
      String type = '';

      if (isFromLocalStorage) {
        amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
        type = item['type']?.toString() ?? '';
      } else {
        if (item is Map<String, dynamic>) {
          amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
          type = item['type']?.toString() ?? '';
        } else {
          try {
            amount = double.tryParse(item.amount?.toString() ?? '0') ?? 0.0;
            type = item.type?.toString() ?? '';
          } catch (e) {
            debugPrint('Error accessing item amount/type: $e');
            amount = 0.0;
            type = '';
          }
        }
      }

      if (type.toLowerCase() == 'credit') {
        totalCredit += amount;
      } else if (type.toLowerCase() == 'debit') {
        totalDebit += amount;
      }
    }

    double balance = totalCredit - totalDebit;

    debugPrint(
        "Calculated values - Credit: $totalCredit, Debit: $totalDebit, Balance: $balance");

    // Show Total Credit
    bytes += generator.text(
        'Total Credit: Rs. ${totalCredit.toStringAsFixed(2)}',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: textSizeSmall));

    // Show Total Debit
    bytes += generator.text('Total Debit: Rs. ${totalDebit.toStringAsFixed(2)}',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: textSizeSmall));

    // Show Balance with color coding (positive = green, negative = red)
    String balanceText = 'Balance: Rs. ${balance.toStringAsFixed(2)}';
    bytes += generator.text(balanceText,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: textSizeSmall));

    bytes += generator.hr();

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

  List<int> _buildDateRangeRow(Generator generator, String? fromDate,
      String? toDate, PosFontType fontType) {
    List<int> bytes = [];

    debugPrint("===== BUILD DATE RANGE ROW DEBUG =====");
    debugPrint("From date: $fromDate");
    debugPrint("To date: $toDate");

    // Add date range row with smaller text size in 6+6 column layout
    debugPrint("Creating date range row with 6+6 column layout");
    List<PosColumn> dateRangeColumns = [
      PosColumn(
          text: 'From: ${fromDate ?? 'N/A'}',
          width: 6,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: textSizeSmall,
              width: textSizeSmall)),
      PosColumn(
          text: 'To: ${toDate ?? 'N/A'}',
          width: 6,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: textSizeSmall,
              width: textSizeSmall)),
    ];

    int dateRangeRowWidth = 6 + 6;
    debugPrint("Date range row total width: $dateRangeRowWidth");
    if (dateRangeRowWidth != 12) {
      debugPrint(
          "ERROR: Date range row columns width ($dateRangeRowWidth) is not equal to 12!");
    }

    bytes += generator.row(dateRangeColumns);

    debugPrint("===== END BUILD DATE RANGE ROW DEBUG =====");
    return bytes;
  }

  // List<int> _buildOrderBarcode(Generator generator, String orderNumber,
  //     String selectedPaperSize, PosFontType fontType) {
  //   List<int> bytes = [];

  //   debugPrint(
  //       "Generating Order ID barcode: $orderNumber for $selectedPaperSize paper");

  //   // Adjust barcode size based on paper width
  //   bool is58mm = selectedPaperSize == '58mm';
  //   int barcodeHeight =
  //       is58mm ? 40 : 30; // Bigger height for 58mm (increased from 20 to 40)

  //   try {
  //     // Use CODE39 which supports: '0'–'9', A–Z, SP, $, %, *, +, -, ., /
  //     // Keep the hyphen as CODE39 supports it
  //     String cleanOrderNumber =
  //         orderNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
  //     if (cleanOrderNumber.isNotEmpty) {
  //       List<String> code39Data = cleanOrderNumber.split("");
  //       bytes += generator.barcode(
  //         Barcode.code39(code39Data),
  //         height: barcodeHeight,
  //         width: 1,
  //         textPos: BarcodeText.none,
  //         align: PosAlign.center,
  //       );
  //       debugPrint(
  //           "Generated CODE39 barcode with data: $cleanOrderNumber (height: $barcodeHeight)");
  //     } else {
  //       debugPrint("No valid characters for barcode, displaying as text");
  //     }
  //   } catch (e) {
  //     debugPrint(
  //         "Error generating CODE39 barcode: $e, displaying as text fallback");

  //     // Final fallback: Just display the order number as text
  //     bytes += generator.text(orderNumber,
  //         styles: PosStyles(
  //             fontType: fontType, align: PosAlign.center, bold: true));
  //   }

  //   return bytes;
  // }

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
      String? fromDate,
      String? toDate,
      PosFontType fontType) {
    debugPrint("===== THERMAL CUSTOMER DETAILS DEBUG =====");
    debugPrint("Building customer details section for thermal printer:");
    debugPrint("  customerName: '$customerName'");
    debugPrint("  customerPhone: '$customerPhone'");
    debugPrint("  customerEmail: '$customerEmail'");
    debugPrint("  customerAddress: '$customerAddress'");
    debugPrint("  fromDate: '$fromDate'");
    debugPrint("  toDate: '$toDate'");
    debugPrint("  Are any customer fields non-null and non-empty?");
    debugPrint("    Name: ${customerName != null && customerName.isNotEmpty}");
    debugPrint(
        "    Phone: ${customerPhone != null && customerPhone.isNotEmpty}");
    debugPrint(
        "    Email: ${customerEmail != null && customerEmail.isNotEmpty}");
    debugPrint(
        "    Address: ${customerAddress != null && customerAddress.isNotEmpty}");
    debugPrint("===== END THERMAL CUSTOMER DETAILS DEBUG =====");

    List<int> bytes = [];

    // Add a header for customer details
    bytes += generator.text('Customer Information',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: true,
            height: textSizeSmall,
            width: textSizeSmall));

    bytes += generator.hr();

    // Add customer details
    if (customerName != null && customerName.isNotEmpty) {
      bytes += generator.text('Name: $customerName',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    if (customerEmail != null && customerEmail.isNotEmpty) {
      bytes += generator.text('Email: $customerEmail',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    if (customerPhone != null && customerPhone.isNotEmpty) {
      bytes += generator.text('Phone: $customerPhone',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    if (customerAddress != null && customerAddress.isNotEmpty) {
      bytes += generator.text('Address: $customerAddress',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    // Add date range information in the same format as date/time row
    if ((fromDate != null && fromDate.isNotEmpty) ||
        (toDate != null && toDate.isNotEmpty)) {
      bytes += generator.emptyLines(1);
      bytes += _buildDateRangeRow(generator, fromDate, toDate, fontType);
    }

    bytes += generator.emptyLines(1);
    return bytes;
  }
}
