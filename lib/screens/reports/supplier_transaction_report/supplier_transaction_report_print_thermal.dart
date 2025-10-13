import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupplierTransactionReportThermalPrinter {
  final BuildContext context;
  var printerManager = PrinterManager.instance;

  // Font configuration - default fallback (will be overridden by user preference)
  static const PosFontType defaultFontType = PosFontType.fontB;

  // Text size variables for consistent sizing
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  SupplierTransactionReportThermalPrinter(this.context);

  // Helper method to get label from resolved labels with fallback
  String _getLabel(DocumentConfig? config, String field, String fallback) {
    final resolvedLabels = config?.resolvedLabels;
    if (resolvedLabels == null) return fallback;
    
    switch (field) {
      case 'sl_number':
        return resolvedLabels.slNumber ?? fallback;
      case 'date':
        return resolvedLabels.date ?? fallback;
      case 'item':
        return resolvedLabels.item ?? fallback;
      case 'debit':
        return resolvedLabels.debit ?? fallback;
      case 'credit':
        return resolvedLabels.credit ?? fallback;
      case 'status':
        return resolvedLabels.status ?? fallback;
      default:
        return fallback;
    }
  }

  // Load font type from SharedPreferences
  Future<PosFontType> _loadFontType() async {
    final prefs = await SharedPreferences.getInstance();
    final fontStyle =
        prefs.getString('default_font_style') ?? 'Font B (Default)';
    return fontStyle.contains('Font A') ? PosFontType.fontA : PosFontType.fontB;
  }

  Future<void> printSupplierTransactionReport({
    required BluetoothPrinter selectedPrinter,
    required List<SupplierTransaction> cartItems,
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
    String? supplierName,
    String? supplierPhone,
    String? supplierEmail,
    String? supplierAddress,
    String? fromDate,
    String? toDate,
  }) async {
    debugPrint("===== SUPPLIER THERMAL PRINTER DEBUG INFO =====");
    debugPrint("Supplier data received:");
    debugPrint("  Name: $supplierName");
    debugPrint("  Phone: $supplierPhone");
    debugPrint("  Email: $supplierEmail");
    debugPrint("  Address: $supplierAddress");
    debugPrint("===== END SUPPLIER THERMAL PRINTER DEBUG INFO =====");

    debugPrint("===== SUPPLIER TRANSACTION REPORT THERMAL PRINTING DEBUG =====");

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

    debugPrint("Printing supplier transaction report with thermal printer:");
    debugPrint(
        "Printer: ${selectedPrinter.deviceName} (${selectedPrinter.typePrinter})");
    debugPrint("Paper size: $selectedPaperSize");

    // Use the loaded display configuration with fallback
    final apiDisplayConfig = billDocumentConfig.displayConfiguration?.options;
    _debugPrintTemplateSettings(apiDisplayConfig);
    
    // Ensure complete display config by merging with fallback
    final displayConfig = _ensureCompleteDisplayConfig(apiDisplayConfig);

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

      debugPrint("Starting to build supplier transaction report sections...");

      // Pass the display config, document config, and selected font type to helper functions
      debugPrint("Building header...");
      bytes += _buildHeader(generator, displayConfig, billDocumentConfig,
          orderDate, orderNumber, selectedFontType);
      debugPrint("Header built successfully");

      // Build supplier details if available
      if (supplierName != null ||
          supplierPhone != null ||
          supplierEmail != null ||
          supplierAddress != null ||
          fromDate != null ||
          toDate != null) {
        debugPrint("Building supplier details...");
        bytes += _buildSupplierDetails(generator, supplierName, supplierPhone,
            supplierEmail, supplierAddress, fromDate, toDate, selectedFontType, displayConfig);
        debugPrint("Supplier details built successfully");
      }

      debugPrint("Building supplier transaction report items...");
      bytes += _buildSupplierTransactionReportItems(
          generator,
          cartItems,
          displayConfig,
          isFromLocalStorage,
          selectedPaperSize,
          billDocumentConfig,
          selectedFontType);
      debugPrint("Supplier transaction report items built successfully");

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

      // Note: Terms & Conditions and Thank You Message are not available in Supplier Statement template
      // These fields are only available in Bill template, not Supplier Statement template

      // Footer
      if (displayConfig?['showFooter']?.visible == true) {
        debugPrint("Building footer...");
        bytes += _buildFooter(generator, displayConfig, billDocumentConfig, selectedFontType);
        debugPrint("Footer built successfully");
      }

      // Cut the receipt
      bytes += generator.cut();

      debugPrint("Supplier transaction report generated, sending to printer...");
      // Print receipt
      await printerManager.send(
          type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 67; // Back to supplier transaction report
      }
    } catch (e) {
      debugPrint("ERROR printing supplier transaction report: ${e.toString()}");
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

    // Show header if enabled
    if (displayConfig?['showHeader']?.visible == true) {
      String headerText = docConfig?.header ?? 'EPosenke';
      bytes += generator.text(headerText,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              width: textSizeMedium,
              height: textSizeMedium));
    }

    // Show subheader if enabled
    if (displayConfig?['showSubheader']?.visible == true) {
      String subheaderText = docConfig?.subheader ?? 'Supplier Transaction Report';
      bytes += generator.text(subheaderText,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: false,
              height: textSizeSmall));
    }

    bytes += generator.emptyLines(1);

    return bytes;
  }

  List<int> _buildSupplierDetails(
      Generator generator,
      String? supplierName,
      String? supplierPhone,
      String? supplierEmail,
      String? supplierAddress,
      String? fromDate,
      String? toDate,
      PosFontType fontType,
      Map<String, DisplayOption>? displayConfig) {
    List<int> bytes = [];

    debugPrint("===== BUILD SUPPLIER DETAILS DEBUG =====");
    debugPrint("Supplier name: $supplierName");
    debugPrint("Supplier phone: $supplierPhone");
    debugPrint("Supplier email: $supplierEmail");
    debugPrint("Supplier address: $supplierAddress");
    debugPrint("From date: $fromDate");
    debugPrint("To date: $toDate");

    // Add supplier information header
    bytes += generator.text('SUPPLIER INFORMATION',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: true,
            height: textSizeSmall));
    bytes += generator.hr();

    // Add supplier details if available and enabled
    if (displayConfig?['showSupplierName']?.visible == true &&
        supplierName != null &&
        supplierName.isNotEmpty) {
      bytes += generator.text('Name: $supplierName',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    if (displayConfig?['showSupplierPhone']?.visible == true &&
        supplierPhone != null &&
        supplierPhone.isNotEmpty) {
      bytes += generator.text('Phone: $supplierPhone',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    if (displayConfig?['showSupplierEmail']?.visible == true &&
        supplierEmail != null &&
        supplierEmail.isNotEmpty) {
      bytes += generator.text('Email: $supplierEmail',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    if (displayConfig?['showSupplierAddress']?.visible == true &&
        supplierAddress != null &&
        supplierAddress.isNotEmpty) {
      bytes += generator.text('Address: $supplierAddress',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
    }

    // Add date range if available and enabled
    if (displayConfig?['showDates']?.visible == true) {
      if (fromDate != null && fromDate.isNotEmpty) {
        bytes += generator.text('From: $fromDate',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: textSizeSmall));
      }

      if (toDate != null && toDate.isNotEmpty) {
        bytes += generator.text('To: $toDate',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: textSizeSmall));
      }
    }

    bytes += generator.hr();
    bytes += generator.emptyLines(1);

    debugPrint("===== END BUILD SUPPLIER DETAILS DEBUG =====");
    return bytes;
  }

  List<int> _buildSupplierTransactionReportItems(
      Generator generator,
      List<SupplierTransaction> cartItems,
      Map<String, DisplayOption>? displayConfig,
      bool isFromLocalStorage,
      String selectedPaperSize,
      DocumentConfig? billDocumentConfig,
      PosFontType fontType) {
    List<int> bytes = [];

    debugPrint("===== BUILD SUPPLIER TRANSACTION REPORT ITEMS DEBUG =====");
    debugPrint("Cart items count: ${cartItems.length}");
    debugPrint("Selected paper size: $selectedPaperSize");
    debugPrint("Is from local storage: $isFromLocalStorage");

    // Determine if we're using 58mm paper for font size adjustment
    bool is58mm = selectedPaperSize == '58mm';

    // Add table headers with fixed widths - matching image: SL, Date, Type, Debit, Credit, Status
    List<PosColumn> headerColumns = [];
    int totalHeaderWidth = 0;

    debugPrint("Building header columns...");

    // Add Sl.No column - use resolved label
    headerColumns.add(PosColumn(
        text: _getLabel(billDocumentConfig, 'sl_number', 'SL'),
        width: 1,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 1;
    debugPrint("Added SL column with width 1, total width: $totalHeaderWidth");

    // Add Date column - use resolved label
    headerColumns.add(PosColumn(
        text: _getLabel(billDocumentConfig, 'date', 'Date'),
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint("Added Date column with width 2, total width: $totalHeaderWidth");

    // Add Type column (transaction type) - use resolved label (item)
    headerColumns.add(PosColumn(
        text: _getLabel(billDocumentConfig, 'item', 'Type'),
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.left,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint(
        "Added Type column with width 2, total width: $totalHeaderWidth");

    // Add Debit column - use resolved label
    headerColumns.add(PosColumn(
        text: _getLabel(billDocumentConfig, 'debit', 'Debit'),
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint(
        "Added Debit column with width 2, total width: $totalHeaderWidth");

    // Add Credit column - use resolved label
    headerColumns.add(PosColumn(
        text: _getLabel(billDocumentConfig, 'credit', 'Credit'),
        width: 2,
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.right,
            bold: true,
            height: is58mm ? textSizeSmall : textSizeSmall)));
    totalHeaderWidth += 2;
    debugPrint(
        "Added Credit column with width 2, total width: $totalHeaderWidth");

    // Add Status column if enabled - use resolved label
    if (displayConfig?['showStatus']?.visible == true) {
      headerColumns.add(PosColumn(
          text: _getLabel(billDocumentConfig, 'status', 'Status'),
          width: 3,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: is58mm ? textSizeSmall : textSizeSmall)));
      totalHeaderWidth += 3;
      debugPrint(
          "Added Status column with width 3, total width: $totalHeaderWidth");
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

      String type = item.type;
      String transactionType = item.transactionType;
      double amount = double.tryParse(item.amount) ?? 0.0;
      String status = item.status;
      String date = item.date;

      String slNumber = (i + 1).toString();
      
      // Format amounts for Debit/Credit columns
      String debitAmount = (type.toLowerCase() == 'debit') ? amount.toStringAsFixed(2) : '-';
      String creditAmount = (type.toLowerCase() == 'credit') ? amount.toStringAsFixed(2) : '-';
      
      // Format date to show only date (not time)
      String formattedDate = date;
      try {
        // Try to parse and format the date if it's in a standard format
        formattedDate = DateHelper.formatISODate(date);
      } catch (e) {
        // Keep original date if parsing fails
        formattedDate = date;
      }
      
      // Format status to match image
      String displayStatus = status;
      if (status == 'SUCC') {
        displayStatus = 'Paid';
      } else if (status == 'FAIL') {
        displayStatus = 'Pending';
      } else if (status == 'INIT') {
        displayStatus = 'Initiated';
      }
      
      debugPrint(
          "Item $i: Date: $formattedDate, Type: $transactionType, Debit: $debitAmount, Credit: $creditAmount, Status: $displayStatus");

      // Create row with 6 columns: SL, Date, Type, Debit, Credit, Status
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
            text: formattedDate,
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
            text: debitAmount,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
        PosColumn(
            text: creditAmount,
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)),
      ];

      // Add status column if enabled
      if (displayConfig?['showStatus']?.visible == true) {
        itemRow.add(PosColumn(
            text: displayStatus,
            width: 3,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: is58mm ? textSizeSmall : textSizeSmall)));
      }

      int itemRowWidth = 1 + 2 + 2 + 2 + 2 + (displayConfig?['showStatus']?.visible == true ? 3 : 0);
      debugPrint("Item row total width: $itemRowWidth");
      if (itemRowWidth != 12) {
        debugPrint(
            "ERROR: Item row columns width ($itemRowWidth) is not equal to 12!");
      }

      bytes += generator.row(itemRow);
    }

    bytes += generator.hr();
    debugPrint("===== END BUILD SUPPLIER TRANSACTION REPORT ITEMS DEBUG =====");
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
      List<SupplierTransaction> cartItems,
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
      double amount = double.tryParse(item.amount) ?? 0.0;
      String type = item.type;

      if (type.toLowerCase() == 'credit') {
        totalCredit += amount;
      } else if (type.toLowerCase() == 'debit') {
        totalDebit += amount;
      }
    }

    double balance = totalCredit - totalDebit;

    debugPrint(
        "Calculated values - Credit: $totalCredit, Debit: $totalDebit, Balance: $balance");

    // Show Total Credit if enabled
    if (displayConfig?['showTotalCredit']?.visible == true) {
      bytes += generator.text(
          'Total Credit: Rs. ${totalCredit.toStringAsFixed(2)}',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: textSizeSmall));
    }

    // Show Total Debit if enabled
    if (displayConfig?['showTotalDebit']?.visible == true) {
      bytes += generator.text('Total Debit: Rs. ${totalDebit.toStringAsFixed(2)}',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: textSizeSmall));
    }

    // Show Balance if enabled
    if (displayConfig?['showBalance']?.visible == true) {
      String balanceText = 'Balance: Rs. ${balance.toStringAsFixed(2)}';
      bytes += generator.text(balanceText,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: textSizeSmall));
    }

    bytes += generator.hr();

    debugPrint("===== END BUILD TOTAL AMOUNT DEBUG =====");
    return bytes;
  }



  List<int> _buildFooter(Generator generator,
      Map<String, DisplayOption>? displayConfig, DocumentConfig? billDocumentConfig, PosFontType fontType) {
    List<int> bytes = [];

    if (displayConfig?['showFooter']?.visible == true) {
      final footerText = billDocumentConfig?.footer ??
          'This is a computer-generated document. No signature is required.';
      
      bytes += generator.hr();
      bytes += generator.text(
          footerText,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: false,
              height: textSizeSmall));
    }

    return bytes;
  }

  List<int> _buildDateTimeRow(
      Generator generator, String orderDate, PosFontType fontType) {
    List<int> bytes = [];

    debugPrint("===== BUILD DATE TIME ROW DEBUG =====");
    debugPrint("Order date: $orderDate");

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

    debugPrint("===== END BUILD DATE TIME ROW DEBUG =====");
    return bytes;
  }



  Future<void> _connectToPrinter(BluetoothPrinter printer) async {
    switch (printer.typePrinter) {
      case PrinterType.usb:
        await printerManager.connect(
            type: printer.typePrinter,
            model: UsbPrinterInput(name: printer.deviceName));
        break;
      case PrinterType.bluetooth:
        await printerManager.connect(
            type: printer.typePrinter,
            model: BluetoothPrinterInput(
                name: printer.deviceName,
                address: printer.address!,
                isBle: false,
                autoConnect: false));
        break;
      case PrinterType.network:
        await printerManager.connect(
            type: printer.typePrinter,
            model: TcpPrinterInput(ipAddress: printer.address!));
        break;
      default:
        break;
    }
  }

  Future<void> _disconnectPrinter(BluetoothPrinter printer) async {
    await printerManager.disconnect(type: printer.typePrinter);
  }

  void _debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    debugPrint("===== TEMPLATE SETTINGS DEBUG =====");
    if (displayConfig != null) {
      displayConfig.forEach((key, value) {
        debugPrint("$key: visible=${value.visible}, value=${value.value}");
      });
    } else {
      debugPrint("Display config is null");
    }
    debugPrint("===== END TEMPLATE SETTINGS DEBUG =====");
  }

  // Create fallback display configuration when API doesn't provide column settings
  Map<String, DisplayOption> _createFallbackDisplayConfig() {
    debugPrint("⚠️ Creating fallback display configuration for Supplier Statement (Thermal)");
    return {
      // Header/Footer settings
      'showHeader': DisplayOption(visible: true, value: null),
      'showSubheader': DisplayOption(visible: true, value: null),
      'showFooter': DisplayOption(visible: true, value: null),
      'showDates': DisplayOption(visible: true, value: null),
      
      // Supplier details
      'showSupplierName': DisplayOption(visible: true, value: null),
      'showSupplierEmail': DisplayOption(visible: true, value: null),
      'showSupplierPhone': DisplayOption(visible: true, value: null),
      'showSupplierAddress': DisplayOption(visible: true, value: null),
      
      // Table column visibility - matching image (SL, Date, Debit, Credit, Status)
      'showSlNumber': DisplayOption(visible: true, value: null),
      'showDate': DisplayOption(visible: true, value: null),
      'showDebit': DisplayOption(visible: true, value: null),
      'showCredit': DisplayOption(visible: true, value: null),
      
      // Summary totals (shown at bottom, not in table)
      'showTotalCredit': DisplayOption(visible: true, value: null),
      'showTotalDebit': DisplayOption(visible: true, value: null),
      'showBalance': DisplayOption(visible: true, value: null),
      'showStatus': DisplayOption(visible: true, value: null),
    };
  }

  // Merge API config with fallback to ensure all required keys exist
  Map<String, DisplayOption> _ensureCompleteDisplayConfig(Map<String, DisplayOption>? apiConfig) {
    final fallback = _createFallbackDisplayConfig();
    
    if (apiConfig == null || apiConfig.isEmpty) {
      debugPrint("⚠️ API config is null/empty, using complete fallback");
      return fallback;
    }
    
    // Merge: API config takes precedence, but fallback fills in missing keys
    final merged = Map<String, DisplayOption>.from(fallback);
    apiConfig.forEach((key, value) {
      merged[key] = value;
    });
    
    debugPrint("✅ Merged display config with ${merged.length} total options");
    return merged;
  }
}