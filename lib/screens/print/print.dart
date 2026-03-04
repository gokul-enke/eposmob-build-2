import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/layouts/layouts.dart';
import 'package:pos_machine/screens/print/standard_layouts/standard_layouts.dart';
// import 'package:pos_machine/resources/localization_service.dart';

class PrintPage extends StatefulWidget {
  final List<dynamic> cartItems;
  final String? storeName;
  final String formattedTotal;
  final String? savedTotal;
  final String? discountAmount;
  final String orderDate;
  final String orderNumber;
  final String? tokenNumber;
  final bool isFromLocalStorage;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final OrderReturns? orderReturns; // Add this line
  final double? customerOldBalance;
  final double? customerCurrentBalance;
  final double? paidAmount;
  final String? orderComment;
  final String? deliveryMethod;
  final String? customerAlternatePhone;
  final String? paymentMethod;
  final String? customerVatNumber;
  final Map<String, dynamic>?
      paymentBreakdown; // Added for multi-payment support
  final bool isDefaultCustomer;
  final String? netExcTax;

  const PrintPage({
    super.key,
    required this.cartItems,
    required this.formattedTotal,
    this.savedTotal,
    this.discountAmount,
    this.storeName,
    required this.orderDate,
    required this.orderNumber,
    this.tokenNumber,
    this.isFromLocalStorage = false,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.orderReturns, // Add this line
    this.customerOldBalance,
    this.customerCurrentBalance,
    this.paidAmount,
    this.orderComment,
    this.deliveryMethod,
    this.customerAlternatePhone,
    this.paymentMethod,
    this.customerVatNumber,
    this.paymentBreakdown,
    this.isDefaultCustomer = false,
    this.netExcTax,
  });

  @override
  _PrintPageState createState() => _PrintPageState();

  /// Auto-print with default printer without showing UI
  /// Returns true if printing succeeded, false if no printer or failed
  static Future<bool> autoPrint(
    BuildContext context, {
    required List<dynamic> cartItems,
    String? storeName,
    required String formattedTotal,
    String? savedTotal,
    String? discountAmount,
    required String orderDate,
    required String orderNumber,
    String? tokenNumber,
    bool isFromLocalStorage = false,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    OrderReturns? orderReturns,
    double? customerOldBalance,
    double? customerCurrentBalance,
    double? paidAmount,
    String? orderComment,
    String? deliveryMethod,
    String? customerAlternatePhone,
    String? paymentMethod,
    String? customerVatNumber,
    Map<String, dynamic>? paymentBreakdown,
    bool isDefaultCustomer = false,
    String? netExcTax,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPrinterJson = prefs.getString('default_printer');

      if (defaultPrinterJson == null) {
        debugPrint('[PrintPage] No default printer found');
        return false;
      }

      final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);
      final selectedPrinter = BluetoothPrinter(
        deviceName: printerData['deviceName'],
        address: printerData['address'],
        vendorId: printerData['vendorId'],
        productId: printerData['productId'],
        typePrinter: PrinterType.values.firstWhere(
          (e) => e.toString() == printerData['typePrinter'],
        ),
      );

      debugPrint(
          '[PrintPage] Auto-printing with default printer: ${selectedPrinter.deviceName}');

      // Load document config from cache (NO API CALL - instant!)
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final appSettings = appSettingsProvider.appSettings;

      if (appSettings == null) {
        debugPrint('[PrintPage] App settings not loaded');
        return false;
      }

      // Determine type based on orderReturns
      final hasReturns = orderReturns != null &&
          orderReturns.returnItems != null &&
          orderReturns.returnItems!.isNotEmpty;

      DocumentConfig? billDocumentConfig;

      // Try multiple config name patterns to find cached config
      if (hasReturns) {
        billDocumentConfig =
            docConfigProvider.getCachedConfig("Sales and Return Bill") ??
                docConfigProvider.getCachedConfig("sales_and_return_bill");
      } else {
        billDocumentConfig = docConfigProvider.getCachedConfig("Bill") ??
            docConfigProvider.getCachedConfig("bill");
      }

      if (billDocumentConfig == null) {
        debugPrint(
            '[PrintPage] Document config not found in cache. Printing not possible.');
        return false;
      }

      debugPrint('[PrintPage] Using cached config: ${billDocumentConfig.type}');

      // Get paper size
      String paperSize = prefs.getString('default_paper_size') ?? '80mm';
      if (paperSize == 'Thermal') {
        paperSize = '80mm';
      }

      // Get receipt theme
      final theme = await _getReceiptThemeStatic(billDocumentConfig, prefs);

      // Fetch ZATCA credentials
      final sharedPrefProvider = SharedPreferenceProvider();
      final zatcaVatNumber = await sharedPrefProvider.getZatcaVatNumber();
      final zatcaCompanyName = await sharedPrefProvider.getZatcaCompanyName();

      // Create params
      final params = ReceiptLayoutParams(
        context: context,
        selectedPrinter: selectedPrinter,
        cartItems: cartItems,
        formattedTotal: formattedTotal,
        savedTotal: savedTotal,
        discountAmount: discountAmount,
        orderDate: orderDate,
        orderNumber: orderNumber,
        tokenNumber: tokenNumber,
        isFromLocalStorage: isFromLocalStorage,
        selectedPaperSize: paperSize,
        billDocumentConfig: billDocumentConfig,
        customerCareNumber: appSettings.customerCarePhone,
        customerCareEmail: appSettings.customerCareEmail,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        orderReturns: orderReturns,
        customerOldBalance: customerOldBalance,
        customerCurrentBalance: customerCurrentBalance,
        paidAmount: paidAmount,
        orderComment: orderComment,
        deliveryMethod: deliveryMethod,
        customerAlternatePhone: customerAlternatePhone,
        paymentMethod: paymentMethod,
        customerVatNumber: customerVatNumber,
        paymentBreakdown: paymentBreakdown,
        zatcaVatNumber: zatcaVatNumber,
        zatcaCompanyName: zatcaCompanyName,
        isDefaultCustomer: isDefaultCustomer,
        hideDefaultCustomerPhone: appSettings.hideDefaultPhone,
        netExcTax: netExcTax,
      );

      // Print
      if (paperSize == '112mm' || paperSize == '80mm' || paperSize == '58mm') {
        final layout = ReceiptLayoutFactory.getLayout(theme);
        await layout.printThermal(params);
      } else {
        // Use StandardPdfLayoutFactory for A4/A5 printing
        final standardLayout = StandardPdfLayoutFactory.getLayout(theme);
        await standardLayout.generateAndPrintPdf(params);
      }

      debugPrint('[PrintPage] Auto-print successful');
      return true;
    } catch (e) {
      debugPrint('[PrintPage] Auto-print failed: $e');
      return false;
    }
  }

  static Future<String> _getReceiptThemeStatic(
      DocumentConfig? billDocumentConfig, SharedPreferences prefs) async {
    final localTheme = prefs.getString('billing_receipt_theme');

    if (localTheme != null && localTheme.isNotEmpty) {
      return localTheme;
    }

    final apiTheme = billDocumentConfig?.activeTheme;
    if (apiTheme != null && apiTheme.isNotEmpty) {
      return apiTheme;
    }

    return 'classic';
  }
}

class _PrintPageState extends State<PrintPage> {
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  BluetoothPrinter? selectedPrinter;
  bool _isScanning = false;
  bool _isLoading = true;
  String selectedPaperSize = '80mm';

  DocumentConfig? _billDocumentConfig;

  static const Color primaryColor = Color(0XFF3C92F5);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color textPrimaryColor = Color(0xFF2C3E50);
  static const Color textSecondaryColor = Color(0xFF7F8C8D);
  static const Color backgroundColor = Color(0xFFF5F6FA);

  final List<String> paperSizes = ['112mm', '80mm', '58mm', 'A5', 'A4'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      Provider.of<PaymentGatewaysProvider>(context, listen: false)
          .fetchPaymentGateways(accessToken: accessToken!);

      await _loadDefaultPaperSize();
      await _loadDocumentConfigurationsFromProvider();
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
    debugPrint(
        '[PrintPage] dispose(): canceling discovery subscription if any');
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    debugPrint('[PrintPage] _checkPermissions() called');
    if (await _requestPermissions()) {
      debugPrint('[PrintPage] Permissions granted. Proceeding to scan.');
      _scan();
    } else {
      debugPrint('[PrintPage] Permissions NOT granted. Showing dialog.');
      _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    debugPrint(
        '[PrintPage] _requestPermissions() platform(os)=${Platform.operatingSystem} theme=${Theme.of(context).platform}');
    if (Theme.of(context).platform == TargetPlatform.android) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      statuses.forEach((perm, status) {
        debugPrint(
            '[PrintPage] Permission ${perm.toString()} => ${status.toString()}');
      });

      final granted = statuses.values.every((status) => status.isGranted);
      debugPrint('[PrintPage] All permissions granted: $granted');
      return granted;
    }
    debugPrint(
        '[PrintPage] Non-Android platform; skipping runtime permission request.');
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
    if (_isScanning) {
      debugPrint(
          '[PrintPage] _scan() requested but a scan is already in progress. Ignoring.');
      return;
    }
    debugPrint(
        '[PrintPage] Starting scan... platform=${Platform.operatingSystem}');
    await _subscription?.cancel();
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      // Bluetooth discovery only on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('[PrintPage] Beginning Bluetooth discovery (isBle=false)');
        _subscription = printerManager
            .discovery(type: PrinterType.bluetooth, isBle: false)
            .listen((device) {
          debugPrint(
              '[PrintPage] BT device found: name=${device.name}, address=${device.address}');
          final printer = BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            typePrinter: PrinterType.bluetooth,
          );
          setState(() {
            devices.add(printer);
          });
        }, onError: (err) {
          debugPrint('[PrintPage] Bluetooth discovery error: $err');
        }, onDone: () {
          final btCount = devices
              .where((p) => p.typePrinter == PrinterType.bluetooth)
              .length;
          debugPrint(
              '[PrintPage] Bluetooth discovery done. Total BT devices: $btCount');
        }, cancelOnError: false);
      } else {
        debugPrint(
            '[PrintPage] Skipping Bluetooth discovery on desktop platform (${Platform.operatingSystem}).');
      }

      debugPrint('[PrintPage] Beginning USB discovery');
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        debugPrint(
            '[PrintPage] USB device found: name=${device.name}, vendorId=${device.vendorId}, productId=${device.productId}');
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
      debugPrint(
          '[PrintPage] USB discovery completed. Total devices now: ${devices.length}');
    } catch (e, st) {
      debugPrint('[PrintPage] Error during scanning: $e');
      debugPrint('[PrintPage] Stacktrace: $st');
    } finally {
      setState(() {
        _isScanning = false;
      });
      debugPrint('[PrintPage] Scan finished. devices.length=${devices.length}');
    }
  }

  Future<void> _loadDefaultPrinter() async {
    debugPrint(
        '[PrintPage] _loadDefaultPrinter() reading from SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    final defaultPrinterJson = prefs.getString('default_printer');

    if (defaultPrinterJson != null) {
      final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);

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
          '[PrintPage] Default printer loaded: name=${selectedPrinter?.deviceName}, address=${selectedPrinter?.address}, type=${selectedPrinter?.typePrinter}');

      if (selectedPrinter != null && _billDocumentConfig != null) {
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        final appSettings = appSettingsProvider.appSettings;
        if (appSettings != null) {
          _handlePrinting(
              appSettings.customerCarePhone, appSettings.customerCareEmail);
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      debugPrint('[PrintPage] No default printer found in SharedPreferences');
    }
  }

  Future<void> _saveDefaultPrinter(BluetoothPrinter printer) async {
    final prefs = await SharedPreferences.getInstance();
    final printerData = {
      'deviceName': printer.deviceName,
      'address': printer.address,
      'vendorId': printer.vendorId,
      'productId': printer.productId,
      'typePrinter': printer.typePrinter.toString(),
    };
    await prefs.setString('default_printer', json.encode(printerData));
  }

  void selectPrinter(BluetoothPrinter printer) {
    debugPrint(
        '[PrintPage] selectPrinter(): name=${printer.deviceName}, address=${printer.address}, type=${printer.typePrinter}');
    setState(() {
      selectedPrinter = printer;
    });

    _saveDefaultPrinter(printer);

    if (mounted) {
      showScaffold(
        context: context,
        message: "${printer.deviceName.toString()} Printer Selected",
      );
    }
  }

  Future<void> _loadDocumentConfigurationsFromProvider() async {
    try {
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      final accessToken = Provider.of<AuthModel>(context, listen: false).token;

      // Get current language from LocalizationService
      // final language = LocalizationService.locale.languageCode;

      // Determine type based on orderReturns
      final hasReturns = widget.orderReturns != null &&
          widget.orderReturns!.returnItems != null &&
          widget.orderReturns!.returnItems!.isNotEmpty;

      // Use cached config directly (NO API CALL - instant!)
      if (hasReturns) {
        _billDocumentConfig =
            docConfigProvider.getCachedConfig("Sales and Return Bill") ??
                docConfigProvider.getCachedConfig("sales_and_return_bill");
      } else {
        _billDocumentConfig = docConfigProvider.getCachedConfig("Bill") ??
            docConfigProvider.getCachedConfig("bill");
      }

      if (_billDocumentConfig == null) {
        debugPrint("WARNING: Document config not found in cache");
        // Try fallback names
        _billDocumentConfig = hasReturns
            ? docConfigProvider.getDocumentConfig("Sales and Return Bill")
            : docConfigProvider.getDocumentConfig("Bill");
      } else {
        debugPrint(
            "✅ Document config loaded from cache: ${_billDocumentConfig?.type}");
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("ERROR getting document configurations: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDocumentConfigurations(String accessToken) async {
    try {
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      debugPrint("Fetching document configurations from API with token...");
      await docConfigProvider.fetchDocumentConfigurations(
          accessToken: accessToken);

      // Check if orderReturns data is available and load appropriate config
      if (widget.orderReturns != null &&
          widget.orderReturns!.returnItems != null &&
          widget.orderReturns!.returnItems!.isNotEmpty) {
        debugPrint(
            "Order has returns, loading 'Sales Return Bill' configuration from API...");
        _billDocumentConfig =
            docConfigProvider.getDocumentConfig("Sales and Return Bill");

        if (_billDocumentConfig != null) {
          debugPrint(
              "SUCCESS: Sales Return Bill configuration loaded from API");
        } else {
          debugPrint(
              "Sales Return Bill not found, falling back to Bill configuration");
          _billDocumentConfig = docConfigProvider.getDocumentConfig("Bill");
        }
      } else {
        debugPrint("No returns, loading 'Bill' configuration from API...");
        _billDocumentConfig = docConfigProvider.getDocumentConfig("Bill");
      }

      if (_billDocumentConfig != null) {
        debugPrint("SUCCESS: Document configuration loaded from API");
      } else {
        debugPrint("ERROR: Document configuration still null after API fetch");
      }

      setState(() {
        _isLoading = false;
      });
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

  Future<void> _handlePrinting(
      String customerCareNumber, String customerCareEmail) async {
    debugPrint("[LOGO_DEBUG] _handlePrinting entry in print.dart");
    debugPrint("[LOGO_DEBUG] selectedPaperSize: $selectedPaperSize");

    if (_billDocumentConfig == null) {
      debugPrint("ERROR: Bill document configuration not loaded yet.");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Document configuration not loaded. Please try again.",
        );
      }
      return;
    }

    if (selectedPaperSize == '112mm' ||
        selectedPaperSize == '80mm' ||
        selectedPaperSize == '58mm') {
      await _printThermalReceipt(customerCareNumber, customerCareEmail);
    } else {
      await _generateAndPrintPDF(customerCareNumber, customerCareEmail);
    }
  }

  Future<void> _printThermalReceipt(
      String customerCareNumber, String customerCareEmail) async {
    // Get theme with priority: Local SharedPreferences > API fallback
    final theme = await _getReceiptTheme();
    final layout = ReceiptLayoutFactory.getLayout(theme);

    debugPrint("[PrintPage] Using receipt theme: $theme");

    // Fetch ZATCA credentials for Saudi Arabia e-invoicing
    final sharedPrefProvider = SharedPreferenceProvider();
    final zatcaVatNumber = await sharedPrefProvider.getZatcaVatNumber();
    final zatcaCompanyName = await sharedPrefProvider.getZatcaCompanyName();

    if (zatcaVatNumber != null && zatcaCompanyName != null) {
      debugPrint(
          "[PrintPage] ZATCA credentials found - VAT: $zatcaVatNumber, Company: $zatcaCompanyName");
    } else {
      debugPrint("[PrintPage] No ZATCA credentials found, using standard QR");
    }

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final bool hideDefaultCustomerPhone =
        appSettingsProvider.appSettings?.hideDefaultPhone ?? true;

    // Create params object for the layout
    final params = ReceiptLayoutParams(
      context: context,
      selectedPrinter: selectedPrinter!,
      cartItems: widget.cartItems,
      formattedTotal: widget.formattedTotal,
      savedTotal: widget.savedTotal,
      discountAmount: widget.discountAmount,
      orderDate: widget.orderDate,
      orderNumber: widget.orderNumber,
      tokenNumber: widget.tokenNumber,
      isFromLocalStorage: widget.isFromLocalStorage,
      selectedPaperSize: selectedPaperSize,
      billDocumentConfig: _billDocumentConfig!,
      customerCareNumber: customerCareNumber,
      customerCareEmail: customerCareEmail,
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      customerEmail: widget.customerEmail,
      customerAddress: widget.customerAddress,
      orderReturns: widget.orderReturns,
      customerOldBalance: widget.customerOldBalance,
      customerCurrentBalance: widget.customerCurrentBalance,
      paidAmount: widget.paidAmount,
      orderComment: widget.orderComment,
      deliveryMethod: widget.deliveryMethod,
      customerAlternatePhone: widget.customerAlternatePhone,
      paymentMethod: widget.paymentMethod,
      customerVatNumber: widget.customerVatNumber,
      paymentBreakdown: widget.paymentBreakdown,
      zatcaVatNumber: zatcaVatNumber,
      zatcaCompanyName: zatcaCompanyName,
      isDefaultCustomer: widget.isDefaultCustomer,
      hideDefaultCustomerPhone: hideDefaultCustomerPhone,
      netExcTax: widget.netExcTax,
    );

    // Print using the selected layout
    await layout.printThermal(params);
  }

  /// Get receipt theme with priority: Local setting > API fallback
  Future<String> _getReceiptTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final localTheme = prefs.getString('billing_receipt_theme');

    // Priority: Local setting takes precedence
    if (localTheme != null && localTheme.isNotEmpty) {
      debugPrint("[PrintPage] Using local theme preference: $localTheme");
      return localTheme;
    }

    // Fallback to API theme from document config
    final apiTheme = _billDocumentConfig?.activeTheme;
    if (apiTheme != null && apiTheme.isNotEmpty) {
      debugPrint("[PrintPage] Using API theme: $apiTheme");
      return apiTheme;
    }

    // Default to classic
    debugPrint("[PrintPage] No theme set, using default: classic");
    return 'classic';
  }

  Future<void> _generateAndPrintPDF(
      String customerCareNumber, String customerCareEmail) async {
    // Get theme with priority: Local SharedPreferences > API fallback
    final theme = await _getReceiptTheme();
    final standardLayout = StandardPdfLayoutFactory.getLayout(theme);

    debugPrint("[PrintPage] Using standard PDF theme: $theme");

    // Fetch ZATCA credentials for Saudi Arabia e-invoicing
    final sharedPrefProvider = SharedPreferenceProvider();
    final zatcaVatNumber = await sharedPrefProvider.getZatcaVatNumber();
    final zatcaCompanyName = await sharedPrefProvider.getZatcaCompanyName();

    if (zatcaVatNumber != null && zatcaCompanyName != null) {
      debugPrint(
          "[PrintPage] ZATCA credentials found for PDF - VAT: $zatcaVatNumber, Company: $zatcaCompanyName");
    } else {
      debugPrint(
          "[PrintPage] No ZATCA credentials found for PDF, using standard QR");
    }

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final bool hideDefaultCustomerPhone =
        appSettingsProvider.appSettings?.hideDefaultPhone ?? true;

    // Create params object for the layout
    final params = ReceiptLayoutParams(
      context: context,
      selectedPrinter: selectedPrinter!,
      cartItems: widget.cartItems,
      formattedTotal: widget.formattedTotal,
      savedTotal: widget.savedTotal,
      discountAmount: widget.discountAmount,
      orderDate: widget.orderDate,
      orderNumber: widget.orderNumber,
      tokenNumber: widget.tokenNumber,
      isFromLocalStorage: widget.isFromLocalStorage,
      selectedPaperSize: selectedPaperSize,
      billDocumentConfig: _billDocumentConfig!,
      customerCareNumber: customerCareNumber,
      customerCareEmail: customerCareEmail,
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      customerEmail: widget.customerEmail,
      customerAddress: widget.customerAddress,
      orderReturns: widget.orderReturns,
      customerOldBalance: widget.customerOldBalance,
      customerCurrentBalance: widget.customerCurrentBalance,
      paidAmount: widget.paidAmount,
      orderComment: widget.orderComment,
      deliveryMethod: widget.deliveryMethod,
      customerAlternatePhone: widget.customerAlternatePhone,
      paymentMethod: widget.paymentMethod,
      customerVatNumber: widget.customerVatNumber,
      paymentBreakdown: widget.paymentBreakdown,
      zatcaVatNumber: zatcaVatNumber,
      zatcaCompanyName: zatcaCompanyName,
      isDefaultCustomer: widget.isDefaultCustomer,
      hideDefaultCustomerPhone: hideDefaultCustomerPhone,
      netExcTax: widget.netExcTax,
    );

    // Print using the selected standard PDF layout
    await standardLayout.generateAndPrintPdf(params);
  }

  Future<void> _loadDefaultPaperSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPaperSize = prefs.getString('default_paper_size');

      if (defaultPaperSize != null) {
        setState(() {
          if (defaultPaperSize == 'Thermal') {
            selectedPaperSize = '80mm';
            _saveDefaultPaperSize('80mm');
          } else {
            selectedPaperSize = defaultPaperSize;
          }
        });
      } else {
        _saveDefaultPaperSize(selectedPaperSize);
      }
    } catch (e) {
      debugPrint("ERROR loading paper size preferences: $e");
    }
  }

  Future<void> _saveDefaultPaperSize(String paperSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_paper_size', paperSize);

    setState(() {
      selectedPaperSize = paperSize;
    });
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
            if (_billDocumentConfig == null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Loading document configuration...',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        String? accessToken =
                            Provider.of<AuthModel>(context, listen: false)
                                .token;
                        if (accessToken != null) {
                          await _loadDocumentConfigurations(accessToken);
                        }
                      },
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ElevatedButton.icon(
              onPressed: () {
                debugPrint("[LOGO_DEBUG] Print Receipt button pressed");
                if (selectedPrinter == null) {
                  debugPrint("[LOGO_DEBUG] No printer selected");
                  showScaffoldError(
                    context: context,
                    message: "Please select a printer first",
                  );
                  return;
                }
                if (_billDocumentConfig == null) {
                  debugPrint("[LOGO_DEBUG] _billDocumentConfig is null");
                  showScaffoldError(
                    context: context,
                    message:
                        "Document configuration not loaded. Please wait or try again.",
                  );
                  return;
                }
                debugPrint("[LOGO_DEBUG] Calling _handlePrinting");
                _handlePrinting(appSettings!.customerCarePhone,
                    appSettings.customerCareEmail);
              },
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
}
