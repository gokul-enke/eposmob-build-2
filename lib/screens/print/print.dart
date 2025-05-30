import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:pos_machine/providers/document_config_provider.dart'; // Import DocumentConfigProvider
import 'package:pos_machine/models/document_configurations.dart';

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
  // Removed selectedTemplate
  String selectedPaperSize = '80mm'; // Default to 80mm thermal paper

  // Add DocumentConfig state variable
  DocumentConfig? _billDocumentConfig;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      Provider.of<PaymentGatewaysProvider>(context, listen: false)
          .fetchPaymentGateways(accessToken: accessToken!);

      // Load saved paper size first so auto-print uses correct method
      await _loadDefaultPaperSize();

      // Fetch document configurations and load the Bill template first
      // This is critical for auto-printing to work properly
      await _loadDocumentConfigurations(accessToken);

      // Load default printer last (this may trigger auto-printing)
      await _loadDefaultPrinter();
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
        if (_billDocumentConfig != null) {
          final appSettingsProvider =
              Provider.of<AppSettingsProvider>(context, listen: false);
          final appSettings = appSettingsProvider.appSettings;
          _handlePrinting(
              appSettings!.customerCarePhone, appSettings.customerCareEmail);
        } else {
          debugPrint(
              "Waiting for document configurations to load before auto-printing");
        }
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

  // New method to load document configurations
  Future<void> _loadDocumentConfigurations(String accessToken) async {
    try {
      debugPrint("===== CONFIG LOADING DEBUG =====");
      debugPrint("Fetching document configurations...");
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      await docConfigProvider.fetchDocumentConfigurations(
          accessToken: accessToken);

      // Find the "Bill" configuration
      _billDocumentConfig = docConfigProvider.getDocumentConfig("Bill");

      if (_billDocumentConfig != null) {
        debugPrint(
            "Successfully loaded 'Bill' document configuration. Display settings:");
        _billDocumentConfig?.displayConfiguration?.options
            ?.forEach((key, value) {
          debugPrint("- $key: visible=${value.visible}, value=${value.value}");
        });
      } else {
        debugPrint(
            "ERROR: 'Bill' document configuration not found in API response.");
        if (mounted) {
          showScaffoldError(
            context: context,
            message: "Bill document configuration not found.",
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
      debugPrint("=======================");
    } catch (e) {
      debugPrint("ERROR fetching document configurations: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error loading document configurations: ${e.toString()}",
        );
      }
    }
  }
  // Removed _loadReceiptTemplate method
  // Removed _createDefaultTemplate method

  // Removed reloadTemplateSettings method
  // Removed _updateSettingsForPaperSize method

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

    // Ensure _billDocumentConfig is loaded before printing
    if (_billDocumentConfig == null) {
      debugPrint("ERROR: Bill document configuration not loaded yet.");
      if (mounted) {
        // showScaffoldError(
        //   context: context,
        //   message: "Document configurations not loaded. Please wait.",
        // );
      }
      return;
    }

    debugPrint("Printing receipt with thermal printer:");
    debugPrint(
        "Printer: ${selectedPrinter!.deviceName} (${selectedPrinter!.typePrinter})");
    debugPrint("Paper size: $selectedPaperSize");

    // Use the loaded display configuration
    final displayConfig = _billDocumentConfig?.displayConfiguration?.options;
    _debugPrintTemplateSettings(
        displayConfig); // Updated debug print to take config

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

      // Pass the display config and document config to helper functions
      bytes += _buildHeader(generator, displayConfig, _billDocumentConfig);
      bytes += _buildCartItems(generator, widget.cartItems, displayConfig,
          widget.isFromLocalStorage);
      bytes += _buildTotalAmount(generator, displayConfig,
          widget.formattedTotal, widget.savedTotal, widget.cartItems.length);

      // Thank You Message
      if (displayConfig?['showThankYouMessage']?.visible == true) {
        bytes += _buildThankYouMessage(generator, displayConfig);
      }

      // QR Code
      if (displayConfig?['showQRCode']?.visible == true) {
        // Access link from PaymentGatewaysProvider
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
            widget.formattedTotal, widget.orderNumber, displayConfig);
      } else {
        debugPrint("Skipping QR code, disabled in settings");
      }

      // Terms & Conditions
      if (displayConfig?['showTermsConditions']?.visible == true) {
        bytes += _buildTermsConditions(generator, displayConfig);
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

  // Modify _buildHeader to use DisplayConfiguration and DocumentConfig
  List<int> _buildHeader(Generator generator,
      Map<String, DisplayOption>? displayConfig, DocumentConfig? docConfig) {
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
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2),
        ),
      ]);
    }

    // Description (subheader from DocumentConfig or value from displayConfig)
    if (displayConfig?['showDescription']?.visible == true) {
      final description = displayConfig?['showDescription']?.value as String? ??
          docConfig?.subheader ??
          'Mini Supermarket';
      bytes += generator.row([
        PosColumn(
          text: description.isNotEmpty ? description : 'Mini Supermarket',
          width: 12,
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size1,
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
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size1,
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
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size1,
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
            styles: const PosStyles(align: PosAlign.center));
      }
    }

    // Email
    if (displayConfig?['showEmail']?.visible == true) {
      final email = displayConfig?['showEmail']?.value as String? ??
          appSettings?.customerCareEmail ??
          '';
      if (email.isNotEmpty) {
        bytes += generator.text('Email: $email',
            styles: const PosStyles(align: PosAlign.center));
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
          styles: const PosStyles(align: PosAlign.center, bold: true));
    }

    // Invoice Number
    if (displayConfig?['showInvoiceNumber']?.visible == true) {
      // Use the numberPrefix from docConfig if available, otherwise just use orderNumber
      final invoiceNumberText =
          docConfig?.numberPrefix != null && docConfig!.numberPrefix!.isNotEmpty
              ? '${docConfig.numberPrefix}${widget.orderNumber}'
              : 'INV No: ${widget.orderNumber}';

      bytes += generator.text(invoiceNumberText,
          styles: const PosStyles(align: PosAlign.center, bold: true));
    }

    // Date Header
    if (displayConfig?['showDateHeader']?.visible == true) {
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
// Removed _buildTableHeader (it was unused in the original code)

  // Modify _buildCartItems to use DisplayConfiguration and DocumentConfig
  List<int> _buildCartItems(Generator generator, List<dynamic> cartItems,
      Map<String, DisplayOption>? displayConfig, bool isFromLocalStorage) {
    List<int> bytes = [];

    // Determine if we're using 58mm paper for font size adjustment
    bool is58mm = selectedPaperSize == '58mm';

    // Add table headers with fixed widths as requested
    // Header: #SL=1, PARTICULARS=3, MRP=2, QTY=2, RATE=2, TOTAL=2 = Total 12
    
    List<PosColumn> headerColumns = [];
    
    if (displayConfig?['showSLNumber']?.visible == true) {
      headerColumns.add(PosColumn(
          text: '#SL',
          width: 1,
          styles: PosStyles(
            align: PosAlign.left, 
            bold: true,
            height: is58mm ? PosTextSize.size1 : PosTextSize.size1
          )));
    }
    
    if (displayConfig?['showParticulars']?.visible == true) {
      final label = _billDocumentConfig?.resolvedLabels?.itemName ?? 'PARTICULARS';
      // Fixed width for header title
      int particularsWidth = 3;
      if (displayConfig?['showSLNumber']?.visible != true) {
        particularsWidth += 1; // Add SL width if SL is not visible
      }
      
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: particularsWidth,
          styles: PosStyles(
            align: PosAlign.left, 
            bold: true,
            height: is58mm ? PosTextSize.size1 : PosTextSize.size1
          )));
    }
    
    if (displayConfig?['showMRP']?.visible == true) {
      headerColumns.add(PosColumn(
          text: 'MRP',
          width: 2,
          styles: PosStyles(
            align: PosAlign.right, 
            bold: true,
            height: is58mm ? PosTextSize.size1 : PosTextSize.size1
          )));
    }
    
    if (displayConfig?['showQty']?.visible == true) {
      final label = _billDocumentConfig?.resolvedLabels?.unitName ?? 'QTY';
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
            align: PosAlign.right, 
            bold: true,
            height: is58mm ? PosTextSize.size1 : PosTextSize.size1
          )));
    }
    
    if (displayConfig?['showRate']?.visible == true) {
      final label = _billDocumentConfig?.resolvedLabels?.priceName ?? 'RATE';
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
            align: PosAlign.right, 
            bold: true,
            height: is58mm ? PosTextSize.size1 : PosTextSize.size1
          )));
    }
    
    if (displayConfig?['showTotal']?.visible == true) {
      final label = _billDocumentConfig?.resolvedLabels?.amountName ?? 'TOTAL';
      headerColumns.add(PosColumn(
          text: label.toUpperCase(),
          width: 2,
          styles: PosStyles(
            align: PosAlign.right, 
            bold: true,
            height: is58mm ? PosTextSize.size1 : PosTextSize.size1
          )));
    }
    
    if (headerColumns.isNotEmpty) {
      bytes += generator.row(headerColumns);
      bytes += generator.hr();
    }

    // Now process each cart item with the new structure
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';

      if (isFromLocalStorage) {
        productName = item['productName'] ?? '';
        mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        quantity = item['quantity'] ?? '0';
        unitPrice = (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        totalPrice = (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
      } else {
        productName = item.productName ?? '';
        mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        totalPrice = (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
      }

      String slNumber = (i + 1).toString();
      
      // First row: SL# + Product Name (product name takes full width, not header width)
      List<PosColumn> productNameRow = [];
      
      if (displayConfig?['showSLNumber']?.visible == true) {
        productNameRow.add(PosColumn(
            text: '#$slNumber',
            width: 1,
            styles: PosStyles(
              align: PosAlign.left,
              height: is58mm ? PosTextSize.size1 : PosTextSize.size1
            )));
      }
      
      if (displayConfig?['showParticulars']?.visible == true) {
        // Product name takes full width: 11 (when SL visible) or 12 (when SL hidden)
        int productNameWidth = displayConfig?['showSLNumber']?.visible == true ? 11 : 12;
        
        // Calculate character limit for product name based on width
        // Use a more conservative estimate for character wrapping
        int maxCharsPerLine = productNameWidth * 3; // Reduced from 4 to 3 for better wrapping
        
        if (productName.length <= maxCharsPerLine) {
          // Product name fits in one line - takes full width
          productNameRow.add(PosColumn(
              text: productName,
              width: productNameWidth,
              styles: PosStyles(
                align: PosAlign.left,
                height: is58mm ? PosTextSize.size1 : PosTextSize.size1
              )));
          
          bytes += generator.row(productNameRow);
        } else {
          // Product name needs multiple lines - split properly
          String remainingName = productName;
          bool isFirstLine = true;
          
          while (remainingName.isNotEmpty) {
            String currentLine;
            
            if (remainingName.length <= maxCharsPerLine) {
              // Remaining text fits in current line
              currentLine = remainingName;
              remainingName = '';
            } else {
              // Find a good break point (prefer breaking at spaces)
              int breakPoint = maxCharsPerLine;
              
              // Look for a space near the break point to avoid cutting words
              for (int i = maxCharsPerLine - 1; i >= maxCharsPerLine - 10 && i >= 0; i--) {
                if (i < remainingName.length && remainingName[i] == ' ') {
                  breakPoint = i;
                  break;
                }
              }
              
              currentLine = remainingName.substring(0, breakPoint).trim();
              remainingName = remainingName.substring(breakPoint).trim();
            }
            
            List<PosColumn> nameLineRow = [];
            
            if (isFirstLine && displayConfig?['showSLNumber']?.visible == true) {
              nameLineRow.add(PosColumn(
                  text: '#$slNumber',
                  width: 1,
                  styles: PosStyles(
                    align: PosAlign.left,
                    height: is58mm ? PosTextSize.size1 : PosTextSize.size1
                  )));
            } else if (!isFirstLine && displayConfig?['showSLNumber']?.visible == true) {
              // Empty space for SL column on continuation lines
              nameLineRow.add(PosColumn(
                  text: '',
                  width: 1,
                  styles: PosStyles(align: PosAlign.left)));
            }
            
            nameLineRow.add(PosColumn(
                text: currentLine,
                width: productNameWidth,
                styles: PosStyles(
                  align: PosAlign.left,
                  height: is58mm ? PosTextSize.size1 : PosTextSize.size1
                 )));
            
            bytes += generator.row(nameLineRow);
            isFirstLine = false;
          }
        }
      } else if (displayConfig?['showSLNumber']?.visible == true) {
        // Only SL number, no product name - fill the row to width 12
        productNameRow.add(PosColumn(
            text: '#$slNumber',
            width: 1,
            styles: PosStyles(
              align: PosAlign.left,
              height: is58mm ? PosTextSize.size1 : PosTextSize.size1
            )));
        productNameRow.add(PosColumn(
            text: '',
            width: 11,
            styles: PosStyles(align: PosAlign.left)));
        bytes += generator.row(productNameRow);
      }
      
      // Second row: Price details with new width specifications
      List<PosColumn> priceDetailsRow = [];
      
      // Add empty space for SL column (width 1)
      if (displayConfig?['showSLNumber']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: '',
            width: 1,
            styles: PosStyles(align: PosAlign.left)));
      }
      
      // Add price columns with new exact widths
      if (displayConfig?['showMRP']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: mrp,
            width: 3,
            styles: PosStyles(
              align: PosAlign.right,
              height: is58mm ? PosTextSize.size1 : PosTextSize.size1
            )));
      }
      if (displayConfig?['showQty']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: quantity,
            width: 2,
            styles: PosStyles(
              align: PosAlign.right,
              height: is58mm ? PosTextSize.size1 : PosTextSize.size1
            )));
      }
      if (displayConfig?['showRate']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: unitPrice,
            width: 3,
            styles: PosStyles(
              align: PosAlign.right,
              height: is58mm ? PosTextSize.size1 : PosTextSize.size1
            )));
      }
      if (displayConfig?['showTotal']?.visible == true) {
        priceDetailsRow.add(PosColumn(
            text: totalPrice,
            width: 3,
            styles: PosStyles(
              align: PosAlign.right,
              height: is58mm ? PosTextSize.size1 : PosTextSize.size1
            )));
      }
      
      if (priceDetailsRow.isNotEmpty) {
        bytes += generator.row(priceDetailsRow);
      }
      
      // Remove the empty line separator between items to eliminate spacing
      // bytes += generator.emptyLines(1);
    }

    bytes += generator.hr();
    return bytes;
  }

  // Modify _buildTotalAmount to use DisplayConfiguration and DocumentConfig
  List<int> _buildTotalAmount(
      Generator generator,
      Map<String, DisplayOption>? displayConfig,
      String formattedTotal,
      String? savedTotal,
      int itemCount) {
    List<int> bytes = [];

    double saved = double.tryParse(savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(formattedTotal) ?? 0.0;
    double totalMrp = saved + total;

    // Display Item Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      bytes += generator.row([
        PosColumn(
            text: 'Items',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: itemCount.toString(),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    // Display Total MRP
    if (displayConfig?['showMRPTotal']?.visible == true) {
      bytes += generator.row([
        PosColumn(
            text: 'Total MRP',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: totalMrp.toStringAsFixed(2),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    // Display You Saved / Discount
    if (displayConfig?['showSaved']?.visible == true) {
      bytes += generator.row([
        PosColumn(
            text:
                'You Saved', // Or 'Discount' based on resolved_labels if available
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: saved.toStringAsFixed(2),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    } else if (displayConfig?['showDiscount']?.visible == true) {
      // If showDiscount is true but showSaved is false, use a generic Discount label
      bytes += generator.row([
        PosColumn(
            text: 'Discount',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: saved.toStringAsFixed(2),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    // Display Net Total (Amount)
    if (displayConfig?['showNetAmount']?.visible == true) {
      // Use resolved_labels for label if available, otherwise 'Net Total' or 'Amount'
      final label =
          _billDocumentConfig?.resolvedLabels?.amountName ?? 'Net Total';
      bytes += generator.row([
        PosColumn(
            text: label,
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size2)),
        PosColumn(
            text: total.toStringAsFixed(2),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size2)),
      ]);
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
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr(); // Add HR after amount in words
    }

    return bytes;
  }

  // Modify _buildThankYouMessage to use DisplayConfiguration
  List<int> _buildThankYouMessage(
      Generator generator, Map<String, DisplayOption>? displayConfig) {
    List<int> bytes = [];

    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final message = displayConfig?['showThankYouMessage']?.value as String? ??
          'Thank You... Visit Again';
      bytes += generator.text(
          message.isNotEmpty ? message : 'Thank You... Visit Again',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.hr(); // Add HR after thank you message
    }

    return bytes;
  }

  // Modify _buildQRCode to use DisplayConfiguration and received data
  List<int> _buildQRCode(
      Generator generator,
      String qrCodeLinkTemplate, // Renamed to indicate it's a template
      String formattedTotal,
      String orderNumber,
      Map<String, DisplayOption>? displayConfig) {
    if (displayConfig?['showQRCode']?.visible != true) {
      debugPrint("QR Code disabled in settings, skipping");
      return [];
    }

    debugPrint("Generating QR code (enabled in settings)");

    List<int> bytes = [];

    bytes += generator.emptyLines(1);

    // Use the provided QR code link template, total, and order number
    // Replace placeholders in the template string
    final qrData = qrCodeLinkTemplate
        .replaceAll('{formattedTotal}', formattedTotal)
        .replaceAll('{orderNumber}', orderNumber);

    bytes += generator.qrcode(
      qrData,
      size: QRSize.Size4,
      align: PosAlign.center,
    );

    bytes += generator.emptyLines(1);

    final qrCodeMessage = displayConfig?['showQRCode']?.value as String? ??
        'Scan this QR code to Pay';
    bytes += generator.text(
        qrCodeMessage.isNotEmpty ? qrCodeMessage : 'Scan this QR code to Pay',
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.emptyLines(1);
    return bytes;
  }

  // Modify _buildTermsConditions to use DisplayConfiguration and DocumentConfig
  List<int> _buildTermsConditions(
      Generator generator, Map<String, DisplayOption>? displayConfig) {
    if (displayConfig?['showTermsConditions']?.visible != true) {
      debugPrint("Terms & Conditions disabled in settings, skipping");
      return [];
    }

    // Only show terms if actual data is available from API
    String? terms = _billDocumentConfig?.terms;
    if (terms == null || terms.trim().isEmpty) {
      debugPrint("No Terms & Conditions data available from API, skipping");
      return [];
    }

    debugPrint("Generating Terms & Conditions (enabled in settings with data)");

    List<int> bytes = [];

    // Add header text based on displayConfig value or default
    final termsHeader =
        displayConfig?['showTermsConditions']?.value as String? ??
            'Terms & Conditions';
    bytes += generator.text(
        termsHeader.isNotEmpty ? termsHeader : 'Terms & Conditions',
        styles: const PosStyles(bold: true, align: PosAlign.left));

    // Use the terms from DocumentConfig (already validated as non-empty)
    List<String> termsList = terms.split('\n');
    for (var term in termsList) {
      if (term.trim().isNotEmpty) {
        bytes +=
            generator.text(term, styles: const PosStyles(align: PosAlign.left));
      }
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

    // Ensure _billDocumentConfig is loaded before printing
    if (_billDocumentConfig == null) {
      debugPrint("ERROR: Bill document configuration not loaded yet.");
      if (mounted) {
        // showScaffoldError(
        //   context: context,
        //   message: "Document configurations not loaded. Please wait.",
        // );
      }
      return;
    }

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
      // Ensure _billDocumentConfig is loaded before printing
      if (_billDocumentConfig == null) {
        debugPrint("ERROR: Bill document configuration not loaded yet.");
        if (mounted) {
          showScaffoldError(
            context: context,
            message: "Document configurations not loaded. Please wait.",
          );
        }
        return;
      }

      // Check if printer is selected before proceeding
      if (selectedPrinter == null) {
        debugPrint("ERROR: No printer selected for printing");
        if (mounted) {
          showScaffoldError(
            context: context,
            message: "No Printer Selected",
          );
        }
        return;
      }

      final displayConfig = _billDocumentConfig?.displayConfiguration?.options;
      _debugPrintTemplateSettings(displayConfig); // Updated debug print

      if (mounted) {
        showScaffold(
          context: context,
          message: "Preparing ${selectedPaperSize} document for printing...",
        );
      }

      // Create a PDF document
      final pdf = pw.Document();

      // Get settings from the loaded display configuration
      final updatedSettings = displayConfig; // Directly use the loaded config

      debugPrint("PDF Generation - Using user settings:");
      debugPrint(
          "showStoreName: ${updatedSettings?['showStoreName']?.visible}");
      debugPrint(
          "showDescription: ${updatedSettings?['showDescription']?.visible}");
      debugPrint(
          "showStoreAddress: ${updatedSettings?['showStoreAddress']?.visible}");
      debugPrint(
          "showFssaiInfo: ${updatedSettings?['showFssaiInfo']?.visible}");
      debugPrint("showTel: ${updatedSettings?['showTel']?.visible}");
      debugPrint("showEmail: ${updatedSettings?['showEmail']?.visible}");
      debugPrint(
          "showInvoiceTitle: ${updatedSettings?['showInvoiceTitle']?.visible}");
      debugPrint(
          "showInvoiceNumber: ${updatedSettings?['showInvoiceNumber']?.visible}");
      debugPrint(
          "showDateHeader: ${updatedSettings?['showDateHeader']?.visible}");
      debugPrint("showSLNumber: ${updatedSettings?['showSLNumber']?.visible}");
      debugPrint(
          "showParticulars: ${updatedSettings?['showParticulars']?.visible}");
      debugPrint("showMRP: ${updatedSettings?['showMRP']?.visible}");
      debugPrint("showQty: ${updatedSettings?['showQty']?.visible}");
      debugPrint("showRate: ${updatedSettings?['showRate']?.visible}");
      debugPrint("showTotal: ${updatedSettings?['showTotal']?.visible}");
      debugPrint("showDiscount: ${updatedSettings?['showDiscount']?.visible}");
      debugPrint(
          "showNetAmount: ${updatedSettings?['showNetAmount']?.visible}");
      debugPrint("showMRPTotal: ${updatedSettings?['showMRPTotal']?.visible}");
      debugPrint("showSaved: ${updatedSettings?['showSaved']?.visible}");
      debugPrint(
          "showAmountInWords: ${updatedSettings?['showAmountInWords']?.visible}");
      debugPrint(
          "showItemsCount: ${updatedSettings?['showItemsCount']?.visible}");
      debugPrint(
          "showThankYouMessage: ${updatedSettings?['showThankYouMessage']?.visible}");
      debugPrint("showQRCode: ${updatedSettings?['showQRCode']?.visible}");
      debugPrint(
          "showTermsConditions: ${updatedSettings?['showTermsConditions']?.visible}");

      // Access Payment Gateways Provider for QR code link
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
        fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0, // Reduced from 7.0/10.0 to 6.0/8.0
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
                      if (updatedSettings?['showStoreName']?.visible == true)
                        pw.Text(
                          updatedSettings?['showStoreName']?.value as String? ??
                              _billDocumentConfig?.header ??
                              'STORE NAME',
                          style: headerStyle,
                        ),

                      // Store description (subheader from DocumentConfig or value from displayConfig)
                      if (updatedSettings?['showDescription']?.visible == true)
                        pw.Text(
                          updatedSettings?['showDescription']?.value
                                  as String? ??
                              _billDocumentConfig?.subheader ??
                              'Mini Supermarket',
                          style: pw.TextStyle(
                            fontSize: selectedPaperSize == 'A5' ? 10.0 : 12.0,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),

                      // Store address - Only show if data is available
                      if (updatedSettings?['showStoreAddress']?.visible == true) ...[
                        if ((updatedSettings?['showStoreAddress']?.value as String?)?.isNotEmpty == true)
                          pw.Text(
                            updatedSettings!['showStoreAddress']!.value as String,
                            style: bodyStyle,
                          ),
                      ],

                      // FSSAI info - Only show if data is available
                      if (updatedSettings?['showFssaiInfo']?.visible == true) ...[
                        if ((updatedSettings?['showFssaiInfo']?.value as String?)?.isNotEmpty == true)
                          pw.Text(
                            updatedSettings!['showFssaiInfo']!.value as String,
                            style: bodyStyle,
                          ),
                      ],

                      // Contact information (Tel and Email)
                      if (updatedSettings?['showTel']?.visible == true)
                        pw.Text(
                          updatedSettings?['showTel']?.value as String? ??
                              customerCareNumber,
                          style: bodyStyle,
                        ),

                      if (updatedSettings?['showEmail']?.visible == true)
                        pw.Text(
                          updatedSettings?['showEmail']?.value as String? ??
                              customerCareEmail,
                          style: bodyStyle,
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Invoice information in a framed box
                if ((updatedSettings?['showInvoiceTitle']?.visible == true) ||
                    (updatedSettings?['showInvoiceNumber']?.visible == true))
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
                            if (updatedSettings?['showInvoiceTitle']?.visible ==
                                true)
                              pw.Text(
                                  updatedSettings?['showInvoiceTitle']?.value
                                          as String? ??
                                      _billDocumentConfig?.header ??
                                      'INVOICE',
                                  style: subheaderStyle),
                            if (updatedSettings?['showInvoiceNumber']
                                    ?.visible ==
                                true)
                              // Use numberPrefix from DocumentConfig if available
                              pw.Text(
                                  (_billDocumentConfig?.numberPrefix != null &&
                                          _billDocumentConfig!
                                              .numberPrefix!.isNotEmpty)
                                      ? '${_billDocumentConfig!.numberPrefix}${widget.orderNumber}'
                                      : 'No: ${widget.orderNumber}',
                                  style: subheaderStyle),
                          ],
                        ),
                        if (updatedSettings?['showDateHeader']?.visible ==
                            true) ...[
                          // Assuming showDateHeader controls date in PDF header box
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
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
                if ((updatedSettings?['showSLNumber']?.visible == true) ||
                    (updatedSettings?['showParticulars']?.visible == true) ||
                    (updatedSettings?['showMRP']?.visible == true) ||
                    (updatedSettings?['showQty']?.visible == true) ||
                    (updatedSettings?['showRate']?.visible == true) ||
                    (updatedSettings?['showTotal']?.visible ==
                        true)) // Only show item details section if any item columns are visible
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
                        _buildPdfItemsTable(tableHeaderStyle, bodyStyle,
                            updatedSettings), // Pass displayConfig
                      ],
                    ),
                  ),

                pw.SizedBox(height: 15),

                // Summary in a framed box
                if ((updatedSettings?['showItemsCount']?.visible == true) ||
                    (updatedSettings?['showMRPTotal']?.visible == true) ||
                    (updatedSettings?['showSaved']?.visible == true) ||
                    (updatedSettings?['showDiscount']?.visible == true) ||
                    (updatedSettings?['showNetAmount']?.visible ==
                        true)) // Only show summary section if any summary items are visible
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
                        _buildPdfSummary(
                            bodyStyle, updatedSettings), // Pass displayConfig
                      ],
                    ),
                  ),

                pw.SizedBox(height: 10),

                // Amount in words
                if (updatedSettings?['showAmountInWords']?.visible == true)
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
                    if (updatedSettings?['showThankYouMessage']?.visible ==
                        true)
                      pw.Center(
                        child: pw.Text(
                          updatedSettings?['showThankYouMessage']?.value
                                  as String? ??
                              'Thank You... Visit Again',
                          style: subheaderStyle,
                        ),
                      ),

                    pw.SizedBox(height: 10),

                    // QR Code for payment - Only show if enabled in settings
                    if (updatedSettings?['showQRCode']?.visible == true) ...[
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: manualPaymentGateway
                                  .link // Use the link from PaymentGatewaysProvider
                                  .replaceAll(
                                      '{formattedTotal}', widget.formattedTotal)
                                  .replaceAll(
                                      '{orderNumber}', widget.orderNumber),
                              width: selectedPaperSize == 'A5' ? 100 : 120,
                              height: selectedPaperSize == 'A5' ? 100 : 120,
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              updatedSettings?['showQRCode']?.value
                                      as String? ??
                                  'Scan to Pay',
                              style: pw.TextStyle(
                                fontSize:
                                    selectedPaperSize == 'A5' ? 9.0 : 11.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),
                    ],

                    // Terms & Conditions - Only show if enabled and data is available
                    if (updatedSettings?['showTermsConditions']?.visible == true) ...[
                      // Only show if actual terms data is available
                      if (_billDocumentConfig?.terms != null && _billDocumentConfig!.terms!.trim().isNotEmpty) ...[
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Terms & Conditions:', // Fixed label
                                style: pw.TextStyle(
                                    fontSize:
                                        selectedPaperSize == 'A5' ? 7.0 : 10.0,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 5),
                            ..._buildTermsConditionsList(
                                updatedSettings?['showTermsConditions']?.value
                                        as String? ??
                                    _billDocumentConfig!.terms!,
                                smallStyle),
                          ],
                        ),
                        pw.SizedBox(height: 10),
                      ],
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
              if (mounted) {
                showScaffold(
                    context: context, message: "PDF created successfully");
                Navigator.pop(context);
                SideBarController sideBarController =
                    Get.put(SideBarController());
                sideBarController.index.value = 46;
              }
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
          debugPrint("Error opening PDF: ${e.toString()}");
          if (!isWindows) {
            await _sharePdfFallback(file);
          } else {
            if (mounted) {
              showScaffold(
                  context: context, message: "PDF created successfully");
              Navigator.pop(context);
              SideBarController sideBarController =
                  Get.put(SideBarController());
              sideBarController.index.value = 46;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error generating PDF: ${e.toString()}");
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
      debugPrint("Error sharing PDF fallback: ${e.toString()}");
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

  // Modify _buildPdfItemsTable to use DisplayConfiguration and DocumentConfig
  pw.Widget _buildPdfItemsTable(pw.TextStyle headerStyle,
      pw.TextStyle contentStyle, Map<String, DisplayOption>? displayConfig) {
    // Create headers for the table based on visibility and resolved labels
    final List<String> tableHeaders = [];
    final Map<int, pw.Alignment> cellAlignmentsMap = {};
    final List<double> columnWidths = [];
    int visibleColIndex = 0;

    if (displayConfig?['showSLNumber']?.visible == true) {
      tableHeaders.add('SL#');
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(1); // Smaller width for serial number
    }
    if (displayConfig?['showParticulars']?.visible == true) {
      final label =
          _billDocumentConfig?.resolvedLabels?.itemName ?? 'PARTICULARS';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerLeft;
      columnWidths.add(
          5); // Much larger width for product names to accommodate long names
    }
    if (displayConfig?['showMRP']?.visible == true) {
      tableHeaders.add('MRP');
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showQty']?.visible == true) {
      final label = _billDocumentConfig?.resolvedLabels?.unitName ?? 'QTY';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Compact for quantity
    }
    if (displayConfig?['showRate']?.visible == true) {
      final label = _billDocumentConfig?.resolvedLabels?.priceName ?? 'RATE';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for price values
    }
    if (displayConfig?['showTotal']?.visible == true) {
      final label = _billDocumentConfig?.resolvedLabels?.amountName ?? 'TOTAL';
      tableHeaders.add(label.toUpperCase());
      cellAlignmentsMap[visibleColIndex++] = pw.Alignment.centerRight;
      columnWidths.add(1.5); // Slightly larger for total values
    }

    // Create table data based on visibility with smart product name handling
    List<List<String>> tableData = [];
    for (var i = 0; i < widget.cartItems.length; i++) {
      var item = widget.cartItems[i];

      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';

      if (widget.isFromLocalStorage) {
        productName = item['productName'] ?? '';
        mrp = (double.tryParse(item['mrp']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        quantity = item['quantity'] ?? '0';
        unitPrice = (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        totalPrice = (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
      } else {
        productName = item.productName ?? '';
        mrp = (double.tryParse(item.mrp?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
        totalPrice = (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);
      }

      // Smart product name handling for PDF - Let PDF table handle wrapping naturally
      String displayProductName =
          productName; // Use full product name without truncation

      // Remove the artificial character limit - let the PDF table handle text wrapping
      // The pw.Table.fromTextArray will automatically wrap long text within cells

      List<String> rowData = [];
      if (displayConfig?['showSLNumber']?.visible == true)
        rowData.add((i + 1).toString());
      if (displayConfig?['showParticulars']?.visible == true)
        rowData.add(displayProductName); // Use the full product name
      if (displayConfig?['showMRP']?.visible == true) rowData.add(mrp);
      if (displayConfig?['showQty']?.visible == true) rowData.add(quantity);
      if (displayConfig?['showRate']?.visible == true) rowData.add(unitPrice);
      if (displayConfig?['showTotal']?.visible == true) rowData.add(totalPrice);

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
      cellAlignments: cellAlignmentsMap, // Use the dynamically created map
      cellPadding: const pw.EdgeInsets.all(5),
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      columnWidths: Map.fromIterable(columnWidths.asMap().keys,
          key: (i) => i,
          value: (i) => pw.FlexColumnWidth(
              columnWidths[i])), // Use flex width based on defined widths
    );
  }

  // Modify _buildPdfSummary to use DisplayConfiguration and DocumentConfig
  pw.Widget _buildPdfSummary(
      pw.TextStyle style, Map<String, DisplayOption>? displayConfig) {
    double savedTotal = double.tryParse(widget.savedTotal ?? '0.0') ?? 0.0;
    double formattedTotal = double.tryParse(widget.formattedTotal) ?? 0.0;
    double totalMRP = savedTotal + formattedTotal;

    List<pw.Widget> summaryWidgets = [];

    // Display Item Count
    if (displayConfig?['showItemsCount']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total Items:', style: style), // Fixed label
            pw.Text(widget.cartItems.length.toString(), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    // Display Total MRP
    if (displayConfig?['showMRPTotal']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total MRP:', style: style), // Fixed label
            pw.Text(totalMRP.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    // Display You Saved / Discount
    if (displayConfig?['showSaved']?.visible == true) {
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('You Saved:', style: style), // Fixed label
            pw.Text(savedTotal.toStringAsFixed(2), style: style),
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    } else if (displayConfig?['showDiscount']?.visible == true) {
      // If showDiscount is true but showSaved is false, use a generic Discount label
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Discount:', style: style), // Fixed label
            pw.Text(savedTotal.toStringAsFixed(2),
                style: style), // Still using savedTotal for the value
          ],
        ),
      );
      summaryWidgets.add(pw.SizedBox(height: 5));
    }

    // Display Net Total (Amount)
    if (displayConfig?['showNetAmount']?.visible == true) {
      // Use resolved_labels for label if available, otherwise 'Net Total' or 'Amount'
      final label =
          _billDocumentConfig?.resolvedLabels?.amountName ?? 'Net Total';
      summaryWidgets.add(pw.Divider(color: PdfColors.grey300));
      summaryWidgets.add(pw.SizedBox(height: 5));
      summaryWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$label:',
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

  // _buildTermsConditionsList can remain largely the same, just use the terms string derived from DisplayConfiguration
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

    try {
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
        debugPrint("No saved paper size, saving default: $selectedPaperSize");
        // Save default paper size to preferences
        _saveDefaultPaperSize(selectedPaperSize);
      }
    } catch (e) {
      debugPrint("ERROR loading paper size preferences: $e");
      // Continue with default value
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

    // Removed call to reloadTemplateSettings() as it's no longer needed with direct config loading

    debugPrint("Paper size saved");
    debugPrint("===========================");
  }

  // Modify _debugPrintTemplateSettings to take display config
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

  // Removed reloadTemplateSettings method

  // Removed _updateSettingsForPaperSize method

  // Update _buildReceiptPreview to use _billDocumentConfig
  Widget _buildReceiptPreview() {
    // Use the loaded _billDocumentConfig instead of selectedTemplate
    final displayConfig = _billDocumentConfig?.displayConfiguration?.options;
    final docConfig =
        _billDocumentConfig; // Pass DocumentConfig for header/subheader defaults

    // If config is not loaded yet, show a loading indicator or empty container
    if (displayConfig == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
            if (displayConfig['showStoreName']?.visible == true)
              Text(
                displayConfig['showStoreName']?.value as String? ??
                    docConfig?.header ??
                    'STORE NAME',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            if (displayConfig['showDescription']?.visible == true)
              Text(
                displayConfig['showDescription']?.value as String? ??
                    docConfig?.subheader ??
                    'Your one-stop shop for all needs',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            if (displayConfig['showStoreAddress']?.visible == true)
              Text(
                displayConfig['showStoreAddress']?.value as String? ??
                    'Shop Address',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (displayConfig['showFssaiInfo']?.visible == true)
              Text(
                displayConfig['showFssaiInfo']?.value as String? ??
                    'Fssai: xxxx',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (displayConfig['showTel']?.visible == true)
              Text(
                displayConfig['showTel']?.value as String? ??
                    'TEL: ${appSettings?.customerCarePhone ?? ""}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (displayConfig['showEmail']?.visible == true)
              Text(
                displayConfig['showEmail']?.value as String? ??
                    'Email: ${appSettings?.customerCareEmail ?? ""}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),

            // Invoice Title and Number
            if (displayConfig['showInvoiceTitle']?.visible == true)
              Text(
                displayConfig['showInvoiceTitle']?.value as String? ??
                    docConfig?.header ??
                    'INVOICE',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            if (displayConfig['showInvoiceNumber']?.visible == true)
              Text(
                docConfig?.numberPrefix != null &&
                        docConfig!.numberPrefix!.isNotEmpty
                    ? '${docConfig.numberPrefix}12345' // Use a sample number for preview
                    : 'INV No: 12345',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            const Divider(),

            // Item details preview (simplified)
            if ((displayConfig['showSLNumber']?.visible == true) ||
                (displayConfig['showParticulars']?.visible == true) ||
                (displayConfig['showMRP']?.visible == true) ||
                (displayConfig['showQty']?.visible == true) ||
                (displayConfig['showRate']?.visible == true) ||
                (displayConfig['showTotal']?.visible == true))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${displayConfig['showSLNumber']?.visible == true ? '#SL' : ''} ${displayConfig['showParticulars']?.visible == true ? (_billDocumentConfig?.resolvedLabels?.itemName ?? 'PARTICULARS').toUpperCase() : ''} ${displayConfig['showMRP']?.visible == true ? 'MRP' : ''} ${displayConfig['showQty']?.visible == true ? (_billDocumentConfig?.resolvedLabels?.unitName ?? 'QTY').toUpperCase() : ''} ${displayConfig['showRate']?.visible == true ? (_billDocumentConfig?.resolvedLabels?.priceName ?? 'RATE').toUpperCase() : ''} ${displayConfig['showTotal']?.visible == true ? (_billDocumentConfig?.resolvedLabels?.amountName ?? 'TOTAL').toUpperCase() : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  const Divider(height: 4),
                  // Add a sample item row based on visible columns
                  Text(
                      '${displayConfig['showSLNumber']?.visible == true ? '1     ' : ''}${displayConfig['showParticulars']?.visible == true ? 'Sample Item      ' : ''}${displayConfig['showMRP']?.visible == true ? '10.00  ' : ''}${displayConfig['showQty']?.visible == true ? '2   ' : ''}${displayConfig['showRate']?.visible == true ? '5.00  ' : ''}${displayConfig['showTotal']?.visible == true ? '10.00' : ''}',
                      style: const TextStyle(fontSize: 12)),
                  const Divider(height: 4),
                ],
              ),

            // Summary preview (simplified)
            if ((displayConfig['showItemsCount']?.visible == true) ||
                (displayConfig['showMRPTotal']?.visible == true) ||
                (displayConfig['showSaved']?.visible == true) ||
                (displayConfig['showDiscount']?.visible == true) ||
                (displayConfig['showNetAmount']?.visible == true))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayConfig['showItemsCount']?.visible == true)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Items:', style: TextStyle(fontSize: 12)),
                        Text('5', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (displayConfig['showMRPTotal']?.visible == true)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Total MRP:', style: TextStyle(fontSize: 12)),
                        Text('120.00', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (displayConfig['showSaved']?.visible == true)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('You Saved:', style: TextStyle(fontSize: 12)),
                        Text('20.00', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (displayConfig['showDiscount']?.visible == true &&
                      displayConfig['showSaved']?.visible != true)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Discount:', style: TextStyle(fontSize: 12)),
                        Text('20.00', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (displayConfig['showNetAmount']?.visible == true) ...[
                    const Divider(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${_billDocumentConfig?.resolvedLabels?.amountName ?? 'Net Total'}:',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('100.00',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ],
              ),

            // Amount in words preview
            if (displayConfig['showAmountInWords']?.visible == true) ...[
              const SizedBox(height: 8),
              const Divider(),
              const Text(
                'Amount in words: One Hundred Only.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const Divider(),
            ],

            // Thank You message preview
            if (displayConfig['showThankYouMessage']?.visible == true)
              Text(
                displayConfig['showThankYouMessage']?.value as String? ??
                    'Thank You... Visit Again',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),

            // QR Code preview
            if (displayConfig['showQRCode']?.visible == true) ...[
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 80,
                color: Colors.grey[300], // Placeholder for QR code
                child: const Center(
                    child: Text('QR Code', style: TextStyle(fontSize: 10))),
              ),
              const SizedBox(height: 4),
              Text(
                displayConfig['showQRCode']?.value as String? ?? 'Scan to Pay',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],

            // Terms & Conditions preview
            if (displayConfig['showTermsConditions']?.visible == true) ...[
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      displayConfig['showTermsConditions']?.value as String? ??
                          'Terms & Conditions:',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    docConfig?.terms ??
                        '1. Replace or Return only within 7 Days...\n2. Replace only with Bill...',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              const Divider(),
            ],
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
