import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/screens/print/printer_settings.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class PrintPage extends StatefulWidget {
  final List<dynamic> cartItems;
  final String? storeName;
  final String formattedTotal;
  final String? savedTotal;
  final String orderDate;
  final String orderNumber;
  final bool isFromLocalStorage;

  const PrintPage({
    Key? key,
    required this.cartItems,
    required this.formattedTotal,
    this.savedTotal,
    this.storeName,
    required this.orderDate,
    required this.orderNumber,
    this.isFromLocalStorage = false,
  }) : super(key: key);

  @override
  _PrintPageState createState() => _PrintPageState();
}

class _PrintPageState extends State<PrintPage> {
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  BluetoothPrinter? selectedPrinter;
  bool _isScanning = false;
  bool _isLoading = true;
  ReceiptTemplate? selectedTemplate;
  String selectedPaperSize = '80mm'; // Default to 80mm thermal paper

  static const Color primaryColor = Color(0XFF3C92F5);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color textPrimaryColor = Color(0xFF2C3E50);
  static const Color textSecondaryColor = Color(0xFF7F8C8D);
  static const Color backgroundColor = Color(0xFFF5F6FA);

  // List of available paper sizes
  final List<String> paperSizes = ['80mm', '58mm', 'A5', 'A4'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      Provider.of<PaymentGatewaysProvider>(context, listen: false)
          .fetchPaymentGateways(accessToken: accessToken!);
      // Load saved paper size first so auto-print uses correct method
      _loadDefaultPaperSize();
      _loadDefaultPrinter();
      _loadReceiptTemplate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPermissions();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (await _requestPermissions()) {
      _scan();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    }
    return true;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
            'This app needs Bluetooth and Location permissions to scan for printers.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  void _scan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      // Scan for Bluetooth printers
      _subscription = printerManager
          .discovery(type: PrinterType.bluetooth, isBle: false)
          .listen((device) {
        // debugPrint('Found Bluetooth device: ${device.name}');
        final printer = BluetoothPrinter(
          deviceName: device.name,
          address: device.address,
          typePrinter: PrinterType.bluetooth,
        );
        setState(() {
          devices.add(printer);
        });
      });

      // Scan for USB printers
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        // debugPrint('Found USB device: ${device.name}');
        final printer = BluetoothPrinter(
          deviceName: device.name,
          vendorId: device.vendorId,
          productId: device.productId,
          typePrinter: PrinterType.usb,
        );
        setState(() {
          devices.add(printer);
        });
      });
    } catch (e) {
      // debugPrint('Error during scanning: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultPrinterJson = prefs.getString('default_printer');

    debugPrint("===== PRINTER DEBUG =====");
    debugPrint("Loading default printer from preferences...");
    debugPrint(
        "Found saved printer: ${defaultPrinterJson != null ? 'YES' : 'NO'}");

    if (defaultPrinterJson != null) {
      final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);
      debugPrint("Saved printer data: $printerData");

      setState(() {
        selectedPrinter = BluetoothPrinter(
          deviceName: printerData['deviceName'],
          address: printerData['address'],
          vendorId: printerData['vendorId'],
          productId: printerData['productId'],
          typePrinter: PrinterType.values.firstWhere(
            (e) => e.toString() == printerData['typePrinter'],
          ),
        );
        _isLoading = false;
      });

      debugPrint(
          "Loaded printer: ${selectedPrinter?.deviceName ?? 'None'} (${selectedPrinter?.typePrinter.toString() ?? 'Unknown type'})");
      debugPrint("Address: ${selectedPrinter?.address ?? 'N/A'}");
      debugPrint(
          "VendorID: ${selectedPrinter?.vendorId ?? 'N/A'}, ProductID: ${selectedPrinter?.productId ?? 'N/A'}");

      // If we have a default printer, automatically print using correct method
      if (selectedPrinter != null) {
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        final appSettings = appSettingsProvider.appSettings;
        _handlePrinting(
            appSettings!.customerCarePhone, appSettings.customerCareEmail);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      debugPrint("No default printer saved in preferences");
    }
    debugPrint("=======================");
  }

  Future<void> _saveDefaultPrinter(BluetoothPrinter printer) async {
    debugPrint("===== PRINTER DEBUG =====");
    debugPrint(
        "Saving printer as default: ${printer.deviceName} (${printer.typePrinter})");
    debugPrint("Address: ${printer.address ?? 'N/A'}");
    debugPrint(
        "VendorID: ${printer.vendorId ?? 'N/A'}, ProductID: ${printer.productId ?? 'N/A'}");

    final prefs = await SharedPreferences.getInstance();
    final printerData = {
      'deviceName': printer.deviceName,
      'address': printer.address,
      'vendorId': printer.vendorId,
      'productId': printer.productId,
      'typePrinter': printer.typePrinter.toString(),
    };
    await prefs.setString('default_printer', json.encode(printerData));
    debugPrint("Printer saved to preferences: $printerData");
    debugPrint("=======================");
  }

  void selectPrinter(BluetoothPrinter printer) {
    // debugPrint('Selecting printer:');
    // debugPrint('Device Name: ${printer.deviceName}');
    // debugPrint('Address: ${printer.address}');
    // debugPrint('Type: ${printer.typePrinter}');
    // debugPrint('VendorId: ${printer.vendorId}');
    // debugPrint('ProductId: ${printer.productId}');

    setState(() {
      selectedPrinter = printer;
    });

    // Save the selected printer as default
    _saveDefaultPrinter(printer);

    if (mounted) {
      showScaffold(
        context: context,
        message: "${printer.deviceName.toString()} Printer Selected",
      );
    }
  }

  Future<void> _loadReceiptTemplate() async {
    debugPrint("===== TEMPLATE DEBUG =====");
    debugPrint("Loading receipt template from preferences...");
    
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = prefs.getString('receipt_templates');
    
    debugPrint("Found templates in prefs: ${templatesJson != null ? 'YES' : 'NO'}");
    
    ReceiptTemplate defaultTemplate;
    
    if (templatesJson != null) {
      try {
        final List<dynamic> decodedData = json.decode(templatesJson);
        debugPrint("Successfully decoded template data, found ${decodedData.length} templates");
        
        final List<ReceiptTemplate> loadedTemplates = decodedData
            .map((template) => ReceiptTemplate.fromJson(template))
            .toList();

        // Find default template
        defaultTemplate = loadedTemplates.firstWhere(
          (template) => template.isDefault,
          orElse: () => loadedTemplates.isNotEmpty
              ? loadedTemplates.first
              : _createDefaultTemplate(),
        );
        
        debugPrint("Found default template: ${defaultTemplate.name}");
      } catch (e) {
        debugPrint("ERROR decoding templates: $e");
        // Create a default template with appropriate settings
        defaultTemplate = _createDefaultTemplate();
      }
    } else {
      debugPrint("No templates found in preferences, creating default");
      // Create a default template with appropriate settings
      defaultTemplate = _createDefaultTemplate();
    }
    
    // Apply paper size-specific settings
    final settings = _updateSettingsForPaperSize(defaultTemplate.settings);
    defaultTemplate = ReceiptTemplate(
      name: defaultTemplate.name,
      settings: settings,
      isDefault: defaultTemplate.isDefault,
    );
    
    setState(() {
      selectedTemplate = defaultTemplate;
    });
    
    debugPrint("Final template settings after paper size adjustment:");
    debugPrint("showQRCode: ${defaultTemplate.settings.showQRCode}");
    debugPrint("showTermsConditions: ${defaultTemplate.settings.showTermsConditions}");
    debugPrint("=======================");
  }

  ReceiptTemplate _createDefaultTemplate() {
    final bool isSpecialPaperSize = selectedPaperSize == 'A4' || selectedPaperSize == 'A5';
    
    return ReceiptTemplate(
      name: 'Default Template',
      settings: ReceiptSettings(
        showStoreName: true,
        showDescription: true,
        showTel: true,
        showEmail: true,
        showInvoiceNumber: true,
        showStoreAddress: true,
        showFssaiInfo: true,
        showDateHeader: true,
        showSLNumber: true,
        showParticulars: true,
        showMRP: true,
        showQty: true,
        showRate: true,
        showTotal: true,
        showDiscount: true,
        showNetAmount: true,
        showMRPTotal: true,
        showSaved: true,
        showAmountInWords: true,
        showItemsCount: true,
        showThankYouMessage: true,
        showQRCode: !isSpecialPaperSize, // false for A4/A5
        showTermsConditions: !isSpecialPaperSize, // false for A4/A5
      ),
      isDefault: true,
    );
  }

  Future<void> printReceipt(
      String customerCareNumber, String customerCareEmail) async {
    debugPrint("===== THERMAL PRINTING DEBUG =====");
    if (selectedPrinter == null) {
      debugPrint("ERROR: No printer selected for thermal printing");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "No Printer Selected",
        );
      }
      return;
    }

    debugPrint("Printing receipt with thermal printer:");
    debugPrint(
        "Printer: ${selectedPrinter!.deviceName} (${selectedPrinter!.typePrinter})");
    debugPrint("Paper size: $selectedPaperSize");
    
    // Print template settings debug info
    _debugPrintTemplateSettings();

    try {
      // Connect to the printer
      debugPrint("Connecting to printer...");
      await _connectToPrinter();
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

      // Get settings from template or use defaults - respect user settings
      final settings = selectedTemplate?.settings ?? ReceiptSettings();
      
      debugPrint("Using user settings for printing:");
      debugPrint("showQRCode: ${settings.showQRCode}");
      debugPrint("showTermsConditions: ${settings.showTermsConditions}");
      
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final appSettings = appSettingsProvider.appSettings;

      // Header
      bytes += _buildHeader(generator, settings, appSettings!);

      // Cart Items
      bytes += _buildCartItems(generator, widget.cartItems, settings);

      // Total Amount
      bytes += _buildTotalAmount(generator, settings);

      // Thank You Message
      if (settings.showThankYouMessage) {
        bytes += _buildThankYouMessage(generator, settings);
      }

      // Debug: Check QR code setting
      debugPrint("QR Code setting from user: ${settings.showQRCode}");
      
      // QR Code - respect user setting without paper size check
      if (settings.showQRCode) {
        debugPrint("Adding QR code to receipt");
        bytes += _buildQRCode(generator, customerCareNumber, settings);
      } else {
        debugPrint("Skipping QR code, disabled in settings");
      }

      // Debug: Check Terms setting
      debugPrint("Terms & Conditions setting from user: ${settings.showTermsConditions}");
      
      // Terms & Conditions - respect user setting without paper size check
      if (settings.showTermsConditions) {
        debugPrint("Adding Terms & Conditions to receipt");
        bytes += _buildTermsConditions(generator, settings);
      } else {
        debugPrint("Skipping Terms & Conditions, disabled in settings");
      }

      // Cut the receipt
      bytes += generator.cut();

      debugPrint("Receipt generated, sending to printer...");
      // Print receipt
      await printerManager.send(
          type: selectedPrinter!.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully");

      if (mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e) {
      debugPrint("ERROR printing receipt: ${e.toString()}");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error printing: ${e.toString()}",
        );
      }
    } finally {
      debugPrint("Disconnecting from printer...");
      await _disconnectPrinter();
      debugPrint("==========================");
    }
  }

  List<int> _buildHeader(
      Generator generator, ReceiptSettings settings, AppSettings appSettings) {
    List<int> bytes = [];

    if (settings.showStoreName) {
      bytes += generator.row([
        PosColumn(
          text:
              settings.storeName.isNotEmpty ? settings.storeName : 'STORE NAME',
          width: 12,
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2),
        ),
      ]);
    }

    if (settings.showStoreAddress) {
      bytes += generator.row([
        PosColumn(
          text: settings.storeAddress.isNotEmpty
              ? settings.storeAddress
              : 'Shop Address',
          width: 12,
          styles: const PosStyles(
              align: PosAlign.center, height: PosTextSize.size1),
        ),
      ]);
    }

    if (settings.showFssaiInfo) {
      bytes += generator.row([
        PosColumn(
          text: settings.fssaiInfo.isNotEmpty
              ? settings.fssaiInfo
              : 'Fssai: xxxx',
          width: 12,
          styles: const PosStyles(
              align: PosAlign.center, height: PosTextSize.size1),
        ),
      ]);
    }

    if (settings.showTel) {
      bytes += generator.text(
          settings.telephone.isNotEmpty
              ? settings.telephone
              : 'TEL: ${appSettings.customerCarePhone}',
          styles: const PosStyles(align: PosAlign.center));
    }

    if (settings.showEmail) {
      bytes += generator.text(
          settings.email.isNotEmpty
              ? settings.email
              : 'Email: ${appSettings.customerCareEmail}',
          styles: const PosStyles(align: PosAlign.center));
    }

    // Add invoice title and number as separate elements
    if (settings.showInvoiceTitle) {
      bytes += generator.text(
          settings.invoiceTitle.isNotEmpty ? settings.invoiceTitle : appSettings.printTitle,
          styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    
    if (settings.showInvoiceNumber) {
      bytes += generator.text('INV No: ${widget.orderNumber}',
          styles: const PosStyles(align: PosAlign.center, bold: true));
    }

    if (settings.showDateHeader) {
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(
            text: DateHelper.formatISODate(widget.orderDate),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: DateHelper.formatISODateToIST(widget.orderDate),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
      bytes += generator.hr();
    }

    return bytes;
  }

  List<int> _buildTableHeader(Generator generator, ReceiptSettings settings) {
    List<PosColumn> columns = [];
    int totalWidth = 0;

    // Always add SL# column
    columns.add(PosColumn(
        text: 'SL#',
        width: 1,
        styles: const PosStyles(align: PosAlign.center)));
    totalWidth += 1;

    // Always add PARTICULARS column
    columns.add(PosColumn(text: 'PARTICULARS', width: 3));
    totalWidth += 3;

    // Always add MRP column
    columns.add(PosColumn(
        text: 'MRP', width: 2, styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Always add QTY column
    columns.add(PosColumn(
        text: 'QTY', width: 2, styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Always add RATE column
    columns.add(PosColumn(
        text: 'RATE',
        width: 2,
        styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Always add TOTAL column
    columns.add(PosColumn(
        text: 'TOTAL',
        width: 2,
        styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Adjust if total width is not 12
    if (totalWidth < 12 && columns.isNotEmpty) {
      // Add remaining width to the first column
      columns[0] = PosColumn(
        text: columns[0].text,
        width: columns[0].width + (12 - totalWidth),
        styles: columns[0].styles,
      );
    }

    return generator.row(columns) + generator.hr();
  }

  List<int> _buildCartItems(
      Generator generator, List<dynamic> cartItems, ReceiptSettings settings) {
    List<int> bytes = [];

    // Add table headers once at the top
    bytes += generator.row([
      PosColumn(
          text: '#SL',
          width: 2,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'MRP',
          width: 2,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'QTY',
          width: 2,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'RATE',
          width: 3,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
      PosColumn(
          text: 'TOTAL',
          width: 3,
          styles: const PosStyles(align: PosAlign.left, bold: true)),
    ]);

    bytes += generator.hr();

    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      // Handle different models based on data source
      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';

      // Adapt the model based on whether it's from local storage or current cart
      if (widget.isFromLocalStorage) {
        productName = item['productName'] ?? '';
        mrp = item['mrp'] ?? '0.00';
        quantity = item['quantity'] ?? '0';
        unitPrice = item['unitPrice'] ?? '0.00';
        totalPrice = item['totalPrice'] ?? '0.00';
      } else {
        productName = item.productName ?? '';
        mrp = item.mrp ?? '0.00';
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = item.unitPrice?.toString() ?? '0.00';
        totalPrice = item.totalPrice?.toString() ?? '0.00';
      }

      // Display the product name with serial number on one or two lines based on length
      String slNumber = (i + 1).toString();
      if (productName.length <= 28) {
        // Display on one line if it fits
        bytes += generator.row([
          PosColumn(
              text: '#$slNumber',
              width: 2,
              styles: const PosStyles(align: PosAlign.left)),
          PosColumn(
              text: productName,
              width: 10,
              styles: const PosStyles(align: PosAlign.left)),
        ]);
      } else {
        // Split across two lines if longer
        bytes += generator.row([
          PosColumn(
              text: '#$slNumber',
              width: 2,
              styles: const PosStyles(align: PosAlign.left)),
          PosColumn(
              text: productName.substring(0, 28),
              width: 10,
              styles: const PosStyles(align: PosAlign.left)),
        ]);

        // For continuation lines, add spaces instead of serial number
        String secondLine = productName.substring(28);

        // If second line is too long, truncate with ellipsis
        if (secondLine.length > 30) {
          secondLine = secondLine.substring(0, 27) + '...';
        }

        bytes += generator.row([
          PosColumn(
              text: '',
              width: 2,
              styles: const PosStyles(align: PosAlign.left)),
          PosColumn(
              text: secondLine,
              width: 10,
              styles: const PosStyles(align: PosAlign.left)),
        ]);
      }

      // Display item details in tabular format with indent to align with product name
      bytes += generator.row([
        PosColumn(
            text: '', width: 2, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: mrp, width: 2, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: quantity,
            width: 2,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: unitPrice,
            width: 3,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: totalPrice,
            width: 3,
            styles: const PosStyles(align: PosAlign.left)),
      ]);
    }

    return bytes;
  }

  List<int> _buildTotalAmount(Generator generator, ReceiptSettings settings) {
    List<int> bytes = [];

    // Display item count
    // if (settings.showMRPTotal) {
    //   bytes += generator.row([
    //     PosColumn(
    //         text: 'Discount',
    //         width: 6,
    //         styles: const PosStyles(
    //             align: PosAlign.left, bold: true, height: PosTextSize.size1)),
    //     PosColumn(
    //         text: (double.parse(widget.formattedTotal) -
    //                 double.parse(widget.savedTotal!))
    //             .toString(),
    //         width: 6,
    //         styles: const PosStyles(
    //             align: PosAlign.right, bold: true, height: PosTextSize.size1)),
    //   ]);
    // }

    if (settings.showNetAmount) {
      bytes += generator.row([
        PosColumn(
            text: 'Net Total',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size2)),
        PosColumn(
            text: widget.formattedTotal,
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size2)),
      ]);
    }

    if (settings.showMRPTotal) {
      bytes += generator.row([
        PosColumn(
            text: 'Total MRP',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text:
                "${(double.parse(widget.savedTotal!) + double.parse(widget.formattedTotal))}",
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    if (settings.showSaved) {
      bytes += generator.row([
        PosColumn(
            text: 'You Saved',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: widget.savedTotal.toString(),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    // Add a separator line
    bytes += generator.hr();

    if (settings.showAmountInWords) {
      bytes += generator.text(
          '${AmountHelper().convertNumberToWords(double.parse(widget.formattedTotal))} Only.',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();
    }

    // Display item count
    if (settings.showMRPTotal) {
      bytes += generator.row([
        PosColumn(
            text: 'Items',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: widget.cartItems.length.toString(),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }
    bytes += generator.hr();

    return bytes;
  }

  List<int> _buildThankYouMessage(
      Generator generator, ReceiptSettings settings) {
    List<int> bytes = [];

    bytes += generator.text(
        settings.thankYouMessage.isNotEmpty
            ? settings.thankYouMessage
            : 'Thank You... Visit Again',
        styles: const PosStyles(bold: true, align: PosAlign.center));

    bytes += generator.hr();
    return bytes;
  }

  List<int> _buildQRCode(Generator generator, String customerCareNumber,
      ReceiptSettings settings) {
    // Double-check settings
    if (!settings.showQRCode) {
      debugPrint("QR Code disabled in settings, skipping");
      return [];
    }
    
    debugPrint("Generating QR code (enabled in settings)");
    
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
    List<int> bytes = [];

    bytes += generator.emptyLines(1);

    bytes += generator.qrcode(
      'upi://pay?pa=${manualPaymentGateway.link}&am=${widget.formattedTotal}&tn=${widget.orderNumber}&cu=INR&ds=EPOS&t=c&st=1&se=1&sd=1',
      size: QRSize.Size4,
      align: PosAlign.center,
    );

    bytes += generator.emptyLines(1);

    bytes += generator.text(
        settings.qrCodeMessage.isNotEmpty
            ? settings.qrCodeMessage
            : 'Scan this QR code to Pay',
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.emptyLines(1);
    return bytes;
  }

  List<int> _buildTermsConditions(
      Generator generator, ReceiptSettings settings) {
    // Double-check settings
    if (!settings.showTermsConditions) {
      debugPrint("Terms & Conditions disabled in settings, skipping");
      return [];
    }
    
    debugPrint("Generating Terms & Conditions (enabled in settings)");
    
    List<int> bytes = [];

    bytes += generator.text('Terms & Conditions',
        styles: const PosStyles(bold: true, align: PosAlign.left));

    String terms = settings.termsConditions.isNotEmpty
        ? settings.termsConditions
        : '1. Replace or Return only within 7 Days of Purchase.\n2. Replace only with Bill.';

    List<String> termsList = terms.split('\n');
    for (var term in termsList) {
      bytes +=
          generator.text(term, styles: const PosStyles(align: PosAlign.left));
    }

    bytes += generator.hr();
    return bytes;
  }

  Future<void> _connectToPrinter() async {
    if (selectedPrinter!.typePrinter == PrinterType.usb) {
      await printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: selectedPrinter!.deviceName ?? 'Unknown',
          productId: selectedPrinter!.productId,
          vendorId: selectedPrinter!.vendorId,
        ),
      );
    } else if (selectedPrinter!.typePrinter == PrinterType.bluetooth) {
      if (selectedPrinter!.address == null) {
        throw Exception('Bluetooth printer address is null');
      }
      await printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: selectedPrinter!.deviceName ?? 'Unknown',
          address: selectedPrinter!.address!,
          isBle: false,
        ),
      );
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
      await printerManager.disconnect(type: selectedPrinter!.typePrinter);
    } catch (e) {
      // Handle disconnection error
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    debugPrint("appSettings!.customerCareEmail.toString()");
    debugPrint(appSettings!.customerCareEmail.toString());

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Select Printer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            SideBarController sideBarController = Get.put(SideBarController());
            sideBarController.index.value = 46;
          },
        ),
        elevation: 0,
        backgroundColor: primaryColor,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Paper Size Selection Card
            Card(
              elevation: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.1), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paper Size',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPaperSize,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: paperSizes.map((String size) {
                        return DropdownMenuItem<String>(
                          value: size,
                          child: Text(size),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedPaperSize = newValue!;
                          _saveDefaultPaperSize(selectedPaperSize);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.1), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Printers',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning
                          ? 'Scanning...'
                          : '${devices.length} devices found',
                      style: const TextStyle(
                        color: textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.print_disabled,
                            size: 64,
                            color: textSecondaryColor,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No printers found',
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the refresh button to scan for printers',
                            style: TextStyle(
                              color: textSecondaryColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final printer = devices[index];
                        final isSelected = selectedPrinter == printer;

                        return Card(
                          elevation: isSelected ? 2 : 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: primaryColor, width: 2)
                                  : null,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.print,
                                color: isSelected
                                    ? primaryColor
                                    : textSecondaryColor,
                                size: 28,
                              ),
                              title: Text(
                                printer.deviceName ?? 'Unknown device',
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                printer.address ?? '',
                                style: const TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? accentColor
                                      : Colors.grey[200],
                                  foregroundColor: isSelected
                                      ? Colors.white
                                      : textSecondaryColor,
                                  elevation: isSelected ? 2 : 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () => selectPrinter(printer),
                                child: Text(
                                  isSelected ? 'Selected' : 'Select',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => selectedPrinter == null
                  ? null
                  : _handlePrinting(appSettings.customerCarePhone,
                      appSettings.customerCareEmail),
              icon: const Icon(Icons.receipt_long),
              label: const Text(
                'Print Receipt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: textSecondaryColor.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _checkPermissions,
        tooltip: 'Scan for printers',
        backgroundColor: _isScanning ? textSecondaryColor : primaryColor,
        elevation: 4,
        child: _isScanning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.refresh,
                color: Colors.white,
              ),
      ),
    );
  }

  // Function to handle printing based on selected paper size
  Future<void> _handlePrinting(
      String customerCareNumber, String customerCareEmail) async {
    debugPrint("===== PRINTING DEBUG =====");
    debugPrint("Starting print job with:");
    debugPrint(
        "Selected printer: ${selectedPrinter?.deviceName ?? 'None'} (${selectedPrinter?.typePrinter.toString() ?? 'Unknown'})");
    debugPrint("Selected paper size: $selectedPaperSize");

    // Ensure template settings are up to date before printing
    await reloadTemplateSettings();

    if (selectedPaperSize == '80mm' || selectedPaperSize == '58mm') {
      // Use thermal printer for thermal paper sizes
      debugPrint("Using thermal printing method for $selectedPaperSize paper");
      await printReceipt(customerCareNumber, customerCareEmail);
    } else {
      // Use PDF generation for A4/A5 paper sizes
      debugPrint("Using PDF generation method for $selectedPaperSize paper");
      await generateAndPrintPDF(customerCareNumber, customerCareEmail);
    }
    debugPrint("========================");
  }

  // Method for PDF generation and printing to standard printers
  Future<void> generateAndPrintPDF(
      String customerCareNumber, String customerCareEmail) async {
    try {
      // Print template settings debug info
      _debugPrintTemplateSettings();
      
      if (mounted) {
        showScaffold(
          context: context,
          message: "Preparing ${selectedPaperSize} document for printing...",
        );
      }

      // Create a PDF document
      final pdf = pw.Document();

      // Get settings from template or use defaults - respect user settings
      final settings = selectedTemplate?.settings ?? ReceiptSettings();
      
      // Use settings as-is without forcing QR and Terms to be disabled
      final updatedSettings = settings;
      
      debugPrint("PDF Generation - Using user settings:");
      debugPrint("showQRCode: ${updatedSettings.showQRCode}");
      debugPrint("showTermsConditions: ${updatedSettings.showTermsConditions}");

      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final appSettings = appSettingsProvider.appSettings;
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

      // Determine page format based on paper size
      PdfPageFormat pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;

      // Define styles with adjustments for A5 vs A4
      final headerStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 16.0 : 18.0,
        fontWeight: pw.FontWeight.bold,
      );
      final subheaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 12.0 : 14.0,
        fontWeight: pw.FontWeight.bold,
      );
      final bodyStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.0 : 11.0,
      );
      final smallStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.0 : 9.0,
      );
      final tableHeaderStyle = pw.TextStyle(
        fontSize: selectedPaperSize == 'A5' ? 7.0 : 10.0,
        fontWeight: pw.FontWeight.bold,
      );

      // Add content to a multi-page PDF so overflow flows to new pages
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(30),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
          build: (pw.Context context) => [
            // Wrap entire content in a Column so it flows
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with store information
                pw.Center(
                  child: pw.Column(
                    children: [
                      // Store name
                      if (updatedSettings.showStoreName)
                        pw.Text(
                          updatedSettings.storeName.isNotEmpty
                              ? updatedSettings.storeName
                              : 'STORE NAME',
                          style: headerStyle,
                        ),

                      // Store description
                      if (updatedSettings.showDescription)
                        pw.Text(
                          updatedSettings.description.isNotEmpty
                              ? updatedSettings.description
                              : 'Mini Supermarket',
                          style: pw.TextStyle(
                            fontSize: selectedPaperSize == 'A5' ? 10.0 : 12.0,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),

                      // Store address
                      if (updatedSettings.showStoreAddress)
                        pw.Text(
                          updatedSettings.storeAddress.isNotEmpty
                              ? updatedSettings.storeAddress
                              : 'Shop Address',
                          style: bodyStyle,
                        ),

                      // FSSAI info
                      if (updatedSettings.showFssaiInfo)
                        pw.Text(
                          updatedSettings.fssaiInfo.isNotEmpty
                              ? updatedSettings.fssaiInfo
                              : 'Fssai: xxxx',
                          style: bodyStyle,
                        ),

                      // Contact information
                      if (updatedSettings.showTel)
                        pw.Text(
                          updatedSettings.telephone.isNotEmpty
                              ? updatedSettings.telephone
                              : 'TEL: ${appSettings!.customerCarePhone}',
                          style: bodyStyle,
                        ),

                      if (updatedSettings.showEmail)
                        pw.Text(
                          updatedSettings.email.isNotEmpty
                              ? updatedSettings.email
                              : 'Email: ${appSettings!.customerCareEmail}',
                          style: bodyStyle,
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Invoice information in a framed box
                if (updatedSettings.showInvoiceTitle || updatedSettings.showInvoiceNumber)
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1, color: PdfColors.grey300),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            if (updatedSettings.showInvoiceTitle)
                              pw.Text(
                                updatedSettings.invoiceTitle.isNotEmpty
                                    ? updatedSettings.invoiceTitle
                                    : appSettings!.printTitle,
                                style: subheaderStyle
                              ),
                            if (updatedSettings.showInvoiceNumber)
                              pw.Text('No: ${widget.orderNumber}',
                                style: subheaderStyle
                              ),
                          ],
                        ),
                        if (updatedSettings.showDateHeader) ...[
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                  'Date: ${DateHelper.formatISODate(widget.orderDate)}',
                                  style: bodyStyle),
                              pw.Text(
                                  'Time: ${DateHelper.formatISODateToIST(widget.orderDate)}',
                                  style: bodyStyle),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                pw.SizedBox(height: 15),

                // Items table in a framed box
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: PdfColors.grey300),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ITEM DETAILS', style: subheaderStyle),
                      pw.SizedBox(height: 10),
                      _buildPdfItemsTable(tableHeaderStyle, bodyStyle, updatedSettings),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                // Summary in a framed box
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: PdfColors.grey300),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ORDER SUMMARY', style: subheaderStyle),
                      pw.SizedBox(height: 10),
                      _buildPdfSummary(bodyStyle, updatedSettings),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // Amount in words
                if (updatedSettings.showAmountInWords)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 10),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey300),
                        bottom: pw.BorderSide(color: PdfColors.grey300),
                      ),
                    ),
                    child: pw.Text(
                      'Amount in words: ${AmountHelper().convertNumberToWords(double.parse(widget.formattedTotal))} Only.',
                      style: pw.TextStyle(
                        fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),

                pw.SizedBox(height: 10),

                // Footer section
                pw.Column(
                  children: [
                    // Thank You message
                    if (updatedSettings.showThankYouMessage)
                      pw.Center(
                        child: pw.Text(
                          updatedSettings.thankYouMessage.isNotEmpty
                              ? updatedSettings.thankYouMessage
                              : 'Thank You... Visit Again',
                          style: subheaderStyle,
                        ),
                      ),

                    pw.SizedBox(height: 10),

                    // QR Code for payment - Only show if enabled in settings
                    if (updatedSettings.showQRCode) ...[
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data:
                                  'upi://pay?pa=${manualPaymentGateway.link}&am=${widget.formattedTotal}&tn=${widget.orderNumber}&cu=INR&ds=EPOS&t=c&st=1&se=1&sd=1',
                              width: selectedPaperSize == 'A5' ? 100 : 120,
                              height: selectedPaperSize == 'A5' ? 100 : 120,
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              updatedSettings.qrCodeMessage.isNotEmpty
                                  ? updatedSettings.qrCodeMessage
                                  : 'Scan to Pay',
                              style: pw.TextStyle(
                                fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),
                    ],

                    // Terms & Conditions - Only show if enabled in settings
                    if (updatedSettings.showTermsConditions) ...[
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Terms & Conditions:',
                              style: pw.TextStyle(
                                  fontSize:
                                      selectedPaperSize == 'A5' ? 7.0 : 10.0,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          ..._buildTermsConditionsList(
                              updatedSettings.termsConditions.isNotEmpty
                                  ? updatedSettings.termsConditions
                                  : '1. Replace or Return only within 7 Days of Purchase.\n2. Replace only with Bill.\n3. Warranty as per manufacturer terms and conditions.',
                              smallStyle),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Save PDF to a temporary file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Receipt-${widget.orderNumber}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Determine if running on Windows
      final bool isWindows = Platform.isWindows;

      if (isWindows) {
        await _handleWindowsPdf(file);
      } else {
        // Try to open the PDF directly for non-Windows platforms
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            if (!isWindows) {
              await _sharePdfFallback(file);
            } else {
              _showFileLocationInfo(file);
            }
          } else {
            if (mounted) {
              showScaffold(
                  context: context, message: "PDF opened for printing");
              Navigator.pop(context);
              SideBarController sideBarController =
                  Get.put(SideBarController());
              sideBarController.index.value = 46;
            }
          }
        } catch (e) {
          if (!isWindows) {
            await _sharePdfFallback(file);
          } else {
            _showFileLocationInfo(file);
          }
        }
      }
    } catch (e) {
      debugPrint("Error generating PDF: $e");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: ${e.toString()}",
        );
      }
    }
  }

  // Windows-specific handling for PDF
  Future<void> _handleWindowsPdf(File file) async {
    try {
      // First try to open with the default Windows PDF viewer
      final result = await OpenFile.open(file.path);

      // Always close the page on Windows, regardless of result
      if (mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e) {
      debugPrint("Windows PDF handling error: $e");
      // Still close the page on error
      if (mounted) {
        showScaffold(context: context, message: "PDF created successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    }
  }

  // Show information about file location (for Windows) - Now unused but kept for reference
  void _showFileLocationInfo(File file) {
    if (mounted) {
      // Just close the page instead of showing dialog
      Navigator.pop(context);
      SideBarController sideBarController = Get.put(SideBarController());
      sideBarController.index.value = 46;
    }
  }

  // Fallback method to share PDF if direct opening fails (for mobile platforms)
  Future<void> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share PDF as fallback...");
      // Only try to share on non-Windows platforms
      if (!Platform.isWindows) {
        await Share.shareFiles(
          [file.path],
          subject: 'Receipt #${widget.orderNumber}',
          text: 'Your receipt for order #${widget.orderNumber}',
        );

        if (mounted) {
          showScaffold(
              context: context, message: "PDF shared. Please open it to print");
          Navigator.pop(context);
          SideBarController sideBarController = Get.put(SideBarController());
          sideBarController.index.value = 46;
        }
      } else {
        // For Windows, show the file location
        _showFileLocationInfo(file);
      }
    } catch (e) {
      debugPrint("Error sharing PDF fallback: $e");
      if (mounted) {
        if (Platform.isWindows) {
          // Show file location on Windows
          _showFileLocationInfo(file);
        } else {
          showScaffoldError(
            context: context,
            message:
                "Unable to open or share PDF: ${e.toString()}. Please check app permissions.",
          );
        }
      }
    }
  }

  pw.Widget _buildPdfItemsTable(
      pw.TextStyle headerStyle, pw.TextStyle contentStyle, ReceiptSettings settings) {
    // Create headers for the table
    final tableHeaders = [];
    if (settings.showSLNumber) tableHeaders.add('SL#');
    if (settings.showParticulars) tableHeaders.add('PARTICULARS');
    if (settings.showMRP) tableHeaders.add('MRP');
    if (settings.showQty) tableHeaders.add('QTY');
    if (settings.showRate) tableHeaders.add('RATE');
    if (settings.showTotal) tableHeaders.add('TOTAL');

    // Create table data
    List<List<String>> tableData = [];
    for (var i = 0; i < widget.cartItems.length; i++) {
      var item = widget.cartItems[i];

      // Handle different models based on data source
      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';

      // Adapt the model based on whether it's from local storage or current cart
      if (widget.isFromLocalStorage) {
        productName = item['productName'] ?? '';
        mrp = item['mrp'] ?? '0.00';
        quantity = item['quantity'] ?? '0';
        unitPrice = item['unitPrice'] ?? '0.00';
        totalPrice = item['totalPrice'] ?? '0.00';
      } else {
        productName = item.productName ?? '';
        mrp = item.mrp ?? '0.00';
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = item.unitPrice?.toString() ?? '0.00';
        totalPrice = item.totalPrice?.toString() ?? '0.00';
      }

      List<String> rowData = [];
      if (settings.showSLNumber) rowData.add((i + 1).toString());
      if (settings.showParticulars) rowData.add(productName);
      if (settings.showMRP) rowData.add(mrp);
      if (settings.showQty) rowData.add(quantity);
      if (settings.showRate) rowData.add(unitPrice);
      if (settings.showTotal) rowData.add(totalPrice);

      tableData.add(rowData);
    }

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      headerStyle: headerStyle,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
      ),
      headerHeight: 25,
      cellStyle: contentStyle,
      cellHeight: 25,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.all(5),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
    );
  }

  pw.Widget _buildPdfSummary(pw.TextStyle style, ReceiptSettings settings) {
    double savedTotal = double.tryParse(widget.savedTotal ?? '0.0') ?? 0.0;
    double formattedTotal = double.tryParse(widget.formattedTotal) ?? 0.0;
    double totalMRP = savedTotal + formattedTotal;

    List<pw.Widget> summaryWidgets = [];

    if (settings.showItemsCount) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total Items:', style: style),
            pw.Text(widget.cartItems.length.toString(), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    if (settings.showMRPTotal) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total MRP:', style: style),
            pw.Text(totalMRP.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    if (settings.showSaved) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('You Saved:', style: style),
            pw.Text(savedTotal.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    if (settings.showNetAmount) {
      summaryWidgets.add(pw.Divider(color: PdfColors.grey300));
      summaryWidgets.add(pw.SizedBox(height: 5));
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Net Total:',
                style: pw.TextStyle(
                  fontSize: 12.0,
                  fontWeight: pw.FontWeight.bold,
                )),
            pw.Text(formattedTotal.toStringAsFixed(2),
                style: pw.TextStyle(
                  fontSize: 12.0,
                  fontWeight: pw.FontWeight.bold,
                )),
          ],
        ),
      );
    }

    return pw.Column(children: summaryWidgets);
  }

  List<pw.Widget> _buildTermsConditionsList(
      String termsText, pw.TextStyle style) {
    List<String> terms = termsText.split('\n');
    List<pw.Widget> termWidgets = [];

    for (int i = 0; i < terms.length; i++) {
      termWidgets.add(
        pw.Text(
          terms[i],
          style: style,
        ),
      );

      if (i < terms.length - 1) {
        termWidgets.add(pw.SizedBox(height: 2));
      }
    }

    return termWidgets;
  }

  Future<void> _loadDefaultPaperSize() async {
    debugPrint("===== PAPER SIZE DEBUG =====");
    debugPrint("Loading default paper size from preferences...");

    final prefs = await SharedPreferences.getInstance();
    final defaultPaperSize = prefs.getString('default_paper_size');

    debugPrint(
        "Found saved paper size: ${defaultPaperSize ?? 'None (will use default 80mm)'}");

    if (defaultPaperSize != null) {
      setState(() {
        // Handle migration from 'Thermal' to '80mm'
        if (defaultPaperSize == 'Thermal') {
          selectedPaperSize = '80mm';
          debugPrint("Converting legacy 'Thermal' value to '80mm'");
          // Update stored preference to new value
          _saveDefaultPaperSize('80mm');
        } else {
          selectedPaperSize = defaultPaperSize;
          debugPrint("Set selected paper size to: $selectedPaperSize");
        }
      });
    } else {
      debugPrint("No saved paper size, using default: $selectedPaperSize");
    }
    debugPrint("===========================");
  }

  Future<void> _saveDefaultPaperSize(String paperSize) async {
    debugPrint("===== PAPER SIZE DEBUG =====");
    debugPrint("Saving paper size as default: $paperSize");

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_paper_size', paperSize);

    // Force reload template settings when paper size changes
    setState(() {
      selectedPaperSize = paperSize;
    });
    
    await reloadTemplateSettings();
    
    debugPrint("Paper size saved and template reloaded");
    debugPrint("===========================");
  }

  // Add this method to print debugging info before generating outputs
  void _debugPrintTemplateSettings() {
    if (selectedTemplate == null) {
      debugPrint("ERROR: No template selected!");
      return;
    }
    
    debugPrint("Current template settings:");
    debugPrint("Template name: ${selectedTemplate!.name}");
    debugPrint("Paper size: $selectedPaperSize");
    debugPrint("showQRCode: ${selectedTemplate!.settings.showQRCode}");
    debugPrint("showTermsConditions: ${selectedTemplate!.settings.showTermsConditions}");
  }

  // Add this new method to reload template settings
  Future<void> reloadTemplateSettings() async {
    debugPrint("===== RELOAD TEMPLATE DEBUG =====");
    debugPrint("Reloading template settings...");
    await _loadReceiptTemplate();
    debugPrint("Template reload complete");
    debugPrint("===============================");
  }

  // Add a global method to update settings before any printing or PDF generation
  ReceiptSettings _updateSettingsForPaperSize(ReceiptSettings settings) {
    // No longer force disable QR code and terms for A4/A5
    // Instead respect user settings for all paper sizes
    debugPrint("Using original settings for ${selectedPaperSize}");
    debugPrint("showQRCode: ${settings.showQRCode}");
    debugPrint("showTermsConditions: ${settings.showTermsConditions}");
    return settings;
  }

  // Update the receipt preview in the settings screen to show the invoice title and number separately
  Widget _buildReceiptPreview() {
    if (selectedTemplate == null) return const SizedBox();

    final settings = selectedTemplate!.settings;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      width: 300,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Store Header
            if (settings.showStoreName)
              Text(
                settings.storeName.isNotEmpty
                    ? settings.storeName
                    : 'STORE NAME',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            if (settings.showDescription)
              Text(
                settings.description.isNotEmpty
                    ? settings.description
                    : 'Your one-stop shop for all needs',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            if (settings.showStoreAddress)
              Text(
                settings.storeAddress.isNotEmpty
                    ? settings.storeAddress
                    : 'Shop Address',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showFssaiInfo)
              Text(
                settings.fssaiInfo.isNotEmpty
                    ? settings.fssaiInfo
                    : 'Fssai: xxxx',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showTel)
              Text(
                settings.telephone.isNotEmpty
                    ? settings.telephone
                    : 'TEL: ${appSettings?.customerCarePhone ?? ""}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showEmail)
              Text(
                settings.email.isNotEmpty
                    ? settings.email
                    : 'Email: ${appSettings?.customerCareEmail ?? ""}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            
            // Invoice Title and Number
            if (settings.showInvoiceTitle)
              Text(
                settings.invoiceTitle.isNotEmpty
                    ? settings.invoiceTitle
                    : 'INVOICE',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            if (settings.showInvoiceNumber)
              const Text(
                'INV No: 12345',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            const Divider(),

            // ... rest of the existing code ...
          ],
        ),
      ),
    );
  }
}

class BluetoothPrinter {
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  PrinterType typePrinter;
  bool isConnected;

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.bluetooth,
    this.isConnected = false,
  });

  bool get isUSB => typePrinter == PrinterType.usb;
  bool get isBluetooth => typePrinter == PrinterType.bluetooth;
}
