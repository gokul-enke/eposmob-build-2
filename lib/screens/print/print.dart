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
import 'package:pos_machine/providers/bank_provider.dart';
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
import 'package:pos_machine/screens/print/receipt_customer_segment.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/services/printer_permission_service.dart';
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
  final String? customerCrNumber;
  final String? customerType;
  final String? documentConfigType;
  final String? documentTitleOverride;
  final Map<String, dynamic>?
      paymentBreakdown; // Added for multi-payment support
  final bool isDefaultCustomer;
  final String? netExcTax;
  final double? apiTotalTax;

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
    this.customerCrNumber,
    this.customerType,
    this.documentConfigType,
    this.documentTitleOverride,
    this.paymentBreakdown,
    this.isDefaultCustomer = false,
    this.netExcTax,
    this.apiTotalTax,
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
    String? customerCrNumber,
    String? customerType,
    String? documentConfigType,
    String? documentTitleOverride,
    Map<String, dynamic>? paymentBreakdown,
    bool isDefaultCustomer = false,
    String? netExcTax,
    double? apiTotalTax,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isB2B = _isB2BForDocument(
        documentConfigType,
        customerType: customerType,
        customerVatNumber: customerVatNumber,
        customerCrNumber: customerCrNumber,
      );
      final printerPrefsKey =
          _printerPrefsKeyForDocument(documentConfigType, isB2B: isB2B);
      // B2B falls back to the legacy B2C printer when not separately configured.
      final defaultPrinterJson = prefs.getString(printerPrefsKey) ??
          prefs.getString('default_printer');

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
      final bankProvider = Provider.of<BankProvider>(context, listen: false);
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final appSettings = appSettingsProvider.appSettings;

      if (appSettings == null) {
        debugPrint('[PrintPage] App settings not loaded');
        return false;
      }

      // Get paper size
      String paperSize = prefs.getString(_paperSizePrefsKeyForDocument(
              documentConfigType,
              isB2B: isB2B)) ??
          prefs.getString('default_paper_size') ??
          '80mm';
      if (paperSize == 'Thermal') {
        paperSize = '80mm';
      }

      // Determine type based on paper size and orderReturns
      final hasReturns = orderReturns != null &&
          orderReturns.returnItems != null &&
          orderReturns.returnItems!.isNotEmpty;

      final billDocumentConfig = _resolveCachedDocumentConfig(
        docConfigProvider,
        documentConfigType: documentConfigType,
        hasReturns: hasReturns,
        paperSize: paperSize,
      );

      if (billDocumentConfig == null) {
        debugPrint(
            '[PrintPage] Document config not found in cache. Printing not possible.');
        return false;
      }

      debugPrint('[PrintPage] Using cached config: ${billDocumentConfig.type}');
      _debugInvoiceTitleConfig('autoPrint', billDocumentConfig);

      // Get receipt theme
      final theme = await _getReceiptThemeStatic(
        billDocumentConfig,
        prefs,
        documentConfigType: documentConfigType,
        isB2B: isB2B,
      );

      // Fetch ZATCA credentials
      final sharedPrefProvider = SharedPreferenceProvider();
      final zatcaVatNumber = await sharedPrefProvider.getZatcaVatNumber();
      final zatcaCompanyName = await sharedPrefProvider.getZatcaCompanyName();

      // Create params
      debugPrint(
          '[PrintPage.autoPrint] Creating ReceiptLayoutParams with ${cartItems.length} cart items');
      debugPrint(
          '[PrintPage.autoPrint] order=$orderNumber, customerType=${customerType ?? 'null'}, hasCustomerKyc=${(customerVatNumber?.trim().isNotEmpty ?? false) || (customerCrNumber?.trim().isNotEmpty ?? false)}, theme=$theme');
      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];
        debugPrint(
            '[PrintPage.autoPrint] Cart item $i: ${_cartItemName(item)}, qty=${_cartItemQuantity(item)}, total=${_cartItemTotal(item)}');
      }
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
        customerCrNumber: customerCrNumber,
        customerType: customerType,
        documentTitleOverride: documentTitleOverride,
        paymentBreakdown:
            _resolvePaymentBreakdown(context, paymentBreakdown, paymentMethod),
        zatcaVatNumber: zatcaVatNumber,
        zatcaCompanyName: zatcaCompanyName,
        isDefaultCustomer: isDefaultCustomer,
        hideDefaultCustomerPhone: appSettings.hideDefaultPhone,
        netExcTax: netExcTax,
        bankDetails: bankProvider.banks,
        storeName: storeName,
        storeLocation: storeSession.activeStore?.location,
        storePhone: storeSession.activeStore?.phone,
        storeEmail: storeSession.activeStore?.email,
        apiTotalTax: apiTotalTax,
      );
      final invoiceTitleConfig = params.displayConfig?['showInvoiceTitle'];
      debugPrint(
          '[PrintPage.autoPrint] documentTitleOverride=${documentTitleOverride ?? 'null'}, resolved showInvoiceTitle visible=${invoiceTitleConfig?.visible}, value=${invoiceTitleConfig?.value}');

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
    DocumentConfig? billDocumentConfig,
    SharedPreferences prefs, {
    String? documentConfigType,
    bool isB2B = false,
  }) async {
    final localTheme = prefs.getString(
            _themePrefsKeyForDocument(documentConfigType, isB2B: isB2B)) ??
        prefs.getString('billing_receipt_theme');

    if (localTheme != null && localTheme.isNotEmpty) {
      return localTheme;
    }

    final apiTheme = billDocumentConfig?.activeTheme;
    if (apiTheme != null && apiTheme.isNotEmpty) {
      return apiTheme;
    }

    return 'classic';
  }

  static void _debugInvoiceTitleConfig(
      String source, DocumentConfig billDocumentConfig) {
    final options = billDocumentConfig.displayConfiguration?.options;
    final normalTitle = options?['showInvoiceTitle'];
    final b2bTitle =
        options?['showInvoiceTitleB2B'] ?? options?['showInvoiceTitleB2b'];
    final b2bTitleKey = options?['showInvoiceTitleB2B'] != null
        ? 'showInvoiceTitleB2B'
        : (options?['showInvoiceTitleB2b'] != null
            ? 'showInvoiceTitleB2b'
            : 'missing');
    debugPrint(
        '[PrintPage.$source] documentConfig type=${billDocumentConfig.type}, activeTheme=${billDocumentConfig.activeTheme}, optionsCount=${options?.length ?? 0}');
    debugPrint(
        '[PrintPage.$source] showInvoiceTitle visible=${normalTitle?.visible}, value=${normalTitle?.value}, default=${normalTitle?.defaultValue}');
    debugPrint(
        '[PrintPage.$source] B2B invoice title key=$b2bTitleKey, exists=${b2bTitle != null}, visible=${b2bTitle?.visible}, value=${b2bTitle?.value}, default=${b2bTitle?.defaultValue}');
  }

  /// Ensures the payment breakdown handed to a layout is keyed by human-readable
  /// method names. When a caller only supplies the raw multi-payment JSON
  /// (`paymentMethod`) — common for locally-saved/offline orders — the method
  /// keys are numeric ids (e.g. "15"). We resolve those to names here, where a
  /// BuildContext + providers are available, so dynamic/extra methods (BANK,
  /// Cheque, Online Payment, ...) print by name on every layout.
  static Map<String, dynamic>? _resolvePaymentBreakdown(
    BuildContext context,
    Map<String, dynamic>? paymentBreakdown,
    String? paymentMethod,
  ) {
    if (paymentBreakdown != null && paymentBreakdown.isNotEmpty) {
      return paymentBreakdown;
    }
    final parsed = PaymentHelper.parseLocalMultiPayment(context, paymentMethod);
    if (parsed != null && parsed.paymentBreakdown.isNotEmpty) {
      return parsed.paymentBreakdown;
    }
    return paymentBreakdown;
  }

  static String _cartItemName(dynamic item) {
    String withVariant(String name, dynamic rawAttributes) {
      final attrs = _variantAttributeLabel(rawAttributes);
      if (attrs.isEmpty || name.contains('($attrs)')) {
        return name;
      }
      return name.trim().isEmpty ? attrs : '$name ($attrs)';
    }

    if (item is Map) {
      final name =
          (item['productName'] ?? item['product_name'] ?? '').toString();
      return withVariant(
        name,
        item['variant_attributes'] ?? item['variantAttributes'],
      );
    }
    try {
      final displayName = item.displayName?.toString();
      if (displayName != null && displayName.trim().isNotEmpty) {
        return displayName;
      }
    } catch (_) {}
    final name = item.productName?.toString() ?? '';
    try {
      return withVariant(name, item.variantAttributes);
    } catch (_) {
      return name;
    }
  }

  static String _variantAttributeLabel(dynamic rawAttributes) {
    dynamic attrs = rawAttributes;
    if (attrs is String) {
      final trimmed = attrs.trim();
      if (trimmed.isEmpty) return '';
      try {
        attrs = json.decode(trimmed);
      } catch (_) {
        return trimmed;
      }
    }
    if (attrs is Map) {
      return attrs.values
          .map((value) => value?.toString() ?? '')
          .where((value) => value.trim().isNotEmpty)
          .join(' | ');
    }
    return '';
  }

  static String _cartItemQuantity(dynamic item) {
    if (item is Map) {
      return (item['quantity'] ?? '').toString();
    }
    return item.quantity?.toString() ?? '';
  }

  static String _cartItemTotal(dynamic item) {
    if (item is Map) {
      return (item['totalPrice'] ?? item['total_price'] ?? '').toString();
    }
    return item.totalPrice?.toString() ?? '';
  }

  static DocumentConfig? _resolveCachedDocumentConfig(
    DocumentConfigProvider docConfigProvider, {
    String? documentConfigType,
    required bool hasReturns,
    String? paperSize,
  }) {
    final requestedType = documentConfigType?.trim();
    if (requestedType != null && requestedType.isNotEmpty) {
      if (_isStandardPaperSize(paperSize) &&
          requestedType.toLowerCase() == 'bill') {
        return docConfigProvider.getCachedConfig("Bill A4") ??
            docConfigProvider.getCachedConfig("bill_a4") ??
            docConfigProvider.getCachedConfig("bill-a4") ??
            docConfigProvider.getCachedConfig(requestedType);
      }
      return docConfigProvider.getCachedConfig(requestedType) ??
          docConfigProvider.getCachedConfig(requestedType.toLowerCase());
    }

    if (hasReturns) {
      if (_isStandardPaperSize(paperSize)) {
        return docConfigProvider.getCachedConfig("Sales and Return Bill A4") ??
            docConfigProvider.getCachedConfig("Sales and Return Bill") ??
            docConfigProvider.getCachedConfig("sales_and_return_bill");
      }
      return docConfigProvider.getCachedConfig("Sales and Return Bill") ??
          docConfigProvider.getCachedConfig("sales_and_return_bill");
    }

    if (_isStandardPaperSize(paperSize)) {
      return docConfigProvider.getCachedConfig("Bill A4") ??
          docConfigProvider.getCachedConfig("bill_a4") ??
          docConfigProvider.getCachedConfig("bill-a4") ??
          docConfigProvider.getCachedConfig("Bill") ??
          docConfigProvider.getCachedConfig("bill");
    }

    return docConfigProvider.getCachedConfig("Bill") ??
        docConfigProvider.getCachedConfig("bill");
  }

  static bool _isStandardPaperSize(String? paperSize) {
    return paperSize == 'A4' || paperSize == 'A5';
  }

  static bool _isQuotationDocument(String? documentConfigType) {
    return documentConfigType?.trim().toLowerCase() == 'quotation';
  }

  static String _printerPrefsKeyForDocument(String? documentConfigType,
      {bool isB2B = false}) {
    if (_isQuotationDocument(documentConfigType)) return 'quotation_printer';
    return isB2B ? 'default_printer_b2b' : 'default_printer';
  }

  static String _paperSizePrefsKeyForDocument(String? documentConfigType,
      {bool isB2B = false}) {
    if (_isQuotationDocument(documentConfigType)) return 'quotation_paper_size';
    return isB2B ? 'default_paper_size_b2b' : 'default_paper_size';
  }

  static String _themePrefsKeyForDocument(String? documentConfigType,
      {bool isB2B = false}) {
    if (_isQuotationDocument(documentConfigType)) {
      return 'quotation_receipt_theme';
    }
    return isB2B ? 'billing_receipt_theme_b2b' : 'billing_receipt_theme';
  }

  /// Whether this print job is for a business (B2B) customer.
  /// B2B settings fall back to the legacy B2C keys when not configured, so the
  /// segment only matters for the Billing document type.
  static bool _isB2BForDocument(
    String? documentConfigType, {
    String? customerType,
    String? customerVatNumber,
    String? customerCrNumber,
  }) {
    if (_isQuotationDocument(documentConfigType)) return false;
    return ReceiptCustomerSegment.isBusiness(
      customerType: customerType,
      vatNumber: customerVatNumber,
      crNumber: customerCrNumber,
    );
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

  /// Whether the current order is for a business (B2B) customer, used to route
  /// to the B2B printer / paper size / theme preferences.
  bool get _isB2B => PrintPage._isB2BForDocument(
        widget.documentConfigType,
        customerType: widget.customerType,
        customerVatNumber: widget.customerVatNumber,
        customerCrNumber: widget.customerCrNumber,
      );

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
    if (Platform.isAndroid) {
      final granted =
          await PrinterPermissionService.requestRequiredPermissions();
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
            'Allow Nearby devices and Location access to scan for printers. On Android 11 and older, Bluetooth scanning appears under Location.'),
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
    final defaultPrinterJson =
        prefs.getString(PrintPage._printerPrefsKeyForDocument(
              widget.documentConfigType,
              isB2B: _isB2B,
            )) ??
            prefs.getString('default_printer');

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
    await prefs.setString(
      PrintPage._printerPrefsKeyForDocument(widget.documentConfigType,
          isB2B: _isB2B),
      json.encode(printerData),
    );
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

      // Get current language from LocalizationService
      // final language = LocalizationService.locale.languageCode;

      // Determine type based on orderReturns
      final hasReturns = widget.orderReturns != null &&
          widget.orderReturns!.returnItems != null &&
          widget.orderReturns!.returnItems!.isNotEmpty;

      // Use cached config directly (NO API CALL - instant!)
      _billDocumentConfig = PrintPage._resolveCachedDocumentConfig(
        docConfigProvider,
        documentConfigType: widget.documentConfigType,
        hasReturns: hasReturns,
        paperSize: selectedPaperSize,
      );

      if (_billDocumentConfig == null) {
        debugPrint("WARNING: Document config not found in cache");
        // Try fallback names
        if (widget.documentConfigType?.trim().isNotEmpty == true) {
          final requestedType = widget.documentConfigType!.trim();
          _billDocumentConfig =
              docConfigProvider.getDocumentConfig(requestedType) ??
                  docConfigProvider.getDocumentConfig(
                    requestedType.toLowerCase(),
                  );
        } else {
          _billDocumentConfig = hasReturns
              ? docConfigProvider.getDocumentConfig("Sales and Return Bill")
              : docConfigProvider.getDocumentConfig("Bill");
        }
      } else {
        debugPrint(
            "✅ Document config loaded from cache: ${_billDocumentConfig?.type}");
      }
      if (_billDocumentConfig != null) {
        PrintPage._debugInvoiceTitleConfig(
            '_loadDocumentConfigurationsFromProvider', _billDocumentConfig!);
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

      final hasReturns = widget.orderReturns != null &&
          widget.orderReturns!.returnItems != null &&
          widget.orderReturns!.returnItems!.isNotEmpty;
      _billDocumentConfig = PrintPage._resolveCachedDocumentConfig(
        docConfigProvider,
        documentConfigType: widget.documentConfigType,
        hasReturns: hasReturns,
        paperSize: selectedPaperSize,
      );

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

    try {
      if (selectedPaperSize == '112mm' ||
          selectedPaperSize == '80mm' ||
          selectedPaperSize == '58mm') {
        await _printThermalReceipt(customerCareNumber, customerCareEmail);
      } else {
        await _generateAndPrintPDF(customerCareNumber, customerCareEmail);
      }
    } catch (e, stacktrace) {
      // Receipt layouts already show the actionable error. Catch it here so
      // automatic printing from this page does not create an unhandled Future.
      debugPrint('[PrintPage] Print failed: $e');
      debugPrint('Stacktrace: $stacktrace');
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
    final bankProvider = Provider.of<BankProvider>(context, listen: false);
    final storeSession =
        Provider.of<StoreSessionProvider>(context, listen: false);
    final bool hideDefaultCustomerPhone =
        appSettingsProvider.appSettings?.hideDefaultPhone ?? true;

    // Create params object for the layout
    debugPrint(
        '[PrintPage._printThermalReceipt] Cart items count: ${widget.cartItems.length}');
    for (int i = 0; i < widget.cartItems.length; i++) {
      final item = widget.cartItems[i];
      debugPrint(
          '[PrintPage._printThermalReceipt] Item $i: name=${PrintPage._cartItemName(item)}, qty=${PrintPage._cartItemQuantity(item)}, total=${PrintPage._cartItemTotal(item)}');
    }
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
      customerCrNumber: widget.customerCrNumber,
      customerType: widget.customerType,
      documentTitleOverride: widget.documentTitleOverride,
      paymentBreakdown: PrintPage._resolvePaymentBreakdown(
          context, widget.paymentBreakdown, widget.paymentMethod),
      zatcaVatNumber: zatcaVatNumber,
      zatcaCompanyName: zatcaCompanyName,
      isDefaultCustomer: widget.isDefaultCustomer,
      hideDefaultCustomerPhone: hideDefaultCustomerPhone,
      netExcTax: widget.netExcTax,
      bankDetails: bankProvider.banks,
      storeName: widget.storeName,
      storeLocation: storeSession.activeStore?.location,
      storePhone: storeSession.activeStore?.phone,
      storeEmail: storeSession.activeStore?.email,
      apiTotalTax: widget.apiTotalTax,
    );
    final invoiceTitleConfig = params.displayConfig?['showInvoiceTitle'];
    debugPrint(
        '[PrintPage._printThermalReceipt] order=${widget.orderNumber}, customerType=${widget.customerType ?? 'null'}, hasCustomerKyc=${(widget.customerVatNumber?.trim().isNotEmpty ?? false) || (widget.customerCrNumber?.trim().isNotEmpty ?? false)}, resolved showInvoiceTitle visible=${invoiceTitleConfig?.visible}, value=${invoiceTitleConfig?.value}');

    // Print using the selected layout
    await layout.printThermal(params);
  }

  /// Get receipt theme with priority: Local setting > API fallback
  Future<String> _getReceiptTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final localTheme = prefs.getString(PrintPage._themePrefsKeyForDocument(
          widget.documentConfigType,
          isB2B: _isB2B,
        )) ??
        prefs.getString('billing_receipt_theme');

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
    final bankProvider = Provider.of<BankProvider>(context, listen: false);
    final storeSession =
        Provider.of<StoreSessionProvider>(context, listen: false);
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
      customerCrNumber: widget.customerCrNumber,
      customerType: widget.customerType,
      documentTitleOverride: widget.documentTitleOverride,
      paymentBreakdown: PrintPage._resolvePaymentBreakdown(
          context, widget.paymentBreakdown, widget.paymentMethod),
      zatcaVatNumber: zatcaVatNumber,
      zatcaCompanyName: zatcaCompanyName,
      isDefaultCustomer: widget.isDefaultCustomer,
      hideDefaultCustomerPhone: hideDefaultCustomerPhone,
      netExcTax: widget.netExcTax,
      bankDetails: bankProvider.banks,
      storeName: widget.storeName,
      storeLocation: storeSession.activeStore?.location,
      storePhone: storeSession.activeStore?.phone,
      storeEmail: storeSession.activeStore?.email,
      apiTotalTax: widget.apiTotalTax,
    );
    final invoiceTitleConfig = params.displayConfig?['showInvoiceTitle'];
    debugPrint(
        '[PrintPage._generateAndPrintPDF] order=${widget.orderNumber}, customerType=${widget.customerType ?? 'null'}, hasCustomerKyc=${(widget.customerVatNumber?.trim().isNotEmpty ?? false) || (widget.customerCrNumber?.trim().isNotEmpty ?? false)}, resolved showInvoiceTitle visible=${invoiceTitleConfig?.visible}, value=${invoiceTitleConfig?.value}');

    // Print using the selected standard PDF layout
    await standardLayout.generateAndPrintPdf(params);
  }

  Future<void> _loadDefaultPaperSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPaperSize =
          prefs.getString(PrintPage._paperSizePrefsKeyForDocument(
                widget.documentConfigType,
                isB2B: _isB2B,
              )) ??
              prefs.getString('default_paper_size');

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
    await prefs.setString(
      PrintPage._paperSizePrefsKeyForDocument(widget.documentConfigType,
          isB2B: _isB2B),
      paperSize,
    );

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
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
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
            sideBarController.index.value = 90;
          },
        ),
        elevation: 0,
        backgroundColor: primaryColor,
      ),
      body: SafeArea(
        child: Container(
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
